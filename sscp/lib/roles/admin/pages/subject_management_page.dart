import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' as excel_pkg;
import 'dart:io';
import '../../../models/faculty_assignment_model.dart';
import '../../../services/faculty_assignment_service.dart';

class SubjectManagementPage extends StatefulWidget {
  const SubjectManagementPage({super.key});

  @override
  State<SubjectManagementPage> createState() => _SubjectManagementPageState();
}

class _SubjectManagementPageState extends State<SubjectManagementPage>
    with SingleTickerProviderStateMixin {
  final FacultyAssignmentService _service = FacultyAssignmentService();
  late TabController _tabController;

  List<Subject> _subjects = [];
  List<String> _departments = [];
  bool _isLoading = true;
  String? _errorMessage;

  // Filters
  String? _selectedDepartment;
  int? _selectedYear;
  String? _selectedSemester;

  // Excel upload state
  File? _selectedFile;
  FilePickerResult? _selectedFilePickerResult;
  String? _selectedFileName;
  bool _isUploading = false;
  Map<String, dynamic>? _uploadResult;

  // Predefined departments (fallback if none found in DB)
  final List<String> _fallbackDepartments = [
    'CSE', 'ECE', 'EEE', 'ME', 'CE', 'IT', 'CSBS', 'AIDS', 'AIML', 'CSD'
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this); // 4 years
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
        _service.getAllSubjects(),
        _service.getDepartments(),
      ]);

      setState(() {
        _subjects = results[0] as List<Subject>;
        final fetchedDepts = results[1] as List<String>;
        
        // Combine fetched departments with fallback, remove duplicates
        _departments = {...fetchedDepts, ..._fallbackDepartments}.toList()..sort();
        
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        // Use fallback departments on error
        _departments = List.from(_fallbackDepartments);
        _errorMessage = 'Error loading data: $e';
        _isLoading = false;
      });
    }
  }

  List<Subject> _getFilteredSubjects(int year) {
    return _subjects.where((s) {
      bool matchesYear = s.year == year;
      bool matchesDept =
          _selectedDepartment == null || s.department == _selectedDepartment;
      bool matchesSem =
          _selectedSemester == null || s.semester == _selectedSemester;
      return matchesYear && matchesDept && matchesSem;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Subject Management'),
        backgroundColor: const Color(0xFF1e3a5f),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.upload_file),
            onPressed: () => _showExcelUploadDialog(context),
            tooltip: 'Upload Excel',
          ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => _showExcelFormatInfo(context),
            tooltip: 'Excel Format Info',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.yellow,
          tabs: const [
            Tab(text: 'Year 1'),
            Tab(text: 'Year 2'),
            Tab(text: 'Year 3'),
            Tab(text: 'Year 4'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? _buildErrorView()
              : Column(
                  children: [
                    _buildFilterBar(isMobile),
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildYearTab(1, isMobile),
                          _buildYearTab(2, isMobile),
                          _buildYearTab(3, isMobile),
                          _buildYearTab(4, isMobile),
                        ],
                      ),
                    ),
                  ],
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddSubjectDialog(context),
        backgroundColor: const Color(0xFF1e3a5f),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add Subject', style: TextStyle(color: Colors.white)),
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

  Widget _buildFilterBar(bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      color: Colors.grey.shade100,
      child: isMobile
          ? Column(
              children: [
                _buildDepartmentFilter(),
                const SizedBox(height: 8),
                _buildSemesterFilter(),
              ],
            )
          : Row(
              children: [
                Expanded(child: _buildDepartmentFilter()),
                const SizedBox(width: 16),
                Expanded(child: _buildSemesterFilter()),
                const SizedBox(width: 16),
                _buildStatsChip(),
              ],
            ),
    );
  }

  Widget _buildDepartmentFilter() {
    return DropdownButtonFormField<String>(
      decoration: const InputDecoration(
        labelText: 'Department',
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      value: _selectedDepartment,
      items: [
        const DropdownMenuItem(value: null, child: Text('All Departments')),
        ..._departments.map((dept) {
          return DropdownMenuItem(value: dept, child: Text(dept));
        }),
      ],
      onChanged: (value) {
        setState(() {
          _selectedDepartment = value;
        });
      },
    );
  }

  Widget _buildSemesterFilter() {
    return DropdownButtonFormField<String>(
      decoration: const InputDecoration(
        labelText: 'Semester',
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      value: _selectedSemester,
      items: const [
        DropdownMenuItem(value: null, child: Text('All Semesters')),
        DropdownMenuItem(value: 'I', child: Text('Semester I')),
        DropdownMenuItem(value: 'II', child: Text('Semester II')),
      ],
      onChanged: (value) {
        setState(() {
          _selectedSemester = value;
        });
      },
    );
  }

  Widget _buildStatsChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1e3a5f).withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        'Total: ${_subjects.length} subjects',
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          color: Color(0xFF1e3a5f),
        ),
      ),
    );
  }

  Widget _buildYearTab(int year, bool isMobile) {
    final subjects = _getFilteredSubjects(year);

    // Group by semester
    final semISubjects = subjects.where((s) => s.semester == 'I').toList();
    final semIISubjects = subjects.where((s) => s.semester == 'II').toList();

    if (subjects.isEmpty) {
      return _buildEmptyState(year);
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        padding: EdgeInsets.all(isMobile ? 12 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (semISubjects.isNotEmpty) ...[
              _buildSemesterSection('Semester I', semISubjects, isMobile),
              const SizedBox(height: 24),
            ],
            if (semIISubjects.isNotEmpty) ...[
              _buildSemesterSection('Semester II', semIISubjects, isMobile),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(int year) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.book_outlined, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            'No Subjects for Year $year',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add subjects using the button below',
            style: TextStyle(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _showAddSubjectDialog(context, prefilledYear: year),
            icon: const Icon(Icons.add),
            label: const Text('Add Subject'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1e3a5f),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSemesterSection(
      String title, List<Subject> subjects, bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF1e3a5f),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.calendar_today, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${subjects.length}',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        ...subjects.map((subject) => _buildSubjectCard(subject, isMobile)),
      ],
    );
  }

  Widget _buildSubjectCard(Subject subject, bool isMobile) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 1,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getDepartmentColor(subject.department),
          child: Text(
            subject.code.isNotEmpty
                ? subject.code.substring(0, subject.code.length > 2 ? 2 : subject.code.length)
                : 'SB',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 11,
            ),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                subject.name,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
            if (subject.subjectType != SubjectType.core)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: subject.subjectType == SubjectType.oe
                      ? Colors.purple.shade100
                      : Colors.teal.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  subject.subjectType.displayName,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: subject.subjectType == SubjectType.oe
                        ? Colors.purple.shade700
                        : Colors.teal.shade700,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Text(
          '${subject.code} • ${subject.department} • ${subject.credits} Credits',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 20),
              onPressed: () => _showEditSubjectDialog(context, subject),
              tooltip: 'Edit',
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
              onPressed: () => _confirmDeleteSubject(subject),
              tooltip: 'Delete',
            ),
          ],
        ),
      ),
    );
  }

  Color _getDepartmentColor(String department) {
    final colors = {
      'CSE': Colors.blue,
      'ECE': Colors.green,
      'EEE': Colors.orange,
      'ME': Colors.purple,
      'CE': Colors.teal,
      'IT': Colors.indigo,
    };
    return colors[department] ?? const Color(0xFF1e3a5f);
  }

  // ============ DIALOGS ============
  void _showAddSubjectDialog(BuildContext context, {int? prefilledYear}) {
    final codeController = TextEditingController();
    final nameController = TextEditingController();
    final creditsController = TextEditingController(text: '3');
    String? selectedDepartment = _selectedDepartment ?? (_departments.isNotEmpty ? _departments.first : null);
    int selectedYear = prefilledYear ?? (_tabController.index + 1);
    String selectedSemester = 'I';
    SubjectType selectedSubjectType = SubjectType.core;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.book, color: Color(0xFF1e3a5f)),
                  SizedBox(width: 8),
                  Text('Add New Subject'),
                ],
              ),
              content: SizedBox(
                width: MediaQuery.of(context).size.width * 0.8,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Subject Code
                      TextField(
                        controller: codeController,
                        decoration: const InputDecoration(
                          labelText: 'Subject Code *',
                          border: OutlineInputBorder(),
                          hintText: 'e.g., CS301, EC201',
                          prefixIcon: Icon(Icons.code),
                        ),
                        textCapitalization: TextCapitalization.characters,
                      ),
                      const SizedBox(height: 16),

                      // Subject Name
                      TextField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'Subject Name *',
                          border: OutlineInputBorder(),
                          hintText: 'e.g., Database Management Systems',
                          prefixIcon: Icon(Icons.text_fields),
                        ),
                        textCapitalization: TextCapitalization.words,
                      ),
                      const SizedBox(height: 16),

                      // Department
                      DropdownButtonFormField<String>(
                        decoration: const InputDecoration(
                          labelText: 'Department *',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.business),
                        ),
                        value: selectedDepartment,
                        items: _departments.map((dept) {
                          return DropdownMenuItem(value: dept, child: Text(dept));
                        }).toList(),
                        onChanged: (value) {
                          setDialogState(() {
                            selectedDepartment = value;
                          });
                        },
                      ),
                      const SizedBox(height: 16),

                      // Subject Type (Core/OE/PE)
                      DropdownButtonFormField<SubjectType>(
                        decoration: const InputDecoration(
                          labelText: 'Subject Type *',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.category),
                        ),
                        value: selectedSubjectType,
                        items: SubjectType.values.map((type) {
                          return DropdownMenuItem(
                            value: type,
                            child: Text(type.fullName),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setDialogState(() {
                            selectedSubjectType = value ?? SubjectType.core;
                          });
                        },
                      ),
                      const SizedBox(height: 16),

                      // Year and Semester Row
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              decoration: const InputDecoration(
                                labelText: 'Year *',
                                border: OutlineInputBorder(),
                              ),
                              value: selectedYear,
                              items: [1, 2, 3, 4].map((year) {
                                return DropdownMenuItem(
                                  value: year,
                                  child: Text('Year $year'),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setDialogState(() {
                                  selectedYear = value ?? 1;
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
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Credits
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
                    // Validate
                    if (codeController.text.trim().isEmpty ||
                        nameController.text.trim().isEmpty ||
                        selectedDepartment == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please fill all required fields'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }

                    try {
                      final subject = Subject(
                        id: '',
                        code: codeController.text.trim().toUpperCase(),
                        name: nameController.text.trim(),
                        department: selectedDepartment!,
                        credits: int.tryParse(creditsController.text) ?? 3,
                        year: selectedYear,
                        semester: selectedSemester,
                        subjectType: selectedSubjectType,
                      );

                      await _service.createSubject(subject);
                      Navigator.pop(context);
                      _loadData();

                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Subject added successfully'),
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
                  icon: const Icon(Icons.add),
                  label: const Text('Add'),
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

  void _showEditSubjectDialog(BuildContext context, Subject subject) {
    final codeController = TextEditingController(text: subject.code);
    final nameController = TextEditingController(text: subject.name);
    final creditsController = TextEditingController(text: subject.credits.toString());
    String selectedDepartment = subject.department;
    int selectedYear = subject.year;
    String selectedSemester = subject.semester;
    SubjectType selectedSubjectType = subject.subjectType;

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
                        value: selectedDepartment,
                        items: _departments.map((dept) {
                          return DropdownMenuItem(value: dept, child: Text(dept));
                        }).toList(),
                        onChanged: (value) {
                          setDialogState(() {
                            selectedDepartment = value ?? selectedDepartment;
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      // Subject Type (Core/OE/PE)
                      DropdownButtonFormField<SubjectType>(
                        decoration: const InputDecoration(
                          labelText: 'Subject Type *',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.category),
                        ),
                        value: selectedSubjectType,
                        items: SubjectType.values.map((type) {
                          return DropdownMenuItem(
                            value: type,
                            child: Text(type.fullName),
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
                              value: selectedYear,
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
                              value: selectedSemester,
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
                      await _service.updateSubject(
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
                      _loadData();

                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Subject updated successfully'),
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

  void _confirmDeleteSubject(Subject subject) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Subject?'),
        content: Text(
            'Are you sure you want to delete "${subject.name}" (${subject.code})?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await _service.deleteSubject(subject.id);
              Navigator.pop(context);
              _loadData();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Subject deleted'),
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

  // ============ EXCEL UPLOAD METHODS ============
  void _showExcelUploadDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.upload_file, color: Color(0xFF1e3a5f)),
                  SizedBox(width: 8),
                  Text('Upload Subjects from Excel'),
                ],
              ),
              content: SizedBox(
                width: MediaQuery.of(context).size.width * 0.8,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Required columns info
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.info, color: Colors.blue.shade700, size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  'Required Columns:',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue.shade700,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              '• Code - Subject code (e.g., CS301)\n'
                              '• Name - Subject name\n'
                              '• Department - Department code (e.g., CSE)\n'
                              '• Year - Year number (1-4)\n'
                              '• Semester - Semester (I or II, or 1, 2)\n'
                              '• Type - Core, OE, or PE (optional)\n'
                              '• Credits - Optional (default: 3)',
                              style: TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // File selection
                      InkWell(
                        onTap: _isUploading ? null : () async {
                          await _pickExcelFile();
                          setDialogState(() {});
                        },
                        child: Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: _selectedFileName != null
                                  ? Colors.green
                                  : Colors.grey.shade300,
                              width: 2,
                              style: BorderStyle.solid,
                            ),
                            borderRadius: BorderRadius.circular(8),
                            color: _selectedFileName != null
                                ? Colors.green.shade50
                                : Colors.grey.shade50,
                          ),
                          child: Column(
                            children: [
                              Icon(
                                _selectedFileName != null
                                    ? Icons.check_circle
                                    : Icons.cloud_upload_outlined,
                                size: 48,
                                color: _selectedFileName != null
                                    ? Colors.green
                                    : Colors.grey,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _selectedFileName ?? 'Click to select Excel file',
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  color: _selectedFileName != null
                                      ? Colors.green.shade700
                                      : Colors.grey.shade600,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              if (_selectedFileName == null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  'Supported: .xlsx, .xls',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),

                      // Upload result
                      if (_uploadResult != null) ...[
                        const SizedBox(height: 16),
                        _buildUploadResultCard(),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: _isUploading ? null : () {
                    setState(() {
                      _selectedFile = null;
                      _selectedFilePickerResult = null;
                      _selectedFileName = null;
                      _uploadResult = null;
                    });
                    Navigator.pop(context);
                  },
                  child: const Text('Close'),
                ),
                if (_selectedFileName != null && _uploadResult == null)
                  ElevatedButton.icon(
                    onPressed: _isUploading ? null : () async {
                      setDialogState(() => _isUploading = true);
                      await _handleExcelUpload();
                      setDialogState(() => _isUploading = false);
                    },
                    icon: _isUploading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.upload),
                    label: Text(_isUploading ? 'Uploading...' : 'Upload'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1e3a5f),
                      foregroundColor: Colors.white,
                    ),
                  ),
                if (_uploadResult != null && _uploadResult!['success'] == true)
                  ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        _selectedFile = null;
                        _selectedFilePickerResult = null;
                        _selectedFileName = null;
                        _uploadResult = null;
                      });
                      Navigator.pop(context);
                      _loadData();
                    },
                    icon: const Icon(Icons.done),
                    label: const Text('Done'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
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

  Widget _buildUploadResultCard() {
    final success = _uploadResult!['success'] as bool;
    final message = _uploadResult!['message'] as String;
    final created = _uploadResult!['created'] as int;
    final failed = _uploadResult!['failed'] as int;
    final totalRows = _uploadResult!['totalRows'] as int;
    final failedReasons = _uploadResult!['failedReasons'] as List<dynamic>;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: success ? Colors.green.shade50 : Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: success ? Colors.green.shade200 : Colors.red.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                success ? Icons.check_circle : Icons.error,
                color: success ? Colors.green : Colors.red,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: success ? Colors.green.shade700 : Colors.red.shade700,
                  ),
                ),
              ),
            ],
          ),
          if (totalRows > 0) ...[
            const SizedBox(height: 8),
            Text('Total rows: $totalRows'),
            Text('Created: $created', style: const TextStyle(color: Colors.green)),
            if (failed > 0)
              Text('Failed: $failed', style: const TextStyle(color: Colors.red)),
          ],
          if (failedReasons.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Text('Errors:', style: TextStyle(fontWeight: FontWeight.bold)),
            ...failedReasons.take(5).map((reason) => Text(
              '• $reason',
              style: const TextStyle(fontSize: 12, color: Colors.red),
            )),
            if (failedReasons.length > 5)
              Text('... and ${failedReasons.length - 5} more errors'),
          ],
        ],
      ),
    );
  }

  Future<void> _pickExcelFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
        allowMultiple: false,
      );

      if (result != null) {
        setState(() {
          _selectedFilePickerResult = result;
          _selectedFileName = result.files.single.name;
          _uploadResult = null;

          if (!kIsWeb && result.files.single.path != null) {
            _selectedFile = File(result.files.single.path!);
          } else {
            _selectedFile = null;
          }
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking file: $e')),
      );
    }
  }

  Future<void> _handleExcelUpload() async {
    if (_selectedFile == null && _selectedFilePickerResult == null) {
      setState(() {
        _uploadResult = {
          'success': false,
          'message': 'Please select a file first',
          'totalRows': 0,
          'created': 0,
          'failed': 0,
          'failedReasons': [],
        };
      });
      return;
    }

    setState(() => _isUploading = true);

    try {
      List<int> bytes;
      
      if (_selectedFile != null) {
        bytes = await _selectedFile!.readAsBytes();
      } else if (_selectedFilePickerResult?.files.single.bytes != null) {
        bytes = _selectedFilePickerResult!.files.single.bytes!;
      } else {
        throw Exception('No file data available');
      }

      // Parse Excel
      final excel = excel_pkg.Excel.decodeBytes(bytes);

      if (excel.sheets.isEmpty) {
        setState(() {
          _uploadResult = {
            'success': false,
            'message': 'Excel file is empty',
            'totalRows': 0,
            'created': 0,
            'failed': 0,
            'failedReasons': [],
          };
        });
        return;
      }

      final sheet = excel.sheets.values.first;
      final rows = sheet.rows;

      if (rows.isEmpty || rows.length < 2) {
        setState(() {
          _uploadResult = {
            'success': false,
            'message': 'Excel file has no data rows',
            'totalRows': 0,
            'created': 0,
            'failed': 0,
            'failedReasons': [],
          };
        });
        return;
      }

      // Get headers
      final headers = rows.first
          .map((cell) => cell?.value?.toString().trim().toLowerCase() ?? '')
          .toList();

      // Check required columns
      final requiredColumns = ['code', 'name', 'department', 'year', 'semester'];
      final missingColumns = requiredColumns
          .where((col) => !headers.contains(col))
          .toList();

      if (missingColumns.isNotEmpty) {
        setState(() {
          _uploadResult = {
            'success': false,
            'message': 'Missing required columns: ${missingColumns.join(", ")}',
            'totalRows': 0,
            'created': 0,
            'failed': 0,
            'failedReasons': [],
          };
        });
        return;
      }

      // Find column indices
      final codeIndex = headers.indexOf('code');
      final nameIndex = headers.indexOf('name');
      final deptIndex = headers.indexOf('department');
      final yearIndex = headers.indexOf('year');
      final semIndex = headers.indexOf('semester');
      final creditsIndex = headers.indexOf('credits');
      final typeIndex = headers.indexOf('type');

      int created = 0;
      int failed = 0;
      List<String> failedReasons = [];

      // Process data rows
      for (int i = 1; i < rows.length; i++) {
        final row = rows[i];

        try {
          final code = row[codeIndex]?.value?.toString().trim() ?? '';
          final name = row[nameIndex]?.value?.toString().trim() ?? '';
          final department = row[deptIndex]?.value?.toString().trim() ?? '';
          final yearStr = row[yearIndex]?.value?.toString().trim() ?? '';
          final semester = row[semIndex]?.value?.toString().trim() ?? '';
          final creditsStr = creditsIndex >= 0 && creditsIndex < row.length
              ? row[creditsIndex]?.value?.toString().trim() ?? '3'
              : '3';
          final typeStr = typeIndex >= 0 && typeIndex < row.length
              ? row[typeIndex]?.value?.toString().trim() ?? 'Core'
              : 'Core';

          // Skip empty rows
          if (code.isEmpty && name.isEmpty) continue;

          // Validate required fields
          if (code.isEmpty || name.isEmpty || department.isEmpty ||
              yearStr.isEmpty || semester.isEmpty) {
            failedReasons.add('Row ${i + 1}: Missing required fields');
            failed++;
            continue;
          }

          // Parse year
          final year = int.tryParse(yearStr);
          if (year == null || year < 1 || year > 4) {
            failedReasons.add('Row ${i + 1}: Invalid year "$yearStr"');
            failed++;
            continue;
          }

          // Normalize semester
          String normalizedSemester = semester.toUpperCase();
          if (normalizedSemester == '1' || normalizedSemester == 'SEM 1' ||
              normalizedSemester == 'SEMESTER 1' || normalizedSemester == 'SEM I' ||
              normalizedSemester == 'SEMESTER I') {
            normalizedSemester = 'I';
          } else if (normalizedSemester == '2' || normalizedSemester == 'SEM 2' ||
              normalizedSemester == 'SEMESTER 2' || normalizedSemester == 'SEM II' ||
              normalizedSemester == 'SEMESTER II') {
            normalizedSemester = 'II';
          }

          if (normalizedSemester != 'I' && normalizedSemester != 'II') {
            failedReasons.add('Row ${i + 1}: Invalid semester "$semester"');
            failed++;
            continue;
          }

          final credits = int.tryParse(creditsStr) ?? 3;

          // Create subject
          final subject = Subject(
            id: '',
            code: code.toUpperCase(),
            name: name,
            department: department.toUpperCase(),
            year: year,
            semester: normalizedSemester,
            credits: credits,
            subjectType: SubjectTypeExtension.fromString(typeStr),
          );

          await _service.createSubject(subject);
          created++;

        } catch (e) {
          failedReasons.add('Row ${i + 1}: Error - $e');
          failed++;
        }
      }

      setState(() {
        _uploadResult = {
          'success': created > 0,
          'message': created > 0
              ? 'Upload completed successfully!'
              : 'No subjects were created',
          'totalRows': rows.length - 1,
          'created': created,
          'failed': failed,
          'failedReasons': failedReasons,
        };
      });

    } catch (e) {
      setState(() {
        _uploadResult = {
          'success': false,
          'message': 'Upload failed: $e',
          'totalRows': 0,
          'created': 0,
          'failed': 0,
          'failedReasons': [],
        };
      });
    } finally {
      setState(() => _isUploading = false);
    }
  }

  void _showExcelFormatInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.table_chart, color: Color(0xFF1e3a5f)),
            SizedBox(width: 8),
            Text('Excel File Format'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Your Excel file should have the following columns in the first row:',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 16),
              Table(
                border: TableBorder.all(color: Colors.grey.shade300),
                columnWidths: const {
                  0: FlexColumnWidth(1),
                  1: FlexColumnWidth(2),
                },
                children: [
                  TableRow(
                    decoration: BoxDecoration(color: Colors.grey.shade100),
                    children: const [
                      Padding(
                        padding: EdgeInsets.all(8),
                        child: Text('Column', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      Padding(
                        padding: EdgeInsets.all(8),
                        child: Text('Description', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  _buildTableRow('Code *', 'Subject code (e.g., CS301, EC201)'),
                  _buildTableRow('Name *', 'Full subject name'),
                  _buildTableRow('Department *', 'Department code (e.g., CSE, ECE)'),
                  _buildTableRow('Year *', 'Year number: 1, 2, 3, or 4'),
                  _buildTableRow('Semester *', 'I or II (also accepts 1, 2, SEM I, etc.)'),
                  _buildTableRow('Type', 'Core, OE, or PE (optional, default: Core)'),
                  _buildTableRow('Credits', 'Number of credits (optional, default: 3)'),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.lightbulb, color: Colors.amber),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Columns marked with * are required. Column names are case-insensitive.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  TableRow _buildTableRow(String column, String description) {
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: Text(column, style: const TextStyle(fontWeight: FontWeight.w500)),
        ),
        Padding(
          padding: const EdgeInsets.all(8),
          child: Text(description),
        ),
      ],
    );
  }
}
