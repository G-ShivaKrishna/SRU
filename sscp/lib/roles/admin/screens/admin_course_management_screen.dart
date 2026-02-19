import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../models/course_model.dart';
import '../../../models/faculty_assignment_model.dart';
import '../../../services/admin_course_service.dart';
import '../../../services/faculty_assignment_service.dart';
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
  final FacultyAssignmentService _subjectService = FacultyAssignmentService();
  CourseRegistrationSettings? _settings;
  bool _isLoading = true;

  // Local state for year selection with safe defaults
  List<String> _selectedYears = <String>['1', '2', '3', '4'];
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 30));

  @override
  void initState() {
    super.initState();
    _loadRegistrationSettings();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadRegistrationSettings() async {
    try {
      final settings = await _courseService.getRegistrationSettings();
      setState(() {
        _settings = settings;
        if (settings != null) {
          _selectedYears = settings.enabledYears.isNotEmpty 
              ? List<String>.from(settings.enabledYears)
              : ['1', '2', '3', '4'];
          _startDate = settings.registrationStartDate;
          _endDate = settings.registrationEndDate;
        }
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
          title: const Text('Subject Registration Management'),
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
                    Tab(text: 'Subject Requirements'),
                    Tab(text: 'Student Submissions'),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _buildRegistrationSettingsTab(context),
                    _buildSubjectRequirementsTab(context),
                    _buildStudentSubmissionsTab(context),
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
                    'Enabled Years:', 
                    _settings!.enabledYears.isEmpty
                        ? 'None'
                        : _settings!.enabledYears.map((y) => 'Year $y').join(', ')),
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
    bool isEnabled = _settings?.isRegistrationEnabled ?? false;
    const List<String> allYears = ['1', '2', '3', '4'];
    bool allSelected = _selectedYears.length == 4;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          title: const Text('Enable Course Registration'),
          subtitle: const Text(
              'Toggle to enable/disable course registration'),
          value: isEnabled,
          onChanged: (value) async {
            try {
              await _courseService.toggleRegistration(
                value,
                _startDate,
                _endDate,
                enabledYears: _selectedYears,
              );
              await _loadRegistrationSettings();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Registration ${value ? 'enabled' : 'disabled'} successfully',
                    ),
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
        ),
        if (isEnabled) ...[
          const SizedBox(height: 16),
          // Year selection section
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Enable for Years:',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    // Select All / Deselect All button
                    TextButton.icon(
                      onPressed: () {
                        setState(() {
                          if (allSelected) {
                            _selectedYears.clear();
                          } else {
                            _selectedYears = List<String>.from(allYears);
                          }
                        });
                      },
                      icon: Icon(
                        allSelected ? Icons.deselect : Icons.select_all,
                        size: 18,
                      ),
                      label: Text(allSelected ? 'Deselect All' : 'Select All'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: allYears.map((year) {
                    final isYearEnabled = _selectedYears.contains(year);
                    return FilterChip(
                      label: Text('Year $year'),
                      selected: isYearEnabled,
                      selectedColor: Colors.green.shade100,
                      checkmarkColor: Colors.green.shade700,
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _selectedYears.add(year);
                          } else {
                            _selectedYears.remove(year);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                // Save years button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1e3a5f),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: _selectedYears.isEmpty
                        ? null
                        : () async {
                            try {
                              await _courseService.toggleRegistration(
                                isEnabled,
                                _startDate,
                                _endDate,
                                enabledYears: _selectedYears,
                              );
                              await _loadRegistrationSettings();
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Registration enabled for Year(s): ${_selectedYears.join(", ")}',
                                    ),
                                    backgroundColor: Colors.green,
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
                    icon: const Icon(Icons.save, color: Colors.white),
                    label: const Text(
                      'Save Year Settings',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildDatePickerField(
            'Registration Start Date',
            _startDate,
            (selectedDate) {
              setState(() {
                _startDate = selectedDate;
              });
            },
          ),
          const SizedBox(height: 12),
          _buildDatePickerField(
            'Registration End Date',
            _endDate,
            (selectedDate) {
              setState(() {
                _endDate = selectedDate;
              });
            },
          ),
        ],
      ],
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

  // ============ Subject Requirements Tab ============
  Widget _buildSubjectRequirementsTab(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    const years = ['1', '2', '3', '4'];
    const branches = ['CSE', 'ECE', 'EEE', 'ME', 'CE'];

    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Info card about Subject Management
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue.shade700),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Subjects (Core/OE/PE) are managed in Subject Management. Here you can set how many OE and PE subjects each student must select.',
                    style: TextStyle(color: Colors.blue.shade700),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildSectionCard(
            'Set Subject Selection Requirements',
            [
              _buildSubjectRequirementsForm(years, branches, context),
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
          const SizedBox(height: 16),
          _buildSectionCard(
            'Available Subjects Overview',
            [
              _buildAvailableSubjectsOverview(context),
            ],
            context,
          ),
        ],
      ),
    );
  }

  Widget _buildSubjectRequirementsForm(
      List<String> years, List<String> branches, BuildContext context) {
    String selectedYear = '1';
    String selectedBranch = 'CSE';
    int oeCount = 1;
    int peCount = 1;

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
              'Number of Subjects Student Must Select:',
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
              'Programme Electives (PE)',
              peCount,
              (value) {
                setState(() {
                  peCount = value;
                });
              },
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1e3a5f),
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
                    seCount: 0, // Not used anymore
                    createdAt: DateTime.now(),
                    updatedAt: DateTime.now(),
                  );

                  await _courseService.addCourseRequirement(requirement);
                  setState(() {});

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Requirements saved successfully'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error: $e'),
                        backgroundColor: Colors.red,
                      ),
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

  Widget _buildAvailableSubjectsOverview(BuildContext context) {
    return FutureBuilder<List<Subject>>(
      future: _subjectService.getAllSubjects(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final subjects = snapshot.data ?? [];
        
        // Group by year and type
        final Map<int, Map<SubjectType, int>> yearTypeCount = {};
        for (int year = 1; year <= 4; year++) {
          yearTypeCount[year] = {
            SubjectType.core: 0,
            SubjectType.oe: 0,
            SubjectType.pe: 0,
          };
        }

        for (final subject in subjects) {
          if (yearTypeCount.containsKey(subject.year)) {
            yearTypeCount[subject.year]![subject.subjectType] = 
                (yearTypeCount[subject.year]![subject.subjectType] ?? 0) + 1;
          }
        }

        return Column(
          children: [
            for (int year = 1; year <= 4; year++)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Text(
                      'Year $year',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    _buildSubjectCountChip('Core', yearTypeCount[year]![SubjectType.core]!, Colors.blue),
                    const SizedBox(width: 8),
                    _buildSubjectCountChip('OE', yearTypeCount[year]![SubjectType.oe]!, Colors.green),
                    const SizedBox(width: 8),
                    _buildSubjectCountChip('PE', yearTypeCount[year]![SubjectType.pe]!, Colors.orange),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildSubjectCountChip(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        '$label: $count',
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
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
              _buildRequirementBadge('OE', requirement.oeCount, Colors.green),
              _buildRequirementBadge('PE', requirement.peCount, Colors.orange),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRequirementBadge(String type, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            type,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            count.toString(),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // ============ Student Submissions Tab ============

  Widget _buildStudentSubmissionsTab(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    const years = ['1', '2', '3', '4'];
    const branches = ['CSE', 'ECE', 'EEE', 'ME', 'CE'];
    String selectedYear = '1';
    String selectedBranch = 'CSE';

    return StatefulBuilder(
      builder: (context, setState) {
        return SingleChildScrollView(
          padding: EdgeInsets.all(isMobile ? 12 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Filter section
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Filter by Year and Branch',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: selectedYear,
                            items: years
                                .map((year) => DropdownMenuItem(
                                      value: year,
                                      child: Text('Year $year'),
                                    ))
                                .toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setState(() => selectedYear = value);
                              }
                            },
                            decoration: InputDecoration(
                              labelText: 'Year',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: selectedBranch,
                            items: branches
                                .map((branch) => DropdownMenuItem(
                                      value: branch,
                                      child: Text(branch),
                                    ))
                                .toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setState(() => selectedBranch = value);
                              }
                            },
                            decoration: InputDecoration(
                              labelText: 'Branch',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Student submissions list from studentSubjectSelections
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('studentSubjectSelections')
                    .where('year', isEqualTo: int.tryParse(selectedYear) ?? 1)
                    .where('department', isEqualTo: selectedBranch)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Text('Error: ${snapshot.error}'),
                    );
                  }

                  final submissions = snapshot.data?.docs ?? [];
                  if (submissions.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            Icon(Icons.inbox, size: 64, color: Colors.grey[400]),
                            const SizedBox(height: 16),
                            const Text(
                              'No student submissions yet',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: submissions.length,
                    itemBuilder: (context, index) {
                      final data = submissions[index].data() as Map<String, dynamic>;
                      return _buildSubjectSubmissionCard(
                        context,
                        submissions[index].id,
                        data,
                      );
                    },
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSubjectSubmissionCard(
    BuildContext context,
    String docId,
    Map<String, dynamic> data,
  ) {
    final studentId = data['studentId'] ?? '';
    final studentName = data['studentName'] ?? studentId;
    final isSubmitted = data['isSubmitted'] == true;
    final coreCount = (data['coreSubjectIds'] as List?)?.length ?? 0;
    final oeCount = (data['selectedOEIds'] as List?)?.length ?? 0;
    final peCount = (data['selectedPEIds'] as List?)?.length ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(
          color: isSubmitted ? Colors.green.shade300 : Colors.orange.shade300,
        ),
        borderRadius: BorderRadius.circular(8),
        color: isSubmitted ? Colors.green.shade50 : Colors.orange.shade50,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: const Color(0xFF1e3a5f),
                radius: 20,
                child: Text(
                  studentName.isNotEmpty ? studentName[0].toUpperCase() : 'S',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      studentName,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      studentId,
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isSubmitted ? Colors.green : Colors.orange,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  isSubmitted ? 'Submitted' : 'Draft',
                  style: const TextStyle(color: Colors.white, fontSize: 11),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildSelectionChip('Core', coreCount, Colors.blue),
              const SizedBox(width: 8),
              _buildSelectionChip('OE', oeCount, Colors.green),
              const SizedBox(width: 8),
              _buildSelectionChip('PE', peCount, Colors.orange),
              const Spacer(),
              TextButton.icon(
                onPressed: () => _showSubjectDetailsDialog(context, data),
                icon: const Icon(Icons.visibility, size: 18),
                label: const Text('View'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSelectionChip(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        '$label: $count',
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }

  void _showSubjectDetailsDialog(BuildContext context, Map<String, dynamic> data) {
    final studentId = data['studentId'] ?? '';
    final studentName = data['studentName'] ?? studentId;
    final coreSubjectCodes = List<String>.from(data['coreSubjectCodes'] ?? []);
    final selectedOEIds = List<String>.from(data['selectedOEIds'] ?? []);
    final selectedPEIds = List<String>.from(data['selectedPEIds'] ?? []);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$studentName\'s Subjects'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Student ID: $studentId'),
              Text('Year: ${data['year']} | Semester: ${data['semester']}'),
              Text('Department: ${data['department']}'),
              const SizedBox(height: 16),
              const Text('Core Subjects:', style: TextStyle(fontWeight: FontWeight.bold)),
              if (coreSubjectCodes.isEmpty)
                const Text('No core subjects', style: TextStyle(color: Colors.grey))
              else
                ...coreSubjectCodes.map((code) => Padding(
                  padding: const EdgeInsets.only(left: 8, top: 4),
                  child: Text('• $code'),
                )),
              const SizedBox(height: 12),
              const Text('Selected OE Subjects:', style: TextStyle(fontWeight: FontWeight.bold)),
              if (selectedOEIds.isEmpty)
                const Text('No OE subjects selected', style: TextStyle(color: Colors.grey))
              else
                FutureBuilder<List<Subject>>(
                  future: _getSubjectsByIds(selectedOEIds),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const CircularProgressIndicator();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: snapshot.data!.map((s) => Padding(
                        padding: const EdgeInsets.only(left: 8, top: 4),
                        child: Text('• ${s.code} - ${s.name}'),
                      )).toList(),
                    );
                  },
                ),
              const SizedBox(height: 12),
              const Text('Selected PE Subjects:', style: TextStyle(fontWeight: FontWeight.bold)),
              if (selectedPEIds.isEmpty)
                const Text('No PE subjects selected', style: TextStyle(color: Colors.grey))
              else
                FutureBuilder<List<Subject>>(
                  future: _getSubjectsByIds(selectedPEIds),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const CircularProgressIndicator();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: snapshot.data!.map((s) => Padding(
                        padding: const EdgeInsets.only(left: 8, top: 4),
                        child: Text('• ${s.code} - ${s.name}'),
                      )).toList(),
                    );
                  },
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<List<Subject>> _getSubjectsByIds(List<String> ids) async {
    if (ids.isEmpty) return [];
    final subjects = <Subject>[];
    for (final id in ids) {
      try {
        final doc = await FirebaseFirestore.instance.collection('subjects').doc(id).get();
        if (doc.exists) {
          subjects.add(Subject.fromFirestore(doc));
        }
      } catch (_) {}
    }
    return subjects;
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
}

