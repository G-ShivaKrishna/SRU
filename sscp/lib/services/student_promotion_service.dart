import 'package:cloud_firestore/cloud_firestore.dart';

/// Service to handle student year/semester progression
class StudentPromotionService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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
      var results = snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
      
      // Client-side filter for year (handle both string and int)
      if (year != null) {
        results = results.where((student) {
          final studentYear = int.tryParse(student['year']?.toString() ?? '0') ?? 0;
          return studentYear == year;
        }).toList();
      }
      
      // Client-side filter for semester (treat missing/null as semester 1)
      if (semester != null) {
        results = results.where((student) {
          final studentSemester = int.tryParse(student['semester']?.toString() ?? '1') ?? 1;
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
  static Future<Map<String, dynamic>> promoteStudent(String hallTicketNumber) async {
    try {
      final docRef = _firestore.collection('students').doc(hallTicketNumber);
      final doc = await docRef.get();

      if (!doc.exists) {
        return {'success': false, 'message': 'Student not found'};
      }

      final data = doc.data()!;
      int currentYear = int.tryParse(data['year']?.toString() ?? '1') ?? 1;
      int currentSemester = int.tryParse(data['semester']?.toString() ?? '1') ?? 1;

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
        final studentSemester = int.tryParse(data['semester']?.toString() ?? '1') ?? 1;
        final status = data['status']?.toString() ?? 'active';
        return studentYear == fromYear && studentSemester == fromSemester && status != 'graduated';
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
  static Future<Map<String, dynamic>> demoteStudent(String hallTicketNumber) async {
    try {
      final docRef = _firestore.collection('students').doc(hallTicketNumber);
      final doc = await docRef.get();

      if (!doc.exists) {
        return {'success': false, 'message': 'Student not found'};
      }

      final data = doc.data()!;
      int currentYear = int.tryParse(data['year']?.toString() ?? '1') ?? 1;
      int currentSemester = int.tryParse(data['semester']?.toString() ?? '1') ?? 1;

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

      await docRef.update({
        'year': year,
        'semester': semester,
        'status': 'active',
        'lastModifiedAt': FieldValue.serverTimestamp(),
      });

      return {
        'success': true,
        'message': 'Student updated to Year $year, Semester $semester',
      };
    } catch (e) {
      return {'success': false, 'message': 'Error updating student: $e'};
    }
  }
}
