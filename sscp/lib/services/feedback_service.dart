import 'package:cloud_firestore/cloud_firestore.dart';
import 'audit_log_service.dart';

class FeedbackService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference get _feedbackCollection =>
      _firestore.collection('studentFeedback');
  CollectionReference get _feedbackSessionsCollection =>
      _firestore.collection('feedbackSessions');

  // ============ ADMIN: Feedback Session Management ============

  /// Create a new feedback session (admin enables feedback for a semester)
  Future<String> createFeedbackSession({
    required String academicYear,
    required String semester,
    required DateTime startDate,
    required DateTime endDate,
    required List<String> enabledYears, // e.g., ['1', '2', '3', '4']
    required List<String> enabledBranches,
  }) async {
    try {
      final docRef = await _feedbackSessionsCollection.add({
        'academicYear': academicYear,
        'semester': semester,
        'startDate': Timestamp.fromDate(startDate),
        'endDate': Timestamp.fromDate(endDate),
        'enabledYears': enabledYears,
        'enabledBranches': enabledBranches,
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
      });
      return docRef.id;
    } catch (e) {
      throw Exception('Failed to create feedback session: $e');
    }
  }

  /// Get active feedback session
  Future<Map<String, dynamic>?> getActiveFeedbackSession() async {
    try {
      final now = DateTime.now();
      final snapshot = await _feedbackSessionsCollection
          .where('isActive', isEqualTo: true)
          .get();

      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final startDate = (data['startDate'] as Timestamp).toDate();
        final endDate = (data['endDate'] as Timestamp).toDate();

        if (now.isAfter(startDate) && now.isBefore(endDate)) {
          return {
            'sessionId': doc.id,
            ...data,
            'startDate': startDate,
            'endDate': endDate,
          };
        }
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get active feedback session: $e');
    }
  }

  /// Get all feedback sessions (for admin view)
  Future<List<Map<String, dynamic>>> getAllFeedbackSessions() async {
    try {
      final snapshot = await _feedbackSessionsCollection
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'sessionId': doc.id,
          ...data,
          'startDate': (data['startDate'] as Timestamp).toDate(),
          'endDate': (data['endDate'] as Timestamp).toDate(),
        };
      }).toList();
    } catch (e) {
      throw Exception('Failed to get feedback sessions: $e');
    }
  }

  /// Toggle feedback session active status
  Future<void> toggleFeedbackSession(String sessionId, bool isActive) async {
    try {
      await _feedbackSessionsCollection.doc(sessionId).update({
        'isActive': isActive,
      });
    } catch (e) {
      throw Exception('Failed to toggle feedback session: $e');
    }
  }

  /// Delete feedback session
  Future<void> deleteFeedbackSession(String sessionId) async {
    try {
      await _feedbackSessionsCollection.doc(sessionId).delete();
    } catch (e) {
      throw Exception('Failed to delete feedback session: $e');
    }
  }

  // ============ STUDENT: Check Feedback Access & Submit ============

  /// Check if feedback is enabled for a student
  Future<bool> isFeedbackEnabledForStudent({
    required String studentYear,
    required String studentBranch,
  }) async {
    try {
      final session = await getActiveFeedbackSession();
      if (session == null) return false;

      final enabledYears = List<String>.from(session['enabledYears'] ?? []);
      final enabledBranches =
          List<String>.from(session['enabledBranches'] ?? []);

      // Case-insensitive branch matching
      final branchUpper = studentBranch.toUpperCase();
      final branchMatches = enabledBranches.any((b) =>
          b.toUpperCase() == branchUpper ||
          b.toUpperCase().contains(branchUpper) ||
          branchUpper.contains(b.toUpperCase()));

      return enabledYears.contains(studentYear) && branchMatches;
    } catch (e) {
      return false;
    }
  }

  /// Get subjects for which student can give feedback
  /// These are subjects the student is enrolled in for the current semester
  Future<List<Map<String, dynamic>>> getStudentFeedbackSubjects({
    required String studentId,
    required String studentYear,
    required String studentBranch,
    required String semester,
    String? studentBatch,
    String? studentSection,
  }) async {
    try {
      final subjectsByCode = <String, Map<String, dynamic>>{};

      String resolvedStudentBatch = studentBatch?.trim() ?? '';
      String resolvedStudentSection = studentSection?.trim() ?? '';

      if (resolvedStudentBatch.isEmpty || resolvedStudentSection.isEmpty) {
        final studentDoc =
            await _firestore.collection('students').doc(studentId).get();
        if (studentDoc.exists) {
          final studentData = studentDoc.data() as Map<String, dynamic>;
          resolvedStudentBatch = resolvedStudentBatch.isEmpty
              ? (studentData['batchNumber'] ?? '').toString()
              : resolvedStudentBatch;
          resolvedStudentSection = resolvedStudentSection.isEmpty
              ? (studentData['section'] ?? '').toString()
              : resolvedStudentSection;
        }
      }

      Future<void> addOrMergeSubject({
        required String subjectId,
        required String subjectCode,
        required String subjectName,
        String facultyId = '',
        String facultyName = 'Not Assigned',
      }) async {
        final trimmedCode = subjectCode.trim();
        if (trimmedCode.isEmpty) {
          return;
        }

        var resolvedFacultyId = facultyId.trim();
        var resolvedFacultyName = facultyName.trim();

        if (resolvedFacultyId.isEmpty ||
            resolvedFacultyName.isEmpty ||
            resolvedFacultyName == 'Not Assigned') {
          final facultyAssignment = await _getFacultyForSubject(
            subjectCode: trimmedCode,
            year: studentYear,
            semester: semester,
            studentBranch: studentBranch,
            studentBatch: resolvedStudentBatch,
            studentSection: resolvedStudentSection,
          );
          resolvedFacultyId =
              facultyAssignment?['facultyId']?.toString() ?? resolvedFacultyId;
          resolvedFacultyName = facultyAssignment?['facultyName']?.toString() ??
              resolvedFacultyName;
        }

        if (resolvedFacultyName.isEmpty) {
          resolvedFacultyName = 'Not Assigned';
        }

        final key = _normalizeToken(trimmedCode);
        final existing = subjectsByCode[key];

        if (existing == null) {
          subjectsByCode[key] = {
            'subjectId': subjectId.isNotEmpty ? subjectId : trimmedCode,
            'subjectCode': trimmedCode,
            'subjectName': subjectName.trim(),
            'facultyId': resolvedFacultyId,
            'facultyName': resolvedFacultyName,
          };
          return;
        }

        final existingFacultyName = (existing['facultyName'] ?? '').toString();
        final existingFacultyId = (existing['facultyId'] ?? '').toString();

        if ((existingFacultyId.isEmpty ||
                existingFacultyName == 'Not Assigned') &&
            resolvedFacultyId.isNotEmpty) {
          existing['facultyId'] = resolvedFacultyId;
          existing['facultyName'] = resolvedFacultyName;
        }

        if ((existing['subjectName'] ?? '').toString().trim().isEmpty &&
            subjectName.trim().isNotEmpty) {
          existing['subjectName'] = subjectName.trim();
        }
      }

      // Strategy 1: Get from student's registered courses (studentCourses collection)
      final studentCoursesSnapshot = await _firestore
          .collection('studentCourses')
          .where('studentId', isEqualTo: studentId)
          .get();

      if (studentCoursesSnapshot.docs.isNotEmpty) {
        for (final doc in studentCoursesSnapshot.docs) {
          final data = doc.data();
          // Get selected courses from selectionsByType
          final selectionsByType =
              data['selectionsByType'] as Map<String, dynamic>? ?? {};

          for (final entry in selectionsByType.entries) {
            final courseList = entry.value as List<dynamic>? ?? [];
            for (final course in courseList) {
              if (course is Map<String, dynamic>) {
                await addOrMergeSubject(
                  subjectId:
                      (course['id'] ?? course['courseId'] ?? '').toString(),
                  subjectCode:
                      (course['code'] ?? course['courseCode'] ?? '').toString(),
                  subjectName:
                      (course['name'] ?? course['courseName'] ?? '').toString(),
                );
              }
            }
          }
        }
      }

      // Strategy 2: Merge faculty assignments directly for the student's scope.
      QuerySnapshot<Map<String, dynamic>> assignmentsSnapshot;
      final parsedYear = int.tryParse(studentYear);
      if (parsedYear != null) {
        assignmentsSnapshot = await _firestore
            .collection('facultyAssignments')
            .where('year', isEqualTo: parsedYear)
            .where('isActive', isEqualTo: true)
            .get();
        if (assignmentsSnapshot.docs.isEmpty) {
          assignmentsSnapshot = await _firestore
              .collection('facultyAssignments')
              .where('isActive', isEqualTo: true)
              .get();
        }
      } else {
        assignmentsSnapshot = await _firestore
            .collection('facultyAssignments')
            .where('isActive', isEqualTo: true)
            .get();
      }

      for (final doc in assignmentsSnapshot.docs) {
        final data = doc.data();
        if (!_matchesAssignmentForStudent(
          data,
          studentYear: studentYear,
          studentBranch: studentBranch,
          semester: semester,
          studentBatch: resolvedStudentBatch,
          studentSection: resolvedStudentSection,
        )) {
          continue;
        }

        await addOrMergeSubject(
          subjectId: doc.id,
          subjectCode: (data['subjectCode'] ?? '').toString(),
          subjectName: (data['subjectName'] ?? '').toString(),
          facultyId: (data['facultyId'] ?? '').toString(),
          facultyName: (data['facultyName'] ?? '').toString(),
        );
      }

      // Strategy 3: Merge from subjects collection for current branch/year/semester.
      if (subjectsByCode.isEmpty) {
        // Try multiple query approaches for subjects
        QuerySnapshot? subjectsSnapshot;

        // Try with year as int
        subjectsSnapshot = await _firestore
            .collection('subjects')
            .where('year', isEqualTo: int.tryParse(studentYear) ?? 0)
            .get();

        // If empty, try with year as string
        if (subjectsSnapshot.docs.isEmpty) {
          subjectsSnapshot = await _firestore
              .collection('subjects')
              .where('year', isEqualTo: studentYear)
              .get();
        }

        // Filter by branch in memory (handles case sensitivity)
        final branchLower = studentBranch.toLowerCase();
        for (final doc in subjectsSnapshot.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final docDept = (data['department'] ?? '').toString().toLowerCase();
          final docSemester = (data['semester'] ?? '').toString();

          // Check if department matches (case-insensitive)
          if (docDept == branchLower ||
              docDept.contains(branchLower) ||
              branchLower.contains(docDept)) {
            if (!_semesterMatches(docSemester, semester)) {
              continue;
            }

            await addOrMergeSubject(
              subjectId: doc.id,
              subjectCode: (data['code'] ?? doc.id).toString(),
              subjectName: (data['name'] ?? '').toString(),
            );
          }
        }
      }

      // Strategy 4: If still empty, fall back to year-level assignments.
      if (subjectsByCode.isEmpty) {
        final assignmentsSnapshot = await _firestore
            .collection('facultyAssignments')
            .where('year', isEqualTo: int.tryParse(studentYear) ?? studentYear)
            .get();

        for (final doc in assignmentsSnapshot.docs) {
          final data = doc.data();
          await addOrMergeSubject(
            subjectId: doc.id,
            subjectCode: (data['subjectCode'] ?? '').toString(),
            subjectName: (data['subjectName'] ?? '').toString(),
            facultyId: (data['facultyId'] ?? '').toString(),
            facultyName: (data['facultyName'] ?? '').toString(),
          );
        }
      }

      // Strategy 5: Get from courses collection (applicable to this year/branch)
      if (subjectsByCode.isEmpty) {
        final coursesSnapshot = await _firestore
            .collection('courses')
            .where('isActive', isEqualTo: true)
            .get();

        final branchLower = studentBranch.toLowerCase();
        for (final doc in coursesSnapshot.docs) {
          final data = doc.data();
          final applicableYears =
              List<String>.from(data['applicableYears'] ?? []);
          final applicableBranches =
              List<String>.from(data['applicableBranches'] ?? []);

          // Check if course is applicable to this student
          final yearMatches = applicableYears.contains(studentYear) ||
              applicableYears.contains(int.tryParse(studentYear)?.toString());
          final branchMatches = applicableBranches.any((b) =>
              b.toLowerCase() == branchLower ||
              b.toLowerCase().contains(branchLower));

          if (yearMatches && branchMatches) {
            await addOrMergeSubject(
              subjectId: doc.id,
              subjectCode: (data['code'] ?? doc.id).toString(),
              subjectName: (data['name'] ?? '').toString(),
            );
          }
        }
      }

      // Strategy 6: As last resort, get ALL active subjects/courses to show something
      if (subjectsByCode.isEmpty) {
        // Try subjects collection without filters
        var allSubjects =
            await _firestore.collection('subjects').limit(20).get();

        if (allSubjects.docs.isEmpty) {
          allSubjects = await _firestore.collection('courses').limit(20).get();
        }

        for (final doc in allSubjects.docs) {
          final data = doc.data();
          await addOrMergeSubject(
            subjectId: doc.id,
            subjectCode: (data['code'] ?? doc.id).toString(),
            subjectName: (data['name'] ?? '').toString(),
          );
        }
      }

      final subjects = subjectsByCode.values.toList();
      subjects.sort((a, b) => (a['subjectName'] ?? '')
          .toString()
          .compareTo((b['subjectName'] ?? '').toString()));
      return subjects;
    } catch (e) {
      throw Exception('Failed to get feedback subjects: $e');
    }
  }

  Future<Map<String, dynamic>?> _getFacultyForSubject({
    required String subjectCode,
    required String year,
    required String semester,
    required String studentBranch,
    String? studentBatch,
    String? studentSection,
  }) async {
    try {
      final assignmentSnapshot = await _firestore
          .collection('facultyAssignments')
          .where('subjectCode', isEqualTo: subjectCode)
          .get();

      for (final doc in assignmentSnapshot.docs) {
        final data = doc.data();
        if (!_matchesAssignmentForStudent(
          data,
          studentYear: year,
          studentBranch: studentBranch,
          semester: semester,
          studentBatch: studentBatch,
          studentSection: studentSection,
        )) {
          continue;
        }

        return {
          'facultyId': data['facultyId'] ?? '',
          'facultyName': data['facultyName'] ?? '',
        };
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  bool _matchesAssignmentForStudent(
    Map<String, dynamic> data, {
    required String studentYear,
    required String studentBranch,
    required String semester,
    String? studentBatch,
    String? studentSection,
  }) {
    final assignmentYear = _parseInt(data['year']);
    final expectedYear = _parseInt(studentYear);
    if (assignmentYear > 0 &&
        expectedYear > 0 &&
        assignmentYear != expectedYear) {
      return false;
    }

    final assignmentDept =
        _normalizeToken(data['department']?.toString() ?? '');
    final normalizedBranch = _normalizeToken(studentBranch);
    if (assignmentDept.isNotEmpty && assignmentDept != normalizedBranch) {
      return false;
    }

    final assignmentSemester = data['semester']?.toString() ?? '';
    if (!_semesterMatches(assignmentSemester, semester)) {
      return false;
    }

    final assignedBatches =
        List<String>.from(data['assignedBatches'] ?? const []);
    if (assignedBatches.isEmpty) {
      return true;
    }

    final studentBatchTokens = _buildBatchTokens([
      if ((studentBatch ?? '').trim().isNotEmpty) studentBatch!.trim(),
      if ((studentSection ?? '').trim().isNotEmpty) studentSection!.trim(),
    ]);
    if (studentBatchTokens.isEmpty) {
      return true;
    }

    final assignedTokens = _buildBatchTokens(assignedBatches);
    return assignedTokens.any(studentBatchTokens.contains);
  }

  bool _semesterMatches(String left, String right) {
    final normalizedLeft = _normalizeSemester(left);
    final normalizedRight = _normalizeSemester(right);
    if (normalizedLeft.isEmpty || normalizedRight.isEmpty) {
      return true;
    }
    return normalizedLeft == normalizedRight;
  }

  String _normalizeSemester(String value) {
    final raw = value.trim().toUpperCase();
    if (raw.isEmpty) return '';
    switch (raw) {
      case '1':
      case 'I':
      case '01':
        return '1';
      case '2':
      case 'II':
      case '02':
        return '2';
      case '3':
      case 'III':
      case '03':
        return '3';
      case '4':
      case 'IV':
      case '04':
        return '4';
      case '5':
      case 'V':
      case '05':
        return '5';
      case '6':
      case 'VI':
      case '06':
        return '6';
      case '7':
      case 'VII':
      case '07':
        return '7';
      case '8':
      case 'VIII':
      case '08':
        return '8';
      default:
        return _normalizeToken(raw);
    }
  }

  Set<String> _buildBatchTokens(List<String> values) {
    final tokens = <String>{};
    for (final value in values) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) continue;
      tokens.add(_normalizeToken(trimmed));
      final parts = trimmed
          .split(RegExp(r'[-_/\\s]+'))
          .map(_normalizeToken)
          .where((part) => part.isNotEmpty);
      tokens.addAll(parts);
    }
    return tokens;
  }

  String _normalizeToken(String value) {
    return value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  int _parseInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.floor();
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  /// Check if student has already submitted feedback for a subject
  Future<bool> hasSubmittedFeedback({
    required String studentId,
    required String subjectCode,
    required String sessionId,
  }) async {
    try {
      final snapshot = await _feedbackCollection
          .where('studentId', isEqualTo: studentId)
          .where('subjectCode', isEqualTo: subjectCode)
          .where('sessionId', isEqualTo: sessionId)
          .limit(1)
          .get();

      return snapshot.docs.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Submit feedback for a subject
  Future<void> submitFeedback({
    required String studentId,
    required String sessionId,
    required String subjectCode,
    required String subjectName,
    required String facultyId,
    required Map<String, int> ratings, // category -> rating (1-5)
    String? comments,
  }) async {
    try {
      // Check if already submitted
      final alreadySubmitted = await hasSubmittedFeedback(
        studentId: studentId,
        subjectCode: subjectCode,
        sessionId: sessionId,
      );

      if (alreadySubmitted) {
        throw Exception('Feedback already submitted for this subject');
      }

      // Calculate average rating
      final avgRating = ratings.values.isEmpty
          ? 0.0
          : ratings.values.reduce((a, b) => a + b) / ratings.values.length;

      await _feedbackCollection.add({
        'studentId': studentId,
        'sessionId': sessionId,
        'subjectCode': subjectCode,
        'subjectName': subjectName,
        'facultyId': facultyId,
        'ratings': ratings,
        'averageRating': avgRating,
        'comments': comments ?? '',
        'submittedAt': FieldValue.serverTimestamp(),
      });

      // Log audit trail
      AuditLogService().logFeedbackSubmission(
        studentRollNo: studentId,
        sessionId: sessionId,
        facultyId: facultyId,
        courseCode: subjectCode,
      );
    } catch (e) {
      throw Exception('Failed to submit feedback: $e');
    }
  }

  // ============ FACULTY: View Aggregated Feedback ============

  /// Get aggregated feedback for faculty (no student info visible)
  Future<List<Map<String, dynamic>>> getFacultyFeedbackSummary({
    required String facultyId,
    List<String>? alternateFacultyIds,
  }) async {
    try {
      final candidateIds = _buildFacultyIdCandidates(
        facultyId,
        alternateFacultyIds,
      );

      final docsById = <String, QueryDocumentSnapshot>{};

      if (candidateIds.length == 1) {
        final snapshot = await _feedbackCollection
            .where('facultyId', isEqualTo: candidateIds.first)
            .get();
        for (final doc in snapshot.docs) {
          docsById[doc.id] = doc;
        }
      } else {
        final ids = candidateIds.toList();
        for (var i = 0; i < ids.length; i += 10) {
          final chunk = ids.sublist(i, (i + 10).clamp(0, ids.length));
          if (chunk.isEmpty) continue;
          final snapshot = await _feedbackCollection
              .where('facultyId', whereIn: chunk)
              .get();
          for (final doc in snapshot.docs) {
            docsById[doc.id] = doc;
          }
        }
      }

      // Fallback for inconsistent casing/format in older data.
      if (docsById.isEmpty && candidateIds.isNotEmpty) {
        final normalizedCandidates = candidateIds
            .map(_normalizeFacultyId)
            .where((e) => e.isNotEmpty)
            .toSet();
        if (normalizedCandidates.isNotEmpty) {
          final snapshot = await _feedbackCollection.get();
          for (final doc in snapshot.docs) {
            final data = doc.data() as Map<String, dynamic>;
            final docFacultyId =
                _normalizeFacultyId(data['facultyId']?.toString());
            if (normalizedCandidates.contains(docFacultyId)) {
              docsById[doc.id] = doc;
            }
          }
        }
      }

      // Group feedback by subject and session
      final Map<String, Map<String, dynamic>> groupedFeedback = {};

      for (final doc in docsById.values) {
        final data = doc.data() as Map<String, dynamic>;
        final key = '${data['sessionId']}_${data['subjectCode']}';

        if (!groupedFeedback.containsKey(key)) {
          groupedFeedback[key] = {
            'sessionId': data['sessionId'],
            'subjectCode': data['subjectCode'],
            'subjectName': data['subjectName'],
            'totalResponses': 0,
            'totalRating': 0.0,
            'categoryRatings': <String, List<int>>{},
          };
        }

        groupedFeedback[key]!['totalResponses'] =
            (groupedFeedback[key]!['totalResponses'] as int) + 1;
        groupedFeedback[key]!['totalRating'] =
            (groupedFeedback[key]!['totalRating'] as double) +
                (data['averageRating'] ?? 0.0);

        // Aggregate category ratings
        final ratings = data['ratings'] as Map<String, dynamic>?;
        if (ratings != null) {
          final categoryRatings = groupedFeedback[key]!['categoryRatings']
              as Map<String, List<int>>;
          ratings.forEach((category, rating) {
            if (!categoryRatings.containsKey(category)) {
              categoryRatings[category] = [];
            }
            categoryRatings[category]!.add((rating as num).toInt());
          });
        }
      }

      // Calculate averages
      final result = <Map<String, dynamic>>[];
      for (final entry in groupedFeedback.entries) {
        final data = entry.value;
        final totalResponses = data['totalResponses'] as int;
        final avgRating = totalResponses > 0
            ? (data['totalRating'] as double) / totalResponses
            : 0.0;

        // Calculate category averages
        final categoryRatings =
            data['categoryRatings'] as Map<String, List<int>>;
        final categoryAverages = <String, double>{};
        categoryRatings.forEach((category, ratings) {
          categoryAverages[category] = ratings.isEmpty
              ? 0.0
              : ratings.reduce((a, b) => a + b) / ratings.length;
        });

        // Get session details
        String semester = '';
        String academicYear = '';
        try {
          final sessionDoc =
              await _feedbackSessionsCollection.doc(data['sessionId']).get();
          if (sessionDoc.exists) {
            final sessionData = sessionDoc.data() as Map<String, dynamic>;
            semester = sessionData['semester'] ?? '';
            academicYear = sessionData['academicYear'] ?? '';
          }
        } catch (_) {}

        result.add({
          'subjectCode': data['subjectCode'],
          'subjectName': data['subjectName'],
          'semester': semester,
          'academicYear': academicYear,
          'totalResponses': totalResponses,
          'averageRating': avgRating,
          'categoryAverages': categoryAverages,
        });
      }

      // Sort by academic year and semester (most recent first)
      result.sort((a, b) {
        final yearCompare =
            (b['academicYear'] ?? '').compareTo(a['academicYear'] ?? '');
        if (yearCompare != 0) return yearCompare;
        return (b['semester'] ?? '').compareTo(a['semester'] ?? '');
      });

      return result;
    } catch (e) {
      throw Exception('Failed to get faculty feedback summary: $e');
    }
  }

  /// Get overall average feedback rating for a faculty member
  /// Formula: Sum of all feedback scores / Number of students who gave feedback
  Future<double> getOverallAverageFeedback({
    required String facultyId,
    List<String>? alternateFacultyIds,
  }) async {
    try {
      final candidateIds = _buildFacultyIdCandidates(
        facultyId,
        alternateFacultyIds,
      );

      final docsById = <String, QueryDocumentSnapshot>{};

      if (candidateIds.length == 1) {
        final snapshot = await _feedbackCollection
            .where('facultyId', isEqualTo: candidateIds.first)
            .get();
        for (final doc in snapshot.docs) {
          docsById[doc.id] = doc;
        }
      } else {
        final ids = candidateIds.toList();
        for (var i = 0; i < ids.length; i += 10) {
          final chunk = ids.sublist(i, (i + 10).clamp(0, ids.length));
          if (chunk.isEmpty) continue;
          final snapshot = await _feedbackCollection
              .where('facultyId', whereIn: chunk)
              .get();
          for (final doc in snapshot.docs) {
            docsById[doc.id] = doc;
          }
        }
      }

      if (docsById.isEmpty) {
        return 0.0;
      }

      double totalRating = 0.0;
      int totalResponses = 0;

      for (final doc in docsById.values) {
        final data = doc.data() as Map<String, dynamic>;
        final averageRating = (data['averageRating'] ?? 0.0);
        totalRating += averageRating;
        totalResponses += 1;
      }

      // Calculate overall average: total sum / number of students
      final overallAverage =
          totalResponses > 0 ? totalRating / totalResponses : 0.0;

      return double.parse(overallAverage.toStringAsFixed(2));
    } catch (e) {
      throw Exception('Failed to get overall average feedback: $e');
    }
  }

  /// Get feedback categories (configurable)
  List<String> getFeedbackCategories() {
    return [
      'Subject Knowledge',
      'Teaching Methodology',
      'Communication Skills',
      'Punctuality',
      'Student Interaction',
      'Overall Satisfaction',
    ];
  }

  Set<String> _buildFacultyIdCandidates(
    String facultyId,
    List<String>? alternateFacultyIds,
  ) {
    final raw = <String>{
      facultyId,
      ...?alternateFacultyIds,
    };

    final candidates = <String>{};
    for (final id in raw) {
      final trimmed = id.trim();
      if (trimmed.isEmpty) continue;
      candidates.add(trimmed);
      candidates.add(trimmed.toUpperCase());
      candidates.add(trimmed.toLowerCase());
    }
    return candidates;
  }

  String _normalizeFacultyId(String? value) {
    return (value ?? '').toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  }
}
