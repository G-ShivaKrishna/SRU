import 'package:flutter/material.dart';
import '../../../models/course_model.dart';
import '../../../services/admin_course_service.dart';
import '../../../widgets/app_header.dart';

class AdminCourseManagementScreen extends StatefulWidget {
  const AdminCourseManagementScreen({super.key});

  @override
  State<AdminCourseManagementScreen> createState() =>
      _AdminCourseManagementScreenState();
}

class _AdminCourseManagementScreenState
    extends State<AdminCourseManagementScreen> {
  final AdminCourseService _courseService = AdminCourseService();
  CourseRegistrationSettings? _settings;
  bool _isLoading = true;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _loadRegistrationSettings();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadRegistrationSettings() async {
    try {
      final settings = await _courseService.getRegistrationSettings();
      setState(() {
        _settings = settings;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading settings: $e')),
        );
      }
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Course Management'),
          backgroundColor: const Color(0xFF1e3a5f),
          foregroundColor: Colors.white,
        ),
        body: Column(
          children: [
            const AppHeader(),
            if (_isLoading)
              const Expanded(
                child: Center(child: CircularProgressIndicator()),
              )
            else ...[
              Container(
                color: const Color(0xFF1e3a5f),
                child: TabBar(
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white70,
                  indicatorColor: Colors.yellow,
                  tabs: const [
                    Tab(text: 'Registration Settings'),
                    Tab(text: 'Manage Courses'),
                    Tab(text: 'Course Requirements'),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _buildRegistrationSettingsTab(context),
                    _buildManageCoursesTab(context),
                    _buildCourseRequirementsTab(context),
                  ],
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }

  // ============ Registration Settings Tab ============
  Widget _buildRegistrationSettingsTab(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionCard(
            'Course Registration Status',
            [
              _buildRegistrationToggle(),
              const SizedBox(height: 16),
              if (_settings != null) ...[
                _buildInfoRow('Registration Enabled:',
                    _settings!.isRegistrationEnabled ? 'Yes' : 'No'),
                _buildInfoRow(
                    'Start Date:', _formatDate(_settings!.registrationStartDate)),
                _buildInfoRow(
                    'End Date:', _formatDate(_settings!.registrationEndDate)),
              ],
            ],
            context,
          ),
        ],
      ),
    );
  }

  Widget _buildRegistrationToggle() {
    return StatefulBuilder(
      builder: (context, setState) {
        bool isEnabled = _settings?.isRegistrationEnabled ?? false;
        DateTime startDate =
            _settings?.registrationStartDate ?? DateTime.now();
        DateTime endDate = _settings?.registrationEndDate ??
            DateTime.now().add(const Duration(days: 30));

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              title: const Text('Enable Course Registration'),
              subtitle: const Text(
                  'Toggle to enable/disable course registration for all students'),
              value: isEnabled,
              onChanged: (value) async {
                try {
                  await _courseService.toggleRegistration(
                    value,
                    startDate,
                    endDate,
                  );
                  await _loadRegistrationSettings();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Registration ${value ? 'enabled' : 'disabled'} successfully',
                      ),
                    ),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              },
            ),
            if (isEnabled) ...[
              const SizedBox(height: 16),
              _buildDatePickerField(
                'Registration Start Date',
                startDate,
                (selectedDate) {
                  startDate = selectedDate;
                },
              ),
              const SizedBox(height: 12),
              _buildDatePickerField(
                'Registration End Date',
                endDate,
                (selectedDate) {
                  endDate = selectedDate;
                },
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildDatePickerField(
    String label,
    DateTime initialDate,
    Function(DateTime) onDateSelected,
  ) {
    return GestureDetector(
      onTap: () async {
        final pickedDate = await showDatePicker(
          context: context,
          initialDate: initialDate,
          firstDate: DateTime.now(),
          lastDate: DateTime.now().add(const Duration(days: 365)),
        );
        if (pickedDate != null) {
          onDateSelected(pickedDate);
        }
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatDate(initialDate),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const Icon(Icons.calendar_today, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  // ============ Manage Courses Tab ============
  Widget _buildManageCoursesTab(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionCard(
            'Add New Course',
            [
              _buildAddCourseForm(context),
            ],
            context,
          ),
          const SizedBox(height: 16),
          _buildSectionCard(
            'All Courses',
            [
              _buildCoursesList(context),
            ],
            context,
          ),
        ],
      ),
    );
  }

  Widget _buildAddCourseForm(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    late String selectedType = 'OE';
    late TextEditingController codeController;
    late TextEditingController nameController;
    late TextEditingController creditsController;
    List<String> selectedYears = [];
    List<String> selectedBranches = [];

    const years = ['1', '2', '3', '4'];
    const branches = ['CSE', 'ECE', 'EEE', 'ME', 'CE'];

    resetForm() {
      codeController.clear();
      nameController.clear();
      creditsController.clear();
      selectedYears = [];
      selectedBranches = [];
      selectedType = 'OE';
    }

    return StatefulBuilder(
      builder: (context, setState) {
        codeController = TextEditingController();
        nameController = TextEditingController();
        creditsController = TextEditingController();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTextFieldWithLabel('Course Code', codeController,
                isMobile: isMobile),
            const SizedBox(height: 12),
            _buildTextFieldWithLabel('Course Name', nameController,
                isMobile: isMobile),
            const SizedBox(height: 12),
            _buildTextFieldWithLabel('Credits', creditsController,
                isMobile: isMobile,
                keyboardType: TextInputType.number),
            const SizedBox(height: 12),
            _buildDropdownField(
              'Course Type',
              selectedType,
              ['OE', 'PE', 'SE'],
              (value) {
                setState(() {
                  selectedType = value ?? 'OE';
                });
              },
              isMobile: isMobile,
            ),
            const SizedBox(height: 12),
            _buildMultiSelectField(
              'Select Years',
              years,
              selectedYears,
              (year, isSelected) {
                setState(() {
                  if (isSelected) {
                    selectedYears.add(year);
                  } else {
                    selectedYears.remove(year);
                  }
                });
              },
            ),
            const SizedBox(height: 12),
            _buildMultiSelectField(
              'Select Branches',
              branches,
              selectedBranches,
              (branch, isSelected) {
                setState(() {
                  if (isSelected) {
                    selectedBranches.add(branch);
                  } else {
                    selectedBranches.remove(branch);
                  }
                });
              },
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
              onPressed: () async {
                if (codeController.text.isEmpty ||
                    nameController.text.isEmpty ||
                    creditsController.text.isEmpty ||
                    selectedYears.isEmpty ||
                    selectedBranches.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please fill all fields'),
                    ),
                  );
                  return;
                }

                try {
                  final course = Course(
                    id: '',
                    code: codeController.text,
                    name: nameController.text,
                    credits: int.parse(creditsController.text),
                    type:
                        selectedType == 'OE'
                            ? CourseType.OE
                            : selectedType == 'PE'
                                ? CourseType.PE
                                : CourseType.SE,
                    applicableYears: selectedYears,
                    applicableBranches: selectedBranches,
                    createdAt: DateTime.now(),
                    updatedAt: DateTime.now(),
                  );

                  await _courseService.addCourse(course);
                  resetForm();
                  setState(() {});

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Course added successfully'),
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e')),
                    );
                  }
                }
              },
              child: const Text(
                'Add Course',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCoursesList(BuildContext context) {
    return FutureBuilder<List<Course>>(
      future: _courseService.getAllCourses(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text('Error: ${snapshot.error}'),
          );
        }

        final courses = snapshot.data ?? [];
        if (courses.isEmpty) {
          return const Center(
            child: Text('No courses added yet'),
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: courses.length,
          itemBuilder: (context, index) {
            final course = courses[index];
            return _buildCourseCard(course, context);
          },
        );
      },
    );
  }

  Widget _buildCourseCard(Course course, BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${course.code} - ${course.name}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Type: ${course.type.toString().split('.').last} | Credits: ${course.credits}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton(
                itemBuilder: (context) => [
                  PopupMenuItem(
                    child: const Text('Edit'),
                    onTap: () {
                      _showEditCourseDialog(context, course);
                    },
                  ),
                  PopupMenuItem(
                    child: const Text('Delete'),
                    onTap: () async {
                      final confirm = await _showConfirmDialog(context,
                          'Are you sure you want to delete this course?');
                      if (confirm) {
                        try {
                          await _courseService.deleteCourse(course.id);
                          setState(() {});
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Course deleted successfully'),
                              ),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error: $e')),
                            );
                          }
                        }
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 4,
            children: [
              ...course.applicableYears.map((year) => Chip(
                    label: Text('Year $year'),
                    labelStyle: const TextStyle(fontSize: 10),
                  )),
              ...course.applicableBranches.map((branch) => Chip(
                    label: Text(branch),
                    labelStyle: const TextStyle(fontSize: 10),
                  )),
            ],
          ),
        ],
      ),
    );
  }

  // ============ Course Requirements Tab ============
  Widget _buildCourseRequirementsTab(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    const years = ['1', '2', '3', '4'];
    const branches = ['CSE', 'ECE', 'EEE', 'ME', 'CE'];

    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionCard(
            'Set Course Requirements',
            [
              _buildRequirementsForm(years, branches, context),
            ],
            context,
          ),
          const SizedBox(height: 16),
          _buildSectionCard(
            'Current Requirements',
            [
              _buildRequirementsList(context),
            ],
            context,
          ),
        ],
      ),
    );
  }

  Widget _buildRequirementsForm(
      List<String> years, List<String> branches, BuildContext context) {
    String selectedYear = '1';
    String selectedBranch = 'CSE';
    int oeCount = 1;
    int peCount = 1;
    int seCount = 1;

    return StatefulBuilder(
      builder: (context, setState) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDropdownField(
              'Year',
              selectedYear,
              years,
              (value) {
                setState(() {
                  selectedYear = value ?? '1';
                });
              },
            ),
            const SizedBox(height: 12),
            _buildDropdownField(
              'Branch',
              selectedBranch,
              branches,
              (value) {
                setState(() {
                  selectedBranch = value ?? 'CSE';
                });
              },
            ),
            const SizedBox(height: 16),
            Text(
              'Number of Courses Required:',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 12),
            _buildCounterField(
              'Open Electives (OE)',
              oeCount,
              (value) {
                setState(() {
                  oeCount = value;
                });
              },
            ),
            const SizedBox(height: 12),
            _buildCounterField(
              'Program Electives (PE)',
              peCount,
              (value) {
                setState(() {
                  peCount = value;
                });
              },
            ),
            const SizedBox(height: 12),
            _buildCounterField(
              'Subject Electives (SE)',
              seCount,
              (value) {
                setState(() {
                  seCount = value;
                });
              },
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
              onPressed: () async {
                try {
                  final requirement = CourseRequirement(
                    id: '',
                    year: selectedYear,
                    branch: selectedBranch,
                    oeCount: oeCount,
                    peCount: peCount,
                    seCount: seCount,
                    createdAt: DateTime.now(),
                    updatedAt: DateTime.now(),
                  );

                  await _courseService.addCourseRequirement(requirement);
                  setState(() {});

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Requirements saved successfully'),
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e')),
                    );
                  }
                }
              },
              child: const Text(
                'Save Requirements',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildRequirementsList(BuildContext context) {
    return FutureBuilder<List<CourseRequirement>>(
      future: _courseService.getAllCourseRequirements(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text('Error: ${snapshot.error}'),
          );
        }

        final requirements = snapshot.data ?? [];
        if (requirements.isEmpty) {
          return const Center(
            child: Text('No requirements set yet'),
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: requirements.length,
          itemBuilder: (context, index) {
            final req = requirements[index];
            return _buildRequirementCard(req, context);
          },
        );
      },
    );
  }

  Widget _buildRequirementCard(CourseRequirement requirement, BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Year ${requirement.year} - ${requirement.branch}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              PopupMenuButton(
                itemBuilder: (context) => [
                  PopupMenuItem(
                    child: const Text('Delete'),
                    onTap: () async {
                      final confirm = await _showConfirmDialog(context,
                          'Are you sure you want to delete this requirement?');
                      if (confirm) {
                        try {
                          await _courseService
                              .deleteCourseRequirement(requirement.id);
                          setState(() {});
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Requirement deleted successfully'),
                              ),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error: $e')),
                            );
                          }
                        }
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildRequirementBadge('OE', requirement.oeCount),
              _buildRequirementBadge('PE', requirement.peCount),
              _buildRequirementBadge('SE', requirement.seCount),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRequirementBadge(String type, int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.blue[100],
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Text(
            type,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.blue,
            ),
          ),
          Text(
            count.toString(),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.blue,
            ),
          ),
        ],
      ),
    );
  }

  // ============ Helper Widgets ============

  Widget _buildSectionCard(
    String title,
    List<Widget> children,
    BuildContext context,
  ) {
    final isMobile = MediaQuery.of(context).size.width < 600;

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
            padding: EdgeInsets.all(isMobile ? 12 : 14),
            decoration: BoxDecoration(
              color: const Color(0xFF1e3a5f),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(7),
                topRight: Radius.circular(7),
              ),
            ),
            child: Text(
              title,
              style: TextStyle(
                color: Colors.white,
                fontSize: isMobile ? 13 : 15,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(isMobile ? 12 : 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextFieldWithLabel(
    String label,
    TextEditingController controller, {
    bool isMobile = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1e3a5f),
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
            ),
            contentPadding: EdgeInsets.symmetric(
              horizontal: 12,
              vertical: isMobile ? 10 : 12,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownField(
    String label,
    String value,
    List<String> items,
    Function(String?)? onChanged, {
    bool isMobile = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1e3a5f),
          ),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: value,
          items: items.map((item) {
            return DropdownMenuItem(
              value: item,
              child: Text(item),
            );
          }).toList(),
          onChanged: onChanged,
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
            ),
            contentPadding: EdgeInsets.symmetric(
              horizontal: 12,
              vertical: isMobile ? 10 : 12,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMultiSelectField(
    String label,
    List<String> items,
    List<String> selectedItems,
    Function(String, bool) onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1e3a5f),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: items.map((item) {
            return FilterChip(
              label: Text(item),
              selected: selectedItems.contains(item),
              onSelected: (isSelected) {
                onChanged(item, isSelected);
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildCounterField(
    String label,
    int value,
    Function(int) onChanged,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.remove),
                onPressed: value > 0 ? () => onChanged(value - 1) : null,
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  value.toString(),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add),
                onPressed: () => onChanged(value + 1),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF1e3a5f),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  Future<bool> _showConfirmDialog(BuildContext context, String message) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _showEditCourseDialog(BuildContext context, Course course) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    late String selectedType = course.type.toString().split('.').last;
    late TextEditingController codeController = TextEditingController(text: course.code);
    late TextEditingController nameController = TextEditingController(text: course.name);
    late TextEditingController creditsController = TextEditingController(text: course.credits.toString());
    List<String> selectedYears = List.from(course.applicableYears);
    List<String> selectedBranches = List.from(course.applicableBranches);

    const years = ['1', '2', '3', '4'];
    const branches = ['CSE', 'ECE', 'EEE', 'ME', 'CE'];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Course'),
        content: StatefulBuilder(
          builder: (context, setState) {
            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildTextFieldWithLabel('Course Code', codeController, isMobile: isMobile),
                  const SizedBox(height: 12),
                  _buildTextFieldWithLabel('Course Name', nameController, isMobile: isMobile),
                  const SizedBox(height: 12),
                  _buildTextFieldWithLabel('Credits', creditsController, isMobile: isMobile, keyboardType: TextInputType.number),
                  const SizedBox(height: 12),
                  _buildDropdownField(
                    'Course Type',
                    selectedType,
                    ['OE', 'PE', 'SE'],
                    (value) {
                      setState(() {
                        selectedType = value ?? 'OE';
                      });
                    },
                    isMobile: isMobile,
                  ),
                  const SizedBox(height: 12),
                  _buildMultiSelectField(
                    'Select Years',
                    years,
                    selectedYears,
                    (year, isSelected) {
                      setState(() {
                        if (isSelected) {
                          selectedYears.add(year);
                        } else {
                          selectedYears.remove(year);
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildMultiSelectField(
                    'Select Branches',
                    branches,
                    selectedBranches,
                    (branch, isSelected) {
                      setState(() {
                        if (isSelected) {
                          selectedBranches.add(branch);
                        } else {
                          selectedBranches.remove(branch);
                        }
                      });
                    },
                  ),
                ],
              ),
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () {
              codeController.dispose();
              nameController.dispose();
              creditsController.dispose();
              Navigator.pop(context);
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
            ),
            onPressed: () async {
              if (codeController.text.isEmpty ||
                  nameController.text.isEmpty ||
                  creditsController.text.isEmpty ||
                  selectedYears.isEmpty ||
                  selectedBranches.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please fill all fields'),
                  ),
                );
                return;
              }

              try {
                final updatedCourse = course.copyWith(
                  code: codeController.text,
                  name: nameController.text,
                  credits: int.parse(creditsController.text),
                  type: selectedType == 'OE'
                      ? CourseType.OE
                      : selectedType == 'PE'
                          ? CourseType.PE
                          : CourseType.SE,
                  applicableYears: selectedYears,
                  applicableBranches: selectedBranches,
                  updatedAt: DateTime.now(),
                );

                await _courseService.updateCourse(course.id, updatedCourse);
                
                codeController.dispose();
                nameController.dispose();
                creditsController.dispose();

                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Course updated successfully'),
                    ),
                  );
                  setState(() {});
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            child: const Text(
              'Save',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

