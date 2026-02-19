import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/course_model.dart';
import '../models/student_course_selection_model.dart';

class StudentCourseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference get _studentCoursesCollection =>
      _firestore.collection('studentCourses');
  CollectionReference get _coursesCollection => _firestore.collection('courses');
  DocumentReference get _registrationSettingsDoc =>
      _firestore.collection('settings').doc('courseRegistration');
  CollectionReference get _courseRequirementsCollection =>
      _firestore.collection('courseRequirements');

  // ============ Registration Settings ============

  /// Get current registration status
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

  /// Check if registration is currently open based on dates
  Future<bool> isRegistrationOpen() async {
    try {
      final settings = await getRegistrationSettings();
      if (settings == null) return false;

      final now = DateTime.now();
      return settings.isRegistrationEnabled &&
          now.isAfter(settings.registrationStartDate) &&
          now.isBefore(settings.registrationEndDate);
    } catch (e) {
      throw Exception('Failed to check registration status: $e');
    }
  }

  // ============ Course Loading ============

  /// Get available courses for student's year and branch, grouped by type
  Future<Map<CourseType, List<Course>>> getAvailableCoursesGroupedByType(
      String year, String branch) async {
    try {
      final courses = <CourseType, List<Course>>{};

      for (final courseType in CourseType.values) {
        final typeStr = courseType.toString().split('.').last;
        print('DEBUG: Querying courses - type="$typeStr", applicableYears contains "$year", isActive=true');
        
        final snapshot = await _coursesCollection
            .where('type', isEqualTo: typeStr)
            .where('applicableYears', arrayContains: year)
            .where('isActive', isEqualTo: true)
            .get();

        print('DEBUG: Found ${snapshot.docs.length} $typeStr courses before branch filter');
        
        // Filter by branch in-memory since Firestore doesn't support multiple array-contains
        courses[courseType] = snapshot.docs
            .map((doc) => Course.fromFirestore(doc))
            .where((course) => course.applicableBranches.contains(branch))
            .toList();
            
        print('DEBUG: Found ${courses[courseType]!.length} $typeStr courses after branch filter for "$branch"');
      }

      return courses;
    } catch (e) {
      print('DEBUG: Error in getAvailableCoursesGroupedByType: $e');
      throw Exception(
          'Failed to get available courses for year $year, branch $branch: $e');
    }
  }

  /// Get course requirements for student's year and branch
  Future<CourseRequirement?> getCourseRequirement(
      String year, String branch) async {
    try {
      print('DEBUG: Querying courseRequirements - year="$year", branch="$branch"');
      
      final snapshot = await _courseRequirementsCollection
          .where('year', isEqualTo: year)
          .where('branch', isEqualTo: branch)
          .get();

      print('DEBUG: Found ${snapshot.docs.length} matching requirements');
      
      if (snapshot.docs.isNotEmpty) {
        final req = CourseRequirement.fromFirestore(snapshot.docs.first);
        print('DEBUG: Requirement found - OE: ${req.oeCount}, PE: ${req.peCount}, SE: ${req.seCount}');
        return req;
      }
      
      // DEBUG: Try to get all requirements to see what's available
      print('DEBUG: No requirement found. Fetching all requirements to diagnose...');
      final allReqs = await _courseRequirementsCollection.get();
      print('DEBUG: Total requirements in database: ${allReqs.docs.length}');
      for (final doc in allReqs.docs) {
        final data = doc.data() as Map<String, dynamic>;
        print('DEBUG: Available requirement - year="${data['year']}" (${data['year'].runtimeType}), branch="${data['branch']}"');
      }
      
      return null;
    } catch (e) {
      print('DEBUG: Error in getCourseRequirement: $e');
      throw Exception('Failed to get course requirement: $e');
    }
  }

  /// Get specific course by ID
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

  // ============ Student Course Selection ============

  /// Get or create student's course selection record
  Future<StudentCourseSelection> getOrCreateStudentSelection(
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

      // Create new if doesn't exist
      final newSelection = StudentCourseSelection(
        id: '', // Will be set by Firestore
        studentId: studentId,
        year: year,
        branch: branch,
        selectedCourseIds: [],
        selectionsByType: {},
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final docRef =
          await _studentCoursesCollection.add(newSelection.toFirestore());
      return newSelection.copyWith(id: docRef.id);
    } catch (e) {
      throw Exception('Failed to get or create student selection: $e');
    }
  }

  /// Save student's course selections
  Future<void> saveStudentSelection(
      StudentCourseSelection selection) async {
    try {
      await _studentCoursesCollection.doc(selection.id).set(
        selection.copyWith(updatedAt: DateTime.now()).toFirestore(),
        SetOptions(merge: true),
      );
    } catch (e) {
      throw Exception('Failed to save student selection: $e');
    }
  }

  /// Submit final course registration
  Future<void> submitCourseRegistration(
      StudentCourseSelection selection) async {
    try {
      await _studentCoursesCollection.doc(selection.id).set(
        selection.copyWith(isSubmitted: true, updatedAt: DateTime.now()).toFirestore(),
        SetOptions(merge: true),
      );
    } catch (e) {
      throw Exception('Failed to submit course registration: $e');
    }
  }

  /// Add course to student's selection
  /// Validates that student can edit and requirements allow adding more courses
  /// Add course to student's selection
  /// Always fetches fresh state from Firestore for validation to avoid stale data
  Future<void> addCourseSelection(
    String studentId,
    String year,
    String branch,
    String courseId,
    String courseType,
    {StudentCourseSelection? currentSelection}
  ) async {
    try {
      // Always fetch fresh selection from Firestore for accurate validation
      final selection = await getOrCreateStudentSelection(studentId, year, branch);

      // Check if student can edit
      if (!canEditSelection(selection)) {
        throw Exception(
            'Cannot modify submission. Your registration has been submitted and is locked.');
      }

      final requirement = await getCourseRequirement(year, branch);
      if (requirement == null) {
        throw Exception('Course requirements not defined for your year/branch');
      }

      // Check if adding this course would exceed the requirement
      final currentCount =
          (selection.selectionsByType[courseType] as List<dynamic>?)?.length ?? 0;
      final requiredCount = _getRequiredCountForType(requirement, courseType);

      if (currentCount >= requiredCount) {
        throw Exception(
            'Cannot add more $courseType courses. Required: $requiredCount, Current: $currentCount');
      }

      final updatedSelectedCourses = [...selection.selectedCourseIds];
      if (!updatedSelectedCourses.contains(courseId)) {
        updatedSelectedCourses.add(courseId);
      }

      final updatedSelectionsByType = {...selection.selectionsByType};
      if (!updatedSelectionsByType.containsKey(courseType)) {
        updatedSelectionsByType[courseType] = [];
      }
      if (!updatedSelectionsByType[courseType].contains(courseId)) {
        updatedSelectionsByType[courseType].add(courseId);
      }

      await saveStudentSelection(selection.copyWith(
        selectedCourseIds: updatedSelectedCourses,
        selectionsByType: updatedSelectionsByType,
      ));
    } catch (e) {
      throw Exception('Failed to add course selection: $e');
    }
  }

  /// Remove course from student's selection
  /// Validates that student can edit
  /// Always fetches fresh state from Firestore for accurate tracking
  Future<void> removeCourseSelection(
    String studentId,
    String year,
    String branch,
    String courseId,
    String courseType,
    {StudentCourseSelection? currentSelection}
  ) async {
    try {
      // Always fetch fresh selection from Firestore for accurate tracking
      final selection = await getOrCreateStudentSelection(studentId, year, branch);

      // Check if student can edit
      if (!canEditSelection(selection)) {
        throw Exception(
            'Cannot modify submission. Your registration has been submitted and is locked.');
      }

      final updatedSelectedCourses = [...selection.selectedCourseIds];
      updatedSelectedCourses.remove(courseId);

      final updatedSelectionsByType = {...selection.selectionsByType};
      if (updatedSelectionsByType.containsKey(courseType)) {
        updatedSelectionsByType[courseType] =
            (updatedSelectionsByType[courseType] as List<dynamic>)
                .where((id) => id != courseId)
                .toList();
      }

      await saveStudentSelection(selection.copyWith(
        selectedCourseIds: updatedSelectedCourses,
        selectionsByType: updatedSelectionsByType,
      ));
    } catch (e) {
      throw Exception('Failed to remove course selection: $e');
    }
  }

  // ============ Validation ============

  /// Check if student can edit (not submitted or admin unlocked)
  bool canEditSelection(StudentCourseSelection selection) {
    return !selection.isSubmitted || selection.isUnlocked;
  }

  /// Validate student's selections against requirements
  /// Returns validation result with isValid flag and error messages
  Map<String, dynamic> validateSelections(
    StudentCourseSelection selection,
    CourseRequirement? requirement,
  ) {
    if (requirement == null) {
      return {
        'isValid': false,
        'message': 'No course requirements defined for your year/branch',
      };
    }

    final selections = selection.selectionsByType;
    final oeCount = (selections['OE'] as List<dynamic>?)?.length ?? 0;
    final peCount = (selections['PE'] as List<dynamic>?)?.length ?? 0;
    final seCount = (selections['SE'] as List<dynamic>?)?.length ?? 0;

    final oeValid = oeCount == requirement.oeCount;
    final peValid = peCount == requirement.peCount;
    final seValid = seCount == requirement.seCount;

    final errors = <String>[];
    if (!oeValid) {
      errors.add('Open Electives: Select ${requirement.oeCount} (Selected: $oeCount)');
    }
    if (!peValid) {
      errors.add('Program Electives: Select ${requirement.peCount} (Selected: $peCount)');
    }
    if (!seValid) {
      errors.add('Subject Electives: Select ${requirement.seCount} (Selected: $seCount)');
    }

    return {
      'isValid': oeValid && peValid && seValid,
      'oeValid': oeValid,
      'peValid': peValid,
      'seValid': seValid,
      'message': errors.isEmpty
          ? 'All requirements met!'
          : 'Please fix the following:\n\n${errors.join('\n')}',
      'errors': errors,
    };
  }

  /// Get validation status for all course types
  Map<String, Map<String, dynamic>> getValidationStatus(
    StudentCourseSelection selection,
    CourseRequirement? requirement,
  ) {
    if (requirement == null) {
      return {};
    }

    final selections = selection.selectionsByType;
    
    return {
      'OE': {
        'required': requirement.oeCount,
        'selected': (selections['OE'] as List<dynamic>?)?.length ?? 0,
        'isValid': (selections['OE'] as List<dynamic>?)?.length == requirement.oeCount,
      },
      'PE': {
        'required': requirement.peCount,
        'selected': (selections['PE'] as List<dynamic>?)?.length ?? 0,
        'isValid': (selections['PE'] as List<dynamic>?)?.length == requirement.peCount,
      },
      'SE': {
        'required': requirement.seCount,
        'selected': (selections['SE'] as List<dynamic>?)?.length ?? 0,
        'isValid': (selections['SE'] as List<dynamic>?)?.length == requirement.seCount,
      },
    };
  }

  /// Helper method to get required count for a course type
  int _getRequiredCountForType(CourseRequirement requirement, String courseType) {
    switch (courseType) {
      case 'OE':
        return requirement.oeCount;
      case 'PE':
        return requirement.peCount;
      case 'SE':
        return requirement.seCount;
      default:
        return 0;
    }
  }

  /// Check if requirements can be fully satisfied with available courses
  /// Returns true if enough courses are available for the requirement
  Future<bool> canRequirementsBeMet(
    String year,
    String branch,
    CourseRequirement requirement,
  ) async {
    try {
      final availableCourses =
          await getAvailableCoursesGroupedByType(year, branch);

      final oeAvailable = availableCourses[CourseType.OE]?.length ?? 0;
      final peAvailable = availableCourses[CourseType.PE]?.length ?? 0;
      final seAvailable = availableCourses[CourseType.SE]?.length ?? 0;

      return oeAvailable >= requirement.oeCount &&
          peAvailable >= requirement.peCount &&
          seAvailable >= requirement.seCount;
    } catch (e) {
      throw Exception('Failed to check if requirements can be met: $e');
    }
  }
}
