import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../services/faculty_scope_service.dart';
import '../../../widgets/app_header.dart';

// ─── Data model ───────────────────────────────────────────────────────────────

class _Assignment {
  final String docId;
  final String subjectCode;
  final String subjectName;
  final List<String> assignedBatches;
  final String department;
  final int year;
  final String semester;
  final String subjectType;

  const _Assignment({
    required this.docId,
    required this.subjectCode,
    required this.subjectName,
    required this.assignedBatches,
    required this.department,
    required this.year,
    required this.semester,
    required this.subjectType,
  });

  factory _Assignment.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return _Assignment(
      docId: doc.id,
      subjectCode: d['subjectCode'] ?? '',
      subjectName: d['subjectName'] ?? '',
      assignedBatches: List<String>.from(d['assignedBatches'] ?? []),
      department: d['department'] ?? '',
      year: (d['year'] is int)
          ? d['year']
          : int.tryParse(d['year'].toString()) ?? 1,
      semester: d['semester'] ?? '',
      subjectType: d['subjectType'] ?? 'Theory',
    );
  }

  String get displayLabel =>
      '${subjectName.isNotEmpty ? subjectName : subjectCode}'
      '${subjectCode.isNotEmpty ? ' - $subjectCode' : ''}';
}

// ─── Period time-slot labels ──────────────────────────────────────────────────

const List<String> _kPeriodLabels = [
  '09:00AM-\n10:00AM',
  '10:00AM-\n11:00AM',
  '11:00AM-\n12:00PM',
  '12:00PM-\n01:00PM',
  '01:00PM-\n02:00PM',
  '02:00PM-\n03:00PM',
  '03:00PM-\n04:00PM',
  '04:00PM-\n05:00PM',
  '05:00PM-\n06:00PM\n(Free Slot)',
];

// ─── Screen ───────────────────────────────────────────────────────────────────

class AttendanceEntryScreen extends StatefulWidget {
  const AttendanceEntryScreen({super.key});

  @override
  State<AttendanceEntryScreen> createState() => _AttendanceEntryScreenState();
}

