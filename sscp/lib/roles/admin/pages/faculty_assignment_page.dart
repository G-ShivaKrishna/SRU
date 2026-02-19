import 'package:flutter/material.dart';
import '../../../models/faculty_assignment_model.dart';
import '../../../services/faculty_assignment_service.dart';

class FacultyAssignmentPage extends StatefulWidget {
  const FacultyAssignmentPage({super.key});

  @override
  State<FacultyAssignmentPage> createState() => _FacultyAssignmentPageState();
}

class _FacultyAssignmentPageState extends State<FacultyAssignmentPage>
    with SingleTickerProviderStateMixin {
  final FacultyAssignmentService _service = FacultyAssignmentService();
  late TabController _tabController;

  List<FacultyAssignment> _assignments = [];
  List<Map<String, dynamic>> _faculty = [];
  List<Subject> _subjects = [];
  List<StudentBatch> _batches = [];
  List<String> _departments = [];

  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final results = await Future.wait([
        _service.getAllAssignments(),
        _service.getAllFaculty(),
        _service.getAllSubjects(),
        _service.getAllBatches(),
        _service.getDepartments(),
      ]);

      setState(() {
        _assignments = results[0] as List<FacultyAssignment>;
        _faculty = results[1] as List<Map<String, dynamic>>;
        _subjects = results[2] as List<Subject>;
        _batches = results[3] as List<StudentBatch>;
        _departments = results[4] as List<String>;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading data: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Faculty-Batch Assignment'),
        backgroundColor: const Color(0xFF1e3a5f),
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.yellow,
          tabs: const [
            Tab(text: 'Assignments'),
            Tab(text: 'Batches Overview'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? _buildErrorView()
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildAssignmentsTab(isMobile),
                    _buildQuickAssignTab(isMobile),
                  ],
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateAssignmentDialog(context),
        backgroundColor: const Color(0xFF1e3a5f),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('New Assignment',
            style: TextStyle(color: Colors.white)),
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text(_errorMessage ?? 'An error occurred'),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  // ============ ASSIGNMENTS TAB ============
  Widget _buildAssignmentsTab(bool isMobile) {
    if (_assignments.isEmpty) {
      return _buildEmptyState(
        icon: Icons.assignment_outlined,
        title: 'No Assignments Yet',
        subtitle:
            'Create your first faculty-batch assignment by clicking the button below',
      );
    }

    // Group assignments by faculty
    final groupedByFaculty = <String, List<FacultyAssignment>>{};
    for (var assignment in _assignments) {
      groupedByFaculty
          .putIfAbsent(assignment.facultyId, () => [])
          .add(assignment);
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: EdgeInsets.all(isMobile ? 12 : 16),
        itemCount: groupedByFaculty.keys.length,
        itemBuilder: (context, index) {
          final facultyId = groupedByFaculty.keys.elementAt(index);
          final facultyAssignments = groupedByFaculty[facultyId]!;
          final faculty = facultyAssignments.first;

          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            elevation: 2,
            child: ExpansionTile(
              leading: CircleAvatar(
                backgroundColor: const Color(0xFF1e3a5f),
                child: Text(
                  faculty.facultyName.isNotEmpty
                      ? faculty.facultyName[0].toUpperCase()
                      : 'F',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              title: Text(
                faculty.facultyName,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                '${faculty.department} • ${facultyAssignments.length} subject(s)',
              ),
              children: facultyAssignments.map((assignment) {
                return _buildAssignmentTile(assignment, isMobile);
              }).toList(),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAssignmentTile(FacultyAssignment assignment, bool isMobile) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(
          horizontal: isMobile ? 16 : 24,
          vertical: 8,
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF1e3a5f).withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                assignment.subjectCode,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1e3a5f),
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                assignment.subjectName,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: assignment.assignedBatches.map((batch) {
                  return Chip(
                    label: Text(batch, style: const TextStyle(fontSize: 11)),
                    backgroundColor: Colors.blue.shade50,
                    padding: EdgeInsets.zero,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    deleteIcon: const Icon(Icons.close, size: 14),
                    onDeleted: () =>
                        _removeBatchFromAssignment(assignment, batch),
                  );
                }).toList(),
              ),
              const SizedBox(height: 4),
              Text(
                'Year ${assignment.year} • ${assignment.semester} Sem • ${assignment.academicYear}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'edit') {
              _showEditAssignmentDialog(context, assignment);
            } else if (value == 'delete') {
              _confirmDeleteAssignment(assignment);
            } else if (value == 'add_batch') {
              _showAddBatchDialog(context, assignment);
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'add_batch',
              child: Row(
                children: [
                  Icon(Icons.add, size: 20),
                  SizedBox(width: 8),
                  Text('Add Batch'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'edit',
              child: Row(
                children: [
                  Icon(Icons.edit, size: 20),
                  SizedBox(width: 8),
                  Text('Edit'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete, size: 20, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Delete', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============ BATCHES OVERVIEW TAB ============
  Widget _buildQuickAssignTab(bool isMobile) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildQuickAssignCard(context, isMobile),
          const SizedBox(height: 24),
          _buildBatchOverviewCard(context, isMobile),
        ],
      ),
    );
  }

  Widget _buildQuickAssignCard(BuildContext context, bool isMobile) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 12 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.flash_on, color: Colors.amber.shade700),
                const SizedBox(width: 8),
                const Text(
                  'Quick Assignment',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Quickly assign a faculty member to teach a subject to one or more batches',
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _showCreateAssignmentDialog(context),
                icon: const Icon(Icons.add),
                label: const Text('Create New Assignment'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1e3a5f),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.all(16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBatchOverviewCard(BuildContext context, bool isMobile) {
    // Group batches by department
    final batchesByDept = <String, List<StudentBatch>>{};
    for (var batch in _batches) {
      batchesByDept.putIfAbsent(batch.department, () => []).add(batch);
    }

    return Card(
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 12 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.groups, color: Color(0xFF1e3a5f)),
                SizedBox(width: 8),
                Text(
                  'Available Batches',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_batches.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('No batches found. Add students first.'),
                ),
              )
            else
              ...batchesByDept.entries.map((entry) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        entry.key,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1e3a5f),
                        ),
                      ),
                    ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: entry.value.map((batch) {
                        return Chip(
                          avatar: CircleAvatar(
                            backgroundColor: const Color(0xFF1e3a5f),
                            child: Text(
                              '${batch.studentCount}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                              ),
                            ),
                          ),
                          label: Text('${batch.batchName} (Y${batch.year})'),
                        );
                      }).toList(),
                    ),
                    const Divider(),
                  ],
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ),
        ],
      ),
    );
  }

  // ============ DIALOGS ============
  void _showCreateAssignmentDialog(BuildContext context) {
    String? selectedFacultyId;
    String? selectedFacultyName;
    String? selectedDepartment;
    String? selectedSubjectCode;
    String? selectedSubjectName;
    List<String> selectedBatches = [];
    int selectedYear = 1;
    String selectedSemester = 'I';
    String academicYear = _getCurrentAcademicYear();
    Map<int, String> facultyYearSubjectMap = {}; // Track which years faculty is already assigned
    Map<String, String> subjectFacultyMap = {}; // Track which subjects are assigned to which faculty

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            // Filter faculty by department if selected
            final filteredFaculty = selectedDepartment != null
                ? _faculty
                    .where((f) => f['department'] == selectedDepartment)
                    .toList()
                : _faculty;

            // Filter subjects by department, year, and semester
            final filteredSubjects = _subjects.where((s) {
              bool matchesDept = selectedDepartment == null || s.department == selectedDepartment;
              bool matchesYear = s.year == selectedYear;
              bool matchesSem = s.semester == selectedSemester;
              return matchesDept && matchesYear && matchesSem;
            }).toList();

            // Filter batches by department and year
            final filteredBatches = _batches.where((b) {
              bool matchesDept =
                  selectedDepartment == null || b.department == selectedDepartment;
              bool matchesYear = b.year == selectedYear;
              return matchesDept && matchesYear;
            }).toList();

            // Check if selected year is already assigned
            final yearAlreadyAssigned = facultyYearSubjectMap.containsKey(selectedYear);
            final assignedSubjectForYear = facultyYearSubjectMap[selectedYear];
            
            // Check if selected subject is already assigned to another faculty
            final selectedSubjectAssignedTo = selectedSubjectCode != null 
                ? subjectFacultyMap[selectedSubjectCode] 
                : null;
            final subjectAlreadyAssigned = selectedSubjectAssignedTo != null && 
                selectedSubjectAssignedTo != selectedFacultyName;

            return AlertDialog(
              title: const Text('Create Faculty Assignment'),
              content: SizedBox(
                width: MediaQuery.of(context).size.width * 0.8,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Department Selection
                      DropdownButtonFormField<String>(
                        decoration: const InputDecoration(
                          labelText: 'Department *',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.business),
                        ),
                        value: selectedDepartment,
                        items: _departments.map((dept) {
                          return DropdownMenuItem(
                              value: dept, child: Text(dept));
                        }).toList(),
                        onChanged: (value) async {
                          setDialogState(() {
                            selectedDepartment = value;
                            selectedFacultyId = null;
                            selectedFacultyName = null;
                            selectedSubjectCode = null;
                            selectedSubjectName = null;
                            selectedBatches.clear();
                            facultyYearSubjectMap.clear();
                            subjectFacultyMap.clear();
                          });
                          // Load subject-faculty map for this dept/year/semester
                          if (value != null) {
                            final sfMap = await _service.getSubjectFacultyMap(
                              academicYear: academicYear,
                              semester: selectedSemester,
                              year: selectedYear,
                              department: value,
                            );
                            setDialogState(() {
                              subjectFacultyMap = sfMap;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 16),

                      // Faculty Selection
                      DropdownButtonFormField<String>(
                        decoration: const InputDecoration(
                          labelText: 'Faculty *',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.person),
                        ),
                        value: selectedFacultyId,
                        items: filteredFaculty.map((faculty) {
                          return DropdownMenuItem(
                            value: faculty['facultyId'] as String,
                            child: Text(
                                '${faculty['name']} (${faculty['facultyId']})'),
                          );
                        }).toList(),
                        onChanged: selectedDepartment == null
                            ? null
                            : (value) async {
                                setDialogState(() {
                                  selectedFacultyId = value;
                                  final faculty = filteredFaculty.firstWhere(
                                    (f) => f['facultyId'] == value,
                                  );
                                  selectedFacultyName =
                                      faculty['name'] as String;
                                });
                                // Load faculty's existing year assignments
                                if (value != null) {
                                  final yearMap = await _service.getFacultyYearSubjectMap(
                                    facultyId: value,
                                    academicYear: academicYear,
                                    semester: selectedSemester,
                                  );
                                  setDialogState(() {
                                    facultyYearSubjectMap = yearMap;
                                  });
                                }
                              },
                      ),
                      
                      // Show faculty's existing assignments
                      if (selectedFacultyId != null && facultyYearSubjectMap.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.blue.shade200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'ℹ️ Already teaching:',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue.shade700,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 4),
                              ...facultyYearSubjectMap.entries.map((entry) => Text(
                                '• Year ${entry.key}: ${entry.value}',
                                style: TextStyle(fontSize: 12, color: Colors.blue.shade700),
                              )),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),

                      // Year and Semester Row
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              decoration: InputDecoration(
                                labelText: 'Year *',
                                border: const OutlineInputBorder(),
                                // Show warning if year is already assigned
                                errorText: yearAlreadyAssigned 
                                    ? 'Already teaching "$assignedSubjectForYear"' 
                                    : null,
                                errorStyle: const TextStyle(fontSize: 10),
                              ),
                              value: selectedYear,
                              items: [1, 2, 3, 4].map((year) {
                                final isAssigned = facultyYearSubjectMap.containsKey(year);
                                return DropdownMenuItem(
                                  value: year,
                                  child: Text(
                                    isAssigned ? 'Year $year ⚠️' : 'Year $year',
                                  ),
                                );
                              }).toList(),
                              onChanged: (value) async {
                                setDialogState(() {
                                  selectedYear = value ?? 1;
                                  selectedBatches.clear();
                                  selectedSubjectCode = null;
                                  selectedSubjectName = null;
                                });
                                // Reload subject-faculty map for new year
                                if (selectedDepartment != null) {
                                  final sfMap = await _service.getSubjectFacultyMap(
                                    academicYear: academicYear,
                                    semester: selectedSemester,
                                    year: selectedYear,
                                    department: selectedDepartment,
                                  );
                                  setDialogState(() {
                                    subjectFacultyMap = sfMap;
                                  });
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              decoration: const InputDecoration(
                                labelText: 'Semester *',
                                border: OutlineInputBorder(),
                              ),
                              value: selectedSemester,
                              items: ['I', 'II'].map((sem) {
                                return DropdownMenuItem(
                                  value: sem,
                                  child: Text('Semester $sem'),
                                );
                              }).toList(),
                              onChanged: (value) async {
                                setDialogState(() {
                                  selectedSemester = value ?? 'I';
                                  selectedSubjectCode = null;
                                  selectedSubjectName = null;
                                });
                                // Reload faculty year map for new semester
                                if (selectedFacultyId != null) {
                                  final yearMap = await _service.getFacultyYearSubjectMap(
                                    facultyId: selectedFacultyId!,
                                    academicYear: academicYear,
                                    semester: selectedSemester,
                                  );
                                  setDialogState(() {
                                    facultyYearSubjectMap = yearMap;
                                  });
                                }
                                // Reload subject-faculty map for new semester
                                if (selectedDepartment != null) {
                                  final sfMap = await _service.getSubjectFacultyMap(
                                    academicYear: academicYear,
                                    semester: selectedSemester,
                                    year: selectedYear,
                                    department: selectedDepartment,
                                  );
                                  setDialogState(() {
                                    subjectFacultyMap = sfMap;
                                  });
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Subject Selection (from predefined subjects)
                      DropdownButtonFormField<String>(
                        decoration: InputDecoration(
                          labelText: 'Subject *',
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.book),
                          helperText: filteredSubjects.isEmpty
                              ? 'No subjects found. Add subjects in Subject Management.'
                              : null,
                          // Show error if subject is assigned to different faculty
                          errorText: subjectAlreadyAssigned
                              ? 'Already assigned to $selectedSubjectAssignedTo'
                              : null,
                          errorStyle: const TextStyle(fontSize: 10),
                        ),
                        value: selectedSubjectCode,
                        items: filteredSubjects.map((subject) {
                          final assignedTo = subjectFacultyMap[subject.code];
                          final isAssignedToOther = assignedTo != null && assignedTo != selectedFacultyName;
                          return DropdownMenuItem(
                            value: subject.code,
                            child: Text(
                              isAssignedToOther
                                  ? '${subject.code} - ${subject.name} ⚠️'
                                  : '${subject.code} - ${subject.name}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: filteredSubjects.isEmpty
                            ? null
                            : (value) {
                                setDialogState(() {
                                  selectedSubjectCode = value;
                                  final subject = filteredSubjects.firstWhere(
                                    (s) => s.code == value,
                                  );
                                  selectedSubjectName = subject.name;
                                });
                              },
                      ),
                      
                      // Show assigned subjects info
                      if (subjectFacultyMap.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.orange.shade200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '⚠️ Already assigned subjects:',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange.shade700,
                                  fontSize: 11,
                                ),
                              ),
                              const SizedBox(height: 4),
                              ...subjectFacultyMap.entries.take(5).map((entry) => Text(
                                '• ${entry.key}: ${entry.value}',
                                style: TextStyle(fontSize: 11, color: Colors.orange.shade700),
                              )),
                              if (subjectFacultyMap.length > 5)
                                Text(
                                  '... and ${subjectFacultyMap.length - 5} more',
                                  style: TextStyle(fontSize: 11, color: Colors.orange.shade700, fontStyle: FontStyle.italic),
                                ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),

                      // Batch Selection
                      const Text(
                        'Select Batches *',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 8),
                      if (filteredBatches.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            selectedDepartment == null
                                ? 'Select a department first'
                                : 'No batches found for Year $selectedYear',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: filteredBatches.map((batch) {
                              final isSelected =
                                  selectedBatches.contains(batch.batchName);
                              return FilterChip(
                                label: Text(
                                    '${batch.batchName} (${batch.studentCount})'),
                                selected: isSelected,
                                onSelected: (selected) {
                                  setDialogState(() {
                                    if (selected) {
                                      selectedBatches.add(batch.batchName);
                                    } else {
                                      selectedBatches.remove(batch.batchName);
                                    }
                                  });
                                },
                                selectedColor: const Color(0xFF1e3a5f)
                                    .withOpacity(0.2),
                                checkmarkColor: const Color(0xFF1e3a5f),
                              );
                            }).toList(),
                          ),
                        ),
                      const SizedBox(height: 16),

                      // Academic Year
                      TextField(
                        decoration: const InputDecoration(
                          labelText: 'Academic Year',
                          border: OutlineInputBorder(),
                          hintText: 'e.g., 2024-25',
                        ),
                        controller: TextEditingController(text: academicYear),
                        onChanged: (value) {
                          academicYear = value;
                        },
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
                ElevatedButton(
                  onPressed: () async {
                    // Validate
                    if (selectedFacultyId == null ||
                        selectedDepartment == null ||
                        selectedBatches.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content:
                              Text('Please fill all required fields'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }

                    if (selectedSubjectCode == null ||
                        selectedSubjectCode!.isEmpty ||
                        selectedSubjectName == null ||
                        selectedSubjectName!.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please select a subject'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }

                    try {
                      final assignment = FacultyAssignment(
                        id: '',
                        facultyId: selectedFacultyId!,
                        facultyName: selectedFacultyName ?? '',
                        department: selectedDepartment!,
                        subjectCode: selectedSubjectCode!,
                        subjectName: selectedSubjectName!,
                        assignedBatches: selectedBatches,
                        academicYear: academicYear,
                        semester: selectedSemester,
                        year: selectedYear,
                        createdAt: DateTime.now(),
                        updatedAt: DateTime.now(),
                        createdBy: 'admin',
                      );

                      await _service.createAssignment(assignment);
                      Navigator.pop(context);
                      _loadData();

                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Assignment created successfully'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1e3a5f),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Create'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showEditAssignmentDialog(
      BuildContext context, FacultyAssignment assignment) {
    List<String> selectedBatches = List.from(assignment.assignedBatches);
    String selectedSemester = assignment.semester;
    String academicYear = assignment.academicYear;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final availableBatches = _batches
                .where((b) =>
                    b.department == assignment.department &&
                    b.year == assignment.year)
                .toList();

            return AlertDialog(
              title: Text('Edit Assignment: ${assignment.subjectName}'),
              content: SizedBox(
                width: MediaQuery.of(context).size.width * 0.8,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Faculty info (read-only)
                      ListTile(
                        leading: const Icon(Icons.person),
                        title: Text(assignment.facultyName),
                        subtitle: Text(assignment.department),
                      ),
                      const Divider(),

                      // Semester
                      DropdownButtonFormField<String>(
                        decoration: const InputDecoration(
                          labelText: 'Semester',
                          border: OutlineInputBorder(),
                        ),
                        value: selectedSemester,
                        items: ['I', 'II'].map((sem) {
                          return DropdownMenuItem(
                            value: sem,
                            child: Text('Semester $sem'),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setDialogState(() {
                            selectedSemester = value ?? 'I';
                          });
                        },
                      ),
                      const SizedBox(height: 16),

                      // Batch Selection
                      const Text(
                        'Assigned Batches',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: availableBatches.map((batch) {
                            final isSelected =
                                selectedBatches.contains(batch.batchName);
                            return FilterChip(
                              label: Text(batch.batchName),
                              selected: isSelected,
                              onSelected: (selected) {
                                setDialogState(() {
                                  if (selected) {
                                    selectedBatches.add(batch.batchName);
                                  } else {
                                    selectedBatches.remove(batch.batchName);
                                  }
                                });
                              },
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Academic Year
                      TextField(
                        decoration: const InputDecoration(
                          labelText: 'Academic Year',
                          border: OutlineInputBorder(),
                        ),
                        controller: TextEditingController(text: academicYear),
                        onChanged: (value) {
                          academicYear = value;
                        },
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
                ElevatedButton(
                  onPressed: () async {
                    if (selectedBatches.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content:
                              Text('Please select at least one batch'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }

                    try {
                      final updated = assignment.copyWith(
                        assignedBatches: selectedBatches,
                        semester: selectedSemester,
                        academicYear: academicYear,
                        updatedAt: DateTime.now(),
                      );
                      await _service.updateAssignment(assignment.id, updated);
                      Navigator.pop(context);
                      _loadData();

                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Assignment updated'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1e3a5f),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showAddBatchDialog(
      BuildContext context, FacultyAssignment assignment) {
    List<String> selectedBatches = [];

    // Get batches not already assigned
    final availableBatches = _batches.where((b) {
      return b.department == assignment.department &&
          b.year == assignment.year &&
          !assignment.assignedBatches.contains(b.batchName);
    }).toList();

    if (availableBatches.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No more batches available to add'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Add Batches'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Adding to: ${assignment.subjectName}'),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: availableBatches.map((batch) {
                      final isSelected =
                          selectedBatches.contains(batch.batchName);
                      return FilterChip(
                        label: Text(batch.batchName),
                        selected: isSelected,
                        onSelected: (selected) {
                          setDialogState(() {
                            if (selected) {
                              selectedBatches.add(batch.batchName);
                            } else {
                              selectedBatches.remove(batch.batchName);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: selectedBatches.isEmpty
                      ? null
                      : () async {
                          try {
                            for (var batch in selectedBatches) {
                              await _service.addBatchToAssignment(
                                  assignment.id, batch);
                            }
                            Navigator.pop(context);
                            _loadData();

                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                    'Added ${selectedBatches.length} batch(es)'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                  child: const Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ============ ACTION METHODS ============
  Future<void> _removeBatchFromAssignment(
      FacultyAssignment assignment, String batchName) async {
    if (assignment.assignedBatches.length == 1) {
      // Show warning if removing last batch
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Remove Last Batch?'),
          content: const Text(
              'This is the only batch assigned. Removing it will delete the entire assignment.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child:
                  const Text('Delete', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );

      if (confirm == true) {
        await _service.deleteAssignment(assignment.id);
        _loadData();
      }
    } else {
      await _service.removeBatchFromAssignment(assignment.id, batchName);
      _loadData();
    }
  }

  void _confirmDeleteAssignment(FacultyAssignment assignment) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Assignment?'),
        content: Text(
            'Are you sure you want to delete the assignment of ${assignment.subjectName} to ${assignment.facultyName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await _service.deleteAssignment(assignment.id);
              Navigator.pop(context);
              _loadData();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Assignment deleted'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  String _getCurrentAcademicYear() {
    final now = DateTime.now();
    if (now.month >= 6) {
      return '${now.year}-${(now.year + 1) % 100}';
    } else {
      return '${now.year - 1}-${now.year % 100}';
    }
  }
}
