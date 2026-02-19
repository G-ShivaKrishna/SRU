import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../models/course_model.dart';
import '../../../models/student_course_selection_model.dart';
import '../../../services/student_course_service.dart';
import '../../../widgets/app_header.dart';

class CourseRegistrationScreen extends StatefulWidget {
  const CourseRegistrationScreen({super.key});

  @override
  State<CourseRegistrationScreen> createState() =>
      _CourseRegistrationScreenState();
}

class _CourseRegistrationScreenState extends State<CourseRegistrationScreen>
    with SingleTickerProviderStateMixin {
  TabController? _tabController;
  final StudentCourseService _courseService = StudentCourseService();
  
  String studentId = '';
  String studentYear = '';
  String studentBranch = '';
  
  CourseRegistrationSettings? _settings;
  Map<CourseType, List<Course>> _availableCourses = {};
  CourseRequirement? _requirement;
  StudentCourseSelection? _studentSelection;
  bool _isLoading = true;
  bool _isSaving = false;
  Map<String, dynamic>? _cachedValidation;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadStudentDataAndCourses();
  }

  Future<void> _loadStudentDataAndCourses() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('No user logged in');
      }

      // Extract hall ticket number from Firebase email
      // Email format: [hallTicketNumber]@sru.edu.in
      final email = user.email ?? '';
      final hallTicketNumber = email.split('@')[0].toUpperCase();

      // Fetch student data using hall ticket number as document ID
      final studentDoc = await FirebaseFirestore.instance
          .collection('students')
          .doc(hallTicketNumber)
          .get();

      if (!studentDoc.exists) {
        throw Exception('Student profile not found for $hallTicketNumber. Please complete your profile first.');
      }

      // Initialize variables directly (not in setState)
      studentId = user.uid;
      studentYear = studentDoc['year']?.toString() ?? '1';
      studentBranch = studentDoc['department']?.toString() ?? 'CSE';

      // Now load the course data (variables are already initialized)
      await _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading student data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadData() async {
    try {
      // DEBUG: Print query parameters
      debugPrint('=== Course Registration Debug ===');
      debugPrint('Querying with Year: "$studentYear", Branch: "$studentBranch"');
      
      final settings = await _courseService.getRegistrationSettings();
      final courses = await _courseService.getAvailableCoursesGroupedByType(
        studentYear,
        studentBranch,
      );
      final requirement =
          await _courseService.getCourseRequirement(studentYear, studentBranch);
      final selection =
          await _courseService.getOrCreateStudentSelection(
        studentId,
        studentYear,
        studentBranch,
      );

      // DEBUG: Print query results
      debugPrint('Requirement found: ${requirement != null}');
      if (requirement != null) {
        debugPrint('Requirement: OE=${requirement.oeCount}, PE=${requirement.peCount}, SE=${requirement.seCount}');
      }
      debugPrint('Courses found: OE=${courses[CourseType.OE]?.length ?? 0}, PE=${courses[CourseType.PE]?.length ?? 0}, SE=${courses[CourseType.SE]?.length ?? 0}');
      debugPrint('=================================');

      setState(() {
        _settings = settings;
        _availableCourses = courses;
        _requirement = requirement;
        _studentSelection = selection;
        _cachedValidation = null; // Reset validation cache
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading course data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: $e')),
        );
      }
      setState(() {
        _isLoading = false;
      });
    }
  }

  bool _isRegistrationOpen() {
    if (_settings == null) return false;
    final now = DateTime.now();
    return _settings!.isRegistrationEnabled &&
        now.isAfter(_settings!.registrationStartDate) &&
        now.isBefore(_settings!.registrationEndDate);
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    if (_isLoading || _tabController == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Student Course Registration'),
          backgroundColor: const Color(0xFF1e3a5f),
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Course Registration'),
        backgroundColor: const Color(0xFF1e3a5f),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          const AppHeader(),
          _buildHeaderSection(context),
          if (!_isRegistrationOpen()) _buildDisabledMessage(context),
          Container(
            color: const Color(0xFF1e3a5f),
            child: TabBar(
              controller: _tabController!,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              indicatorColor: Colors.yellow,
              tabs: const [
                Tab(text: 'Register'),
                Tab(text: 'Edit'),
                Tab(text: 'Status'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController!,
              children: [
                _buildRegisterTab(context),
                _buildEditTab(context),
                _buildStatusTab(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderSection(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Container(
      color: const Color(0xFF1e3a5f),
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      child: Column(
        children: [
          Text(
            'Student Course Registration - Year $studentYear, $studentBranch',
            style: TextStyle(
              color: Colors.yellow,
              fontSize: isMobile ? 13 : 16,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Academic Year: 2025-26',
            style: TextStyle(
              color: Colors.white,
              fontSize: isMobile ? 11 : 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          if (_settings != null)
            Text(
              _isRegistrationOpen()
                  ? 'Registration Open'
                  : 'Registration Closed',
              style: TextStyle(
                color: _isRegistrationOpen() ? Colors.green : Colors.red,
                fontSize: isMobile ? 11 : 12,
                fontWeight: FontWeight.bold,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDisabledMessage(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      margin: EdgeInsets.all(isMobile ? 12 : 16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3CD),
        border: Border.all(color: const Color(0xFFFFE69C)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (_settings != null) ...[
            Text(
              'Registration Closed',
              style: TextStyle(
                fontSize: isMobile ? 14 : 16,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF856404),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Registration Opens: ${_formatDateTime(_settings!.registrationStartDate)}',
              style: TextStyle(
                fontSize: isMobile ? 12 : 13,
                color: const Color(0xFF856404),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              'Registration Closes: ${_formatDateTime(_settings!.registrationEndDate)}',
              style: TextStyle(
                fontSize: isMobile ? 12 : 13,
                color: const Color(0xFF856404),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRegisterTab(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    if (!_isRegistrationOpen()) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(isMobile ? 16 : 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              const Text(
                'Registration is Currently Closed',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              if (_settings != null)
                Text(
                  'Registration will open on ${_formatDateTime(_settings!.registrationStartDate)}',
                  style: TextStyle(
                    fontSize: isMobile ? 12 : 14,
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
            ],
          ),
        ),
      );
    }

    if (_studentSelection?.isSubmitted ?? false) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(isMobile ? 16 : 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle, size: 64, color: Colors.green),
              const SizedBox(height: 16),
              const Text(
                'Registration Submitted',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Your course registration has been submitted successfully.',
                style: TextStyle(
                  fontSize: isMobile ? 12 : 14,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                ),
                onPressed: () => _tabController?.animateTo(2),
                child: const Text(
                  'View Registration',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return _buildRegistrationForm(context);
  }

  Widget _buildRegistrationForm(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 12 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildValidationStatus(context),
            const SizedBox(height: 16),
            ...CourseType.values.map((type) {
              final courses = _availableCourses[type] ?? [];
              final typeStr = type.toString().split('.').last;
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _buildCourseTypeSection(
                  context,
                  typeStr,
                  courses,
                  type,
                ),
              );
            }).toList(),
            const SizedBox(height: 16),
            _buildSubmitButton(context),
          ],
        ),
      ),
    );
  }

  Widget _buildEditTab(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    if (!_isRegistrationOpen()) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(isMobile ? 16 : 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              const Text(
                'Edit Not Available',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Registration is currently closed. You can only edit during the registration period.',
                style: TextStyle(
                  fontSize: isMobile ? 12 : 14,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    // Check if submission is locked
    if ((_studentSelection?.isSubmitted ?? false) &&
        !(_studentSelection?.isUnlocked ?? false)) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(isMobile ? 16 : 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock, size: 64, color: Colors.orange),
              const SizedBox(height: 16),
              const Text(
                'Registration Locked',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Your course registration has been submitted and is now locked. You cannot edit your selections unless the admin unlocks it for you.',
                style: TextStyle(
                  fontSize: isMobile ? 12 : 14,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 12 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if ((_studentSelection?.isSubmitted ?? false) &&
                (_studentSelection?.isUnlocked ?? false))
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.blue[100],
                  border: Border.all(color: Colors.blue[400]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Admin has unlocked your registration for editing. Please review and update your selections.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.blue[900],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            _buildValidationStatus(context),
            const SizedBox(height: 16),
            ...CourseType.values.map((type) {
              final courses = _availableCourses[type] ?? [];
              final typeStr = type.toString().split('.').last;
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _buildCourseTypeSection(
                  context,
                  typeStr,
                  courses,
                  type,
                ),
              );
            }).toList(),
            const SizedBox(height: 16),
            _buildUpdateButton(context),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusTab(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    if (_studentSelection == null || _studentSelection!.selectedCourseIds.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(isMobile ? 16 : 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.info_outline,
                size: 64,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              const Text(
                'No Courses Registered Yet',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'You have not registered for any courses yet. Go to the Register tab to select courses.',
                style: TextStyle(
                  fontSize: isMobile ? 12 : 14,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 12 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ...CourseType.values.map((type) {
              final typeStr = type.toString().split('.').last;
              final selectedIds =
                  (_studentSelection!.selectionsByType[typeStr]
                      as List<dynamic>?) ??
                  [];

              return FutureBuilder<List<Course>>(
                future: Future.wait<Course?>(
                  selectedIds.map((id) => _courseService.getCourse(id as String)),
                ).then((courses) => courses.whereType<Course>().toList()),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final courses = snapshot.data?.whereType<Course>().toList() ?? [];

                  if (courses.isEmpty) return const SizedBox.shrink();

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _buildRegisteredCoursesSection(
                      context,
                      typeStr,
                      courses,
                    ),
                  );
                },
              );
            }).toList(),
            if (_studentSelection!.isSubmitted)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green[100],
                  border: Border.all(color: Colors.green[400]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Your registration has been submitted.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.green[900],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  // New helper methods for integrated functionality

  Widget _buildValidationStatus(BuildContext context) {
    if (_requirement == null) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.orange[100],
          border: Border.all(color: Colors.orange[400]!),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          'Course requirements not set for your year/branch. Please contact Dean Academics.',
          style: TextStyle(
            fontSize: 12,
            color: Colors.orange[900],
          ),
        ),
      );
    }

    // Cache validation to avoid recalculation
    _cachedValidation ??= _courseService.getValidationStatus(
      _studentSelection!,
      _requirement,
    );

    return RepaintBoundary(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.blue[100],
          border: Border.all(color: Colors.blue[400]!),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Course Selection Progress:',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
            const SizedBox(height: 8),
            ..._cachedValidation!.entries.map((entry) {
              final type = entry.key;
              final data = entry.value as Map<String, dynamic>;
              final isValid = data['isValid'] as bool;
              final selected = data['selected'] as int;
              final required = data['required'] as int;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '$type: $selected/$required',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue[900],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Icon(
                      isValid ? Icons.check_circle : Icons.radio_button_unchecked,
                      size: 16,
                      color: isValid ? Colors.green : Colors.orange,
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildCourseTypeSection(
    BuildContext context,
    String typeLabel,
    List<Course> courses,
    CourseType type,
  ) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    if (courses.isEmpty) {
      return _EmptyCourseSection(typeLabel: typeLabel);
    }

    // Get selected courses for this type
    final selectedCourseIds = _studentSelection?.selectionsByType[typeLabel] ?? [];
    final selectedCourses = courses.where((c) => selectedCourseIds.contains(c.id)).toList();
    final availableCourses = courses.where((c) => !selectedCourseIds.contains(c.id)).toList();

    // Get requirement for this type
    final requiredCount = _getRequiredCountForType(typeLabel);
    final canAddMore = selectedCourses.length < requiredCount;
    final remainingSlots = requiredCount - selectedCourses.length;

    return RepaintBoundary(
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                color: Color(0xFF1e3a5f),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(7),
                  topRight: Radius.circular(7),
                ),
              ),
              child: Text(
                '$typeLabel Courses',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Dropdown for selecting courses
                  if (canAddMore && availableCourses.isNotEmpty)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (remainingSlots > 0)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(
                              'Select $remainingSlots more course(s)',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.blue[700],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        _CourseSelectionDropdown(
                          typeLabel: typeLabel,
                          availableCourses: availableCourses,
                          onCourseSelected: (course) async {
                            await _handleCourseSelectionChanged(course, true, typeLabel);
                          },
                        ),
                      ],
                    )
                  else if (!canAddMore)
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                      child: Text(
                        'Required courses selected ($requiredCount/$requiredCount)',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.green[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                      child: Text(
                        'No more courses available',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  
                  if (selectedCourses.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Selected Courses (${selectedCourses.length}/$requiredCount)',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: selectedCourses.length == requiredCount ? Colors.green : Colors.blue,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...selectedCourses.map((course) {
                      return _SelectedCourseWidget(
                        key: ValueKey('selected_${course.id}'),
                        course: course,
                        courseType: typeLabel,
                        onRemove: () async {
                          await _handleCourseSelectionChanged(course, false, typeLabel);
                        },
                      );
                    }).toList(),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Helper method to get required count for a course type
  int _getRequiredCountForType(String courseType) {
    if (_requirement == null) return 0;
    
    switch (courseType) {
      case 'OE':
        return _requirement!.oeCount;
      case 'PE':
        return _requirement!.peCount;
      case 'SE':
        return _requirement!.seCount;
      default:
        return 0;
    }
  }

  Future<void> _handleCourseSelectionChanged(
    Course course,
    bool isSelected,
    String courseType,
  ) async {
    try {
      // Optimistic UI update - update local state immediately
      final currentSelection = _studentSelection;
      if (currentSelection == null) return;

      final updatedSelectedCourseIds = [...currentSelection.selectedCourseIds];
      final updatedSelectionsByType = {...currentSelection.selectionsByType};

      if (isSelected) {
        // Add course
        if (!updatedSelectedCourseIds.contains(course.id)) {
          updatedSelectedCourseIds.add(course.id);
        }
        if (!updatedSelectionsByType.containsKey(courseType)) {
          updatedSelectionsByType[courseType] = [];
        }
        if (!updatedSelectionsByType[courseType].contains(course.id)) {
          updatedSelectionsByType[courseType].add(course.id);
        }
      } else {
        // Remove course
        updatedSelectedCourseIds.remove(course.id);
        if (updatedSelectionsByType.containsKey(courseType)) {
          updatedSelectionsByType[courseType] =
              (updatedSelectionsByType[courseType] as List<dynamic>)
                  .where((id) => id != course.id)
                  .toList();
        }
      }

      // Create the optimistic selection object
      final optimisticSelection = currentSelection.copyWith(
        selectedCourseIds: updatedSelectedCourseIds,
        selectionsByType: updatedSelectionsByType,
      );

      // Update state immediately with new selection
      if (mounted) {
        setState(() {
          _studentSelection = optimisticSelection;
          _cachedValidation = null; // Invalidate validation cache
        });
      }

      // Sync to Firestore in the background (backend validates against fresh Firestore state)
      if (isSelected) {
        await _courseService.addCourseSelection(
          studentId,
          studentYear,
          studentBranch,
          course.id,
          courseType,
        );
      } else {
        await _courseService.removeCourseSelection(
          studentId,
          studentYear,
          studentBranch,
          course.id,
          courseType,
        );
      }
    } catch (e) {
      if (mounted) {
        // Extract user-friendly error message
        String errorMessage = e.toString();
        if (errorMessage.contains('Cannot add more')) {
          // Extract the specific error about course limits
          final match = RegExp(r'Cannot add more (\w+) courses\. Required: (\d+), Current: (\d+)')
              .firstMatch(errorMessage);
          if (match != null) {
            errorMessage = 'You have already selected ${match.group(3)} ${match.group(1)} course(s). '
                'Only ${match.group(2)} are required. Please remove a course if you want to select a different one.';
          }
        }
        
        // Show error and reload from Firestore
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
        // Reload to revert to last saved state
        final savedSelection =
            await _courseService.getOrCreateStudentSelection(
          studentId,
          studentYear,
          studentBranch,
        );
        if (mounted) {
          setState(() {
            _studentSelection = savedSelection;
            _cachedValidation = null;
          });
        }
      }
    }
  }

  Widget _buildRegisteredCoursesSection(
    BuildContext context,
    String typeLabel,
    List<Course> courses,
  ) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: Color(0xFF1e3a5f),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(7),
                topRight: Radius.circular(7),
              ),
            ),
            child: Text(
              '$typeLabel Courses - ${courses.length} course(s)',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: courses.asMap().entries.map((entry) {
                final course = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.green[100],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Icon(
                          Icons.check,
                          size: 16,
                          color: Colors.green,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${course.code} - ${course.name}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Credits: ${course.credits}',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton(BuildContext context) {
    // Check if requirements are met
    final validation = _courseService.validateSelections(
      _studentSelection!,
      _requirement,
    );
    final isValid = validation['isValid'] as bool;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!isValid)
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.orange[100],
              border: Border.all(color: Colors.orange[400]!),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Cannot Submit - Requirements Not Met',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                ...((validation['errors'] as List<String>?) ?? [])
                    .map((error) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            '• $error',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ))
                    .toList(),
              ],
            ),
          ),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isValid ? Colors.green : Colors.grey,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            onPressed: (!isValid || _isSaving)
                ? null
                : () async {
                    setState(() => _isSaving = true);

                    try {
                      await _courseService.submitCourseRegistration(
                        _studentSelection!,
                      );

                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Registration submitted successfully!'),
                            backgroundColor: Colors.green,
                          ),
                        );

                        // Reload data
                        final updated = await _courseService.getOrCreateStudentSelection(
                          studentId,
                          studentYear,
                          studentBranch,
                        );

                        setState(() {
                          _studentSelection = updated;
                          _isSaving = false;
                        });

                        _tabController?.animateTo(2);
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error: $e')),
                        );
                      }
                      setState(() => _isSaving = false);
                    }
                  },
            child: _isSaving
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Text(
                    isValid ? 'Submit Registration' : 'Cannot Submit',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildUpdateButton(BuildContext context) {
    // Check if requirements are met
    final validation = _courseService.validateSelections(
      _studentSelection!,
      _requirement,
    );
    final isValid = validation['isValid'] as bool;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!isValid)
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.orange[100],
              border: Border.all(color: Colors.orange[400]!),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Requirements Not Met',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                ...((validation['errors'] as List<String>?) ?? [])
                    .map((error) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            '• $error',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ))
                    .toList(),
              ],
            ),
          ),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isValid ? Colors.blue : Colors.grey,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            onPressed: (_isSaving || !isValid)
                ? null
                : () async {
                    setState(() => _isSaving = true);

                    try {
                      await _courseService.saveStudentSelection(
                        _studentSelection!,
                      );

                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Changes saved successfully!'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }

                      setState(() => _isSaving = false);
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error: $e')),
                        );
                      }
                      setState(() => _isSaving = false);
                    }
                  },
            child: _isSaving
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Text(
                    isValid ? 'Update Registration' : 'Cannot Save',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}

class _EmptyCourseSection extends StatelessWidget {
  final String typeLabel;

  const _EmptyCourseSection({required this.typeLabel});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: Color(0xFF1e3a5f),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(7),
                topRight: Radius.circular(7),
              ),
            ),
            child: Text(
              '$typeLabel Courses',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Center(
              child: Text(
                'No courses available',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CourseSelectionDropdown extends StatefulWidget {
  final String typeLabel;
  final List<Course> availableCourses;
  final Function(Course) onCourseSelected;

  const _CourseSelectionDropdown({
    required this.typeLabel,
    required this.availableCourses,
    required this.onCourseSelected,
  });

  @override
  State<_CourseSelectionDropdown> createState() =>
      _CourseSelectionDropdownState();
}

class _CourseSelectionDropdownState extends State<_CourseSelectionDropdown> {
  Course? _selectedCourse;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(6),
        color: Colors.grey[50],
      ),
      child: Row(
        children: [
          Expanded(
            child: DropdownButton<Course>(
              isExpanded: true,
              hint: Text(
                'Select a ${widget.typeLabel} course',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              value: _selectedCourse,
              underline: const SizedBox(), // Remove underline
              onChanged: (Course? course) {
                if (course != null) {
                  widget.onCourseSelected(course);
                  setState(() {
                    _selectedCourse = null;
                  });
                }
              },
              items: widget.availableCourses.map((Course course) {
                return DropdownMenuItem<Course>(
                  value: course,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${course.code} - ${course.name}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Credits: ${course.credits}',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            Icons.arrow_drop_down,
            color: Colors.grey[600],
          ),
        ],
      ),
    );
  }
}

class _SelectedCourseWidget extends StatelessWidget {
  final Course course;
  final String courseType;
  final VoidCallback onRemove;

  const _SelectedCourseWidget({
    required Key key,
    required this.course,
    required this.courseType,
    required this.onRemove,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.green[300]!),
        borderRadius: BorderRadius.circular(6),
        color: Colors.green[50],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.green,
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Icon(
              Icons.check,
              color: Colors.white,
              size: 16,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${course.code} - ${course.name}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  'Credits: ${course.credits}',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onRemove,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.red[100],
                borderRadius: BorderRadius.circular(4),
              ),
              child: Icon(
                Icons.close,
                color: Colors.red[600],
                size: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CourseCheckboxWidget extends StatelessWidget {
  final Course course;
  final bool isSelected;
  final String courseType;
  final Function(Course, bool, String) onChanged;

  const _CourseCheckboxWidget({
    required Key key,
    required this.course,
    required this.isSelected,
    required this.courseType,
    required this.onChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border.all(
          color: isSelected ? Colors.blue[400]! : Colors.grey[300]!,
        ),
        borderRadius: BorderRadius.circular(6),
        color: isSelected ? Colors.blue[50] : Colors.white,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(
            value: isSelected,
            onChanged: (value) async {
              await onChanged(course, value ?? false, courseType);
            },
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${course.code} - ${course.name}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  'Credits: ${course.credits}',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
