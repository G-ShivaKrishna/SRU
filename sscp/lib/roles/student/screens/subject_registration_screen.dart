import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../models/faculty_assignment_model.dart';
import '../../../services/student_course_service.dart';
import '../../../widgets/app_header.dart';

/// Subject Registration Screen
/// 
/// This screen shows:
/// 1. Core subjects (auto-assigned by admin) - Read only
/// 2. OE (Open Elective) - Student selectable
/// 3. PE (Programme Elective) - Student selectable
class SubjectRegistrationScreen extends StatefulWidget {
  const SubjectRegistrationScreen({super.key});

  @override
  State<SubjectRegistrationScreen> createState() => _SubjectRegistrationScreenState();
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

  // Selection state
  Set<String> _selectedOEIds = {};
  Set<String> _selectedPEIds = {};

  // Faculty assignments map: subjectCode -> facultyName
  Map<String, String> _facultyMap = {};

  // Requirements
  int _requiredOECount = 1;
  int _requiredPECount = 1;

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isSubmitted = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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

      // Extract hall ticket number from Firebase email
      final email = user.email ?? '';
      final hallTicketNumber = email.split('@')[0].toUpperCase();

      // Fetch student data
      final studentDoc = await FirebaseFirestore.instance
          .collection('students')
          .doc(hallTicketNumber)
          .get();

      if (!studentDoc.exists) {
        throw Exception('Student profile not found. Please complete your profile first.');
      }

      final studentData = studentDoc.data()!;
      _studentId = hallTicketNumber;
      _studentName = studentData['studentName'] ?? '';
      _studentYear = int.tryParse(studentData['year']?.toString() ?? '1') ?? 1;
      _studentDepartment = studentData['department']?.toString() ?? 'CSE';
      
      // Construct batch identifier (e.g., 'CSE-A') from department and batchNumber/section
      final batchNumber = studentData['batchNumber']?.toString() ?? '';
      final section = studentData['section']?.toString() ?? batchNumber;
      _studentBatch = section.isNotEmpty ? '$_studentDepartment-$section' : _studentDepartment;
      
      // Determine current semester (can be made dynamic later)
      // For now, assuming odd year = Sem I, even year = Sem II
      _studentSemester = 'I'; // Can be fetched from settings

      // Load subjects
      await _loadSubjects();

      // Load faculty assignments for all subjects
      await _loadFacultyAssignments();

      // Load existing selections
      await _loadExistingSelections();

      // Auto-register Core subjects
      await _autoRegisterCoreSubjects();

      // Check if submitted
      _isSubmitted = await _courseService.isRegistrationSubmitted(
        studentId: _studentId,
        year: _studentYear,
        semester: _studentSemester,
      );

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
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

    setState(() {
      _coreSubjects = allSubjects[SubjectType.core] ?? [];
      _oeSubjects = allSubjects[SubjectType.oe] ?? [];
      _peSubjects = allSubjects[SubjectType.pe] ?? [];
    });
  }

  Future<void> _loadExistingSelections() async {
    final selections = await _courseService.getStudentElectiveSelections(
      studentId: _studentId,
      year: _studentYear,
      semester: _studentSemester,
    );

    setState(() {
      _selectedOEIds = Set<String>.from(selections['OE'] ?? []);
      _selectedPEIds = Set<String>.from(selections['PE'] ?? []);
    });
  }

  Future<void> _loadFacultyAssignments() async {
    // Collect all subject codes
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

    if (allSubjectCodes.isEmpty) return;

    final facultyMap = await _courseService.getFacultyMapForSubjects(
      subjectCodes: allSubjectCodes,
      year: _studentYear,
      studentBatch: _studentBatch,
    );

    setState(() {
      _facultyMap = facultyMap;
    });
  }

  Future<void> _autoRegisterCoreSubjects() async {
    if (_coreSubjects.isEmpty) return;

    // Auto-register core subjects for this student
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
    if (_isSubmitted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Your registration is already submitted and locked.'),
          backgroundColor: Colors.orange,
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
          const SnackBar(
            content: Text('Selections saved successfully'),
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
    // Validate selections
    if (_selectedOEIds.length < _requiredOECount) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please select at least $_requiredOECount Open Elective(s)'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_selectedPEIds.length < _requiredPECount) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please select at least $_requiredPECount Programme Elective(s)'),
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
        content: const Text(
          'Once submitted, you cannot modify your selections unless the admin unlocks it.\n\nAre you sure you want to submit?',
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
          const SnackBar(
            content: Text('Registration submitted successfully!'),
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
          // Total credits display
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
    int total = 0;
    
    // Core credits
    for (final subject in _coreSubjects) {
      total += subject.credits;
    }
    
    // Selected OE credits
    for (final id in _selectedOEIds) {
      final subject = _oeSubjects.firstWhere(
        (s) => s.id == id,
        orElse: () => Subject(
          id: '', code: '', name: '', department: '',
          credits: 0, year: 0, semester: '',
        ),
      );
      total += subject.credits;
    }
    
    // Selected PE credits
    for (final id in _selectedPEIds) {
      final subject = _peSubjects.firstWhere(
        (s) => s.id == id,
        orElse: () => Subject(
          id: '', code: '', name: '', department: '',
          credits: 0, year: 0, semester: '',
        ),
      );
      total += subject.credits;
    }
    
    return total;
  }

  Widget _buildSubmittedBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      color: Colors.green.shade100,
      child: Row(
        children: [
          Icon(Icons.check_circle, color: Colors.green.shade700),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Registration Submitted - Your selections are locked',
              style: TextStyle(
                color: Colors.green.shade700,
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
          isMobile: isMobile,
        )),
      ],
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
        
        // Subject list
        ...subjects.map((subject) => _buildSubjectCard(
          subject: subject,
          isSelected: selectedIds.contains(subject.id),
          isReadOnly: _isSubmitted,
          isMobile: isMobile,
          onTap: _isSubmitted
              ? null
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
                  });
                },
        )),
      ],
    );
  }

  Widget _buildSubjectCard({
    required Subject subject,
    required bool isSelected,
    required bool isReadOnly,
    required bool isMobile,
    VoidCallback? onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: isSelected ? 2 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: isSelected ? const Color(0xFF1e3a5f) : Colors.transparent,
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
                      ? subject.code.substring(0, subject.code.length > 2 ? 2 : subject.code.length)
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
                    // Show faculty name if assigned
                    if (_facultyMap.containsKey(subject.code)) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.person, size: 14, color: Colors.green.shade700),
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
              else if (isSelected)
                const Icon(Icons.check_circle, color: Color(0xFF1e3a5f))
              else
                Icon(Icons.radio_button_unchecked, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar(bool isMobile) {
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
                onPressed: _isSaving || _isSubmitted ? null : _saveSelections,
                icon: _isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save),
                label: const Text('Save Draft'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _isSaving || _isSubmitted ? null : _submitRegistration,
                icon: const Icon(Icons.send),
                label: const Text('Submit'),
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
