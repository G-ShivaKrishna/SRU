import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../models/faculty_assignment_model.dart';
import '../../../services/student_course_service.dart';
import '../../../services/user_service.dart';

/// Subject Registration Screen
///
/// This screen shows:
/// 1. Core subjects (auto-assigned by admin) - Read only
/// 2. OE (Open Elective) - Student selectable
/// 3. PE (Programme Elective) - Student selectable
class SubjectRegistrationScreen extends StatefulWidget {
  const SubjectRegistrationScreen({super.key});

  @override
  State<SubjectRegistrationScreen> createState() =>
      _SubjectRegistrationScreenState();
}

class _SubjectRegistrationScreenState extends State<SubjectRegistrationScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final StudentCourseService _courseService = StudentCourseService();

  // Student info
  String _studentId = '';
  int _studentYear = 1;
  String _studentSemester = 'I';
  String _studentDepartment = '';
  String _studentName = '';
  String _studentBatch = ''; // e.g., 'CSE-A'

  // Subject data
  List<Subject> _coreSubjects = [];
  List<Subject> _oeSubjects = [];
  List<Subject> _peSubjects = [];

  // Lightweight caches to avoid repeated list scans during rebuilds
  Map<String, int> _oeCreditsById = {};
  Map<String, int> _peCreditsById = {};
  int _coreCredits = 0;
  int _totalCredits = 0;

  // Selection state
  Set<String> _selectedOEIds = {};
  Set<String> _selectedPEIds = {};

  // Faculty assignments map: subjectCode -> facultyName
  Map<String, String> _facultyMap = {};

  // Requirements (loaded from database)
  int _requiredOECount = 0;
  int _requiredPECount = 0;

  // History future for Status tab
  Future<QuerySnapshot>? _historyFuture;

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isSubmitted = false;
  bool _isRegistrationOpen =
      false; // Whether registration is open for student's year
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadStudentDataAndSubjects();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadStudentDataAndSubjects() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('No user logged in');
      }

      final email = user.email ?? '';
      var hallTicketNumber = UserService.getCurrentUserId();
      if (hallTicketNumber == null || hallTicketNumber.isEmpty) {
        hallTicketNumber = email.split('@')[0].toUpperCase();
      }

      if (hallTicketNumber.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('User information not found'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isLoading = false);
        return;
      }

      final studentDoc = await FirebaseFirestore.instance
          .collection('students')
          .doc(hallTicketNumber)
          .get();

      if (!studentDoc.exists) {
        throw Exception(
            'Student profile not found. Please complete your profile first.');
      }

      final studentData = studentDoc.data()!;
      _studentId = hallTicketNumber;
      _studentName = studentData['studentName'] ?? '';
      _studentYear = int.tryParse(studentData['year']?.toString() ?? '1') ?? 1;
      _studentDepartment = studentData['department']?.toString() ?? 'CSE';

      final batchNumber = studentData['batchNumber']?.toString() ?? '';
      final section = studentData['section']?.toString() ?? batchNumber;
      _studentBatch = section.isNotEmpty
          ? '$_studentDepartment-$section'
          : _studentDepartment;

      final semesterInt =
          int.tryParse(studentData['semester']?.toString() ?? '1') ?? 1;
      _studentSemester = semesterInt == 1 ? 'I' : 'II';

      await _loadSubjects();

      final semesterNumber = _studentSemester == 'I' ? '1' : '2';

      final loadRequirementsFuture = _loadRequirements();
      final loadFacultyAssignmentsFuture = _loadFacultyAssignments();
      final loadExistingSelectionsFuture = _loadExistingSelections();
      final autoRegisterCoreFuture = _autoRegisterCoreSubjects();
      final submittedFuture = _courseService.isRegistrationSubmitted(
        studentId: _studentId,
        year: _studentYear,
        semester: _studentSemester,
      );
      final registrationOpenFuture = _courseService.isRegistrationOpen(
        year: _studentYear.toString(),
        semester: semesterNumber,
        branch: _studentDepartment,
      );

      await Future.wait([
        loadRequirementsFuture,
        loadFacultyAssignmentsFuture,
        loadExistingSelectionsFuture,
        autoRegisterCoreFuture,
      ]);

      _isSubmitted = await submittedFuture;
      _isRegistrationOpen = await registrationOpenFuture;

      _historyFuture = FirebaseFirestore.instance
          .collection('studentSubjectSelections')
          .where('studentId', isEqualTo: _studentId)
          .get();

      if (!mounted) return;
      setState(() => _isLoading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Error: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadSubjects() async {
    final allSubjects = await _courseService.getSubjectsGroupedByType(
      year: _studentYear,
      semester: _studentSemester,
      department: _studentDepartment,
    );

    _coreSubjects = allSubjects[SubjectType.core] ?? [];
    _oeSubjects = allSubjects[SubjectType.oe] ?? [];
    _peSubjects = allSubjects[SubjectType.pe] ?? [];

    _oeCreditsById = {for (final s in _oeSubjects) s.id: s.credits};
    _peCreditsById = {for (final s in _peSubjects) s.id: s.credits};
    _coreCredits = _coreSubjects.fold(0, (sum, s) => sum + s.credits);
    _recomputeTotalCredits();
  }

  Future<void> _loadRequirements() async {
    final semesterNum = _studentSemester == 'I' ? '1' : '2';
    final requirement = await _courseService.getCourseRequirement(
      _studentYear.toString(),
      _studentDepartment,
      semester: semesterNum,
    );

    if (requirement != null) {
      _requiredOECount = requirement.oeCount;
      _requiredPECount = requirement.peCount;
      return;
    }

    _requiredOECount = 0;
    _requiredPECount = 0;
  }

  Future<void> _loadExistingSelections() async {
    final selections = await _courseService.getStudentElectiveSelections(
      studentId: _studentId,
      year: _studentYear,
      semester: _studentSemester,
    );

    _selectedOEIds = Set<String>.from(selections['OE'] ?? []);
    _selectedPEIds = Set<String>.from(selections['PE'] ?? []);
    _recomputeTotalCredits();
  }

  Future<void> _loadFacultyAssignments() async {
    final allSubjectCodes = <String>[];
    for (final subject in _coreSubjects) {
      allSubjectCodes.add(subject.code);
    }
    for (final subject in _oeSubjects) {
      allSubjectCodes.add(subject.code);
    }
    for (final subject in _peSubjects) {
      allSubjectCodes.add(subject.code);
    }

    if (allSubjectCodes.isEmpty) {
      _facultyMap = {};
      return;
    }

    _facultyMap = await _courseService.getFacultyMapForSubjects(
      subjectCodes: allSubjectCodes,
      year: _studentYear,
      studentBatch: _studentBatch,
    );
  }

  void _recomputeTotalCredits() {
    final oeCredits =
        _selectedOEIds.fold(0, (sum, id) => sum + (_oeCreditsById[id] ?? 0));
    final peCredits =
        _selectedPEIds.fold(0, (sum, id) => sum + (_peCreditsById[id] ?? 0));
    _totalCredits = _coreCredits + oeCredits + peCredits;
  }

  Future<void> _autoRegisterCoreSubjects() async {
    if (_coreSubjects.isEmpty) return;

    await _courseService.autoRegisterCoreSubjects(
      studentId: _studentId,
      studentName: _studentName,
      year: _studentYear,
      semester: _studentSemester,
      department: _studentDepartment,
      coreSubjectIds: _coreSubjects.map((s) => s.id).toList(),
      coreSubjectCodes: _coreSubjects.map((s) => s.code).toList(),
    );
  }

  Future<void> _saveSelections() async {
    if (!_isRegistrationOpen) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Registration is not currently open for your year.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      await _courseService.saveCompleteRegistration(
        studentId: _studentId,
        studentName: _studentName,
        year: _studentYear,
        semester: _studentSemester,
        department: _studentDepartment,
        coreSubjectIds: _coreSubjects.map((s) => s.id).toList(),
        coreSubjectCodes: _coreSubjects.map((s) => s.code).toList(),
        selectedOEIds: _selectedOEIds.toList(),
        selectedPEIds: _selectedPEIds.toList(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isSubmitted
                ? 'Changes saved. Your submitted registration has been updated.'
                : 'Selections saved successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Future<void> _submitRegistration() async {
    // Check if registration is open for this year
    if (!_isRegistrationOpen) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Registration is not currently open for your year.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Validate selections
    if (_selectedOEIds.length < _requiredOECount) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('Please select at least $_requiredOECount Open Elective(s)'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_selectedPEIds.length < _requiredPECount) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Please select at least $_requiredPECount Programme Elective(s)'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Confirm dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Submit Registration?'),
        content: Text(
          _isSubmitted
              ? 'Your registration has already been submitted. Submitting again will save your latest changes. You can continue editing until the registration window closes.\n\nDo you want to update your submission?'
              : 'Once submitted, your choices will be recorded, but you can still modify them until the registration window closes.\n\nAre you sure you want to submit?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1e3a5f),
              foregroundColor: Colors.white,
            ),
            child: const Text('Submit'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isSaving = true);

    try {
      final wasAlreadySubmitted = _isSubmitted;

      // Save first
      await _courseService.saveCompleteRegistration(
        studentId: _studentId,
        studentName: _studentName,
        year: _studentYear,
        semester: _studentSemester,
        department: _studentDepartment,
        coreSubjectIds: _coreSubjects.map((s) => s.id).toList(),
        coreSubjectCodes: _coreSubjects.map((s) => s.code).toList(),
        selectedOEIds: _selectedOEIds.toList(),
        selectedPEIds: _selectedPEIds.toList(),
      );

      // Then submit
      await _courseService.submitSubjectRegistration(
        studentId: _studentId,
        year: _studentYear,
        semester: _studentSemester,
      );

      setState(() {
        _isSubmitted = true;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(wasAlreadySubmitted
                ? 'Registration updated successfully!'
                : 'Registration submitted successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error submitting: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Subject Registration'),
        backgroundColor: const Color(0xFF1e3a5f),
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.yellow,
          tabs: [
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lock, size: 16),
                  const SizedBox(width: 4),
                  Text('Core (${_coreSubjects.length})'),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('OE (${_selectedOEIds.length}/${_oeSubjects.length})'),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('PE (${_selectedPEIds.length}/${_peSubjects.length})'),
                ],
              ),
            ),
            const Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.assignment_turned_in, size: 16),
                  SizedBox(width: 4),
                  Text('Status'),
                ],
              ),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? _buildErrorView()
              : Column(
                  children: [
                    // Student info bar
                    _buildStudentInfoBar(isMobile),

                    // Registration closed banner
                    if (!_isRegistrationOpen) _buildRegistrationClosedBanner(),

                    // Status bar
                    if (_isSubmitted) _buildSubmittedBanner(),

                    // Tab content
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildCoreSubjectsTab(isMobile),
                          _buildElectiveTab(
                            subjects: _oeSubjects,
                            selectedIds: _selectedOEIds,
                            type: 'OE',
                            typeName: 'Open Elective',
                            requiredCount: _requiredOECount,
                            isMobile: isMobile,
                          ),
                          _buildElectiveTab(
                            subjects: _peSubjects,
                            selectedIds: _selectedPEIds,
                            type: 'PE',
                            typeName: 'Programme Elective',
                            requiredCount: _requiredPECount,
                            isMobile: isMobile,
                          ),
                          _buildStatusTab(isMobile),
                        ],
                      ),
                    ),
                  ],
                ),
      bottomNavigationBar: _isLoading || _errorMessage != null
          ? null
          : _buildBottomBar(isMobile),
    );
  }

  // ── Status Tab ──────────────────────────────────────────────────────────

  Widget _buildStatusTab(bool isMobile) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStatusSummaryCard(),
          const SizedBox(height: 16),
          _buildCurrentRegistrationTable(isMobile),
          const SizedBox(height: 24),
          _buildSubjectHistory(isMobile),
        ],
      ),
    );
  }

  Widget _buildStatusSummaryCard() {
    final String statusLabel;
    final Color statusColor;
    final IconData statusIcon;

    if (_isSubmitted && !_isRegistrationOpen) {
      statusLabel = 'Submitted';
      statusColor = Colors.green;
      statusIcon = Icons.verified;
    } else if (_isSubmitted && _isRegistrationOpen) {
      statusLabel = 'Submitted (Editable)';
      statusColor = Colors.blue;
      statusIcon = Icons.edit_note;
    } else if (_selectedOEIds.isNotEmpty || _selectedPEIds.isNotEmpty) {
      statusLabel = 'Draft';
      statusColor = Colors.orange;
      statusIcon = Icons.edit;
    } else {
      statusLabel = 'Not Started';
      statusColor = Colors.grey;
      statusIcon = Icons.radio_button_unchecked;
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF1e3a5f),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                const Icon(Icons.assignment, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Current Registration',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.2),
                    border: Border.all(color: statusColor),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 13, color: statusColor),
                      const SizedBox(width: 4),
                      Text(
                        statusLabel,
                        style: TextStyle(
                            color: statusColor,
                            fontSize: 12,
                            fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Colors.white24),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Wrap(
              spacing: 24,
              runSpacing: 10,
              children: [
                _statusInfoChip('Name', _studentName),
                _statusInfoChip('Year', '$_studentYear'),
                _statusInfoChip('Semester', _studentSemester),
                _statusInfoChip('Branch', _studentDepartment),
                _statusInfoChip(
                  'Registration',
                  _isRegistrationOpen ? 'Open' : 'Closed',
                  valueColor: _isRegistrationOpen
                      ? Colors.greenAccent
                      : Colors.redAccent,
                ),
                _statusInfoChip(
                  'Total Credits',
                  '$_totalCredits',
                  valueColor: Colors.yellow,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusInfoChip(String label, String value,
      {Color valueColor = Colors.yellow}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 10, color: Colors.white60)),
        const SizedBox(height: 2),
        Text(value,
            style: TextStyle(
                fontSize: 13,
                color: valueColor,
                fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildCurrentRegistrationTable(bool isMobile) {
    final rows = <Map<String, dynamic>>[];
    for (final s in _coreSubjects) {
      rows.add({
        'subject': s,
        'type': 'Core',
        'bg': Colors.indigo.shade50,
        'fg': Colors.indigo.shade700,
      });
    }
    for (final s in _oeSubjects.where((s) => _selectedOEIds.contains(s.id))) {
      rows.add({
        'subject': s,
        'type': 'OE',
        'bg': Colors.purple.shade50,
        'fg': Colors.purple.shade700,
      });
    }
    for (final s in _peSubjects.where((s) => _selectedPEIds.contains(s.id))) {
      rows.add({
        'subject': s,
        'type': 'PE',
        'bg': Colors.teal.shade50,
        'fg': Colors.teal.shade700,
      });
    }

    if (rows.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 32),
        alignment: Alignment.center,
        child: Column(
          children: [
            Icon(Icons.inbox_outlined, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 12),
            const Text('No subjects registered yet',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('Go to Core / OE / PE tabs to register.',
                style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFF1e3a5f),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(7),
                topRight: Radius.circular(7),
              ),
            ),
            child: Text(
              'Registered Subjects  (${rows.length})',
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13),
            ),
          ),
          Container(
            color: Colors.grey[100],
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                const SizedBox(
                    width: 28,
                    child: Text('#',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1e3a5f)))),
                const Expanded(
                    flex: 2,
                    child: Text('Code',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1e3a5f)))),
                const Expanded(
                    flex: 5,
                    child: Text('Subject Name',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1e3a5f)))),
                if (!isMobile)
                  const Expanded(
                      flex: 2,
                      child: Text('Type',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1e3a5f)))),
                if (!isMobile)
                  const Expanded(
                      flex: 2,
                      child: Text('Credits',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1e3a5f)))),
                const Expanded(
                    flex: 2,
                    child: Text('Status',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1e3a5f)))),
              ],
            ),
          ),
          const Divider(height: 1),
          ...List.generate(rows.length, (idx) {
            final row = rows[idx];
            final Subject subj = row['subject'] as Subject;
            final String type = row['type'] as String;
            final Color bg = row['bg'] as Color;
            final Color fg = row['fg'] as Color;
            final isEven = idx % 2 == 0;
            return Container(
              color: isEven ? Colors.white : Colors.grey[50],
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  SizedBox(
                      width: 28,
                      child: Text('${idx + 1}',
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey[600]))),
                  Expanded(
                      flex: 2,
                      child: Text(subj.code,
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600))),
                  Expanded(
                    flex: 5,
                    child: Text(subj.name,
                        style: const TextStyle(fontSize: 12),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                  ),
                  if (!isMobile)
                    Expanded(
                      flex: 2,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: bg,
                          border: Border.all(color: fg),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(type,
                            style: TextStyle(
                                fontSize: 10,
                                color: fg,
                                fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center),
                      ),
                    ),
                  if (!isMobile)
                    Expanded(
                        flex: 2,
                        child: Text('${subj.credits}',
                            style: const TextStyle(fontSize: 12))),
                  Expanded(
                    flex: 2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        border: Border.all(color: Colors.green.shade300),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text('Registered',
                          style: TextStyle(
                              fontSize: 10,
                              color: Colors.green.shade800,
                              fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildSubjectHistory(bool isMobile) {
    if (_historyFuture == null) return const SizedBox.shrink();
    return FutureBuilder<QuerySnapshot>(
      future: _historyFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data?.docs ?? [];
        final currentDocId =
            '${_studentId}_${_studentYear}_$_studentSemester';
        final historyDocs =
            docs.where((d) => d.id != currentDocId).toList();
        if (historyDocs.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Icon(Icons.history, size: 18, color: Color(0xFF1e3a5f)),
                  SizedBox(width: 8),
                  Text(
                    'Previous Registrations',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1e3a5f)),
                  ),
                ],
              ),
            ),
            ...historyDocs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final docYear = data['year']?.toString() ?? '';
              final docSem = data['semester']?.toString() ?? '';
              final docDept = data['department']?.toString() ?? '';
              final docSubmitted = data['isSubmitted'] == true;

              final coreIds =
                  List<String>.from(data['coreSubjectIds'] ?? []);
              final coreCodes =
                  List<String>.from(data['coreSubjectCodes'] ?? []);
              final oeIds =
                  List<String>.from(data['selectedOEIds'] ?? []);
              final peIds =
                  List<String>.from(data['selectedPEIds'] ?? []);

              final allEntries = [
                ...coreIds.asMap().entries.map((e) => {
                      'id': e.value,
                      'code':
                          e.key < coreCodes.length ? coreCodes[e.key] : '',
                      'type': 'Core',
                    }),
                ...oeIds.map(
                    (id) => {'id': id, 'code': '', 'type': 'OE'}),
                ...peIds.map(
                    (id) => {'id': id, 'code': '', 'type': 'PE'}),
              ];

              final titleParts = [
                if (docYear.isNotEmpty) 'Year $docYear',
                if (docDept.isNotEmpty) docDept,
                if (docSem.isNotEmpty) 'Sem $docSem',
              ];

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(color: Colors.grey.shade300),
                ),
                child: ExpansionTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1e3a5f).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(Icons.history_edu,
                        color: Color(0xFF1e3a5f), size: 18),
                  ),
                  title: Text(
                    titleParts.isEmpty
                        ? 'Previous Registration'
                        : titleParts.join('  |  '),
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: docSubmitted
                                ? Colors.green.shade50
                                : Colors.orange.shade50,
                            border: Border.all(
                              color: docSubmitted
                                  ? Colors.green.shade300
                                  : Colors.orange.shade300,
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            docSubmitted ? 'Submitted' : 'Draft',
                            style: TextStyle(
                              fontSize: 10,
                              color: docSubmitted
                                  ? Colors.green.shade700
                                  : Colors.orange.shade700,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text('${allEntries.length} subject(s)',
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey[600])),
                      ],
                    ),
                  ),
                  childrenPadding:
                      const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  children: allEntries.isEmpty
                      ? [
                          Padding(
                            padding: const EdgeInsets.all(8),
                            child: Text('No subjects recorded.',
                                style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 12)),
                          )
                        ]
                      : [
                          Container(
                            margin: const EdgeInsets.only(top: 8),
                            color: Colors.grey[100],
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 6),
                            child: const Row(
                              children: [
                                SizedBox(
                                    width: 28,
                                    child: Text('#',
                                        style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF1e3a5f)))),
                                Expanded(
                                    flex: 3,
                                    child: Text('Code',
                                        style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF1e3a5f)))),
                                Expanded(
                                    flex: 4,
                                    child: Text('Subject Name',
                                        style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF1e3a5f)))),
                                Expanded(
                                    flex: 2,
                                    child: Text('Type',
                                        style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF1e3a5f)))),
                              ],
                            ),
                          ),
                          const Divider(height: 1),
                          ...List.generate(allEntries.length, (idx) {
                            final entry = allEntries[idx];
                            final String subjectId = entry['id']!;
                            final String prefetchCode = entry['code']!;
                            final String subjectType = entry['type']!;
                            final Map<String, Color> bgMap = {
                              'Core': Colors.indigo.shade50,
                              'OE': Colors.purple.shade50,
                              'PE': Colors.teal.shade50,
                            };
                            final Map<String, Color> fgMap = {
                              'Core': Colors.indigo.shade700,
                              'OE': Colors.purple.shade700,
                              'PE': Colors.teal.shade700,
                            };
                            final bg = bgMap[subjectType] ??
                                Colors.grey.shade50;
                            final fg = fgMap[subjectType] ??
                                Colors.grey.shade700;
                            final isEven = idx % 2 == 0;
                            return FutureBuilder<DocumentSnapshot>(
                              future: FirebaseFirestore.instance
                                  .collection('subjects')
                                  .doc(subjectId)
                                  .get(),
                              builder: (ctx, cs) {
                                final sData = cs.data?.exists == true
                                    ? cs.data!.data()
                                        as Map<String, dynamic>?
                                    : null;
                                final name = sData?['subjectName'] ??
                                    sData?['name'] ??
                                    subjectId;
                                final code = sData?['subjectCode'] ??
                                    sData?['code'] ??
                                    prefetchCode;
                                return Container(
                                  color: isEven
                                      ? Colors.white
                                      : Colors.grey[50],
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 8),
                                  child: Row(
                                    children: [
                                      SizedBox(
                                          width: 28,
                                          child: Text('${idx + 1}',
                                              style: TextStyle(
                                                  fontSize: 12,
                                                  color:
                                                      Colors.grey[600]))),
                                      Expanded(
                                          flex: 3,
                                          child: Text(
                                              code.toString(),
                                              style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight:
                                                      FontWeight.w600))),
                                      Expanded(
                                        flex: 4,
                                        child: Text(
                                            name.toString(),
                                            style: const TextStyle(
                                                fontSize: 12),
                                            maxLines: 2,
                                            overflow:
                                                TextOverflow.ellipsis),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Container(
                                          padding: const EdgeInsets
                                              .symmetric(
                                              horizontal: 6,
                                              vertical: 3),
                                          decoration: BoxDecoration(
                                            color: bg,
                                            border:
                                                Border.all(color: fg),
                                            borderRadius:
                                                BorderRadius.circular(
                                                    12),
                                          ),
                                          child: Text(subjectType,
                                              style: TextStyle(
                                                  fontSize: 10,
                                                  color: fg,
                                                  fontWeight:
                                                      FontWeight.bold),
                                              textAlign:
                                                  TextAlign.center),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            );
                          }),
                        ],
                ),
              );
            }),
          ],
        );
      },
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              _errorMessage ?? 'An error occurred',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadStudentDataAndSubjects,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentInfoBar(bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      color: Colors.grey.shade100,
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: const Color(0xFF1e3a5f),
            child: Text(
              _studentName.isNotEmpty ? _studentName[0].toUpperCase() : 'S',
              style: const TextStyle(color: Colors.white),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _studentName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  'Year $_studentYear • Semester $_studentSemester • $_studentDepartment',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF1e3a5f).withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Total: ${_calculateTotalCredits()} credits',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF1e3a5f),
              ),
            ),
          ),
        ],
      ),
    );
  }

  int _calculateTotalCredits() {
    return _totalCredits;
  }

  Widget _buildSubmittedBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      color: _isRegistrationOpen ? Colors.blue.shade100 : Colors.green.shade100,
      child: Row(
        children: [
          Icon(
            _isRegistrationOpen ? Icons.edit_note : Icons.check_circle,
            color: _isRegistrationOpen
                ? Colors.blue.shade700
                : Colors.green.shade700,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _isRegistrationOpen
                  ? 'Registration submitted. You can still edit and resubmit until the registration window closes.'
                  : 'Registration submitted. The registration window is closed, so your selections are now locked.',
              style: TextStyle(
                color: _isRegistrationOpen
                    ? Colors.blue.shade700
                    : Colors.green.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRegistrationClosedBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      color: Colors.red.shade100,
      child: Row(
        children: [
          Icon(Icons.lock_clock, color: Colors.red.shade700),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Registration is not currently open for Year $_studentYear students',
              style: TextStyle(
                color: Colors.red.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoreSubjectsTab(bool isMobile) {
    if (_coreSubjects.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.info_outline, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            const Text(
              'No Core subjects available for your current semester',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      children: [
        // Info card
        Container(
          padding: const EdgeInsets.all(12),
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue.shade200),
          ),
          child: Row(
            children: [
              Icon(Icons.info, color: Colors.blue.shade700),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Core subjects are mandatory and auto-assigned to you.',
                  style: TextStyle(color: Colors.blue.shade700),
                ),
              ),
            ],
          ),
        ),

        // Subject list
        ..._coreSubjects.map((subject) => _buildSubjectCard(
              subject: subject,
              isSelected: true,
              isReadOnly: true,
              isDisabled: false,
              isMobile: isMobile,
            )),
      ],
    );
  }

  void _showSelectionLimitMessage(String typeName, int requiredCount) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          requiredCount > 0
              ? 'You can select only $requiredCount $typeName subject(s). Deselect one to choose another.'
              : 'No $typeName subjects are required for your current semester.',
        ),
        backgroundColor: Colors.orange,
      ),
    );
  }

  Widget _buildElectiveTab({
    required List<Subject> subjects,
    required Set<String> selectedIds,
    required String type,
    required String typeName,
    required int requiredCount,
    required bool isMobile,
  }) {
    if (subjects.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.info_outline, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              'No $typeName subjects available for your current semester',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    final hasReachedLimit = selectedIds.length >= requiredCount;

    return ListView(
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      children: [
        // Selection progress card
        Container(
          padding: const EdgeInsets.all(12),
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: selectedIds.length >= requiredCount
                ? Colors.green.shade50
                : Colors.orange.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selectedIds.length >= requiredCount
                  ? Colors.green.shade200
                  : Colors.orange.shade200,
            ),
          ),
          child: Row(
            children: [
              Icon(
                selectedIds.length >= requiredCount
                    ? Icons.check_circle
                    : Icons.pending,
                color: selectedIds.length >= requiredCount
                    ? Colors.green.shade700
                    : Colors.orange.shade700,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Selected: ${selectedIds.length} / Required: $requiredCount',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: selectedIds.length >= requiredCount
                        ? Colors.green.shade700
                        : Colors.orange.shade700,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (hasReachedLimit)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.block, size: 18, color: Colors.blue.shade700),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    requiredCount > 0
                        ? 'Required $typeName count reached. Unselected subjects are blocked until you deselect one.'
                        : 'No $typeName subjects are required, so new selections are blocked.',
                    style: TextStyle(
                      color: Colors.blue.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),

        // Subject list
        ...subjects.map((subject) {
          final isSelected = selectedIds.contains(subject.id);
          final isSelectionBlocked =
              _isRegistrationOpen && !isSelected && hasReachedLimit;

          return _buildSubjectCard(
            subject: subject,
            isSelected: isSelected,
            isReadOnly: !_isRegistrationOpen,
            isDisabled: isSelectionBlocked,
            isMobile: isMobile,
            onTap: !_isRegistrationOpen
                ? null
                : isSelectionBlocked
                    ? () => _showSelectionLimitMessage(typeName, requiredCount)
                    : () {
                        setState(() {
                          if (type == 'OE') {
                            if (_selectedOEIds.contains(subject.id)) {
                              _selectedOEIds.remove(subject.id);
                            } else {
                              _selectedOEIds.add(subject.id);
                            }
                          } else {
                            if (_selectedPEIds.contains(subject.id)) {
                              _selectedPEIds.remove(subject.id);
                            } else {
                              _selectedPEIds.add(subject.id);
                            }
                          }
                          _recomputeTotalCredits();
                        });
                      },
          );
        }),
      ],
    );
  }

  Widget _buildSubjectCard({
    required Subject subject,
    required bool isSelected,
    required bool isReadOnly,
    required bool isDisabled,
    required bool isMobile,
    VoidCallback? onTap,
  }) {
    return Opacity(
      opacity: isDisabled ? 0.55 : 1,
      child: Card(
        margin: const EdgeInsets.only(bottom: 8),
        elevation: isSelected ? 2 : 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: isSelected
                ? const Color(0xFF1e3a5f)
                : isDisabled
                    ? Colors.grey.shade300
                    : Colors.transparent,
            width: 2,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Subject code avatar
                CircleAvatar(
                  backgroundColor: isSelected
                      ? const Color(0xFF1e3a5f)
                      : Colors.grey.shade200,
                  child: Text(
                    subject.code.isNotEmpty
                        ? subject.code.substring(
                            0,
                            subject.code.length > 2 ? 2 : subject.code.length,
                          )
                        : 'SB',
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.grey.shade600,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Subject info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        subject.name,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: isSelected ? const Color(0xFF1e3a5f) : null,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${subject.code} • ${subject.department} • ${subject.credits} Credits',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      if (isDisabled) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Blocked until you deselect another subject',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.orange.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                      // Show faculty name if assigned
                      if (_facultyMap.containsKey(subject.code)) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.person,
                                size: 14, color: Colors.green.shade700),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                'Faculty: ${_facultyMap[subject.code]}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.green.shade700,
                                  fontWeight: FontWeight.w500,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

                // Selection indicator
                if (isReadOnly && isSelected)
                  const Icon(Icons.lock, color: Colors.grey)
                else if (isDisabled)
                  Icon(Icons.block, color: Colors.orange.shade700)
                else if (isSelected)
                  const Icon(Icons.check_circle, color: Color(0xFF1e3a5f))
                else
                  Icon(Icons.radio_button_unchecked,
                      color: Colors.grey.shade400),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar(bool isMobile) {
    final isDisabled = _isSaving || !_isRegistrationOpen;

    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: isDisabled ? null : _saveSelections,
                icon: _isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save),
                label: Text(_isSubmitted ? 'Save Changes' : 'Save Draft'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: isDisabled ? null : _submitRegistration,
                icon: const Icon(Icons.send),
                label: Text(_isSubmitted ? 'Update Submission' : 'Submit'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1e3a5f),
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
