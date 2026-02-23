import 'package:cloud_firestore/cloud_firestore.dart';

class FeedbackService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference get _feedbackCollection =>
      _firestore.collection('studentFeedback');
  CollectionReference get _feedbackSettingsCollection =>
      _firestore.collection('feedbackSettings');
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
  }) async {
    try {
      final subjects = <Map<String, dynamic>>[];

      // Strategy 1: Get from student's registered courses (studentCourses collection)
      final studentCoursesSnapshot = await _firestore
          .collection('studentCourses')
          .where('studentId', isEqualTo: studentId)
          .get();

      if (studentCoursesSnapshot.docs.isNotEmpty) {
        for (final doc in studentCoursesSnapshot.docs) {
          final data = doc.data();
          // Get selected courses from selectionsByType
          final selectionsByType = data['selectionsByType'] as Map<String, dynamic>? ?? {};
          
          for (final entry in selectionsByType.entries) {
            final courseList = entry.value as List<dynamic>? ?? [];
            for (final course in courseList) {
              if (course is Map<String, dynamic>) {
                final facultyAssignment = await _getFacultyForSubject(
                  subjectCode: course['code'] ?? course['courseCode'] ?? '',
                  year: studentYear,
                  semester: semester,
                );

                subjects.add({
                  'subjectId': course['id'] ?? course['courseId'] ?? '',
                  'subjectCode': course['code'] ?? course['courseCode'] ?? '',
                  'subjectName': course['name'] ?? course['courseName'] ?? '',
                  'facultyId': facultyAssignment?['facultyId'] ?? '',
                  'facultyName': facultyAssignment?['facultyName'] ?? 'Not Assigned',
                });
              }
            }
          }
        }
      }

      // Strategy 2: If no courses from studentCourses, try subjects collection
      if (subjects.isEmpty) {
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
          
          // Check if department matches (case-insensitive)
          if (docDept == branchLower || docDept.contains(branchLower) || branchLower.contains(docDept)) {
            final facultyAssignment = await _getFacultyForSubject(
              subjectCode: data['code'] ?? doc.id,
              year: studentYear,
              semester: semester,
            );

            subjects.add({
              'subjectId': doc.id,
              'subjectCode': data['code'] ?? doc.id,
              'subjectName': data['name'] ?? '',
              'facultyId': facultyAssignment?['facultyId'] ?? '',
              'facultyName': facultyAssignment?['facultyName'] ?? 'Not Assigned',
            });
          }
        }
      }

      // Strategy 3: If still empty, get from facultyAssignments for this year
      if (subjects.isEmpty) {
        final assignmentsSnapshot = await _firestore
            .collection('facultyAssignments')
            .where('year', isEqualTo: int.tryParse(studentYear) ?? studentYear)
            .get();

        for (final doc in assignmentsSnapshot.docs) {
          final data = doc.data();
          subjects.add({
            'subjectId': doc.id,
            'subjectCode': data['subjectCode'] ?? '',
            'subjectName': data['subjectName'] ?? '',
            'facultyId': data['facultyId'] ?? '',
            'facultyName': data['facultyName'] ?? 'Not Assigned',
          });
        }
      }

      // Strategy 4: Get from courses collection (applicable to this year/branch)
      if (subjects.isEmpty) {
        final coursesSnapshot = await _firestore
            .collection('courses')
            .where('isActive', isEqualTo: true)
            .get();

        final branchLower = studentBranch.toLowerCase();
        for (final doc in coursesSnapshot.docs) {
          final data = doc.data();
          final applicableYears = List<String>.from(data['applicableYears'] ?? []);
          final applicableBranches = List<String>.from(data['applicableBranches'] ?? []);
          
          // Check if course is applicable to this student
          final yearMatches = applicableYears.contains(studentYear) || 
                             applicableYears.contains(int.tryParse(studentYear)?.toString());
          final branchMatches = applicableBranches.any((b) => 
              b.toLowerCase() == branchLower || 
              b.toLowerCase().contains(branchLower));

          if (yearMatches && branchMatches) {
            final facultyAssignment = await _getFacultyForSubject(
              subjectCode: data['code'] ?? doc.id,
              year: studentYear,
              semester: semester,
            );

            subjects.add({
              'subjectId': doc.id,
              'subjectCode': data['code'] ?? doc.id,
              'subjectName': data['name'] ?? '',
              'facultyId': facultyAssignment?['facultyId'] ?? '',
              'facultyName': facultyAssignment?['facultyName'] ?? 'Not Assigned',
            });
          }
        }
      }

      // Strategy 5: As last resort, get ALL active subjects/courses to show something
      if (subjects.isEmpty) {
        // Try subjects collection without filters
        var allSubjects = await _firestore.collection('subjects').limit(20).get();
        
        if (allSubjects.docs.isEmpty) {
          allSubjects = await _firestore.collection('courses').limit(20).get();
        }

        for (final doc in allSubjects.docs) {
          final data = doc.data();
          final facultyAssignment = await _getFacultyForSubject(
            subjectCode: data['code'] ?? doc.id,
            year: studentYear,
            semester: semester,
          );

          subjects.add({
            'subjectId': doc.id,
            'subjectCode': data['code'] ?? doc.id,
            'subjectName': data['name'] ?? '',
            'facultyId': facultyAssignment?['facultyId'] ?? '',
            'facultyName': facultyAssignment?['facultyName'] ?? 'Not Assigned',
          });
        }
      }

      return subjects;
    } catch (e) {
      throw Exception('Failed to get feedback subjects: $e');
    }
  }

  Future<Map<String, dynamic>?> _getFacultyForSubject({
    required String subjectCode,
    required String year,
    required String semester,
  }) async {
    try {
      final assignmentSnapshot = await _firestore
          .collection('facultyAssignments')
          .where('subjectCode', isEqualTo: subjectCode)
          .limit(1)
          .get();

      if (assignmentSnapshot.docs.isNotEmpty) {
        final data = assignmentSnapshot.docs.first.data();
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
    } catch (e) {
      throw Exception('Failed to submit feedback: $e');
    }
  }

  // ============ FACULTY: View Aggregated Feedback ============

  /// Get aggregated feedback for faculty (no student info visible)
  Future<List<Map<String, dynamic>>> getFacultyFeedbackSummary({
    required String facultyId,
  }) async {
    try {
      final snapshot = await _feedbackCollection
          .where('facultyId', isEqualTo: facultyId)
          .get();

      // Group feedback by subject and session
      final Map<String, Map<String, dynamic>> groupedFeedback = {};

      for (final doc in snapshot.docs) {
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
          final sessionDoc = await _feedbackSessionsCollection
              .doc(data['sessionId'])
              .get();
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
}
