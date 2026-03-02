import 'package:flutter/material.dart';
import '../../../services/student_promotion_service.dart';

class StudentPromotionPage extends StatefulWidget {
  const StudentPromotionPage({super.key});

  @override
  State<StudentPromotionPage> createState() => _StudentPromotionPageState();
}

class _StudentPromotionPageState extends State<StudentPromotionPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = false;

  // Bulk promotion state
  int? _selectedYear;
  int? _selectedSemester;
  String? _selectedDepartment;
  List<String> _departments = [];
  int _studentCount = 0;

  // Bulk demotion state
  int? _demoteYear;
  int? _demoteSemester;
  String? _demoteDepartment;
  int _demoteStudentCount = 0;

  // Semester toggle state
  bool _semesterActive = false;
  List<String>? _promotionLog;

  // Individual promotion state
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  Map<String, dynamic>? _selectedStudent;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _promotionLog = <String>[];
    _loadDepartments();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadDepartments() async {
    try {
      final departments = await StudentPromotionService.getDepartments();
      setState(() => _departments = departments);
    } catch (e) {
      _showSnackBar('Error loading departments: $e', isError: true);
    }
  }

  Future<void> _updateStudentCount() async {
    if (_selectedYear == null || _selectedSemester == null) {
      setState(() => _studentCount = 0);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final students = await StudentPromotionService.getStudents(
        year: _selectedYear,
        semester: _selectedSemester,
        department: _selectedDepartment,
      );
      setState(() => _studentCount = students.length);
    } catch (e) {
      _showSnackBar('Error fetching students: $e', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _performBulkPromotion() async {
    if (_selectedYear == null || _selectedSemester == null) {
      _showSnackBar('Please select year and semester', isError: true);
      return;
    }

    if (_studentCount == 0) {
      _showSnackBar('No students to promote', isError: true);
      return;
    }

    // Confirm action
    final confirmed = await _showConfirmDialog(
      title: 'Confirm Bulk Promotion',
      message:
          'This will promote $_studentCount students from Year $_selectedYear, Semester $_selectedSemester.\n\nAre you sure?',
    );

    if (!confirmed) return;

    setState(() => _isLoading = true);
    try {
      final result = await StudentPromotionService.bulkPromoteStudents(
        fromYear: _selectedYear!,
        fromSemester: _selectedSemester!,
        department: _selectedDepartment,
      );

      if (result['success'] == true) {
        _showSnackBar(result['message'] as String);
        await _updateStudentCount();
      } else {
        _showSnackBar(result['message'] as String, isError: true);
      }
    } catch (e) {
      _showSnackBar('Error: $e', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _searchStudents() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      _showSnackBar('Please enter a search query', isError: true);
      return;
    }

    setState(() => _isLoading = true);
    try {
      // Search by hall ticket number
      final students = await StudentPromotionService.getStudents();
      final filtered = students.where((s) {
        final hallTicket =
            (s['hallTicketNumber'] ?? '').toString().toLowerCase();
        final name = (s['name'] ?? '').toString().toLowerCase();
        final queryLower = query.toLowerCase();
        return hallTicket.contains(queryLower) || name.contains(queryLower);
      }).toList();

      setState(() {
        _searchResults = filtered;
        _selectedStudent = null;
      });

      if (filtered.isEmpty) {
        _showSnackBar('No students found');
      }
    } catch (e) {
      _showSnackBar('Error searching: $e', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _promoteSelectedStudent() async {
    if (_selectedStudent == null) return;

    final confirmed = await _showConfirmDialog(
      title: 'Confirm Promotion',
      message: 'Promote ${_selectedStudent!['name']} to the next semester?',
    );

    if (!confirmed) return;

    setState(() => _isLoading = true);
    try {
      final result = await StudentPromotionService.promoteStudent(
        _selectedStudent!['hallTicketNumber'],
      );

      if (result['success'] == true) {
        _showSnackBar(result['message'] as String);
        await _searchStudents(); // Refresh
      } else {
        _showSnackBar(result['message'] as String, isError: true);
      }
    } catch (e) {
      _showSnackBar('Error: $e', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _demoteSelectedStudent() async {
    if (_selectedStudent == null) return;

    final confirmed = await _showConfirmDialog(
      title: 'Confirm Demotion',
      message: 'Demote ${_selectedStudent!['name']} to the previous semester?',
    );

    if (!confirmed) return;

    setState(() => _isLoading = true);
    try {
      final result = await StudentPromotionService.demoteStudent(
        _selectedStudent!['hallTicketNumber'],
      );

      if (result['success'] == true) {
        _showSnackBar(result['message'] as String);
        await _searchStudents(); // Refresh
      } else {
        _showSnackBar(result['message'] as String, isError: true);
      }
    } catch (e) {
      _showSnackBar('Error: $e', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _setStudentYearSemester(int year, int semester) async {
    if (_selectedStudent == null) return;

    setState(() => _isLoading = true);
    try {
      final result = await StudentPromotionService.setStudentYearSemester(
        hallTicketNumber: _selectedStudent!['hallTicketNumber'],
        year: year,
        semester: semester,
      );

      if (result['success'] == true) {
        _showSnackBar(result['message'] as String);
        await _searchStudents(); // Refresh
      } else {
        _showSnackBar(result['message'] as String, isError: true);
      }
    } catch (e) {
      _showSnackBar('Error: $e', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  Future<bool> _showConfirmDialog({
    required String title,
    required String message,
  }) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1e3a5f),
                ),
                child: const Text('Confirm'),
              ),
            ],
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Year Management'),
        backgroundColor: const Color(0xFF1e3a5f),
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Bulk Promotion'),
            Tab(text: 'Bulk Demotion'),
            Tab(text: 'Individual'),
            Tab(text: 'Semester Toggle'),
          ],
        ),
      ),
      body: Stack(
        children: [
          TabBarView(
            controller: _tabController,
            children: [
              _buildBulkPromotionTab(),
              _buildBulkDemotionTab(),
              _buildIndividualTab(),
              _buildSemesterToggleTab(),
            ],
          ),
          if (_isLoading)
            Container(
              color: Colors.black26,
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  Widget _buildBulkPromotionTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Info Card
          Card(
            color: Colors.blue[50],
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Bulk promotion moves all students from the selected year/semester to the next. '
                      'Semester 1 → Semester 2, Semester 2 → Year+1, Semester 1.',
                      style: TextStyle(color: Colors.blue),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Selection Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Select Students to Promote',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),

                  // Year Selection
                  DropdownButtonFormField<int>(
                    initialValue: _selectedYear,
                    decoration: const InputDecoration(
                      labelText: 'From Year',
                      border: OutlineInputBorder(),
                    ),
                    items: [1, 2, 3, 4]
                        .map((y) => DropdownMenuItem(
                              value: y,
                              child: Text('Year $y'),
                            ))
                        .toList(),
                    onChanged: (value) {
                      setState(() => _selectedYear = value);
                      _updateStudentCount();
                    },
                  ),
                  const SizedBox(height: 12),

                  // Semester Selection
                  DropdownButtonFormField<int>(
                    initialValue: _selectedSemester,
                    decoration: const InputDecoration(
                      labelText: 'From Semester',
                      border: OutlineInputBorder(),
                    ),
                    items: [1, 2]
                        .map((s) => DropdownMenuItem(
                              value: s,
                              child: Text('Semester $s'),
                            ))
                        .toList(),
                    onChanged: (value) {
                      setState(() => _selectedSemester = value);
                      _updateStudentCount();
                    },
                  ),
                  const SizedBox(height: 12),

                  // Department Selection (optional)
                  DropdownButtonFormField<String?>(
                    initialValue: _selectedDepartment,
                    decoration: const InputDecoration(
                      labelText: 'Department (Optional)',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('All Departments'),
                      ),
                      ..._departments.map((d) => DropdownMenuItem(
                            value: d,
                            child: Text(d),
                          )),
                    ],
                    onChanged: (value) {
                      setState(() => _selectedDepartment = value);
                      _updateStudentCount();
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Preview Card
          if (_selectedYear != null && _selectedSemester != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _studentCount > 0
                              ? Icons.people
                              : Icons.people_outline,
                          color: _studentCount > 0 ? Colors.green : Colors.grey,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '$_studentCount students will be promoted',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color:
                                _studentCount > 0 ? Colors.green : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_studentCount > 0)
                      Text(
                        _selectedSemester == 1
                            ? 'Year $_selectedYear, Semester 1 → Year $_selectedYear, Semester 2'
                            : _selectedYear == 4
                                ? 'Year 4, Semester 2 → Graduated'
                                : 'Year $_selectedYear, Semester 2 → Year ${_selectedYear! + 1}, Semester 1',
                        style: const TextStyle(color: Colors.grey),
                      ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 24),

          // Promote Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _studentCount > 0 && !_isLoading
                  ? _performBulkPromotion
                  : null,
              icon: const Icon(Icons.arrow_upward),
              label: Text('Promote $_studentCount Students'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1e3a5f),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _updateDemoteStudentCount() async {
    if (_demoteYear == null || _demoteSemester == null) {
      setState(() => _demoteStudentCount = 0);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final students = await StudentPromotionService.getStudents(
        year: _demoteYear,
        semester: _demoteSemester,
        department: _demoteDepartment,
      );
      setState(() => _demoteStudentCount = students.length);
    } catch (e) {
      _showSnackBar('Error fetching students: $e', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _performBulkDemotion() async {
    if (_demoteYear == null || _demoteSemester == null) {
      _showSnackBar('Please select year and semester', isError: true);
      return;
    }

    if (_demoteStudentCount == 0) {
      _showSnackBar('No students to demote', isError: true);
      return;
    }

    // Confirm action
    final confirmed = await _showConfirmDialog(
      title: 'Confirm Bulk Demotion',
      message:
          'This will demote $_demoteStudentCount students from Year $_demoteYear, Semester $_demoteSemester.\n\nAre you sure?',
    );

    if (!confirmed) return;

    setState(() => _isLoading = true);
    try {
      final result = await StudentPromotionService.bulkDemoteStudents(
        fromYear: _demoteYear!,
        fromSemester: _demoteSemester!,
        department: _demoteDepartment,
      );

      if (result['success'] == true) {
        _showSnackBar(result['message'] as String);
        await _updateDemoteStudentCount();
      } else {
        _showSnackBar(result['message'] as String, isError: true);
      }
    } catch (e) {
      _showSnackBar('Error: $e', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Widget _buildBulkDemotionTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Info Card
          Card(
            color: Colors.orange[50],
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.warning_amber, color: Colors.orange),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Bulk demotion moves all students from the selected year/semester to the previous. '
                      'Semester 2 → Semester 1, Semester 1 → Year-1, Semester 2.',
                      style: TextStyle(color: Colors.orange),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Selection Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Select Students to Demote',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),

                  // Year Selection
                  DropdownButtonFormField<int>(
                    initialValue: _demoteYear,
                    decoration: const InputDecoration(
                      labelText: 'From Year',
                      border: OutlineInputBorder(),
                    ),
                    items: [1, 2, 3, 4]
                        .map((y) => DropdownMenuItem(
                              value: y,
                              child: Text('Year $y'),
                            ))
                        .toList(),
                    onChanged: (value) {
                      setState(() => _demoteYear = value);
                      _updateDemoteStudentCount();
                    },
                  ),
                  const SizedBox(height: 12),

                  // Semester Selection
                  DropdownButtonFormField<int>(
                    initialValue: _demoteSemester,
                    decoration: const InputDecoration(
                      labelText: 'From Semester',
                      border: OutlineInputBorder(),
                    ),
                    items: [1, 2]
                        .map((s) => DropdownMenuItem(
                              value: s,
                              child: Text('Semester $s'),
                            ))
                        .toList(),
                    onChanged: (value) {
                      setState(() => _demoteSemester = value);
                      _updateDemoteStudentCount();
                    },
                  ),
                  const SizedBox(height: 12),

                  // Department Selection (optional)
                  DropdownButtonFormField<String?>(
                    initialValue: _demoteDepartment,
                    decoration: const InputDecoration(
                      labelText: 'Department (Optional)',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('All Departments'),
                      ),
                      ..._departments.map((d) => DropdownMenuItem(
                            value: d,
                            child: Text(d),
                          )),
                    ],
                    onChanged: (value) {
                      setState(() => _demoteDepartment = value);
                      _updateDemoteStudentCount();
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Preview Card
          if (_demoteYear != null && _demoteSemester != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _demoteStudentCount > 0
                              ? Icons.people
                              : Icons.people_outline,
                          color: _demoteStudentCount > 0
                              ? Colors.orange
                              : Colors.grey,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '$_demoteStudentCount students will be demoted',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: _demoteStudentCount > 0
                                ? Colors.orange
                                : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_demoteStudentCount > 0)
                      Text(
                        _demoteSemester == 2
                            ? 'Year $_demoteYear, Semester 2 → Year $_demoteYear, Semester 1'
                            : _demoteYear == 1
                                ? 'Cannot demote: Already at Year 1, Semester 1'
                                : 'Year $_demoteYear, Semester 1 → Year ${_demoteYear! - 1}, Semester 2',
                        style: const TextStyle(color: Colors.grey),
                      ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 24),

          // Demote Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _demoteStudentCount > 0 &&
                      !_isLoading &&
                      !(_demoteYear == 1 && _demoteSemester == 1)
                  ? _performBulkDemotion
                  : null,
              icon: const Icon(Icons.arrow_downward),
              label: Text('Demote $_demoteStudentCount Students'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIndividualTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Search Student',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          decoration: const InputDecoration(
                            hintText: 'Enter Hall Ticket Number or Name',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.search),
                          ),
                          onSubmitted: (_) => _searchStudents(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _searchStudents,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1e3a5f),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 18,
                          ),
                        ),
                        child: const Text('Search'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Search Results
          if (_searchResults.isNotEmpty)
            Card(
              child: ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _searchResults.length,
                itemBuilder: (context, index) {
                  final student = _searchResults[index];
                  final isSelected = _selectedStudent?['id'] == student['id'];
                  return ListTile(
                    selected: isSelected,
                    selectedTileColor: Colors.blue[50],
                    leading: CircleAvatar(
                      backgroundColor: isSelected
                          ? const Color(0xFF1e3a5f)
                          : Colors.grey[300],
                      child: Text(
                        (student['name'] ?? 'S')[0].toUpperCase(),
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.black,
                        ),
                      ),
                    ),
                    title: Text(student['name'] ?? 'Unknown'),
                    subtitle: Text(
                      '${student['hallTicketNumber']} • Year ${student['year']}, Sem ${student['semester'] ?? 1} • ${student['department']}',
                    ),
                    trailing: student['status'] == 'graduated'
                        ? const Chip(
                            label: Text('Graduated'),
                            backgroundColor: Colors.green,
                            labelStyle: TextStyle(color: Colors.white),
                          )
                        : null,
                    onTap: () => setState(() => _selectedStudent = student),
                  );
                },
              ),
            ),

          // Selected Student Actions
          if (_selectedStudent != null) ...[
            const SizedBox(height: 16),
            Card(
              color: Colors.blue[50],
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Selected: ${_selectedStudent!['name']}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Current: Year ${_selectedStudent!['year']}, Semester ${_selectedStudent!['semester'] ?? 1}',
                      style: const TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 16),

                    // Action Buttons
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ElevatedButton.icon(
                          onPressed: _promoteSelectedStudent,
                          icon: const Icon(Icons.arrow_upward),
                          label: const Text('Promote'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: _demoteSelectedStudent,
                          icon: const Icon(Icons.arrow_downward),
                          label: const Text('Demote'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: () => _showSetYearSemesterDialog(),
                          icon: const Icon(Icons.edit),
                          label: const Text('Set Manually'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1e3a5f),
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─── Semester Toggle ────────────────────────────────────────────────────────

  /// Promotes every student in the system from highest year/sem down to lowest,
  /// ensuring no student is double-promoted.  All post-promotion side effects
  /// (attendance reset, course archival, mentor removal, faculty prefs reset)
  /// are handled inside [StudentPromotionService.bulkPromoteStudents].
  Future<void> _performFullSemesterPromotion() async {
    final confirmed = await _showConfirmDialog(
      title: 'Start New Semester?',
      message: 'This will:\n\n'
          '• Promote ALL students to the next semester/year\n'
          '• Reset attendance counters to 0\n'
          '• Archive & clear enrolled courses\n'
          '• Remove mentor assignments\n'
          '• Reset faculty course preferences\n\n'
          'This action cannot be undone. Continue?',
    );
    if (!confirmed) return;

    setState(() {
      _isLoading = true;
      _promotionLog = <String>[];
    });

    // Process from the highest year/semester first so students are not
    // promoted a second time when their new group is processed.
    final batches = [
      (year: 4, semester: 2),
      (year: 4, semester: 1),
      (year: 3, semester: 2),
      (year: 3, semester: 1),
      (year: 2, semester: 2),
      (year: 2, semester: 1),
      (year: 1, semester: 2),
      (year: 1, semester: 1),
    ];

    final log = <String>[];
    bool anyError = false;

    for (final b in batches) {
      try {
        final result = await StudentPromotionService.bulkPromoteStudents(
          fromYear: b.year,
          fromSemester: b.semester,
        );
        final msg = result['message'] as String? ?? '';
        log.add('Y${b.year}S${b.semester}: $msg');
        if (result['success'] != true) anyError = true;
      } catch (e) {
        log.add('Y${b.year}S${b.semester}: ERROR — $e');
        anyError = true;
      }
    }

    setState(() {
      _isLoading = false;
      _semesterActive = true;
      _promotionLog = log;
    });

    _showSnackBar(
      anyError
          ? 'Completed with some errors'
          : 'New semester started successfully!',
      isError: anyError,
    );
  }

  Widget _buildSemesterToggleTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 12),

          // Warning banner
          Card(
            color: Colors.red[50],
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.warning_rounded, color: Colors.red[700]),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'This toggle starts a new semester for the entire institution. '
                      'All students will be promoted and all associated data will be reset.',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),

          // Toggle card
          Card(
            elevation: 4,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
              child: Column(
                children: [
                  Icon(
                    _semesterActive
                        ? Icons.check_circle_rounded
                        : Icons.school_rounded,
                    size: 72,
                    color: _semesterActive ? Colors.green : Colors.grey[400],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    _semesterActive
                        ? 'New Semester Active'
                        : 'Start New Semester',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: _semesterActive
                          ? Colors.green[700]
                          : Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _semesterActive
                        ? 'All students have been promoted and data has been reset.'
                        : 'Toggle the switch below to promote all students and reset semester data.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 32),
                  Transform.scale(
                    scale: 1.8,
                    child: Switch(
                      value: _semesterActive,
                      activeThumbColor: Colors.green,
                      inactiveThumbColor: const Color(0xFF1e3a5f),
                      inactiveTrackColor:
                          const Color(0xFF1e3a5f).withOpacity(0.3),
                      onChanged: _isLoading
                          ? null
                          : (value) {
                              if (value) {
                                _performFullSemesterPromotion();
                              } else {
                                setState(() => _semesterActive = false);
                              }
                            },
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _semesterActive ? 'ON' : 'OFF',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: _semesterActive ? Colors.green : Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ),

          _buildWhatItDoes(),
          _buildPromotionLog(),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────

  Widget _buildWhatItDoes() {
    if (_semesterActive) return const SizedBox.shrink();
    return Column(
      children: [
        const SizedBox(height: 24),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'What this does:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const SizedBox(height: 12),
                _infoRow(Icons.arrow_upward, Colors.green,
                    'Promotes ALL students to next semester/year'),
                _infoRow(Icons.bar_chart, Colors.blue,
                    'Resets attendance to 0% for the new semester'),
                _infoRow(Icons.archive_rounded, Colors.orange,
                    'Archives enrolled courses to history & clears current registrations'),
                _infoRow(Icons.person_remove, Colors.purple,
                    'Removes all mentor assignments'),
                _infoRow(Icons.playlist_remove, Colors.red,
                    'Clears faculty course preferences for re-submission'),
                _infoRow(Icons.assignment_turned_in_outlined, Colors.teal,
                    'Deactivates faculty course assignments — admin must re-assign for new semester'),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPromotionLog() {
    final log = _promotionLog;
    if (log == null || log.isEmpty) return const SizedBox.shrink();
    final rows = <Widget>[
      const Text(
        'Promotion Log',
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
      ),
      const SizedBox(height: 8),
    ];
    for (final entry in log) {
      rows.add(Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              entry.contains('ERROR')
                  ? Icons.error_outline
                  : Icons.check_circle_outline,
              size: 16,
              color: entry.contains('ERROR') ? Colors.red : Colors.green,
            ),
            const SizedBox(width: 6),
            Expanded(child: Text(entry, style: const TextStyle(fontSize: 12))),
          ],
        ),
      ));
    }
    return Column(
      children: [
        const SizedBox(height: 24),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: rows,
            ),
          ),
        ),
      ],
    );
  }

  Widget _infoRow(IconData icon, Color color, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }

  void _showSetYearSemesterDialog() {
    int selectedYear = _selectedStudent?['year'] ?? 1;
    int selectedSemester = _selectedStudent?['semester'] ?? 1;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Set Year & Semester'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int>(
                initialValue: selectedYear,
                decoration: const InputDecoration(
                  labelText: 'Year',
                  border: OutlineInputBorder(),
                ),
                items: [1, 2, 3, 4]
                    .map((y) => DropdownMenuItem(
                          value: y,
                          child: Text('Year $y'),
                        ))
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setDialogState(() => selectedYear = value);
                  }
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: selectedSemester,
                decoration: const InputDecoration(
                  labelText: 'Semester',
                  border: OutlineInputBorder(),
                ),
                items: [1, 2]
                    .map((s) => DropdownMenuItem(
                          value: s,
                          child: Text('Semester $s'),
                        ))
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setDialogState(() => selectedSemester = value);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _setStudentYearSemester(selectedYear, selectedSemester);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1e3a5f),
              ),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
