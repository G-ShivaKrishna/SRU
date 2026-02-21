import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/faculty_assignment_model.dart';

class FacultyAssignmentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Collection references
  CollectionReference get _assignmentsCollection =>
      _firestore.collection('facultyAssignments');
  CollectionReference get _subjectsCollection =>
      _firestore.collection('subjects');
  CollectionReference get _facultyCollection =>
      _firestore.collection('faculty');
  CollectionReference get _studentsCollection =>
      _firestore.collection('students');
  CollectionReference get _coursePreferencesCollection =>
      _firestore.collection('coursePreferences');

  // ============ FACULTY COURSE PREFERENCES ============

  /// Get faculty's submitted course preferences
  /// Tries multiple matching strategies since preferences use Firebase Auth UID/email
  /// which may differ from faculty collection data
  /// Returns a list of preferred subjects for a faculty member
  Future<List<FacultyPreferredCourse>> getFacultyPreferences(String facultyId, {String? facultyEmail}) async {
    try {
      QuerySnapshot? snapshot;
      
      // Strategy 1: Try querying by exact email
      if (facultyEmail != null && facultyEmail.isNotEmpty) {
        snapshot = await _coursePreferencesCollection
            .where('facultyEmail', isEqualTo: facultyEmail)
            .get();
        
        // Try with email lowercased
        if (snapshot.docs.isEmpty) {
          snapshot = await _coursePreferencesCollection
              .where('facultyEmail', isEqualTo: facultyEmail.toLowerCase())
              .get();
        }
      }
      
      // Strategy 2: If email didn't work, try facultyId as-is
      if (snapshot == null || snapshot.docs.isEmpty) {
        snapshot = await _coursePreferencesCollection
            .where('facultyId', isEqualTo: facultyId)
            .get();
      }
      
      // Strategy 3: Search all preferences for email containing facultyId pattern
      // e.g., facultyId = "FAC0001" might match email "fac0001@university.edu"
      if (snapshot.docs.isEmpty) {
        final allPrefs = await _coursePreferencesCollection.get();
        final facultyIdLower = facultyId.toLowerCase();
        
        for (final doc in allPrefs.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final storedEmail = (data['facultyEmail'] ?? '').toString().toLowerCase();
          
          // Check if stored email contains the facultyId (e.g., fac0001@... matches FAC0001)
          if (storedEmail.isNotEmpty && storedEmail.contains(facultyIdLower)) {
            // Found a match - use this document
            final List<FacultyPreferredCourse> preferences = [];
            final courses = data['courses'] as List<dynamic>? ?? [];
            final acYear = data['acYear'] ?? '';
            final roundId = data['roundId'] ?? '';
            
            for (int i = 0; i < courses.length; i++) {
              final course = courses[i] as Map<String, dynamic>;
              preferences.add(FacultyPreferredCourse(
                code: course['code'] ?? '',
                name: course['name'] ?? '',
                department: course['dept'] ?? '',
                year: course['year'] ?? 0,
                semester: course['semester'] ?? '',
                subjectType: course['subjectType'] ?? 'Core',
                preferenceOrder: i + 1,
                acYear: acYear,
                roundId: roundId,
              ));
            }
            // Check other docs too for same faculty
            for (final otherDoc in allPrefs.docs) {
              if (otherDoc.id == doc.id) continue;
              final otherData = otherDoc.data() as Map<String, dynamic>;
              final otherEmail = (otherData['facultyEmail'] ?? '').toString().toLowerCase();
              if (otherEmail == storedEmail) {
                final otherCourses = otherData['courses'] as List<dynamic>? ?? [];
                final otherAcYear = otherData['acYear'] ?? '';
                final otherRoundId = otherData['roundId'] ?? '';
                for (int i = 0; i < otherCourses.length; i++) {
                  final course = otherCourses[i] as Map<String, dynamic>;
                  preferences.add(FacultyPreferredCourse(
                    code: course['code'] ?? '',
                    name: course['name'] ?? '',
                    department: course['dept'] ?? '',
                    year: course['year'] ?? 0,
                    semester: course['semester'] ?? '',
                    subjectType: course['subjectType'] ?? 'Core',
                    preferenceOrder: i + 1,
                    acYear: otherAcYear,
                    roundId: otherRoundId,
                  ));
                }
              }
            }
            return preferences;
          }
          
          // Also try matching email prefix with facultyEmail prefix
          if (facultyEmail != null && facultyEmail.contains('@')) {
            final emailPrefix = facultyEmail.split('@')[0].toLowerCase();
            if (storedEmail.isNotEmpty && storedEmail.split('@')[0] == emailPrefix) {
              snapshot = await _coursePreferencesCollection
                  .where('facultyEmail', isEqualTo: data['facultyEmail'])
                  .get();
              break;
            }
          }
        }
      }

      if (snapshot == null || snapshot.docs.isEmpty) return [];

      final List<FacultyPreferredCourse> preferences = [];
      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final courses = data['courses'] as List<dynamic>? ?? [];
        final acYear = data['acYear'] ?? '';
        final roundId = data['roundId'] ?? '';
        
        for (int i = 0; i < courses.length; i++) {
          final course = courses[i] as Map<String, dynamic>;
          preferences.add(FacultyPreferredCourse(
            code: course['code'] ?? '',
            name: course['name'] ?? '',
            department: course['dept'] ?? '',
            year: course['year'] ?? 0,
            semester: course['semester'] ?? '',
            subjectType: course['subjectType'] ?? 'Core',
            preferenceOrder: i + 1,
            acYear: acYear,
            roundId: roundId,
          ));
        }
      }
      return preferences;
    } catch (e) {
      return [];
    }
  }

  /// Get faculty's preferred subjects as Subject objects for assignment dropdown
  /// Filters by academic year if provided
  Future<List<Subject>> getFacultyPreferredSubjects({
    required String facultyId,
    String? facultyEmail,
    String? academicYear,
  }) async {
    try {
      final preferences = await getFacultyPreferences(facultyId, facultyEmail: facultyEmail);
      if (preferences.isEmpty) return [];

      // Filter by academic year if provided
      final filtered = academicYear != null
          ? preferences.where((p) => p.acYear == academicYear).toList()
          : preferences;

      // Convert to Subject objects
      return filtered.map((pref) => Subject(
        id: pref.code,
        code: pref.code,
        name: pref.name,
        department: pref.department,
        credits: 0, // Will be updated when matched with actual subject
        year: pref.year,
        semester: pref.semester,
        subjectType: SubjectTypeExtension.fromString(pref.subjectType),
        isActive: true,
      )).toList();
    } catch (e) {
      return [];
    }
  }

  /// Check if a faculty has submitted any course preferences
  Future<bool> hasFacultySubmittedPreferences(String facultyId, {String? facultyEmail}) async {
    try {
      QuerySnapshot snapshot;
      
      if (facultyEmail != null && facultyEmail.isNotEmpty) {
        snapshot = await _coursePreferencesCollection
            .where('facultyEmail', isEqualTo: facultyEmail)
            .limit(1)
            .get();
      } else {
        snapshot = await _coursePreferencesCollection
            .where('facultyId', isEqualTo: facultyId)
            .limit(1)
            .get();
      }
      return snapshot.docs.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  // ============ FACULTY ASSIGNMENT MANAGEMENT ============

  /// Check if faculty already has an assignment for a specific year
  /// Returns the existing assignment if found, null otherwise
  Future<FacultyAssignment?> getFacultyAssignmentForYear({
    required String facultyId,
    required int year,
    required String academicYear,
    required String semester,
  }) async {
    try {
      final snapshot = await _assignmentsCollection
          .where('facultyId', isEqualTo: facultyId)
          .where('year', isEqualTo: year)
          .where('academicYear', isEqualTo: academicYear)
          .where('semester', isEqualTo: semester)
          .where('isActive', isEqualTo: true)
          .get();

      if (snapshot.docs.isEmpty) return null;
      return FacultyAssignment.fromFirestore(snapshot.docs.first);
    } catch (e) {
      return null;
    }
  }

  /// Check if a subject is already assigned to a different faculty
  /// Returns the existing assignment if found, null otherwise
  Future<FacultyAssignment?> getSubjectAssignment({
    required String subjectCode,
    required String academicYear,
    required String semester,
    required int year,
  }) async {
    try {
      final snapshot = await _assignmentsCollection
          .where('subjectCode', isEqualTo: subjectCode)
          .where('academicYear', isEqualTo: academicYear)
          .where('semester', isEqualTo: semester)
          .where('year', isEqualTo: year)
          .where('isActive', isEqualTo: true)
          .get();

      if (snapshot.docs.isEmpty) return null;
      return FacultyAssignment.fromFirestore(snapshot.docs.first);
    } catch (e) {
      return null;
    }
  }

  /// Get subject-faculty mapping for a department/year/semester
  /// Returns map of subjectCode -> facultyName
  Future<Map<String, String>> getSubjectFacultyMap({
    required String academicYear,
    required String semester,
    required int year,
    String? department,
  }) async {
    try {
      Query query = _assignmentsCollection
          .where('academicYear', isEqualTo: academicYear)
          .where('semester', isEqualTo: semester)
          .where('year', isEqualTo: year)
          .where('isActive', isEqualTo: true);

      if (department != null) {
        query = query.where('department', isEqualTo: department);
      }

      final snapshot = await query.get();
      final Map<String, String> subjectFacultyMap = {};
      
      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final subjectCode = data['subjectCode'] ?? '';
        final facultyName = data['facultyName'] ?? '';
        subjectFacultyMap[subjectCode] = facultyName;
      }
      return subjectFacultyMap;
    } catch (e) {
      return {};
    }
  }

  /// Create a new faculty assignment
  /// Enforces: 
  /// 1. One faculty can teach only ONE subject per student year
  /// 2. One subject can only be taught by ONE faculty (per year/semester)
  Future<String> createAssignment(FacultyAssignment assignment) async {
    try {
      // CHECK 1: Faculty can only teach ONE subject per year
      final existingForYear = await getFacultyAssignmentForYear(
        facultyId: assignment.facultyId,
        year: assignment.year,
        academicYear: assignment.academicYear,
        semester: assignment.semester,
      );

      if (existingForYear != null && 
          existingForYear.subjectCode != assignment.subjectCode) {
        throw Exception(
          'Faculty already teaches "${existingForYear.subjectName}" to Year ${assignment.year} students. '
          'A faculty can only teach one subject per student year.'
        );
      }

      // CHECK 2: Subject can only be taught by ONE faculty
      final existingSubjectAssignment = await getSubjectAssignment(
        subjectCode: assignment.subjectCode,
        academicYear: assignment.academicYear,
        semester: assignment.semester,
        year: assignment.year,
      );

      if (existingSubjectAssignment != null && 
          existingSubjectAssignment.facultyId != assignment.facultyId) {
        throw Exception(
          '"${assignment.subjectName}" is already assigned to ${existingSubjectAssignment.facultyName}. '
          'A subject can only be taught by one faculty.'
        );
      }

      // Check for duplicate assignment (same faculty, subject, batch combination)
      final existing = await _assignmentsCollection
          .where('facultyId', isEqualTo: assignment.facultyId)
          .where('subjectCode', isEqualTo: assignment.subjectCode)
          .where('academicYear', isEqualTo: assignment.academicYear)
          .where('semester', isEqualTo: assignment.semester)
          .where('isActive', isEqualTo: true)
          .get();

      if (existing.docs.isNotEmpty) {
        // Update existing assignment with new batches
        final existingDoc = existing.docs.first;
        final existingData = existingDoc.data() as Map<String, dynamic>;
        final existingBatches =
            List<String>.from(existingData['assignedBatches'] ?? []);

        // Merge batches
        final mergedBatches = <String>{...existingBatches, ...assignment.assignedBatches}.toList();

        await _assignmentsCollection.doc(existingDoc.id).update({
          'assignedBatches': mergedBatches,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        return existingDoc.id;
      }

      final docRef = await _assignmentsCollection.add({
        ...assignment.toFirestore(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return docRef.id;
    } catch (e) {
      throw Exception('Failed to create faculty assignment: $e');
    }
  }

  /// Update an existing assignment
  Future<void> updateAssignment(
      String assignmentId, FacultyAssignment assignment) async {
    try {
      await _assignmentsCollection.doc(assignmentId).update({
        ...assignment.toFirestore(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to update faculty assignment: $e');
    }
  }

  /// Delete an assignment
  Future<void> deleteAssignment(String assignmentId) async {
    try {
      await _assignmentsCollection.doc(assignmentId).delete();
    } catch (e) {
      throw Exception('Failed to delete faculty assignment: $e');
    }
  }

  /// Deactivate an assignment (soft delete)
  Future<void> deactivateAssignment(String assignmentId) async {
    try {
      await _assignmentsCollection.doc(assignmentId).update({
        'isActive': false,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to deactivate faculty assignment: $e');
    }
  }

  /// Get faculty's current year-subject mapping
  /// Returns a map of year -> subject name for the current academic year/semester
  Future<Map<int, String>> getFacultyYearSubjectMap({
    required String facultyId,
    required String academicYear,
    required String semester,
  }) async {
    try {
      final snapshot = await _assignmentsCollection
          .where('facultyId', isEqualTo: facultyId)
          .where('academicYear', isEqualTo: academicYear)
          .where('semester', isEqualTo: semester)
          .where('isActive', isEqualTo: true)
          .get();

      final Map<int, String> yearSubjectMap = {};
      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final year = data['year'] ?? 1;
        final subjectName = data['subjectName'] ?? '';
        yearSubjectMap[year] = subjectName;
      }
      return yearSubjectMap;
    } catch (e) {
      return {};
    }
  }

  /// Get all assignments
  Future<List<FacultyAssignment>> getAllAssignments() async {
    try {
      final snapshot = await _assignmentsCollection
          .where('isActive', isEqualTo: true)
          .get();
      final assignments = snapshot.docs
          .map((doc) => FacultyAssignment.fromFirestore(doc))
          .toList();
      // Sort in memory to avoid requiring composite index
      assignments.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return assignments;
    } catch (e) {
      throw Exception('Failed to get assignments: $e');
    }
  }

  /// Get assignments for a specific faculty
  Future<List<FacultyAssignment>> getAssignmentsForFaculty(
      String facultyId) async {
    try {
      final snapshot = await _assignmentsCollection
          .where('facultyId', isEqualTo: facultyId)
          .where('isActive', isEqualTo: true)
          .get();
      return snapshot.docs
          .map((doc) => FacultyAssignment.fromFirestore(doc))
          .toList();
    } catch (e) {
      throw Exception('Failed to get assignments for faculty: $e');
    }
  }

  /// Get assignments for a specific batch
  Future<List<FacultyAssignment>> getAssignmentsForBatch(String batchName) async {
    try {
      final snapshot = await _assignmentsCollection
          .where('assignedBatches', arrayContains: batchName)
          .where('isActive', isEqualTo: true)
          .get();
      return snapshot.docs
          .map((doc) => FacultyAssignment.fromFirestore(doc))
          .toList();
    } catch (e) {
      throw Exception('Failed to get assignments for batch: $e');
    }
  }

  /// Get assignments by academic year and semester
  Future<List<FacultyAssignment>> getAssignmentsByPeriod(
      String academicYear, String semester) async {
    try {
      final snapshot = await _assignmentsCollection
          .where('academicYear', isEqualTo: academicYear)
          .where('semester', isEqualTo: semester)
          .where('isActive', isEqualTo: true)
          .get();
      return snapshot.docs
          .map((doc) => FacultyAssignment.fromFirestore(doc))
          .toList();
    } catch (e) {
      throw Exception('Failed to get assignments by period: $e');
    }
  }

  /// Remove a batch from an assignment
  Future<void> removeBatchFromAssignment(
      String assignmentId, String batchName) async {
    try {
      await _assignmentsCollection.doc(assignmentId).update({
        'assignedBatches': FieldValue.arrayRemove([batchName]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to remove batch from assignment: $e');
    }
  }

  /// Add a batch to an existing assignment
  Future<void> addBatchToAssignment(
      String assignmentId, String batchName) async {
    try {
      await _assignmentsCollection.doc(assignmentId).update({
        'assignedBatches': FieldValue.arrayUnion([batchName]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to add batch to assignment: $e');
    }
  }

  // ============ FACULTY MANAGEMENT ============

  /// Get all faculty members
  Future<List<Map<String, dynamic>>> getAllFaculty() async {
    try {
      final snapshot = await _facultyCollection.get();
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'facultyId': doc.id,
          'name': data['name'] ?? '',
          'department': data['department'] ?? '',
          'designation': data['designation'] ?? '',
          'email': data['email'] ?? '',
          'status': data['status'] ?? 'active',
        };
      }).toList();
    } catch (e) {
      throw Exception('Failed to get faculty list: $e');
    }
  }

  /// Get faculty by department
  Future<List<Map<String, dynamic>>> getFacultyByDepartment(
      String department) async {
    try {
      final snapshot = await _facultyCollection
          .where('department', isEqualTo: department)
          .where('status', isEqualTo: 'active')
          .get();
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'facultyId': doc.id,
          'name': data['name'] ?? '',
          'department': data['department'] ?? '',
          'designation': data['designation'] ?? '',
          'email': data['email'] ?? '',
        };
      }).toList();
    } catch (e) {
      throw Exception('Failed to get faculty by department: $e');
    }
  }

  // ============ SUBJECT MANAGEMENT ============

  /// Create a new subject
  Future<String> createSubject(Subject subject) async {
    try {
      final docRef = await _subjectsCollection.add(subject.toFirestore());
      return docRef.id;
    } catch (e) {
      throw Exception('Failed to create subject: $e');
    }
  }

  /// Get all subjects
  Future<List<Subject>> getAllSubjects() async {
    try {
      final snapshot = await _subjectsCollection
          .where('isActive', isEqualTo: true)
          .get();
      return snapshot.docs.map((doc) => Subject.fromFirestore(doc)).toList();
    } catch (e) {
      throw Exception('Failed to get subjects: $e');
    }
  }

  /// Get subjects by department
  Future<List<Subject>> getSubjectsByDepartment(String department) async {
    try {
      final snapshot = await _subjectsCollection
          .where('department', isEqualTo: department)
          .where('isActive', isEqualTo: true)
          .get();
      return snapshot.docs.map((doc) => Subject.fromFirestore(doc)).toList();
    } catch (e) {
      throw Exception('Failed to get subjects by department: $e');
    }
  }

  /// Get subjects by year and semester
  Future<List<Subject>> getSubjectsByYearSemester(
      int year, String semester) async {
    try {
      final snapshot = await _subjectsCollection
          .where('year', isEqualTo: year)
          .where('semester', isEqualTo: semester)
          .where('isActive', isEqualTo: true)
          .get();
      return snapshot.docs.map((doc) => Subject.fromFirestore(doc)).toList();
    } catch (e) {
      throw Exception('Failed to get subjects by year/semester: $e');
    }
  }

  /// Delete a subject
  Future<void> deleteSubject(String subjectId) async {
    try {
      await _subjectsCollection.doc(subjectId).update({
        'isActive': false,
      });
    } catch (e) {
      throw Exception('Failed to delete subject: $e');
    }
  }

  /// Update a subject
  Future<void> updateSubject(String subjectId, Subject subject) async {
    try {
      await _subjectsCollection.doc(subjectId).update(subject.toFirestore());
    } catch (e) {
      throw Exception('Failed to update subject: $e');
    }
  }

  // ============ BATCH MANAGEMENT ============

  /// Get unique batches from students collection
  Future<List<StudentBatch>> getAllBatches() async {
    try {
      final snapshot = await _studentsCollection.get();
      final batchMap = <String, Map<String, dynamic>>{};

      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final batchNumber = data['batchNumber'] ?? '';
        final department = data['department'] ?? '';
        final year = data['year'] ?? 1;

        if (batchNumber.isNotEmpty) {
          final key = '$department-$batchNumber';
          if (batchMap.containsKey(key)) {
            batchMap[key]!['studentCount'] =
                (batchMap[key]!['studentCount'] as int) + 1;
          } else {
            batchMap[key] = {
              'batchName': batchNumber,
              'department': department,
              'year': year is int ? year : int.tryParse(year.toString()) ?? 1,
              'studentCount': 1,
            };
          }
        }
      }

      return batchMap.entries.map((entry) {
        return StudentBatch(
          id: entry.key,
          batchName: entry.value['batchName'] as String,
          department: entry.value['department'] as String,
          year: entry.value['year'] as int,
          academicYear: _getCurrentAcademicYear(),
          studentCount: entry.value['studentCount'] as int,
        );
      }).toList()
        ..sort((a, b) => a.batchName.compareTo(b.batchName));
    } catch (e) {
      throw Exception('Failed to get batches: $e');
    }
  }

  /// Get batches by department
  Future<List<StudentBatch>> getBatchesByDepartment(String department) async {
    try {
      final allBatches = await getAllBatches();
      return allBatches.where((b) => b.department == department).toList();
    } catch (e) {
      throw Exception('Failed to get batches by department: $e');
    }
  }

  /// Get batches by year
  Future<List<StudentBatch>> getBatchesByYear(int year) async {
    try {
      final allBatches = await getAllBatches();
      return allBatches.where((b) => b.year == year).toList();
    } catch (e) {
      throw Exception('Failed to get batches by year: $e');
    }
  }

  // ============ HELPER METHODS ============

  String _getCurrentAcademicYear() {
    final now = DateTime.now();
    if (now.month >= 6) {
      return '${now.year}-${(now.year + 1) % 100}';
    } else {
      return '${now.year - 1}-${now.year % 100}';
    }
  }

  /// Get departments from existing faculty/students
  Future<List<String>> getDepartments() async {
    try {
      final facultySnapshot = await _facultyCollection.get();
      final departments = <String>{};

      for (var doc in facultySnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final dept = data['department'] as String?;
        if (dept != null && dept.isNotEmpty) {
          departments.add(dept);
        }
      }

      // Also check students for departments
      final studentSnapshot = await _studentsCollection.limit(100).get();
      for (var doc in studentSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final dept = data['department'] as String?;
        if (dept != null && dept.isNotEmpty) {
          departments.add(dept);
        }
      }

      return departments.toList()..sort();
    } catch (e) {
      throw Exception('Failed to get departments: $e');
    }
  }

  /// Upload subjects from Excel file
  Future<Map<String, dynamic>> uploadSubjectsFromExcel(
    List<int> fileBytes,
    String fileName,
  ) async {
    try {
      // Import the Excel package
      final excel = await _parseExcelBytes(fileBytes, fileName);
      
      if (excel == null) {
        return {
          'success': false,
          'message': 'Failed to parse Excel file',
          'totalRows': 0,
          'created': 0,
          'failed': 0,
          'failedReasons': [],
        };
      }

      final results = {
        'success': true,
        'message': '',
        'totalRows': 0,
        'created': 0,
        'failed': 0,
        'failedReasons': <String>[],
      };

      // Get the first sheet
      final sheet = excel.sheets.values.first;
      final rows = sheet.rows;

      if (rows.isEmpty || rows.length < 2) {
        return {
          'success': false,
          'message': 'Excel file is empty or has no data rows',
          'totalRows': 0,
          'created': 0,
          'failed': 0,
          'failedReasons': [],
        };
      }

      // Get headers from first row
      final headers = rows.first
          .map((cell) => cell?.value?.toString().trim().toLowerCase() ?? '')
          .toList();

      // Required columns
      final requiredColumns = ['code', 'name', 'department', 'year', 'semester'];
      final missingColumns = requiredColumns
          .where((col) => !headers.contains(col))
          .toList();

      if (missingColumns.isNotEmpty) {
        return {
          'success': false,
          'message': 'Missing required columns: ${missingColumns.join(", ")}',
          'totalRows': 0,
          'created': 0,
          'failed': 0,
          'failedReasons': [],
        };
      }

      // Find column indices
      final codeIndex = headers.indexOf('code');
      final nameIndex = headers.indexOf('name');
      final deptIndex = headers.indexOf('department');
      final yearIndex = headers.indexOf('year');
      final semIndex = headers.indexOf('semester');
      final creditsIndex = headers.indexOf('credits');

      results['totalRows'] = rows.length - 1;

      // Process data rows (skip header)
      for (int i = 1; i < rows.length; i++) {
        final row = rows[i];
        
        try {
          final code = row[codeIndex]?.value?.toString().trim() ?? '';
          final name = row[nameIndex]?.value?.toString().trim() ?? '';
          final department = row[deptIndex]?.value?.toString().trim() ?? '';
          final yearStr = row[yearIndex]?.value?.toString().trim() ?? '';
          final semester = row[semIndex]?.value?.toString().trim() ?? '';
          final creditsStr = creditsIndex >= 0 && creditsIndex < row.length
              ? row[creditsIndex]?.value?.toString().trim() ?? '3'
              : '3';

          // Validate required fields
          if (code.isEmpty || name.isEmpty || department.isEmpty || 
              yearStr.isEmpty || semester.isEmpty) {
            (results['failedReasons'] as List<String>).add(
              'Row ${i + 1}: Missing required fields'
            );
            results['failed'] = (results['failed'] as int) + 1;
            continue;
          }

          // Parse year
          final year = int.tryParse(yearStr);
          if (year == null || year < 1 || year > 4) {
            (results['failedReasons'] as List<String>).add(
              'Row ${i + 1}: Invalid year "$yearStr"'
            );
            results['failed'] = (results['failed'] as int) + 1;
            continue;
          }

          // Normalize semester
          String normalizedSemester = semester.toUpperCase();
          if (normalizedSemester == '1' || normalizedSemester == 'SEM 1' || 
              normalizedSemester == 'SEMESTER 1' || normalizedSemester == 'SEM I' ||
              normalizedSemester == 'SEMESTER I') {
            normalizedSemester = 'I';
          } else if (normalizedSemester == '2' || normalizedSemester == 'SEM 2' || 
              normalizedSemester == 'SEMESTER 2' || normalizedSemester == 'SEM II' ||
              normalizedSemester == 'SEMESTER II') {
            normalizedSemester = 'II';
          }

          if (normalizedSemester != 'I' && normalizedSemester != 'II') {
            (results['failedReasons'] as List<String>).add(
              'Row ${i + 1}: Invalid semester "$semester"'
            );
            results['failed'] = (results['failed'] as int) + 1;
            continue;
          }

          final credits = int.tryParse(creditsStr) ?? 3;

          // Create subject (using default subjectType as this method is deprecated)
          final subject = Subject(
            id: '',
            code: code.toUpperCase(),
            name: name,
            department: department.toUpperCase(),
            year: year,
            semester: normalizedSemester,
            credits: credits,
            subjectType: SubjectType.core,
          );

          await createSubject(subject);
          results['created'] = (results['created'] as int) + 1;

        } catch (e) {
          (results['failedReasons'] as List<String>).add(
            'Row ${i + 1}: Error - $e'
          );
          results['failed'] = (results['failed'] as int) + 1;
        }
      }

      results['message'] = 'Upload completed: ${results['created']} subjects created, ${results['failed']} failed';
      results['success'] = (results['created'] as int) > 0;

      return results;
    } catch (e) {
      return {
        'success': false,
        'message': 'Upload failed: $e',
        'totalRows': 0,
        'created': 0,
        'failed': 0,
        'failedReasons': [],
      };
    }
  }

  /// Parse Excel bytes using the excel package
  dynamic _parseExcelBytes(List<int> bytes, String fileName) {
    try {
      // This requires the excel package import at the top
      // The actual parsing will be done in the page with imported excel package
      return null; // Placeholder - actual implementation in page
    } catch (e) {
      return null;
    }
  }
}

/// Model class for faculty's preferred course from course preferences
class FacultyPreferredCourse {
  final String code;
  final String name;
  final String department;
  final int year;
  final String semester;
  final String subjectType;
  final int preferenceOrder; // 1 = highest preference
  final String acYear;
  final String roundId;

  FacultyPreferredCourse({
    required this.code,
    required this.name,
    required this.department,
    required this.year,
    required this.semester,
    this.subjectType = 'Core',
    required this.preferenceOrder,
    this.acYear = '',
    this.roundId = '',
  });

  @override
  String toString() => '$code - $name (Preference #$preferenceOrder)';
}
