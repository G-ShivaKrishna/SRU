import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../widgets/app_header.dart';

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

// ─── Assignment model ─────────────────────────────────────────────────────────

class _Assign {
  final String docId;
  final String subjectCode;
  final String subjectName;
  final List<String> assignedBatches;
  final String department;
  final int year;
  final String semester;

  const _Assign({
    required this.docId,
    required this.subjectCode,
    required this.subjectName,
    required this.assignedBatches,
    required this.department,
    required this.year,
    required this.semester,
  });

  factory _Assign.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return _Assign(
      docId: doc.id,
      subjectCode: d['subjectCode'] as String? ?? '',
      subjectName: d['subjectName'] as String? ?? '',
      assignedBatches: List<String>.from(d['assignedBatches'] ?? []),
      department: d['department'] as String? ?? '',
      year: (d['year'] is int)
          ? d['year'] as int
          : int.tryParse(d['year'].toString()) ?? 1,
      semester: d['semester'] as String? ?? '',
    );
  }

  String get displayLabel =>
      '${subjectName.isNotEmpty ? subjectName : subjectCode}'
      '${subjectCode.isNotEmpty ? '  [$subjectCode]' : ''}';
}

// ─── Screen ───────────────────────────────────────────────────────────────────

class MultiBatchAttendanceScreen extends StatefulWidget {
  const MultiBatchAttendanceScreen({super.key});

  @override
  State<MultiBatchAttendanceScreen> createState() =>
      _MultiBatchAttendanceScreenState();
}