class _AttendanceEntryScreenState extends State<AttendanceEntryScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _scopeService = FacultyScopeService();

  // ── Phase 1: selection ─────────────────────────────────────────────────────
  bool _loadingAssignments = true;
  String? _assignmentError;
  List<_Assignment> _assignments = [];
  _Assignment? _selectedAssignment;
  String? _selectedBatch; // null = all batches
  String? _facultyId;

  final DateTime _today = DateTime.now();

  // ── Phase 2: attendance form ───────────────────────────────────────────────
  bool _formVisible = false;
  bool _loadingStudents = false;

  String? _ltpType;
  final _topicCtrl = TextEditingController();
  String? _unitExpNo;
  final List<bool> _periodsSelected = List.filled(9, false);

  List<Map<String, dynamic>> _students = [];
  final Map<String, bool> _attendance = {};

  bool _submitting = false;

  /// Periods (1-9) already submitted by *other* faculties for the selected
  /// batch on today's date. These checkboxes are locked.
  Set<int> _lockedPeriods = {};
  bool _loadingLockedPeriods = false;

  // ── Init ───────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _loadAssignments();
  }

  @override
  void dispose() {
    _topicCtrl.dispose();
    super.dispose();
  }

  // ──────────────────────────────────────────────────────────────────────────

  Future<void> _loadAssignments() async {
    setState(() {
      _loadingAssignments = true;
      _assignmentError = null;
    });
    try {
      final facultyId = await _scopeService.resolveCurrentFacultyId();

      final snap = await _firestore
          .collection('facultyAssignments')
          .where('facultyId', isEqualTo: facultyId)
          .get();

      final list = <_Assignment>[];
      for (final doc in snap.docs) {
        if ((doc.data()['isActive'] ?? true) == true) {
          list.add(_Assignment.fromDoc(doc));
        }
      }
      setState(() {
        _facultyId = facultyId;
        _assignments = list;
        _loadingAssignments = false;
      });
    } catch (e) {
      setState(() {
        _assignmentError = e.toString();
        _loadingAssignments = false;
      });
    }
  }

  Future<void> _loadStudents() async {
    if (_selectedAssignment == null) return;
    setState(() => _loadingStudents = true);
    try {
      final batches = _selectedBatch != null
          ? [_selectedBatch!]
          : _selectedAssignment!.assignedBatches;
      final students = await _scopeService.loadStudentsForAssignment(
        department: _selectedAssignment!.department,
        year: _selectedAssignment!.year,
        assignedBatches: batches,
      );

      setState(() {
        _students = students;
        _attendance.clear();
        for (final s in students) {
          _attendance[s['rollNo']] = true;
        }
        _formVisible = true;
        _loadingStudents = false;
      });
      _fetchLockedPeriods(); // non-blocking – lock periods taken by other faculties
    } catch (e) {
      setState(() => _loadingStudents = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error loading students: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  /// Queries the `attendance` collection for today's date and the selected
  /// batches. Any period already recorded by a *different* faculty is added
  /// to [_lockedPeriods] so that its checkbox becomes disabled.
  Future<void> _fetchLockedPeriods() async {
    if (_selectedAssignment == null) return;
    try {
      setState(() => _loadingLockedPeriods = true);
      final myFacultyId =
          _facultyId ?? await _scopeService.resolveCurrentFacultyId();
      final dateStr = DateFormat('dd-MM-yyyy').format(_today);
      final batches = _selectedBatch != null
          ? [_selectedBatch!]
          : _selectedAssignment!.assignedBatches;
      final selectedBatchTokens = _buildBatchTokens(batches);

      final snap = await _firestore
          .collection('attendance')
          .where('dateStr', isEqualTo: dateStr)
          .get();

      final locked = <int>{};
      for (final doc in snap.docs) {
        final d = doc.data();
        final recordedBy = (d['facultyId'] as String? ?? '');
        if (recordedBy == myFacultyId) {
          continue;
        }
        if (!_matchesAssignmentScope(d, _selectedAssignment!)) {
          continue;
        }
        if (!_hasBatchOverlap(d['batches'], selectedBatchTokens)) {
          continue;
        }

        for (final p in (d['periods'] as List? ?? const [])) {
          final period = p is int ? p : int.tryParse(p.toString()) ?? 0;
          if (period >= 1 && period <= 9) {
            locked.add(period);
          }
        }
      }

      if (mounted) {
        setState(() {
          _lockedPeriods = locked;
          // Uncheck any period that has been locked after selection
          for (final p in locked) {
            if (p >= 1 && p <= 9) _periodsSelected[p - 1] = false;
          }
          _loadingLockedPeriods = false;
        });
      }
    } catch (_) {
      // Non-critical; fail silently and leave no periods locked
      if (mounted) setState(() => _loadingLockedPeriods = false);
    }
  }

  bool _matchesAssignmentScope(
      Map<String, dynamic> data, _Assignment assignment) {
    final assignmentDepartment = _normalize(assignment.department);
    final docDepartment = _normalize(data['department']?.toString() ?? '');
    if (assignmentDepartment.isNotEmpty &&
        docDepartment != assignmentDepartment) {
      return false;
    }

    if (assignment.year > 0 && _parseInt(data['year']) != assignment.year) {
      return false;
    }

    final assignmentSemester = _normalize(assignment.semester);
    final docSemester = _normalize(data['semester']?.toString() ?? '');
    if (assignmentSemester.isNotEmpty &&
        docSemester.isNotEmpty &&
        assignmentSemester != docSemester) {
      return false;
    }

    return true;
  }

  bool _hasBatchOverlap(dynamic rawBatches, Set<String> selectedBatchTokens) {
    if (selectedBatchTokens.isEmpty) {
      return false;
    }

    final docBatches = <String>[];
    if (rawBatches is List) {
      for (final value in rawBatches) {
        final batch = value?.toString() ?? '';
        if (batch.trim().isNotEmpty) {
          docBatches.add(batch);
        }
      }
    } else {
      final batch = rawBatches?.toString() ?? '';
      if (batch.trim().isNotEmpty) {
        docBatches.add(batch);
      }
    }

    final docBatchTokens = _buildBatchTokens(docBatches);
    return docBatchTokens.any(selectedBatchTokens.contains);
  }

  Set<String> _buildBatchTokens(Iterable<String> batches) {
    final tokens = <String>{};
    for (final batch in batches) {
      final trimmed = batch.trim();
      if (trimmed.isEmpty) {
        continue;
      }
      tokens.add(_normalize(trimmed));
      final parts = trimmed
          .split(RegExp(r'[-_/\\s]+'))
          .map(_normalize)
          .where((part) => part.isNotEmpty);
      tokens.addAll(parts);
    }
    return tokens;
  }

  String _normalize(String value) {
    return value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  int _parseInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.floor();
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  Future<void> _submitAttendance() async {
    final assignment = _selectedAssignment!;
    final periodsChosen = <int>[];
    for (var i = 0; i < _periodsSelected.length; i++) {
      if (_periodsSelected[i]) periodsChosen.add(i + 1);
    }
    if (periodsChosen.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Select at least one period.'),
            backgroundColor: Colors.orange),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      final facultyId =
          _facultyId ?? await _scopeService.resolveCurrentFacultyId();

      // Validate that assignment is still active before submitting attendance
      final assignDoc = await _firestore
          .collection('facultyAssignments')
          .doc(assignment.docId)
          .get();
      if (!assignDoc.exists ||
          (assignDoc.data()?['isActive'] ?? true) != true) {
        throw Exception(
            'This course is no longer active. Students may have been promoted. Please refresh the page.');
      }

      final dateStr = DateFormat('dd-MM-yyyy').format(_today);
      final batches = _selectedBatch != null
          ? [_selectedBatch!]
          : assignment.assignedBatches;

      final studentRecords = _students
          .map((s) => {
                'rollNo': s['rollNo'],
                'name': s['name'],
                'hallTicketNumber': s['hallTicketNumber'],
                'batchNumber': s['batchNumber'],
                'present': _attendance[s['rollNo']] ?? true,
              })
          .toList();

      await _firestore.collection('attendance').add({
        'dateStr': dateStr,
        'date':
            Timestamp.fromDate(DateTime(_today.year, _today.month, _today.day)),
        'facultyId': facultyId,
        'subjectCode': assignment.subjectCode,
        'subjectName': assignment.subjectName,
        'department': assignment.department,
        'year': assignment.year,
        'semester': assignment.semester,
        'batches': batches,
        'ltpType': _ltpType ?? '',
        'topicCovered': _topicCtrl.text.trim(),
        'unitExpNo': _unitExpNo ?? '',
        'periods': periodsChosen,
        'students': studentRecords,
        'totalStudents': _students.length,
        'presentCount':
            studentRecords.where((s) => s['present'] == true).length,
        'absentCount':
            studentRecords.where((s) => s['present'] == false).length,
        'submittedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Attendance submitted successfully!'),
              backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() => _submitting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          const AppHeader(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: _formVisible
                    ? _buildAttendanceForm()
                    : _buildSelectionForm(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Phase 1 ────────────────────────────────────────────────────────────────

  Widget _buildSelectionForm() {
    if (_loadingAssignments) {
      return const Padding(
        padding: EdgeInsets.all(64),
        child: CircularProgressIndicator(),
      );
    }
    if (_assignmentError != null) {
      return Column(children: [
        const Icon(Icons.error, color: Colors.red, size: 40),
        const SizedBox(height: 8),
        Text(_assignmentError!, style: const TextStyle(color: Colors.red)),
        TextButton(onPressed: _loadAssignments, child: const Text('Retry')),
      ]);
    }

    final batches = _selectedAssignment?.assignedBatches ?? [];

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 900),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Student Attendance Entry',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1e3a5f)),
          ),
          const SizedBox(height: 28),
          // Class & Course + Batch
          LayoutBuilder(builder: (ctx, cst) {
            final wide = cst.maxWidth > 580;
            final courseWidget = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Class & Course',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                DropdownButtonFormField<_Assignment>(
                  initialValue: _selectedAssignment,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  items: _assignments
                      .map((a) => DropdownMenuItem(
                            value: a,
                            child: Text(a.displayLabel,
                                overflow: TextOverflow.ellipsis),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() {
                    _selectedAssignment = v;
                    _selectedBatch = null;
                  }),
                ),
              ],
            );
            final batchWidget = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Batch (for Electives)',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: _selectedBatch,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  items: [
                    const DropdownMenuItem(
                        value: null, child: Text('All Batches')),
                    ...batches
                        .map((b) => DropdownMenuItem(value: b, child: Text(b))),
                  ],
                  onChanged: batches.isEmpty
                      ? null
                      : (v) => setState(() => _selectedBatch = v),
                ),
                const SizedBox(height: 4),
                const Text('(Batch 1 or 2.. Selection only for Labs)',
                    style: TextStyle(color: Colors.red, fontSize: 11)),
                const Text('(Select E1 or E2... for Subject Batches)',
                    style: TextStyle(color: Color(0xFF1565C0), fontSize: 11)),
              ],
            );
            return wide
                ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(child: courseWidget),
                    const SizedBox(width: 24),
                    Expanded(child: batchWidget),
                  ])
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                        courseWidget,
                        const SizedBox(height: 16),
                        batchWidget,
                      ]);
          }),
          const SizedBox(height: 20),
          // Date + Submit
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 420;
              final submitBtn = ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1565C0),
                  foregroundColor: Colors.white,
                  padding: compact
                      ? const EdgeInsets.symmetric(vertical: 12)
                      : const EdgeInsets.symmetric(
                          horizontal: 32, vertical: 14),
                ),
                onPressed: _selectedAssignment == null || _loadingStudents
                    ? null
                    : _loadStudents,
                child: _loadingStudents
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Text('Submit', style: TextStyle(fontSize: 15)),
              );

              final dateWidget = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Date of Entry',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Container(
                    width: compact ? double.infinity : null,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      border: Border.all(color: Colors.grey[400]!),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(DateFormat('dd/MM/yyyy').format(_today),
                        style: const TextStyle(fontSize: 14)),
                  ),
                ],
              );

              if (compact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    dateWidget,
                    const SizedBox(height: 12),
                    SizedBox(width: double.infinity, child: submitBtn),
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(child: dateWidget),
                  const SizedBox(width: 24),
                  submitBtn,
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  // ── Phase 2 ────────────────────────────────────────────────────────────────

  Widget _buildAttendanceForm() {
    final a = _selectedAssignment!;
    final batches =
        _selectedBatch != null ? [_selectedBatch!] : a.assignedBatches;
    final dateStr = DateFormat('dd-MM-yyyy').format(_today);
    final batchDisplay = batches.join('/ ');

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 1000),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Student Attendance Entry',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1e3a5f))),
          const SizedBox(height: 16),

          // Info box
          Center(
              child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 540),
            child: Container(
              decoration:
                  BoxDecoration(border: Border.all(color: Colors.grey[400]!)),
              child: Table(
                columnWidths: const {
                  0: IntrinsicColumnWidth(),
                  1: FlexColumnWidth()
                },
                children: [
                  _infoRow('Date of Entry :', dateStr),
                  _infoRow('Branch & Spl :', a.department),
                  _infoRow('Year-Sem/ Section/ Batch :',
                      '${a.year}-${a.semester}/ $batchDisplay'),
                  _infoRow('Course & Course Code :',
                      '${a.subjectName}  &  ${a.subjectCode}'),
                ],
              ),
            ),
          )),
          const SizedBox(height: 16),

          // L-T-P / Topic / Unit fields
          Center(
              child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: _buildFormFields(a),
          )),
          const SizedBox(height: 16),

          // Hours / Periods
          _buildHoursSection(),
          const SizedBox(height: 12),

          // Note banner
          Center(
              child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFFFC107),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              "Note : Remove the checkmarks absentee's numbers",
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          )),
          const SizedBox(height: 12),

          // Check / UnCheck
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 420;

              final checkAll = ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1565C0),
                    foregroundColor: Colors.white),
                onPressed: () => setState(() {
                  for (final k in _attendance.keys) {
                    _attendance[k] = true;
                  }
                }),
                child: const Text('Check all'),
              );

              final uncheckAll = ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red, foregroundColor: Colors.white),
                onPressed: () => setState(() {
                  for (final k in _attendance.keys) {
                    _attendance[k] = false;
                  }
                }),
                child: const Text('UnCheck all'),
              );

              if (compact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(width: double.infinity, child: checkAll),
                    const SizedBox(height: 8),
                    SizedBox(width: double.infinity, child: uncheckAll),
                  ],
                );
              }

              return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    checkAll,
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Text('|', style: TextStyle(fontSize: 18)),
                    ),
                    uncheckAll,
                  ]);
            },
          ),
          const SizedBox(height: 16),

          // Student table
          Center(child: _buildStudentTable()),
          const SizedBox(height: 20),

          // Submit
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 420;
              final btn = ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1e3a5f),
                  foregroundColor: Colors.white,
                  padding: compact
                      ? const EdgeInsets.symmetric(vertical: 12)
                      : const EdgeInsets.symmetric(
                          horizontal: 48, vertical: 14),
                ),
                onPressed: _submitting ? null : _submitAttendance,
                child: _submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Text('Submit Attendance',
                        style: TextStyle(fontSize: 15)),
              );

              if (compact) {
                return SizedBox(width: double.infinity, child: btn);
              }

              return Center(child: btn);
            },
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  TableRow _infoRow(String label, String value) {
    return TableRow(
      decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0xFFDDDDDD)))),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          child: Text(label,
              style: const TextStyle(fontSize: 12, color: Colors.black54)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          child: Text(value,
              style:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _buildFormFields(_Assignment a) {
    final isLab = a.subjectType.toLowerCase().contains('lab') ||
        a.subjectType.toLowerCase().contains('practical');
    final unitOptions = isLab
        ? List.generate(20, (i) => 'Exp ${i + 1}')
        : List.generate(10, (i) => 'Unit ${i + 1}');

    Widget buildInputRow({
      required bool compact,
      required String label,
      required Widget input,
    }) {
      if (compact) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            input,
          ],
        );
      }

      return Row(
        children: [
          SizedBox(
            width: 160,
            child: Text(label,
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          Expanded(child: input),
        ],
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 420;

        return Column(children: [
          buildInputRow(
            compact: compact,
            label: 'L-T-P Type',
            input: DropdownButtonFormField<String>(
              initialValue: _ltpType,
              isExpanded: true,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                isDense: true,
              ),
              items: const [
                DropdownMenuItem(value: 'Lecture', child: Text('Lecture')),
                DropdownMenuItem(value: 'Tutorial', child: Text('Tutorial')),
                DropdownMenuItem(value: 'Practical', child: Text('Practical')),
              ],
              onChanged: (v) => setState(() => _ltpType = v),
            ),
          ),
          const SizedBox(height: 10),
          buildInputRow(
            compact: compact,
            label: 'Topic Covered',
            input: TextFormField(
              controller: _topicCtrl,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                isDense: true,
              ),
            ),
          ),
          const SizedBox(height: 10),
          buildInputRow(
            compact: compact,
            label: isLab ? 'Exp No' : 'Unit/Exp No',
            input: DropdownButtonFormField<String>(
              initialValue: _unitExpNo,
              isExpanded: true,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                isDense: true,
              ),
              items: unitOptions
                  .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                  .toList(),
              onChanged: (v) => setState(() => _unitExpNo = v),
            ),
          ),
        ]);
      },
    );
  }

  Widget _buildHoursSection() {
    return Center(
        child: Column(children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('Hours',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          if (_loadingLockedPeriods) ...const [
            SizedBox(width: 10),
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ],
        ],
      ),
      const SizedBox(height: 8),
      ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 850),
        child: Container(
          decoration:
              BoxDecoration(border: Border.all(color: Colors.grey[400]!)),
          child: Table(
            border: TableBorder.all(color: Colors.grey[300]!),
            children: [
              // ── Header row: period labels ────────────────────────────────
              TableRow(
                children: List.generate(9, (i) {
                  final isLocked = _lockedPeriods.contains(i + 1);
                  return Container(
                    color: isLocked ? Colors.grey[200] : null,
                    padding:
                        const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                    child: Text(
                      _kPeriodLabels[i],
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 10,
                        color: isLocked ? Colors.grey[500] : Colors.black87,
                      ),
                    ),
                  );
                }),
              ),
              // ── Checkbox row ─────────────────────────────────────────────
              TableRow(
                children: List.generate(9, (i) {
                  final periodNum = i + 1;
                  final isLocked = _lockedPeriods.contains(periodNum);
                  if (isLocked) {
                    return Tooltip(
                      message:
                          'Period $periodNum already marked by another faculty',
                      child: Container(
                        color: Colors.grey[200],
                        child: const Center(
                          child: Checkbox(
                            value: true,
                            onChanged: null, // disabled – permanently checked
                            activeColor: Colors.grey,
                          ),
                        ),
                      ),
                    );
                  }
                  return Center(
                    child: Checkbox(
                      value: _periodsSelected[i],
                      activeColor: const Color(0xFF1565C0),
                      onChanged: (v) =>
                          setState(() => _periodsSelected[i] = v ?? false),
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
      ),
      if (_lockedPeriods.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline, size: 14, color: Colors.grey),
              const SizedBox(width: 4),
              Text(
                'Locked periods already marked by another faculty',
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
    ]));
  }

  Widget _buildStudentTable() {
    if (_students.isEmpty) {
      return const Text('No students found for the selected batch.',
          style: TextStyle(color: Colors.grey));
    }

    const hStyle = TextStyle(
        fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white);
    const dStyle = TextStyle(fontSize: 12, color: Colors.black87);

    Widget _headerText(String text) {
      return Text(
        text,
        style: hStyle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    Widget _dataText(String text, {TextAlign align = TextAlign.left}) {
      return Text(
        text,
        style: dStyle,
        textAlign: align,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 700;

        if (isCompact) {
          return Column(
            children: List.generate(_students.length, (i) {
              final s = _students[i];
              final roll = s['rollNo'] as String;
              final present = _attendance[roll] ?? true;

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: i % 2 == 0 ? Colors.white : const Color(0xFFF5F8FF),
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${i + 1}. ${(s['name'] ?? '').toString()}',
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 13),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Checkbox(
                          value: present,
                          activeColor: const Color(0xFF1565C0),
                          onChanged: (v) =>
                              setState(() => _attendance[roll] = v ?? true),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text('Batch ID: ${(s['batchNumber'] ?? '').toString()}',
                        style: dStyle),
                    const SizedBox(height: 2),
                    Text(
                        'Hall Ticket No: ${(s['hallTicketNumber'] ?? '').toString()}',
                        style: dStyle),
                    const SizedBox(height: 2),
                    Text('Present: ${present ? 'Yes' : 'No'}', style: dStyle),
                  ],
                ),
              );
            }),
          );
        }

        return Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[400]!),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Column(
            children: [
              Container(
                color: const Color(0xFF1e3a5f),
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                child: Row(
                  children: [
                    Expanded(flex: 1, child: _headerText('S No')),
                    Expanded(flex: 2, child: _headerText('Batch ID')),
                    Expanded(flex: 3, child: _headerText('Hall Ticket No')),
                    Expanded(flex: 4, child: _headerText('Student Name')),
                    Expanded(flex: 2, child: _headerText('Present')),
                  ],
                ),
              ),
              ...List.generate(_students.length, (i) {
                final s = _students[i];
                final roll = s['rollNo'] as String;
                final present = _attendance[roll] ?? true;

                return Container(
                  color: i % 2 == 0 ? Colors.white : const Color(0xFFF5F8FF),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                          flex: 1,
                          child:
                              _dataText('${i + 1}', align: TextAlign.center)),
                      Expanded(
                          flex: 2,
                          child:
                              _dataText((s['batchNumber'] ?? '').toString())),
                      Expanded(
                        flex: 3,
                        child:
                            _dataText((s['hallTicketNumber'] ?? '').toString()),
                      ),
                      Expanded(
                          flex: 4,
                          child: _dataText((s['name'] ?? '').toString())),
                      Expanded(
                        flex: 2,
                        child: Center(
                          child: Checkbox(
                            value: present,
                            activeColor: const Color(0xFF1565C0),
                            onChanged: (v) =>
                                setState(() => _attendance[roll] = v ?? true),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }
}
