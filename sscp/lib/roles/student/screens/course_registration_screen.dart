import 'package:flutter/material.dart';
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
  
  // TODO: Replace with actual student data from authentication
  final String studentId = 'student_001';
  final String studentYear = '2'; // Student's year
  final String studentBranch = 'CSE'; // Student's branch
  
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
    _loadData();
  }

  Future<void> _loadData() async {
    try {
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

      setState(() {
        _settings = settings;
        _availableCourses = courses;
        _requirement = requirement;
        _studentSelection = selection;
        _cachedValidation = null; // Reset validation cache
        _isLoading = false;
      });
    } catch (e) {
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
                children: courses.map((course) {
                  final isSelected = _studentSelection?.selectedCourseIds
                          .contains(course.id) ??
                      false;

                  return _CourseCheckboxWidget(
                    key: ValueKey(course.id),
                    course: course,
                    isSelected: isSelected,
                    courseType: typeLabel,
                    onChanged: _handleCourseSelectionChanged,
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleCourseSelectionChanged(
    Course course,
    bool isSelected,
    String courseType,
  ) async {
    try {
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

      // Reload data minimally
      if (mounted) {
        final updatedSelection =
            await _courseService.getOrCreateStudentSelection(
          studentId,
          studentYear,
          studentBranch,
        );

        setState(() {
          _studentSelection = updatedSelection;
          _cachedValidation = null; // Invalidate validation cache
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
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
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
        onPressed: _isSaving
            ? null
            : () async {
                final validation = _courseService.validateSelections(
                  _studentSelection!,
                  _requirement,
                );

                if (!validation['isValid']) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(validation['message']),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  return;
                }

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
            : const Text(
                'Submit Registration',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }

  Widget _buildUpdateButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue,
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
        onPressed: _isSaving
            ? null
            : () async {
                final validation = _courseService.validateSelections(
                  _studentSelection!,
                  _requirement,
                );

                if (!validation['isValid']) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(validation['message']),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  return;
                }

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
            : const Text(
                'Update Registration',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
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
