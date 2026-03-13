import 'package:cloud_firestore/cloud_firestore.dart';
import 'audit_log_service.dart';

/// Service to handle student year/semester progression
class StudentPromotionService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ─────────────────────────────────────────────────────────────────────────
  // Post-promotion side effects
  // Called after any promotion/demotion to:
  //  1. Archive current course registrations → studentCoursesHistory
  //  2. Delete active studentCourses docs for promoted students
  //  3. Remove mentorAssignments for affected batches
  //  4. Clear mentorName/Phone/Email from student docs
  //  5. Delete all coursePreferences (faculty must re-submit next semester)
  //  6. Set isActive=false on all facultyAssignments (admin re-assigns next sem)
  //  7. Delete all audit logs (clean slate for new semester)
  // ─────────────────────────────────────────────────────────────────────────
  static Future<void> runPostPromotionTasks({
    required List<String> rollNumbers,
    required List<String> batchNumbers,
    List<String>? departments,
  }) async {
    if (rollNumbers.isEmpty) return;
    try {
      print('🧹 Starting post-promotion cleanup...');

      // ── 1 & 2 · Archive + delete studentCourses ──────────────────────────
      const chunkSize = 30; // Firestore whereIn limit
      for (int i = 0; i < rollNumbers.length; i += chunkSize) {
        final chunk = rollNumbers.sublist(
            i, (i + chunkSize).clamp(0, rollNumbers.length));
        final snap = await _firestore
            .collection('studentCourses')
            .where('studentId', whereIn: chunk)
            .get();
        await _archiveAndDelete(snap.docs.cast<DocumentSnapshot>());
      }

      // ── 3 · Delete mentorAssignments for affected batches ─────────────────
      final mentorRefs = <DocumentReference>[];
      final normalizedDepartments =
          departments?.map((d) => d.trim().toUpperCase()).where((d) => d.isNotEmpty).toSet().toList() ?? const <String>[];
      for (final batchNum in batchNumbers) {
        if (batchNum.isEmpty) continue;
        final snap = await _firestore
            .collection('mentorAssignments')
            .where('batchNumber', isEqualTo: batchNum)
            .get();
        for (final doc in snap.docs) {
          final department =
              (doc.data()['department'] ?? '').toString().trim().toUpperCase();
          if (normalizedDepartments.isNotEmpty &&
              department.isNotEmpty &&
              !normalizedDepartments.contains(department)) {
            continue;
          }
          mentorRefs.add(doc.reference);
        }
      }
      if (mentorRefs.isNotEmpty) await _batchDelete(mentorRefs);

      // ── 4 · Clear mentor fields from student docs ─────────────────────────
      const studentChunk = 400;
      for (int i = 0; i < rollNumbers.length; i += studentChunk) {
        final chunk = rollNumbers.sublist(
            i, (i + studentChunk).clamp(0, rollNumbers.length));
        final wb = _firestore.batch();
        for (final roll in chunk) {
          wb.update(_firestore.collection('students').doc(roll), {
            'mentorName': FieldValue.delete(),
            'mentorPhone': FieldValue.delete(),
            'mentorEmail': FieldValue.delete(),
          });
        }
        await wb.commit();
      }

      // ── 5 · Reset faculty course preferences ─────────────────────────────
      final prefSnap = await _firestore.collection('coursePreferences').get();
      if (prefSnap.docs.isNotEmpty) {
        await _batchDelete(prefSnap.docs.map((d) => d.reference).toList());
      }

      // ── 6 · Deactivate all facultyAssignments ────────────────────────────
      // Set isActive=false so faculty cannot enter new attendance/marks
      // against old semester courses. Historical records are preserved.
      // Admin re-assigns faculty for the new semester via Faculty Assignment page.
      const faChunk = 400;
      final faSnap = await _firestore.collection('facultyAssignments').get();
      for (int i = 0; i < faSnap.docs.length; i += faChunk) {
        final chunk =
            faSnap.docs.sublist(i, (i + faChunk).clamp(0, faSnap.docs.length));
        final wb = _firestore.batch();
        for (final doc in chunk) {
          wb.update(doc.reference, {
            'isActive': false,
            'deactivatedAt': FieldValue.serverTimestamp(),
          });
        }
        await wb.commit();
      }

      // ── 7 · Delete all audit logs ─────────────────────────────────────────
      // Clean slate for new semester - old logs are no longer relevant
      print('🧹 Deleting all audit logs...');
      await AuditLogService().deleteAllAuditLogs();
      print('✅ Post-promotion cleanup completed');
    } catch (e) {
      // Side effects must not fail the promotion itself
      print('⚠️ Post-promotion cleanup error: $e');
    }
  }

  /// Helper: archive each doc into studentCoursesHistory, then delete original.
  /// Max 200 docs per call (2 writes/doc → 400 per Firestore batch).
  static Future<void> _archiveAndDelete(List<DocumentSnapshot> docs) async {
    const maxPerBatch = 200;
    for (int i = 0; i < docs.length; i += maxPerBatch) {
      final chunk = docs.sublist(i, (i + maxPerBatch).clamp(0, docs.length));
      final wb = _firestore.batch();
      for (final doc in chunk) {
        final data = doc.data() as Map<String, dynamic>;
        final histRef = _firestore.collection('studentCoursesHistory').doc();
        wb.set(histRef, {
          ...data,
          'archivedAt': FieldValue.serverTimestamp(),
          'originalDocId': doc.id,
        });
        wb.delete(doc.reference);
      }
      await wb.commit();
    }
  }

  /// Helper: delete a list of document references in batches of 400.
  static Future<void> _batchDelete(List<DocumentReference> refs) async {
    const maxPerBatch = 400;
    for (int i = 0; i < refs.length; i += maxPerBatch) {
      final chunk = refs.sublist(i, (i + maxPerBatch).clamp(0, refs.length));
      final wb = _firestore.batch();
      for (final ref in chunk) {
        wb.delete(ref);
      }
      await wb.commit();
    }
  }

  /// Get all students, optionally filtered by department and/or year
  /// Note: semester filtering is done client-side to handle students without semester field
  static Future<List<Map<String, dynamic>>> getStudents({
    String? department,
    int? year,
    int? semester,
    bool excludeGraduated = true,
  }) async {
    try {
      Query<Map<String, dynamic>> query = _firestore.collection('students');

      if (department != null && department.isNotEmpty) {
        query = query.where('department', isEqualTo: department);
      }
      // Don't filter by year in query either, as it might be stored as string or int

      final snapshot = await query.get();
      var results =
          snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();

      // Client-side filter for year (handle both string and int)
      if (year != null) {
        results = results.where((student) {
          final studentYear =
              int.tryParse(student['year']?.toString() ?? '0') ?? 0;
          return studentYear == year;
        }).toList();
      }

      // Client-side filter for semester (treat missing/null as semester 1)
      if (semester != null) {
        results = results.where((student) {
          final studentSemester =
              int.tryParse(student['semester']?.toString() ?? '1') ?? 1;
          return studentSemester == semester;
        }).toList();
      }

      // Exclude graduated students by default
      if (excludeGraduated) {
        results = results.where((student) {
          final status = student['status']?.toString() ?? 'active';
          return status != 'graduated';
        }).toList();
      }

      return results;
    } catch (e) {
      throw Exception('Error fetching students: $e');
    }
  }

  /// Get all unique departments from students collection
  static Future<List<String>> getDepartments() async {
    try {
      final snapshot = await _firestore.collection('students').get();
      final departments = <String>{};
      for (final doc in snapshot.docs) {
        final dept = doc.data()['department']?.toString() ?? '';
        if (dept.isNotEmpty) {
          departments.add(dept);
        }
      }
      return departments.toList()..sort();
    } catch (e) {
      throw Exception('Error fetching departments: $e');
    }
  }

  /// Promote a single student to next semester/year
  /// Semester 1 → Semester 2 (same year)
  /// Semester 2 → Semester 1 (next year)
  /// Year 4 Semester 2 → Graduated (year: 5, status: 'graduated')
  static Future<Map<String, dynamic>> promoteStudent(
      String hallTicketNumber) async {
    try {
      final docRef = _firestore.collection('students').doc(hallTicketNumber);
      final doc = await docRef.get();

      if (!doc.exists) {
        return {'success': false, 'message': 'Student not found'};
      }

      final data = doc.data()!;
      int currentYear = int.tryParse(data['year']?.toString() ?? '1') ?? 1;
      int currentSemester =
          int.tryParse(data['semester']?.toString() ?? '1') ?? 1;

      int newYear = currentYear;
      int newSemester = currentSemester;
      String? newStatus;

      if (currentSemester == 1) {
        // Semester 1 → Semester 2
        newSemester = 2;
      } else {
        // Semester 2 → Next Year, Semester 1
        newSemester = 1;
        newYear = currentYear + 1;

        if (newYear > 4) {
          newStatus = 'graduated';
        }
      }

      final updateData = <String, dynamic>{
        'year': newYear,
        'semester': newSemester,
        'lastPromotedAt': FieldValue.serverTimestamp(),
      };

      if (newStatus != null) {
        updateData['status'] = newStatus;
      }

      await docRef.update(updateData);

      // Run post-promotion side effects
      final batchNum = data['batchNumber']?.toString() ?? '';
      final department = data['department']?.toString() ?? '';
      await runPostPromotionTasks(
        rollNumbers: [hallTicketNumber],
        batchNumbers: batchNum.isNotEmpty ? [batchNum] : [],
        departments: department.isNotEmpty ? [department] : const [],
      );

      return {
        'success': true,
        'message': newStatus == 'graduated'
            ? 'Student marked as graduated'
            : 'Student promoted to Year $newYear, Semester $newSemester',
        'newYear': newYear,
        'newSemester': newSemester,
        'status': newStatus ?? 'active',
      };
    } catch (e) {
      return {'success': false, 'message': 'Error promoting student: $e'};
    }
  }

  /// Bulk promote all students in a specific year and semester
  /// Returns count of successfully promoted students
  /// Note: All filtering is done client-side to handle students with inconsistent field types
  static Future<Map<String, dynamic>> bulkPromoteStudents({
    required int fromYear,
    required int fromSemester,
    String? department,
  }) async {
    try {
      // Query by department only (if provided) - all other filtering is client-side
      Query<Map<String, dynamic>> query = _firestore.collection('students');

      if (department != null && department.isNotEmpty) {
        query = query.where('department', isEqualTo: department);
      }

      final snapshot = await query.get();

      // Filter client-side for year, semester, status
      final matchingDocs = snapshot.docs.where((doc) {
        final data = doc.data();
        final studentYear = int.tryParse(data['year']?.toString() ?? '0') ?? 0;
        final studentSemester =
            int.tryParse(data['semester']?.toString() ?? '1') ?? 1;
        final status = data['status']?.toString() ?? 'active';
        return studentYear == fromYear &&
            studentSemester == fromSemester &&
            status != 'graduated';
      }).toList();

      if (matchingDocs.isEmpty) {
        return {
          'success': true,
          'message': 'No students found matching criteria',
          'promoted': 0,
          'failed': 0,
        };
      }

      int promoted = 0;
      int failed = 0;
      final batch = _firestore.batch();

      int newYear = fromYear;
      int newSemester = fromSemester;
      String? newStatus;

      if (fromSemester == 1) {
        newSemester = 2;
      } else {
        newSemester = 1;
        newYear = fromYear + 1;
        if (newYear > 4) {
          newStatus = 'graduated';
        }
      }

      for (final doc in matchingDocs) {
        final updateData = <String, dynamic>{
          'year': newYear,
          'semester': newSemester,
          'lastPromotedAt': FieldValue.serverTimestamp(),
        };
        if (newStatus != null) {
          updateData['status'] = newStatus;
        }
        batch.update(doc.reference, updateData);
        promoted++;
      }

      await batch.commit();

      // Run post-promotion side effects for all promoted students
      final rollNums = matchingDocs.map((d) => d.id).toList();
      final batchNums = matchingDocs
          .map((d) => d.data()['batchNumber']?.toString() ?? '')
          .where((b) => b.isNotEmpty)
          .toSet()
          .toList();
      final departments = matchingDocs
          .map((d) => d.data()['department']?.toString() ?? '')
          .where((d) => d.isNotEmpty)
          .toSet()
          .toList();
      await runPostPromotionTasks(
        rollNumbers: rollNums,
        batchNumbers: batchNums,
        departments: departments,
      );

      return {
        'success': true,
        'message': newStatus == 'graduated'
            ? '$promoted students marked as graduated'
            : '$promoted students promoted to Year $newYear, Semester $newSemester',
        'promoted': promoted,
        'failed': failed,
        'toYear': newYear,
        'toSemester': newSemester,
      };
    } catch (e) {
      return {'success': false, 'message': 'Error in bulk promotion: $e'};
    }
  }

  /// Demote a student (rollback promotion)
  static Future<Map<String, dynamic>> demoteStudent(
      String hallTicketNumber) async {
    try {
      final docRef = _firestore.collection('students').doc(hallTicketNumber);
      final doc = await docRef.get();

      if (!doc.exists) {
        return {'success': false, 'message': 'Student not found'};
      }

      final data = doc.data()!;
      int currentYear = int.tryParse(data['year']?.toString() ?? '1') ?? 1;
      int currentSemester =
          int.tryParse(data['semester']?.toString() ?? '1') ?? 1;

      int newYear = currentYear;
      int newSemester = currentSemester;

      if (currentSemester == 2) {
        // Semester 2 → Semester 1
        newSemester = 1;
      } else {
        // Semester 1 → Previous Year, Semester 2
        if (currentYear > 1) {
          newYear = currentYear - 1;
          newSemester = 2;
        } else {
          return {
            'success': false,
            'message': 'Cannot demote: Student is already at Year 1, Semester 1'
          };
        }
      }

      await docRef.update({
        'year': newYear,
        'semester': newSemester,
        'status': 'active', // Reactivate if was graduated
        'lastDemotedAt': FieldValue.serverTimestamp(),
      });

      return {
        'success': true,
        'message': 'Student demoted to Year $newYear, Semester $newSemester',
        'newYear': newYear,
        'newSemester': newSemester,
      };
    } catch (e) {
      return {'success': false, 'message': 'Error demoting student: $e'};
    }
  }

  /// Bulk demote all students in a specific year and semester
  /// Returns count of successfully demoted students
  static Future<Map<String, dynamic>> bulkDemoteStudents({
    required int fromYear,
    required int fromSemester,
    String? department,
  }) async {
    try {
      // Cannot demote from Year 1, Semester 1
      if (fromYear == 1 && fromSemester == 1) {
        return {
          'success': false,
          'message': 'Cannot demote: Already at Year 1, Semester 1',
          'demoted': 0,
          'failed': 0,
        };
      }

      // Query by department only - all other filtering is client-side
      Query<Map<String, dynamic>> query = _firestore.collection('students');

      if (department != null && department.isNotEmpty) {
        query = query.where('department', isEqualTo: department);
      }

      final snapshot = await query.get();

      // Filter client-side for year, semester
      final matchingDocs = snapshot.docs.where((doc) {
        final data = doc.data();
        final studentYear = int.tryParse(data['year']?.toString() ?? '0') ?? 0;
        final studentSemester =
            int.tryParse(data['semester']?.toString() ?? '1') ?? 1;
        return studentYear == fromYear && studentSemester == fromSemester;
      }).toList();

      if (matchingDocs.isEmpty) {
        return {
          'success': true,
          'message': 'No students found matching criteria',
          'demoted': 0,
          'failed': 0,
        };
      }

      int demoted = 0;
      final batch = _firestore.batch();

      int newYear = fromYear;
      int newSemester = fromSemester;

      if (fromSemester == 2) {
        // Semester 2 → Semester 1
        newSemester = 1;
      } else {
        // Semester 1 → Previous Year, Semester 2
        newSemester = 2;
        newYear = fromYear - 1;
      }

      for (final doc in matchingDocs) {
        final updateData = <String, dynamic>{
          'year': newYear,
          'semester': newSemester,
          'status': 'active', // Reactivate if was graduated
          'lastDemotedAt': FieldValue.serverTimestamp(),
        };
        batch.update(doc.reference, updateData);
        demoted++;
      }

      await batch.commit();

      return {
        'success': true,
        'message':
            '$demoted students demoted to Year $newYear, Semester $newSemester',
        'demoted': demoted,
        'failed': 0,
        'toYear': newYear,
        'toSemester': newSemester,
      };
    } catch (e) {
      return {'success': false, 'message': 'Error in bulk demotion: $e'};
    }
  }

  /// Manually set a student's year and semester
  static Future<Map<String, dynamic>> setStudentYearSemester({
    required String hallTicketNumber,
    required int year,
    required int semester,
  }) async {
    try {
      if (year < 1 || year > 4) {
        return {'success': false, 'message': 'Year must be between 1 and 4'};
      }
      if (semester < 1 || semester > 2) {
        return {'success': false, 'message': 'Semester must be 1 or 2'};
      }

      final docRef = _firestore.collection('students').doc(hallTicketNumber);
      final doc = await docRef.get();

      if (!doc.exists) {
        return {'success': false, 'message': 'Student not found'};
      }

      final data = doc.data()!;
      await docRef.update({
        'year': year,
        'semester': semester,
        'status': 'active',
        'lastModifiedAt': FieldValue.serverTimestamp(),
        'lastPromotedAt': FieldValue.serverTimestamp(),
      });

      // Run post-promotion side effects
      final batchNum = data['batchNumber']?.toString() ?? '';
      final department = data['department']?.toString() ?? '';
      await runPostPromotionTasks(
        rollNumbers: [hallTicketNumber],
        batchNumbers: batchNum.isNotEmpty ? [batchNum] : [],
        departments: department.isNotEmpty ? [department] : const [],
      );

      return {
        'success': true,
        'message': 'Student updated to Year $year, Semester $semester',
      };
    } catch (e) {
      return {'success': false, 'message': 'Error updating student: $e'};
    }
  }
}
