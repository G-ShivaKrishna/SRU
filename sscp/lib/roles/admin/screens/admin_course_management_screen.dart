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

  static const List<String> _fallbackBranches = <String>[
    'CSE',
    'ECE',
    'EEE',
    'ME',
    'CE',
    'IT',
    'CSBS',
    'AIDS',
    'AIML',
    'CSD',
    'CSM',
  ];

  // Local state for year selection with safe defaults
  List<String> _selectedYears = <String>['1', '2', '3', '4'];
  List<String> _selectedSemesters = <String>['1', '2'];
  List<String>? _selectedBranches; // Empty means all branches
  List<String>? _availableBranches;
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 30));

  List<String> get _selectedBranchesSafe =>
      List<String>.from(_selectedBranches ?? const <String>[]);

  List<String> get _availableBranchesSafe {
    final list = _availableBranches;
    if (list == null || list.isEmpty) {
      return List<String>.from(_fallbackBranches);
    }
    return List<String>.from(list);
  }

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
      final results = await Future.wait<dynamic>([
        _courseService.getRegistrationSettings(),
        _subjectService.getDepartments(),
      ]);

      final settings = results[0] as CourseRegistrationSettings?;
      final fetchedBranches = (results[1] as List<String>)
          .where((b) => b.trim().isNotEmpty)
          .map((b) => b.trim().toUpperCase())
          .toSet();
      final availableBranches = <String>{
        ..._fallbackBranches,
        ...fetchedBranches,
      }.toList()
        ..sort();

      setState(() {
        _settings = settings;
        _availableBranches = availableBranches;
        if (settings != null) {
          _selectedYears = settings.enabledYears.isNotEmpty
              ? List<String>.from(settings.enabledYears)
              : ['1', '2', '3', '4'];
          _selectedSemesters = settings.enabledSemesters.isNotEmpty
              ? List<String>.from(settings.enabledSemesters)
              : ['1', '2'];
          _selectedBranches = List<String>.from(settings.enabledBranches)
              .map((b) => b.trim().toUpperCase())
              .where((b) => b.isNotEmpty)
              .toList();
          _startDate = settings.registrationStartDate;
          _endDate = settings.registrationEndDate;
        } else {
          _selectedBranches = <String>[];
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
            const AppHeader(showBack: false),
            if (_isLoading)
              const Expanded(
                child: Center(child: CircularProgressIndicator()),
              )
            else ...[
              Container(
                color: const Color(0xFF1e3a5f),
                child: const TabBar(
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white70,
                  indicatorColor: Colors.yellow,
                  tabs: [
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
                        : _settings!.enabledYears
                            .map((y) => 'Year $y')
                            .join(', ')),
                _buildInfoRow(
                    'Enabled Semesters:',
                    _settings!.enabledSemesters.isEmpty
                        ? 'None'
                        : _settings!.enabledSemesters
                            .map((s) => 'Sem $s')
                            .join(', ')),
                _buildInfoRow(
                  'Enabled Branches:',
                  _selectedBranchesSafe.isEmpty
                      ? 'All Branches'
                      : _selectedBranchesSafe.join(', '),
                ),
                _buildInfoRow('Start Date:',
                    _formatDate(_settings!.registrationStartDate)),
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
    final selectedBranches = _selectedBranchesSafe;
    final availableBranches = _availableBranchesSafe;
    final isAllBranchesMode = selectedBranches.isEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          title: const Text('Enable Course Registration'),
          subtitle: const Text('Toggle to enable/disable course registration'),
          value: isEnabled,
          onChanged: (value) async {
            try {
              await _courseService.toggleRegistration(
                value,
                _startDate,
                _endDate,
                enabledYears: _selectedYears,
                enabledSemesters: _selectedSemesters,
                enabledBranches: selectedBranches,
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
                const SizedBox(height: 16),
                // ── Semester selection ──────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Enable for Semesters:',
                      style:
                          TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    TextButton.icon(
                      onPressed: () {
                        setState(() {
                          if (_selectedSemesters.length == 2) {
                            _selectedSemesters.clear();
                          } else {
                            _selectedSemesters = ['1', '2'];
                          }
                        });
                      },
                      icon: Icon(
                        _selectedSemesters.length == 2
                            ? Icons.deselect
                            : Icons.select_all,
                        size: 18,
                      ),
                      label: Text(_selectedSemesters.length == 2
                          ? 'Deselect All'
                          : 'Select All'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: ['1', '2'].map((sem) {
                    final isSemEnabled = _selectedSemesters.contains(sem);
                    return FilterChip(
                      label: Text('Semester $sem'),
                      selected: isSemEnabled,
                      selectedColor: Colors.orange.shade100,
                      checkmarkColor: Colors.orange.shade700,
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _selectedSemesters.add(sem);
                          } else {
                            _selectedSemesters.remove(sem);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                // ── Branch selection ───────────────────────────────────
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Enable for All Branches',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  subtitle: Text(isAllBranchesMode
                      ? 'All branches can register'
                      : 'Only selected branches can register'),
                  value: isAllBranchesMode,
                  onChanged: (value) {
                    setState(() {
                      if (value) {
                        _selectedBranches = <String>[];
                      } else if (availableBranches.isNotEmpty) {
                        _selectedBranches = <String>[availableBranches.first];
                      }
                    });
                  },
                ),
                if (!isAllBranchesMode) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Select Branches:',
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                      TextButton.icon(
                        onPressed: () {
                          setState(() {
                            if (selectedBranches.length ==
                                availableBranches.length) {
                              _selectedBranches = <String>[];
                              if (availableBranches.isNotEmpty) {
                                _selectedBranches = <String>[
                                  availableBranches.first
                                ];
                              }
                            } else {
                              _selectedBranches =
                                  List<String>.from(availableBranches);
                            }
                          });
                        },
                        icon: Icon(
                          selectedBranches.length == availableBranches.length
                              ? Icons.deselect
                              : Icons.select_all,
                          size: 18,
                        ),
                        label: Text(
                          selectedBranches.length == availableBranches.length
                              ? 'Deselect All'
                              : 'Select All',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: availableBranches.map((branch) {
                      final isBranchEnabled = selectedBranches.contains(branch);
                      return FilterChip(
                        label: Text(branch),
                        selected: isBranchEnabled,
                        selectedColor: Colors.teal.shade100,
                        checkmarkColor: Colors.teal.shade700,
                        onSelected: (selected) {
                          setState(() {
                            _selectedBranches ??= <String>[];
                            if (selected) {
                              if (!_selectedBranches!.contains(branch)) {
                                _selectedBranches!.add(branch);
                              }
                            } else {
                              _selectedBranches!.remove(branch);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                ],
                const SizedBox(height: 12),
                // Save year, semester, and branch settings
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1e3a5f),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: (_selectedYears.isEmpty ||
                            _selectedSemesters.isEmpty ||
                            (!isAllBranchesMode && selectedBranches.isEmpty))
                        ? null
                        : () async {
                            try {
                              await _courseService.toggleRegistration(
                                isEnabled,
                                _startDate,
                                _endDate,
                                enabledYears: _selectedYears,
                                enabledSemesters: _selectedSemesters,
                                enabledBranches: selectedBranches,
                              );
                              await _loadRegistrationSettings();
                              if (mounted) {
                                final branchLabel = selectedBranches.isEmpty
                                    ? 'All Branches'
                                    : selectedBranches.join(', ');
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Enabled for Year(s): ${_selectedYears.join(", ")} | '
                                      'Semester(s): ${_selectedSemesters.map((s) => "Sem $s").join(", ")} | '
                                      'Branches: $branchLabel',
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
                      'Save Registration Scope',
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
    final branches = _availableBranchesSafe;

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
                    'Subjects (Core/OE/PE) are managed in Subject Management. Here you can set required Core, OE, and PE counts and apply them to one, many, or all branches.',
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
    String selectedSemester = '1';
    final normalizedBranches = branches
        .map((b) => b.trim().toUpperCase())
        .where((b) => b.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    String selectedBranch =
        normalizedBranches.isNotEmpty ? normalizedBranches.first : 'CSE';
    bool applyToAllBranches = false;
    List<String> selectedBranches = <String>[selectedBranch];
    bool useSameCountForAllTypes = false;
    int sameCount = 1;
    int coreCount = 1;
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
              'Semester',
              selectedSemester,
              ['1', '2'],
              (value) {
                setState(() {
                  selectedSemester = value ?? '1';
                });
              },
            ),
            const SizedBox(height: 12),
            _buildDropdownField(
              'Branch',
              selectedBranch,
              normalizedBranches,
              (value) {
                setState(() {
                  selectedBranch = value ?? selectedBranch;
                  if (!selectedBranches.contains(selectedBranch)) {
                    selectedBranches = <String>[selectedBranch];
                  }
                });
              },
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Apply to All Branches'),
              subtitle: Text(applyToAllBranches
                  ? 'Same requirement will be saved for all branches'
                  : 'Save for selected branch(es) only'),
              value: applyToAllBranches,
              onChanged: (value) {
                setState(() {
                  applyToAllBranches = value;
                  if (!applyToAllBranches && selectedBranches.isEmpty) {
                    selectedBranches = <String>[selectedBranch];
                  }
                });
              },
            ),
            if (!applyToAllBranches) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Select Branches:',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        if (selectedBranches.length ==
                            normalizedBranches.length) {
                          selectedBranches = <String>[selectedBranch];
                        } else {
                          selectedBranches =
                              List<String>.from(normalizedBranches);
                        }
                      });
                    },
                    icon: Icon(
                      selectedBranches.length == normalizedBranches.length
                          ? Icons.deselect
                          : Icons.select_all,
                      size: 18,
                    ),
                    label: Text(
                      selectedBranches.length == normalizedBranches.length
                          ? 'Deselect All'
                          : 'Select All',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: normalizedBranches.map((branch) {
                  final selected = selectedBranches.contains(branch);
                  return FilterChip(
                    label: Text(branch),
                    selected: selected,
                    selectedColor: Colors.teal.shade100,
                    checkmarkColor: Colors.teal.shade700,
                    onSelected: (value) {
                      setState(() {
                        if (value) {
                          if (!selectedBranches.contains(branch)) {
                            selectedBranches.add(branch);
                          }
                        } else {
                          selectedBranches.remove(branch);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
            ],
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Use Same Count For Core/OE/PE'),
              subtitle: Text(useSameCountForAllTypes
                  ? 'One value will be applied to all three'
                  : 'Set each count independently'),
              value: useSameCountForAllTypes,
              onChanged: (value) {
                setState(() {
                  useSameCountForAllTypes = value;
                  if (useSameCountForAllTypes) {
                    coreCount = sameCount;
                    oeCount = sameCount;
                    peCount = sameCount;
                  }
                });
              },
            ),
            Text(
              'Number of Subjects Student Must Select:',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 12),
            if (useSameCountForAllTypes)
              _buildCounterField(
                'Common Count (Core/OE/PE)',
                sameCount,
                (value) {
                  setState(() {
                    sameCount = value;
                    coreCount = value;
                    oeCount = value;
                    peCount = value;
                  });
                },
              )
            else ...[
              _buildCounterField(
                'Core Subjects',
                coreCount,
                (value) {
                  setState(() {
                    coreCount = value;
                  });
                },
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
            ],
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
                  final targetBranches = applyToAllBranches
                      ? normalizedBranches
                      : selectedBranches;

                  if (targetBranches.isEmpty) {
                    throw Exception('Please select at least one branch');
                  }

                  await Future.wait(targetBranches.map((branch) {
                    final requirement = CourseRequirement(
                      id: '',
                      year: selectedYear,
                      semester: selectedSemester,
                      branch: branch,
                      coreCount: coreCount,
                      oeCount: oeCount,
                      peCount: peCount,
                      seCount: 0, // Not used in subject registration flow
                      createdAt: DateTime.now(),
                      updatedAt: DateTime.now(),
                    );
                    return _courseService.addCourseRequirement(requirement);
                  }));
                  setState(() {});

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                            'Requirements saved for ${targetBranches.length} branch(es)'),
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
                'Save Requirements Scope',
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

        // Group by year, semester and type
        // Key format: "year_semester" e.g., "1_I", "1_II", "2_I", etc.
        final Map<String, Map<SubjectType, int>> yearSemTypeCount = {};
        final Map<String, List<Subject>> yearSemSubjects = {};

        // Initialize structure for all year+semester combinations
        for (int year = 1; year <= 4; year++) {
          for (String sem in ['I', 'II', '1', '2']) {
            final key = '${year}_$sem';
            yearSemTypeCount[key] = {
              SubjectType.core: 0,
              SubjectType.oe: 0,
              SubjectType.pe: 0,
            };
            yearSemSubjects[key] = [];
          }
        }

        for (final subject in subjects) {
          final key = '${subject.year}_${subject.semester}';
          if (yearSemTypeCount.containsKey(key)) {
            yearSemTypeCount[key]![subject.subjectType] =
                (yearSemTypeCount[key]![subject.subjectType] ?? 0) + 1;
            yearSemSubjects[key]!.add(subject);
          }
        }

        // Build display list: Year 1 Sem 1, Year 1 Sem 2, Year 2 Sem 1, etc.
        final displayList = <Widget>[];
        for (int year = 1; year <= 4; year++) {
          for (String sem in ['I', 'II']) {
            final key = '${year}_$sem';
            // Also check numeric semester format
            final altKey = '${year}_${sem == 'I' ? '1' : '2'}';
            final counts = yearSemTypeCount[key] ?? yearSemTypeCount[altKey];

            if (counts == null) continue;

            // Merge counts from both key formats
            final coreCount = (yearSemTypeCount[key]?[SubjectType.core] ?? 0) +
                (yearSemTypeCount[altKey]?[SubjectType.core] ?? 0);
            final oeCount = (yearSemTypeCount[key]?[SubjectType.oe] ?? 0) +
                (yearSemTypeCount[altKey]?[SubjectType.oe] ?? 0);
            final peCount = (yearSemTypeCount[key]?[SubjectType.pe] ?? 0) +
                (yearSemTypeCount[altKey]?[SubjectType.pe] ?? 0);

            // Merge subjects from both key formats
            final List<Subject> subjectsForYearSem = [
              ...(yearSemSubjects[key] ?? <Subject>[]),
              ...(yearSemSubjects[altKey] ?? <Subject>[]),
            ];

            // Only show if there are subjects
            if (coreCount == 0 && oeCount == 0 && peCount == 0) continue;

            displayList.add(
              _buildExpandableSubjectRow(
                context: context,
                year: year,
                semester: sem,
                coreCount: coreCount,
                oeCount: oeCount,
                peCount: peCount,
                subjects: subjectsForYearSem,
              ),
            );
          }
        }

        if (displayList.isEmpty) {
          return const Center(child: Text('No subjects available'));
        }

        return Column(children: displayList);
      },
    );
  }

  Widget _buildExpandableSubjectRow({
    required BuildContext context,
    required int year,
    required String semester,
    required int coreCount,
    required int oeCount,
    required int peCount,
    required List<Subject> subjects,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        childrenPadding: const EdgeInsets.all(12),
        title: Text(
          'Year $year, Sem $semester',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildSubjectCountChip('Core', coreCount, Colors.blue),
            const SizedBox(width: 8),
            _buildSubjectCountChip('OE', oeCount, Colors.green),
            const SizedBox(width: 8),
            _buildSubjectCountChip('PE', peCount, Colors.orange),
            const SizedBox(width: 8),
            const Icon(Icons.expand_more),
          ],
        ),
        children: [
          if (subjects.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('No subjects in this semester'),
            )
          else
            ...subjects
                .map((subject) => _buildSubjectListItem(context, subject)),
        ],
      ),
    );
  }

  Widget _buildSubjectListItem(BuildContext context, Subject subject) {
    Color typeColor;
    switch (subject.subjectType) {
      case SubjectType.core:
        typeColor = Colors.blue;
        break;
      case SubjectType.oe:
        typeColor = Colors.green;
        break;
      case SubjectType.pe:
        typeColor = Colors.orange;
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: typeColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: typeColor.withOpacity(0.3)),
            ),
            child: Text(
              subject.subjectType.displayName,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: typeColor,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  subject.name,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  '${subject.code} • ${subject.department} • ${subject.credits} Credits',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit, size: 20),
            color: const Color(0xFF1e3a5f),
            tooltip: 'Edit Subject',
            onPressed: () => _showEditSubjectDialog(context, subject),
          ),
          IconButton(
            icon: const Icon(Icons.delete, size: 20),
            color: Colors.red,
            tooltip: 'Delete Subject',
            onPressed: () => _confirmDeleteSubject(context, subject),
          ),
        ],
      ),
    );
  }

  void _showEditSubjectDialog(BuildContext context, Subject subject) {
    final codeController = TextEditingController(text: subject.code);
    final nameController = TextEditingController(text: subject.name);
    final creditsController =
        TextEditingController(text: subject.credits.toString());
    String selectedDepartment = subject.department;
    int selectedYear = subject.year;
    String selectedSemester = subject.semester;
    SubjectType selectedSubjectType = subject.subjectType;

    final departments = [
      'CSE',
      'ECE',
      'EEE',
      'MECH',
      'CIVIL',
      'IT',
      'AIDS',
      'AIML',
      'CSM',
      'CSD'
    ];

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.edit, color: Color(0xFF1e3a5f)),
                  SizedBox(width: 8),
                  Text('Edit Subject'),
                ],
              ),
              content: SizedBox(
                width: MediaQuery.of(context).size.width * 0.8,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: codeController,
                        decoration: const InputDecoration(
                          labelText: 'Subject Code *',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.code),
                        ),
                        textCapitalization: TextCapitalization.characters,
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'Subject Name *',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.text_fields),
                        ),
                        textCapitalization: TextCapitalization.words,
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        decoration: const InputDecoration(
                          labelText: 'Department *',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.business),
                        ),
                        initialValue: departments.contains(selectedDepartment)
                            ? selectedDepartment
                            : departments.first,
                        items: departments.map((dept) {
                          return DropdownMenuItem(
                              value: dept, child: Text(dept));
                        }).toList(),
                        onChanged: (value) {
                          setDialogState(() {
                            selectedDepartment = value ?? selectedDepartment;
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<SubjectType>(
                        decoration: const InputDecoration(
                          labelText: 'Subject Type *',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.category),
                        ),
                        initialValue: selectedSubjectType,
                        items: SubjectType.values.map((type) {
                          return DropdownMenuItem(
                            value: type,
                            child: Text(type.displayName),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setDialogState(() {
                            selectedSubjectType = value ?? selectedSubjectType;
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              decoration: const InputDecoration(
                                labelText: 'Year *',
                                border: OutlineInputBorder(),
                              ),
                              initialValue: selectedYear,
                              items: [1, 2, 3, 4].map((year) {
                                return DropdownMenuItem(
                                  value: year,
                                  child: Text('Year $year'),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setDialogState(() {
                                  selectedYear = value ?? selectedYear;
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              decoration: const InputDecoration(
                                labelText: 'Semester *',
                                border: OutlineInputBorder(),
                              ),
                              initialValue:
                                  ['I', 'II'].contains(selectedSemester)
                                      ? selectedSemester
                                      : 'I',
                              items: ['I', 'II'].map((sem) {
                                return DropdownMenuItem(
                                  value: sem,
                                  child: Text('Semester $sem'),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setDialogState(() {
                                  selectedSemester = value ?? selectedSemester;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: creditsController,
                        decoration: const InputDecoration(
                          labelText: 'Credits',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.star),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton.icon(
                  onPressed: () async {
                    if (codeController.text.trim().isEmpty ||
                        nameController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please fill all required fields'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }

                    try {
                      await _subjectService.updateSubject(
                        subject.id,
                        Subject(
                          id: subject.id,
                          code: codeController.text.trim().toUpperCase(),
                          name: nameController.text.trim(),
                          department: selectedDepartment,
                          credits: int.tryParse(creditsController.text) ?? 3,
                          year: selectedYear,
                          semester: selectedSemester,
                          subjectType: selectedSubjectType,
                        ),
                      );
                      Navigator.pop(context);
                      setState(() {}); // Refresh the list

                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Subject updated successfully'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.save),
                  label: const Text('Save'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1e3a5f),
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _confirmDeleteSubject(BuildContext context, Subject subject) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Subject?'),
        content: Text(
            'Are you sure you want to delete "${subject.name}" (${subject.code})?\n\nThis action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await _subjectService.deleteSubject(subject.id);
                Navigator.pop(context);
                setState(() {}); // Refresh the list

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Subject deleted successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error deleting subject: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
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

  Widget _buildRequirementCard(
      CourseRequirement requirement, BuildContext context) {
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
                'Year ${requirement.year}${requirement.semester.isNotEmpty ? ", Sem ${requirement.semester}" : ""} - ${requirement.branch}',
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
                                content:
                                    Text('Requirement deleted successfully'),
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
              _buildRequirementBadge(
                  'Core', requirement.coreCount, Colors.blue),
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
    String selectedSemester = '1';
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
                      'Filter by Year, Semester and Branch',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (isMobile) ...[
                      DropdownButtonFormField<String>(
                        initialValue: selectedYear,
                        items: years
                            .map((y) => DropdownMenuItem(
                                  value: y,
                                  child: Text('Year $y'),
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
                              borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        initialValue: selectedSemester,
                        items: ['1', '2']
                            .map((s) => DropdownMenuItem(
                                  value: s,
                                  child: Text('Semester $s'),
                                ))
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => selectedSemester = value);
                          }
                        },
                        decoration: InputDecoration(
                          labelText: 'Semester',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        initialValue: selectedBranch,
                        items: branches
                            .map((b) =>
                                DropdownMenuItem(value: b, child: Text(b)))
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => selectedBranch = value);
                          }
                        },
                        decoration: InputDecoration(
                          labelText: 'Branch',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ] else
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: selectedYear,
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
                              initialValue: selectedSemester,
                              items: ['1', '2']
                                  .map((s) => DropdownMenuItem(
                                        value: s,
                                        child: Text('Semester $s'),
                                      ))
                                  .toList(),
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() => selectedSemester = value);
                                }
                              },
                              decoration: InputDecoration(
                                labelText: 'Semester',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: selectedBranch,
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

                  // Filter by semester in Dart to avoid composite index
                  final allDocs = snapshot.data?.docs ?? [];
                  final submissions = allDocs.where((doc) {
                    final d = doc.data() as Map<String, dynamic>;
                    final docSem = (d['semester'] ?? '').toString().trim();
                    final normalizedDocSem = docSem.toUpperCase();
                    final acceptedSemesters =
                        selectedSemester == '1' ? {'1', 'I'} : {'2', 'II'};
                    return acceptedSemesters.contains(normalizedDocSem);
                  }).toList();

                  if (submissions.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            Icon(Icons.inbox,
                                size: 64, color: Colors.grey[400]),
                            const SizedBox(height: 16),
                            Text(
                              'No submissions for Year $selectedYear Sem $selectedSemester – $selectedBranch',
                              style: const TextStyle(
                                fontSize: 16,
                                color: Colors.grey,
                              ),
                              textAlign: TextAlign.center,
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
                      final data =
                          submissions[index].data() as Map<String, dynamic>;
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
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold),
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
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey.shade600),
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

  void _showSubjectDetailsDialog(
      BuildContext context, Map<String, dynamic> data) {
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
              const Text('Core Subjects:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              if (coreSubjectCodes.isEmpty)
                const Text('No core subjects',
                    style: TextStyle(color: Colors.grey))
              else
                ...coreSubjectCodes.map((code) => Padding(
                      padding: const EdgeInsets.only(left: 8, top: 4),
                      child: Text('• $code'),
                    )),
              const SizedBox(height: 12),
              const Text('Selected OE Subjects:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              if (selectedOEIds.isEmpty)
                const Text('No OE subjects selected',
                    style: TextStyle(color: Colors.grey))
              else
                FutureBuilder<List<Subject>>(
                  future: _getSubjectsByIds(selectedOEIds),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const CircularProgressIndicator();
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: snapshot.data!
                          .map((s) => Padding(
                                padding: const EdgeInsets.only(left: 8, top: 4),
                                child: Text('• ${s.code} - ${s.name}'),
                              ))
                          .toList(),
                    );
                  },
                ),
              const SizedBox(height: 12),
              const Text('Selected PE Subjects:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              if (selectedPEIds.isEmpty)
                const Text('No PE subjects selected',
                    style: TextStyle(color: Colors.grey))
              else
                FutureBuilder<List<Subject>>(
                  future: _getSubjectsByIds(selectedPEIds),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const CircularProgressIndicator();
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: snapshot.data!
                          .map((s) => Padding(
                                padding: const EdgeInsets.only(left: 8, top: 4),
                                child: Text('• ${s.code} - ${s.name}'),
                              ))
                          .toList(),
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
        final doc = await FirebaseFirestore.instance
            .collection('subjects')
            .doc(id)
            .get();
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
            decoration: const BoxDecoration(
              color: Color(0xFF1e3a5f),
              borderRadius: BorderRadius.only(
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
          initialValue: value,
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
