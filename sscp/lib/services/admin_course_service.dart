import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/course_model.dart';
import '../models/student_course_selection_model.dart';

class AdminCourseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Collection references
  CollectionReference get _coursesCollection =>
      _firestore.collection('courses');
  CollectionReference get _courseRequirementsCollection =>
      _firestore.collection('courseRequirements');
  CollectionReference get _studentCoursesCollection =>
      _firestore.collection('studentCourses');
  DocumentReference get _registrationSettingsDoc =>
      _firestore.collection('settings').doc('courseRegistration');

  // ============ Course Registration Settings ============

  /// Get current course registration settings
  Future<CourseRegistrationSettings?> getRegistrationSettings() async {
    try {
      final doc = await _registrationSettingsDoc.get();
      if (doc.exists) {
        return CourseRegistrationSettings.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get registration settings: $e');
    }
  }

  /// Enable or disable course registration
  /// enabledYears: List of years for which registration is enabled (e.g., ['1', '2', '3', '4'])
  Future<void> toggleRegistration(
    bool enable,
    DateTime startDate,
    DateTime endDate, {
    List<String> enabledYears = const ['1', '2', '3', '4'],
  }) async {
    try {
      await _registrationSettingsDoc.set({
        'isRegistrationEnabled': enable,
        'enabledYears': enabledYears,
        'registrationStartDate': startDate,
        'registrationEndDate': endDate,
        'lastModifiedBy': DateTime.now(),
        'updatedAt': DateTime.now(),
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      throw Exception('Failed to update registration settings: $e');
    }
  }

  // ============ Course Management ============

  /// Add a new course
  Future<String> addCourse(Course course) async {
    try {
      final docRef = await _coursesCollection.add(course.toFirestore());
      return docRef.id;
    } catch (e) {
      throw Exception('Failed to add course: $e');
    }
  }

  /// Update an existing course
  Future<void> updateCourse(String courseId, Course course) async {
    try {
      await _coursesCollection.doc(courseId).update(course.toFirestore());
    } catch (e) {
      throw Exception('Failed to update course: $e');
    }
  }

  /// Delete a course
  Future<void> deleteCourse(String courseId) async {
    try {
      await _coursesCollection.doc(courseId).delete();
    } catch (e) {
      throw Exception('Failed to delete course: $e');
    }
  }

  /// Get a single course by ID
  Future<Course?> getCourse(String courseId) async {
    try {
      final doc = await _coursesCollection.doc(courseId).get();
      if (doc.exists) {
        return Course.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get course: $e');
    }
  }

  /// Get all courses
  Future<List<Course>> getAllCourses() async {
    try {
      final snapshot = await _coursesCollection.get();
      return snapshot.docs
          .map((doc) => Course.fromFirestore(doc))
          .toList();
    } catch (e) {
      throw Exception('Failed to get courses: $e');
    }
  }

  /// Get courses by type (OE, PE, SE)
  Future<List<Course>> getCoursesByType(CourseType type) async {
    try {
      final snapshot = await _coursesCollection
          .where('type', isEqualTo: type.toString().split('.').last)
          .get();
      return snapshot.docs
          .map((doc) => Course.fromFirestore(doc))
          .toList();
    } catch (e) {
      throw Exception('Failed to get courses by type: $e');
    }
  }

  /// Get courses for a specific year and branch
  Future<List<Course>> getCoursesForYearAndBranch(
      String year, String branch) async {
    try {
      final snapshot = await _coursesCollection
          .where('applicableYears', arrayContains: year)
          .where('applicableBranches', arrayContains: branch)
          .where('isActive', isEqualTo: true)
          .get();
      return snapshot.docs
          .map((doc) => Course.fromFirestore(doc))
          .toList();
    } catch (e) {
      throw Exception(
          'Failed to get courses for year $year and branch $branch: $e');
    }
  }

  /// Get courses by type for specific year and branch
  Future<List<Course>> getCoursesByTypeForYearAndBranch(
      CourseType type, String year, String branch) async {
    try {
      final snapshot = await _coursesCollection
          .where('type', isEqualTo: type.toString().split('.').last)
          .where('applicableYears', arrayContains: year)
          .where('applicableBranches', arrayContains: branch)
          .where('isActive', isEqualTo: true)
          .get();
      return snapshot.docs
          .map((doc) => Course.fromFirestore(doc))
          .toList();
    } catch (e) {
      throw Exception(
          'Failed to get $type courses for year $year and branch $branch: $e');
    }
  }

  // ============ Course Requirements ============

  /// Add course requirements for a year and branch
  Future<String> addCourseRequirement(CourseRequirement requirement) async {
    try {
      // Check if requirement already exists for this year and branch
      final existing = await _courseRequirementsCollection
          .where('year', isEqualTo: requirement.year)
          .where('branch', isEqualTo: requirement.branch)
          .get();

      if (existing.docs.isNotEmpty) {
        // Update existing
        await _courseRequirementsCollection
            .doc(existing.docs.first.id)
            .update(requirement.toFirestore());
        return existing.docs.first.id;
      } else {
        // Create new
        final docRef =
            await _courseRequirementsCollection.add(requirement.toFirestore());
        return docRef.id;
      }
    } catch (e) {
      throw Exception('Failed to add course requirement: $e');
    }
  }

  /// Update course requirements
  Future<void> updateCourseRequirement(
      String requirementId, CourseRequirement requirement) async {
    try {
      await _courseRequirementsCollection
          .doc(requirementId)
          .update(requirement.toFirestore());
    } catch (e) {
      throw Exception('Failed to update course requirement: $e');
    }
  }

  /// Get course requirement for a year and branch
  Future<CourseRequirement?> getCourseRequirement(
      String year, String branch) async {
    try {
      final snapshot = await _courseRequirementsCollection
          .where('year', isEqualTo: year)
          .where('branch', isEqualTo: branch)
          .get();

      if (snapshot.docs.isNotEmpty) {
        return CourseRequirement.fromFirestore(snapshot.docs.first);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get course requirement: $e');
    }
  }

  /// Get all course requirements
  Future<List<CourseRequirement>> getAllCourseRequirements() async {
    try {
      final snapshot = await _courseRequirementsCollection.get();
      return snapshot.docs
          .map((doc) => CourseRequirement.fromFirestore(doc))
          .toList();
    } catch (e) {
      throw Exception('Failed to get course requirements: $e');
    }
  }

  /// Delete course requirement
  Future<void> deleteCourseRequirement(String requirementId) async {
    try {
      await _courseRequirementsCollection.doc(requirementId).delete();
    } catch (e) {
      throw Exception('Failed to delete course requirement: $e');
    }
  }

  // ============ Bulk Operations ============

  /// Get courses grouped by type for a year and branch
  Future<Map<CourseType, List<Course>>> getCoursesByTypeForYearAndBranchGrouped(
      String year, String branch) async {
    try {
      final courses = await getCoursesForYearAndBranch(year, branch);
      final groupedCourses = <CourseType, List<Course>>{};

      for (final courseType in CourseType.values) {
        groupedCourses[courseType] =
            courses.where((c) => c.type == courseType).toList();
      }

      return groupedCourses;
    } catch (e) {
      throw Exception('Failed to get grouped courses: $e');
    }
  }

  // ============ Student Submission Management ============

  /// Get all submitted student selections for a year and branch
  /// Useful for viewing all submissions
  Future<List<StudentCourseSelection>> getSubmittedSelectionsForYearBranch(
      String year, String branch) async {
    try {
      final snapshot = await _studentCoursesCollection
          .where('year', isEqualTo: year)
          .where('branch', isEqualTo: branch)
          .where('isSubmitted', isEqualTo: true)
          .get();

      return snapshot.docs
          .map((doc) => StudentCourseSelection.fromFirestore(doc))
          .toList();
    } catch (e) {
      throw Exception(
          'Failed to get submitted selections for year $year, branch $branch: $e');
    }
  }

  /// Unlock a student's submitted selection for re-editing
  /// Admin can call this to allow student to edit after submission
  Future<void> unlockStudentSelection(String selectionId) async {
    try {
      await _studentCoursesCollection.doc(selectionId).update({
        'isUnlocked': true,
        'updatedAt': DateTime.now(),
      });
    } catch (e) {
      throw Exception('Failed to unlock student selection: $e');
    }
  }

  /// Lock a student's selection (revert unlock)
  /// After student makes edits, admin should lock again
  Future<void> lockStudentSelection(String selectionId) async {
    try {
      await _studentCoursesCollection.doc(selectionId).update({
        'isUnlocked': false,
        'updatedAt': DateTime.now(),
      });
    } catch (e) {
      throw Exception('Failed to lock student selection: $e');
    }
  }

  /// Get a specific student's selection
  Future<StudentCourseSelection?> getStudentSelection(
      String studentId, String year, String branch) async {
    try {
      final snapshot = await _studentCoursesCollection
          .where('studentId', isEqualTo: studentId)
          .where('year', isEqualTo: year)
          .where('branch', isEqualTo: branch)
          .get();

      if (snapshot.docs.isNotEmpty) {
        return StudentCourseSelection.fromFirestore(snapshot.docs.first);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get student selection: $e');
    }
  }
}