class _MultiBatchAttendanceScreenState
    extends State<MultiBatchAttendanceScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  // ── Phase 1 ────────────────────────────────────────────────────────────────
  bool _loadingAssignments = true;
  String? _assignmentError;
  List<_Assign> _assignments = [];
  _Assign? _selectedAssignment;

  final Set<String> _selectedBatches = {};
  final DateTime _today = DateTime.now();

  // ── Phase 2 state ──────────────────────────────────────────────────────────
  bool _formVisible = false;
  bool _loadingStudents = false;

  String? _ltpType;
  final _topicCtrl = TextEditingController();
  String? _unitExpNo;
  final List<bool> _periodsSelected = List.filled(9, false);

  List<Map<String, dynamic>> _students = [];
  final Map<String, bool> _attendance = {};

  bool _submitting = false;
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

  String get _facultyId =>
      _auth.currentUser?.email?.split('@')[0].toUpperCase() ?? '';

  // ── Data loading ───────────────────────────────────────────────────────────

  Future<void> _loadAssignments() async {
    setState(() {
      _loadingAssignments = true;
      _assignmentError = null;
    });
    try {
      final snap = await _firestore
          .collection('facultyAssignments')
          .where('facultyId', isEqualTo: _facultyId)
          .where('isActive', isEqualTo: true)
          .get();
      setState(() {
        _assignments = snap.docs.map(_Assign.fromDoc).toList();
        _loadingAssignments = false;
      });
    } catch (e) {
      setState(() {
        _assignmentError = 'Error loading subjects: $e';
        _loadingAssignments = false;
      });
    }
  }

  Future<void> _loadStudents() async {
    if (_selectedAssignment == null || _selectedBatches.isEmpty) return;
    setState(() => _loadingStudents = true);
    try {
      final batches = _selectedBatches.toList();
      final students = <Map<String, dynamic>>[];
      for (var i = 0; i < batches.length; i += 10) {
        final chunk = batches.sublist(i, (i + 10).clamp(0, batches.length));
        final snap = await _firestore
            .collection('students')
            .where('batchNumber', whereIn: chunk)
            .get();
        for (final doc in snap.docs) {
          final d = doc.data();
          students.add({
            'rollNo': doc.id,
            'name': d['name'] ?? '',
            'hallTicketNumber': d['hallTicketNumber'] ?? doc.id,
            'batchNumber': d['batchNumber'] ?? '',
          });
        }
      }
      students.sort(
          (a, b) => (a['rollNo'] as String).compareTo(b['rollNo'] as String));
      _attendance.clear();
      for (final s in students) {
        _attendance[s['rollNo'] as String] = true;
      }
      setState(() => _students = students);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error loading students: $e')));
      }
    } finally {
      if (mounted) setState(() => _loadingStudents = false);
    }
  }

  Future<void> _loadLockedPeriods() async {
    setState(() => _loadingLockedPeriods = true);
    try {
      final dateStr = DateFormat('dd-MM-yyyy').format(_today);
      final batches = _selectedBatches.toList();
      final locked = <int>{};
      for (var i = 0; i < batches.length; i += 10) {
        final chunk = batches.sublist(i, (i + 10).clamp(0, batches.length));
        if (chunk.isEmpty) continue;
        final snap = await _firestore
            .collection('attendance')
            .where('dateStr', isEqualTo: dateStr)
            .where('batches', arrayContainsAny: chunk)
            .get();
        for (final doc in snap.docs) {
          final d = doc.data();
          if ((d['facultyId'] as String? ?? '') != _facultyId) {
            for (final p in (d['periods'] as List? ?? [])) {
              locked.add(p is int ? p : int.tryParse(p.toString()) ?? 0);
            }
          }
        }
      }
      if (mounted) setState(() => _lockedPeriods = locked);
    } catch (_) {
      // non-fatal
    } finally {
      if (mounted) setState(() => _loadingLockedPeriods = false);
    }
  }

  Future<void> _submitAttendance() async {
    final assignment = _selectedAssignment!;
    final periodsChosen = <int>[];
    for (var i = 0; i < _periodsSelected.length; i++) {
      if (_periodsSelected[i]) periodsChosen.add(i + 1);
    }
    if (_ltpType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Select L/T/P type.'),
            backgroundColor: Colors.orange),
      );
      return;
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
      final dateStr = DateFormat('dd-MM-yyyy').format(_today);
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
        'date': Timestamp.fromDate(
            DateTime(_today.year, _today.month, _today.day)),
        'facultyId': _facultyId,
        'subjectCode': assignment.subjectCode,
        'subjectName': assignment.subjectName,
        'department': assignment.department,
        'year': assignment.year,
        'semester': assignment.semester,
        'batches': _selectedBatches.toList(),
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

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
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Text(_assignmentError!,
                style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 12),
            ElevatedButton(
                onPressed: _loadAssignments,
                child: const Text('Retry')),
          ],
        ),
      );
    }
    if (_assignments.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Text(
          'No active subject assignments found for your account.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 15, color: Colors.grey),
        ),
      );
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 680),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Multi-Batch Attendance',
            style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1e3a5f)),
          ),
          const SizedBox(height: 6),
          Text(
            'Date: ${DateFormat('dd/MM/yyyy').format(_today)}',
            style: const TextStyle(fontSize: 13, color: Colors.grey),
          ),
          const SizedBox(height: 20),

          // Subject
          const Text('Subject',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          DropdownButtonFormField<_Assign>(
            value: _selectedAssignment,
            isExpanded: true,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            hint: const Text('Select subject'),
            items: _assignments
                .map((a) => DropdownMenuItem(
                      value: a,
                      child: Text(a.displayLabel,
                          overflow: TextOverflow.ellipsis),
                    ))
                .toList(),
            onChanged: (v) {
              setState(() {
                _selectedAssignment = v;
                _selectedBatches.clear();
                _students.clear();
                _attendance.clear();
              });
            },
          ),
          const SizedBox(height: 20),

          if (_selectedAssignment != null) ...[
            _buildBatchSelector(),
            const SizedBox(height: 20),
          ],

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1565C0),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              ),
              onPressed: (_selectedAssignment != null &&
                      _selectedBatches.isNotEmpty &&
                      !_loadingStudents)
                  ? () async {
                      await _loadStudents();
                      await _loadLockedPeriods();
                      if (_students.isNotEmpty) {
                        setState(() => _formVisible = true);
                      }
                    }
                  : null,
              child: _loadingStudents
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Text('Proceed to Attendance',
                      style: TextStyle(fontSize: 15)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBatchSelector() {
    final batches = _selectedAssignment!.assignedBatches;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Select Batches',
            style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(
          'Tick one or more batches to include in this session.',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: batches.map((b) {
            final selected = _selectedBatches.contains(b);
            return FilterChip(
              label: Text(b),
              selected: selected,
              selectedColor:
                  const Color(0xFF1e3a5f).withOpacity(0.18),
              checkmarkColor: const Color(0xFF1e3a5f),
              onSelected: (v) {
                setState(() {
                  if (v) {
                    _selectedBatches.add(b);
                  } else {
                    _selectedBatches.remove(b);
                  }
                });
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            TextButton.icon(
              onPressed: () =>
                  setState(() => _selectedBatches.addAll(batches)),
              icon: const Icon(Icons.select_all, size: 16),
              label: const Text('Select All'),
            ),
            TextButton.icon(
              onPressed: () =>
                  setState(() => _selectedBatches.clear()),
              icon: const Icon(Icons.clear, size: 16),
              label: const Text('Clear'),
            ),
          ],
        ),
        if (_selectedBatches.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              'Selected: ${_selectedBatches.join(', ')}',
              style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF1e3a5f),
                  fontWeight: FontWeight.w600),
            ),
          ),
      ],
    );
  }

  // ── Phase 2 ────────────────────────────────────────────────────────────────

  Widget _buildAttendanceForm() {
    final a = _selectedAssignment!;
    final dateStr = DateFormat('dd-MM-yyyy').format(_today);
    final batchDisplay = _selectedBatches.join(' / ');

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 1000),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              TextButton.icon(
                onPressed: () => setState(() {
                  _formVisible = false;
                  _students.clear();
                  _attendance.clear();
                }),
                icon: const Icon(Icons.arrow_back, size: 16),
                label: const Text('Back'),
              ),
            ],
          ),
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
              constraints: const BoxConstraints(maxWidth: 560),
              child: Container(
                decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[400]!)),
                child: Table(
                  columnWidths: const {
                    0: IntrinsicColumnWidth(),
                    1: FlexColumnWidth()
                  },
                  children: [
                    _infoRow('Date of Entry :', dateStr),
                    _infoRow('Branch & Spl :', a.department),
                    _infoRow('Year-Sem / Batches :',
                        'Year ${a.year}  –  Sem ${a.semester}  /  $batchDisplay'),
                    _infoRow('Course & Code :',
                        '${a.subjectName}  &  ${a.subjectCode}'),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 700),
              child: _buildFormFields(),
            ),
          ),
          const SizedBox(height: 16),

          _buildPeriodsSection(),
          const SizedBox(height: 12),

          Center(
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFFC107),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'Note : Remove the checkmarks for absentee\'s numbers',
                textAlign: TextAlign.center,
                style:
                    TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ),
          ),
          const SizedBox(height: 16),

          _buildSummaryBar(),
          const SizedBox(height: 8),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: () => setState(() {
                  for (final s in _students) {
                    _attendance[s['rollNo'] as String] = true;
                  }
                }),
                icon: const Icon(Icons.check_circle, size: 16),
                label: const Text('All Present'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: () => setState(() {
                  for (final s in _students) {
                    _attendance[s['rollNo'] as String] = false;
                  }
                }),
                icon: const Icon(Icons.cancel, size: 16),
                label: const Text('All Absent'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 16),

          _buildStudentTable(),
          const SizedBox(height: 20),

          Center(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1e3a5f),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 48, vertical: 14),
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
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildFormFields() {
    const inputDec = InputDecoration(
        border: OutlineInputBorder(),
        contentPadding:
            EdgeInsets.symmetric(horizontal: 10, vertical: 10));

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('L / T / P',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                value: _ltpType,
                decoration: inputDec,
                hint: const Text('Select'),
                items: const ['L', 'T', 'P']
                    .map((v) =>
                        DropdownMenuItem(value: v, child: Text(v)))
                    .toList(),
                onChanged: (v) => setState(() => _ltpType = v),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Topic Covered',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              TextFormField(
                controller: _topicCtrl,
                decoration: inputDec.copyWith(
                    hintText: 'Enter topic covered'),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Unit / Exp No.',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                value: _unitExpNo,
                decoration: inputDec,
                hint: const Text('Select'),
                items: List.generate(
                        6,
                        (i) => DropdownMenuItem(
                            value: '${i + 1}', child: Text('${i + 1}')))
                    .toList(),
                onChanged: (v) => setState(() => _unitExpNo = v),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPeriodsSection() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(left: 4, bottom: 8),
              child: Text('Hours / Periods',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14)),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: List.generate(9, (i) {
                  final periodNum = i + 1;
                  final isLocked = _lockedPeriods.contains(periodNum);
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Column(
                      children: [
                        Container(
                          width: 82,
                          padding:
                              const EdgeInsets.symmetric(vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1e3a5f),
                            borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(4)),
                          ),
                          child: Text(
                            _kPeriodLabels[i],
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 9),
                          ),
                        ),
                        Container(
                          width: 82,
                          decoration: BoxDecoration(
                            border: Border.all(
                                color: isLocked
                                    ? Colors.grey.shade300
                                    : Colors.grey.shade400),
                            borderRadius: const BorderRadius.vertical(
                                bottom: Radius.circular(4)),
                            color: isLocked
                                ? Colors.grey.shade100
                                : null,
                          ),
                          child: Checkbox(
                            value: isLocked
                                ? true
                                : _periodsSelected[i],
                            onChanged: isLocked
                                ? null
                                : (v) => setState(
                                    () => _periodsSelected[i] =
                                        v ?? false),
                            activeColor: isLocked
                                ? Colors.grey
                                : const Color(0xFF1e3a5f),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ),
            ),
            if (_loadingLockedPeriods)
              const Padding(
                padding: EdgeInsets.only(top: 6, left: 4),
                child: Row(children: [
                  SizedBox(
                      width: 12,
                      height: 12,
                      child:
                          CircularProgressIndicator(strokeWidth: 2)),
                  SizedBox(width: 6),
                  Text('Checking locked periods…',
                      style:
                          TextStyle(fontSize: 11, color: Colors.grey)),
                ]),
              )
            else if (_lockedPeriods.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6, left: 4),
                child: Row(children: [
                  const Icon(Icons.lock_outline,
                      size: 13, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    'Periods ${_lockedPeriods.join(', ')} locked (marked by another faculty)',
                    style: TextStyle(
                        fontSize: 11, color: Colors.grey[600]),
                  ),
                ]),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryBar() {
    final present = _attendance.values.where((v) => v).length;
    final total = _students.length;
    final absent = total - present;
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _statItem('Present', '$present', Colors.green),
            _vDivider(),
            _statItem('Absent', '$absent', Colors.red),
            _vDivider(),
            _statItem('Total', '$total', Colors.blueGrey),
            _vDivider(),
            _statItem('Batches', '${_selectedBatches.length}',
                const Color(0xFF1e3a5f)),
          ],
        ),
      ),
    );
  }

  Widget _statItem(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Column(
        children: [
          Text(value,
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: color)),
          Text(label,
              style:
                  const TextStyle(fontSize: 11, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _vDivider() =>
      Container(height: 36, width: 1, color: Colors.grey.shade300);

  Widget _buildStudentTable() {
    if (_students.isEmpty) {
      return const Center(
          child: Text('No students found for the selected batches.',
              style: TextStyle(color: Colors.grey)));
    }

    const hStyle = TextStyle(
        fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white);
    const dStyle = TextStyle(fontSize: 12, color: Colors.black87);

    Widget hc(String t, {double? w, bool exp = false}) {
      final c = Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: Text(t, style: hStyle),
      );
      return exp ? Expanded(child: c) : SizedBox(width: w, child: c);
    }

    final batchOrder = _selectedBatches.toList()..sort();

    return Column(
      children: batchOrder.map((batch) {
        final batchStudents =
            _students.where((s) => s['batchNumber'] == batch).toList();
        if (batchStudents.isEmpty) return const SizedBox.shrink();

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Batch header
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color:
                      const Color(0xFF1e3a5f).withOpacity(0.85),
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(7)),
                ),
                child: Text(
                  'Batch: $batch  •  ${batchStudents.length} students',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13),
                ),
              ),
              // Column headers
              Container(
                color: const Color(0xFF1e3a5f),
                child: Row(
                  children: [
                    hc('#', w: 40),
                    hc('Roll No.', w: 110),
                    hc('Name', exp: true),
                    hc('Hall Ticket', w: 130),
                    hc('Present', w: 80),
                  ],
                ),
              ),
              // Rows
              ...batchStudents.asMap().entries.map((entry) {
                final idx = entry.key;
                final s = entry.value;
                final roll = s['rollNo'] as String;
                final isPresent = _attendance[roll] ?? true;
                final isEven = idx % 2 == 0;

                return Container(
                  color: isEven
                      ? Colors.white
                      : Colors.grey.shade50,
                  child: Row(
                    children: [
                      SizedBox(
                        width: 40,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 8),
                          child: Text('${idx + 1}',
                              style: dStyle,
                              textAlign: TextAlign.center),
                        ),
                      ),
                      SizedBox(
                        width: 110,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 8),
                          child: Text(roll, style: dStyle),
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 8),
                          child: Text(s['name'] as String,
                              style: dStyle),
                        ),
                      ),
                      SizedBox(
                        width: 130,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 8),
                          child: Text(
                              s['hallTicketNumber'] as String,
                              style: dStyle),
                        ),
                      ),
                      SizedBox(
                        width: 80,
                        child: Center(
                          child: Checkbox(
                            value: isPresent,
                            activeColor: Colors.green,
                            onChanged: (v) => setState(
                                () => _attendance[roll] =
                                    v ?? true),
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
      }).toList(),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  TableRow _infoRow(String label, String value) {
    return TableRow(
      decoration: const BoxDecoration(
          border: Border(
              bottom: BorderSide(color: Color(0xFFDDDDDD)))),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: 8, vertical: 5),
          child: Text(label,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 12)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: 8, vertical: 5),
          child: Text(value,
              style: const TextStyle(fontSize: 12)),
        ),
      ],
    );
  }
}
