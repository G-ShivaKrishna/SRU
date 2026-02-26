import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

/// Full admin attendance management:
///  Tab 1 – View / Edit / Delete any attendance record (any date)
///  Tab 2 – Per-student attendance lookup
///  Tab 3 – Faculty edit-request approval workflow
class AttendanceManagementPage extends StatefulWidget {
  const AttendanceManagementPage({super.key});

  @override
  State<AttendanceManagementPage> createState() =>
      _AttendanceManagementPageState();
}

class _AttendanceManagementPageState extends State<AttendanceManagementPage>
    with SingleTickerProviderStateMixin {
  final _firestore = FirebaseFirestore.instance;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance Management'),
        backgroundColor: const Color(0xFF1e3a5f),
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(icon: Icon(Icons.edit_calendar), text: 'Records'),
            Tab(icon: Icon(Icons.person_search), text: 'Student'),
            Tab(icon: Icon(Icons.pending_actions), text: 'Requests'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _RecordsTab(firestore: _firestore),
          _StudentTab(firestore: _firestore),
          _RequestsTab(firestore: _firestore),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// TAB 1 — All Attendance Records  (view / edit / delete)
// ═══════════════════════════════════════════════════════════════════════════

class _RecordsTab extends StatefulWidget {
  const _RecordsTab({required this.firestore});
  final FirebaseFirestore firestore;
  @override
  State<_RecordsTab> createState() => _RecordsTabState();
}

class _RecordsTabState extends State<_RecordsTab> {
  // ── filters ───────────────────────────────────────────────────────────────
  DateTime? _fromDate;
  DateTime? _toDate;
  final _subjectCtrl = TextEditingController();
  final _facultyCtrl = TextEditingController();
  final _deptCtrl = TextEditingController();
  final _batchCtrl = TextEditingController();

  bool _loading = false;
  List<QueryDocumentSnapshot> _docs = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    // default: no date filter — show all records
    _fromDate = null;
    _toDate = null;
    _fetchRecords();
  }

  @override
  void dispose() {
    _subjectCtrl.dispose();
    _facultyCtrl.dispose();
    _deptCtrl.dispose();
    _batchCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchRecords() async {
    setState(() {
      _loading = true;
      _error = null;
      _docs = [];
    });
    try {
      Query q = widget.firestore.collection('attendance');

      if (_fromDate != null) {
        q = q.where('date',
            isGreaterThanOrEqualTo: Timestamp.fromDate(
                DateTime(_fromDate!.year, _fromDate!.month, _fromDate!.day)));
      }
      if (_toDate != null) {
        q = q.where('date',
            isLessThanOrEqualTo: Timestamp.fromDate(DateTime(
                _toDate!.year, _toDate!.month, _toDate!.day, 23, 59, 59)));
      }

      final snap = await q.get();
      var docs = List<QueryDocumentSnapshot>.from(snap.docs);

      // all text filters are client-side to avoid composite index requirements
      final subCode = _subjectCtrl.text.trim().toUpperCase();
      final fac = _facultyCtrl.text.trim().toUpperCase();
      final dept = _deptCtrl.text.trim().toUpperCase();
      final batch = _batchCtrl.text.trim().toUpperCase();

      if (subCode.isNotEmpty) {
        docs = docs.where((d) {
          final code =
              ((d.data() as Map)['subjectCode'] as String? ?? '').toUpperCase();
          return code.contains(subCode);
        }).toList();
      }
      if (fac.isNotEmpty) {
        docs = docs.where((d) {
          final id =
              ((d.data() as Map)['facultyId'] as String? ?? '').toUpperCase();
          return id.contains(fac);
        }).toList();
      }
      if (dept.isNotEmpty) {
        docs = docs.where((d) {
          final dep =
              ((d.data() as Map)['department'] as String? ?? '').toUpperCase();
          return dep.contains(dept);
        }).toList();
      }
      if (batch.isNotEmpty) {
        docs = docs.where((d) {
          final batches = List<String>.from((d.data() as Map)['batches'] ?? []);
          return batches.any((b) => b.toUpperCase().contains(batch));
        }).toList();
      }

      // sort newest date first
      docs.sort((a, b) {
        final at = (a.data() as Map)['date'] as Timestamp?;
        final bt = (b.data() as Map)['date'] as Timestamp?;
        if (at == null) return 1;
        if (bt == null) return -1;
        return bt.compareTo(at);
      });

      setState(() => _docs = docs);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── date picker ──────────────────────────────────────────────────────────

  Future<void> _pickDate(bool isFrom) async {
    final initial = (isFrom ? _fromDate : _toDate) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2099),
    );
    if (picked != null) {
      setState(() {
        if (isFrom) {
          _fromDate = picked;
        } else {
          _toDate = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── filter panel ────────────────────────────────────────────────
        Container(
          color: Colors.grey.shade100,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Column(
            children: [
              Row(children: [
                Expanded(
                    child: _dateTile('From', _fromDate, () => _pickDate(true),
                        () => setState(() => _fromDate = null))),
                const SizedBox(width: 8),
                Expanded(
                    child: _dateTile('To', _toDate, () => _pickDate(false),
                        () => setState(() => _toDate = null))),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: _subjectCtrl,
                    decoration: _fd('Subject Code'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _facultyCtrl,
                    decoration: _fd('Faculty ID'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _deptCtrl,
                    decoration: _fd('Department'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _batchCtrl,
                    decoration: _fd('Batch'),
                  ),
                ),
              ]),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton.icon(
                  onPressed: _fetchRecords,
                  icon: const Icon(Icons.search, size: 16),
                  label: const Text('Search'),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1e3a5f),
                      foregroundColor: Colors.white),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        // ── results ─────────────────────────────────────────────────────
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(
                      child: Text(_error!,
                          style: const TextStyle(color: Colors.red)))
                  : _docs.isEmpty
                      ? _emptyState('No attendance records found.')
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: _docs.length,
                          itemBuilder: (_, i) => _RecordCard(
                            doc: _docs[i],
                            firestore: widget.firestore,
                            onRefresh: _fetchRecords,
                          ),
                        ),
        ),
      ],
    );
  }

  Widget _dateTile(
      String label, DateTime? dt, VoidCallback onTap, VoidCallback onClear) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(
              color:
                  dt != null ? const Color(0xFF1e3a5f) : Colors.grey.shade400),
          borderRadius: BorderRadius.circular(6),
          color: Colors.white,
        ),
        child: Row(children: [
          Icon(Icons.calendar_today,
              size: 14,
              color: dt != null ? const Color(0xFF1e3a5f) : Colors.grey),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              '$label: ${dt != null ? DateFormat('dd-MM-yyyy').format(dt) : 'Any date'}',
              style: TextStyle(
                  fontSize: 13,
                  color: dt != null
                      ? const Color(0xFF1e3a5f)
                      : Colors.grey.shade600),
            ),
          ),
          if (dt != null)
            GestureDetector(
              onTap: onClear,
              child: const Icon(Icons.close, size: 14, color: Colors.grey),
            ),
        ]),
      ),
    );
  }

  InputDecoration _fd(String h) => InputDecoration(
        hintText: h,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        border: const OutlineInputBorder(),
        fillColor: Colors.white,
        filled: true,
      );

  Widget _emptyState(String msg) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.inbox_outlined, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(msg,
              style: TextStyle(fontSize: 15, color: Colors.grey.shade600)),
        ]),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Expandable card for a single attendance record with in-place edit support
// ─────────────────────────────────────────────────────────────────────────────

class _RecordCard extends StatefulWidget {
  const _RecordCard({
    required this.doc,
    required this.firestore,
    required this.onRefresh,
  });
  final QueryDocumentSnapshot doc;
  final FirebaseFirestore firestore;
  final VoidCallback onRefresh;

  @override
  State<_RecordCard> createState() => _RecordCardState();
}

class _RecordCardState extends State<_RecordCard> {
  bool _expanded = false;
  bool _editing = false;
  bool _saving = false;

  // editable state
  late Map<String, bool> _attendance;
  late String? _ltpType;
  late String? _unitExpNo;
  late TextEditingController _topicCtrl;
  late List<bool> _periodsSelected;

  Map<String, dynamic> get _d => widget.doc.data() as Map<String, dynamic>;

  @override
  void initState() {
    super.initState();
    _initEditing();
  }

  void _initEditing() {
    _attendance = {};
    for (final s in List<Map>.from(_d['students'] ?? [])) {
      _attendance[s['rollNo'] as String] = (s['present'] as bool?) ?? true;
    }
    _ltpType = _d['ltpType'] as String?;
    _unitExpNo = _d['unitExpNo'] as String?;
    _topicCtrl =
        TextEditingController(text: _d['topicCovered'] as String? ?? '');
    final periods = List<int>.from(_d['periods'] ?? []);
    _periodsSelected = List.generate(9, (i) => periods.contains(i + 1));
  }

  @override
  void dispose() {
    _topicCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final periods = <int>[];
      for (var i = 0; i < _periodsSelected.length; i++) {
        if (_periodsSelected[i]) periods.add(i + 1);
      }
      final students = List<Map>.from(_d['students'] ?? []).map((s) {
        final roll = s['rollNo'] as String;
        return {
          'rollNo': roll,
          'name': s['name'],
          'hallTicketNumber': s['hallTicketNumber'],
          'batchNumber': s['batchNumber'],
          'present': _attendance[roll] ?? true,
        };
      }).toList();

      await widget.firestore
          .collection('attendance')
          .doc(widget.doc.id)
          .update({
        'ltpType': _ltpType ?? '',
        'topicCovered': _topicCtrl.text.trim(),
        'unitExpNo': _unitExpNo ?? '',
        'periods': periods,
        'students': students,
        'presentCount': students.where((s) => s['present'] == true).length,
        'absentCount': students.where((s) => s['present'] == false).length,
        'adminEditedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Record updated.'), backgroundColor: Colors.green));
        setState(() => _editing = false);
        widget.onRefresh();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Record'),
        content: Text(
          'Permanently delete attendance for "${_d['subjectCode']} — ${_d['dateStr']}"?\n'
          'This cannot be undone.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child:
                  const Text('Delete', style: TextStyle(color: Colors.white))),
        ],
      ),
    );
    if (ok == true) {
      await widget.firestore
          .collection('attendance')
          .doc(widget.doc.id)
          .delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Record deleted.'), backgroundColor: Colors.red));
        widget.onRefresh();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = _d['dateStr'] as String? ?? '—';
    final subCode = _d['subjectCode'] as String? ?? '—';
    final subName = _d['subjectName'] as String? ?? '';
    final faculty = _d['facultyId'] as String? ?? '—';
    final dept = _d['department'] as String? ?? '—';
    final year = _d['year'];
    final sem = _d['semester'] as String? ?? '—';
    final batches = List<String>.from(_d['batches'] ?? []);
    final total = _d['totalStudents'] ?? 0;
    final present = _d['presentCount'] ?? 0;
    final absent = _d['absentCount'] ?? 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Column(
        children: [
          // ── summary row ───────────────────────────────────────────────
          ListTile(
            dense: true,
            leading: CircleAvatar(
              backgroundColor: const Color(0xFF1e3a5f).withOpacity(0.1),
              child: Text(
                dateStr.split('-')[0],
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1e3a5f)),
              ),
            ),
            title: Text(
              '$subCode${subName.isNotEmpty ? '  —  $subName' : ''}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            subtitle: Text(
              '$dateStr  •  $dept  •  Y$year / S$sem  •  ${batches.join(', ')}\n'
              'Faculty: $faculty  •  P:$present  A:$absent  T:$total',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
            ),
            isThreeLine: true,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  tooltip: 'Delete record',
                  onPressed: _delete,
                ),
                IconButton(
                  icon: Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    color: const Color(0xFF1e3a5f),
                  ),
                  tooltip: _expanded ? 'Collapse' : 'Expand',
                  onPressed: () {
                    setState(() => _expanded = !_expanded);
                    if (!_expanded) _editing = false;
                  },
                ),
              ],
            ),
          ),

          // ── expanded section ──────────────────────────────────────────
          if (_expanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // action bar
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (_editing) ...[
                        OutlinedButton.icon(
                          onPressed: () => setState(() {
                            _editing = false;
                            _initEditing(); // reset
                          }),
                          icon: const Icon(Icons.close, size: 15),
                          label: const Text('Cancel'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: _saving ? null : _save,
                          icon: _saving
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.save, size: 15),
                          label: const Text('Save'),
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white),
                        ),
                      ] else ...[
                        ElevatedButton.icon(
                          onPressed: () => setState(() => _editing = true),
                          icon: const Icon(Icons.edit, size: 15),
                          label: const Text('Edit Record'),
                          style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1e3a5f),
                              foregroundColor: Colors.white),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 12),

                  // ── editable fields ─────────────────────────────────
                  if (_editing) ...[
                    Row(children: [
                      Expanded(child: _ltpDropdown()),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 3,
                        child: TextFormField(
                          controller: _topicCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Topic Covered',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: _unitDropdown()),
                    ]),
                    const SizedBox(height: 12),
                    _periodSelector(),
                    const SizedBox(height: 12),
                  ] else ...[
                    // read-only metadata
                    Wrap(spacing: 16, runSpacing: 6, children: [
                      _chip('L/T/P', _d['ltpType'] as String? ?? '—'),
                      _chip('Topic', _d['topicCovered'] as String? ?? '—'),
                      _chip('Unit', _d['unitExpNo'] as String? ?? '—'),
                      _chip('Periods',
                          List<int>.from(_d['periods'] ?? []).join(', ')),
                    ]),
                    const SizedBox(height: 12),
                  ],

                  // ── student table ────────────────────────────────────
                  _studentTable(_editing),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _ltpDropdown() {
    return DropdownButtonFormField<String>(
      value: ['L', 'T', 'P'].contains(_ltpType) ? _ltpType : null,
      decoration: const InputDecoration(
          labelText: 'L/T/P', border: OutlineInputBorder(), isDense: true),
      items: const ['L', 'T', 'P']
          .map((v) => DropdownMenuItem(value: v, child: Text(v)))
          .toList(),
      onChanged: (v) => setState(() => _ltpType = v),
    );
  }

  Widget _unitDropdown() {
    return DropdownButtonFormField<String>(
      value: (int.tryParse(_unitExpNo ?? '') != null &&
              int.parse(_unitExpNo!) >= 1 &&
              int.parse(_unitExpNo!) <= 6)
          ? _unitExpNo
          : null,
      decoration: const InputDecoration(
          labelText: 'Unit/Exp', border: OutlineInputBorder(), isDense: true),
      items: List.generate(
              6,
              (i) =>
                  DropdownMenuItem(value: '${i + 1}', child: Text('${i + 1}')))
          .toList(),
      onChanged: (v) => setState(() => _unitExpNo = v),
    );
  }

  Widget _periodSelector() {
    const labels = [
      '09-10',
      '10-11',
      '11-12',
      '12-01',
      '01-02',
      '02-03',
      '03-04',
      '04-05',
      '05-06'
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Periods',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          children: List.generate(9, (i) {
            return FilterChip(
              label: Text(labels[i], style: const TextStyle(fontSize: 11)),
              selected: _periodsSelected[i],
              onSelected: (v) => setState(() => _periodsSelected[i] = v),
              selectedColor: const Color(0xFF1e3a5f).withOpacity(0.2),
              checkmarkColor: const Color(0xFF1e3a5f),
            );
          }),
        ),
      ],
    );
  }

  Widget _studentTable(bool editing) {
    final students = List<Map>.from(_d['students'] ?? []);
    if (students.isEmpty) {
      return const Text('No student data.',
          style: TextStyle(color: Colors.grey));
    }

    const hStyle = TextStyle(
        fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Mark all buttons when editing
        if (editing) ...[
          Row(children: [
            TextButton.icon(
              onPressed: () => setState(() {
                for (final s in students) {
                  _attendance[s['rollNo'] as String] = true;
                }
              }),
              icon:
                  const Icon(Icons.check_circle, size: 14, color: Colors.green),
              label: const Text('All Present', style: TextStyle(fontSize: 12)),
            ),
            TextButton.icon(
              onPressed: () => setState(() {
                for (final s in students) {
                  _attendance[s['rollNo'] as String] = false;
                }
              }),
              icon: const Icon(Icons.cancel, size: 14, color: Colors.red),
              label: const Text('All Absent', style: TextStyle(fontSize: 12)),
            ),
          ]),
          const SizedBox(height: 4),
        ],
        // header
        Container(
          color: const Color(0xFF1e3a5f),
          child: Row(children: [
            SizedBox(
                width: 36,
                child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Text('#', style: hStyle))),
            SizedBox(
                width: 100,
                child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Text('Roll No.', style: hStyle))),
            Expanded(
                child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Text('Name', style: hStyle))),
            SizedBox(
                width: 110,
                child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Text('Hall Ticket', style: hStyle))),
            SizedBox(
                width: 70,
                child: Padding(
                    padding: const EdgeInsets.all(6),
                    child:
                        Text(_editing ? 'Present' : 'Status', style: hStyle))),
          ]),
        ),
        // rows
        ...students.asMap().entries.map((entry) {
          final idx = entry.key;
          final s = entry.value;
          final roll = s['rollNo'] as String;
          final isPresent =
              _attendance[roll] ?? (s['present'] as bool? ?? true);
          final isEven = idx % 2 == 0;

          return Container(
            color: isEven ? Colors.white : Colors.grey.shade50,
            child: Row(children: [
              SizedBox(
                  width: 36,
                  child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Text('${idx + 1}',
                          style: const TextStyle(fontSize: 11)))),
              SizedBox(
                  width: 100,
                  child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Text(roll, style: const TextStyle(fontSize: 11)))),
              Expanded(
                  child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Text(s['name'] as String? ?? '',
                          style: const TextStyle(fontSize: 11)))),
              SizedBox(
                  width: 110,
                  child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Text(s['hallTicketNumber'] as String? ?? '',
                          style: const TextStyle(fontSize: 11)))),
              SizedBox(
                width: 70,
                child: editing
                    ? Checkbox(
                        value: isPresent,
                        activeColor: Colors.green,
                        onChanged: (v) =>
                            setState(() => _attendance[roll] = v ?? true),
                      )
                    : Padding(
                        padding: const EdgeInsets.all(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isPresent
                                ? Colors.green.withOpacity(0.15)
                                : Colors.red.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            isPresent ? 'P' : 'A',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isPresent ? Colors.green : Colors.red),
                          ),
                        ),
                      ),
              ),
            ]),
          );
        }),
      ],
    );
  }

  Widget _chip(String label, String value) {
    return Chip(
      label: Text('$label: $value', style: const TextStyle(fontSize: 11)),
      backgroundColor: Colors.blueGrey.withOpacity(0.1),
      padding: EdgeInsets.zero,
      labelPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// TAB 2 — Per-Student Attendance Lookup
// ═══════════════════════════════════════════════════════════════════════════

class _StudentTab extends StatefulWidget {
  const _StudentTab({required this.firestore});
  final FirebaseFirestore firestore;
  @override
  State<_StudentTab> createState() => _StudentTabState();
}

class _StudentTabState extends State<_StudentTab> {
  final _rollCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  // student info
  String? _studentName;
  String? _hallTicket;
  String? _batchNumber;

  // attendance aggregation: subjectCode → {held, present}
  Map<String, Map<String, int>> _subjectStats = {};
  List<Map<String, dynamic>> _allRecords = [];

  @override
  void dispose() {
    _rollCtrl.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final roll = _rollCtrl.text.trim().toUpperCase();
    if (roll.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
      _subjectStats = {};
      _allRecords = [];
      _studentName = null;
      _hallTicket = null;
      _batchNumber = null;
    });
    try {
      // Get student info
      final sDoc =
          await widget.firestore.collection('students').doc(roll).get();
      if (!sDoc.exists) {
        setState(() => _error = 'Student "$roll" not found.');
        return;
      }
      final sd = sDoc.data()!;
      _studentName = sd['name'] as String? ?? roll;
      _hallTicket = sd['hallTicketNumber'] as String? ?? '—';
      _batchNumber = sd['batchNumber'] as String? ?? '—';

      // Fetch all attendance where this student's batch appears
      final batch = _batchNumber!;
      final snap = await widget.firestore
          .collection('attendance')
          .where('batches', arrayContains: batch)
          .get();

      final stats = <String, Map<String, int>>{};
      final records = <Map<String, dynamic>>[];

      for (final doc in snap.docs) {
        final d = doc.data();
        final students = List<Map>.from(d['students'] ?? []);
        final match = students
            .cast<Map<dynamic, dynamic>>()
            .where((s) => (s['rollNo'] as String?)?.toUpperCase() == roll);
        if (match.isEmpty) continue;

        final subCode = d['subjectCode'] as String? ?? '—';
        final subName = d['subjectName'] as String? ?? '';
        final isPresent = match.first['present'] as bool? ?? false;

        stats.putIfAbsent(
            subCode, () => {'held': 0, 'present': 0, 'subName': 0});
        stats[subCode]!['held'] = (stats[subCode]!['held'] ?? 0) + 1;
        if (isPresent) {
          stats[subCode]!['present'] = (stats[subCode]!['present'] ?? 0) + 1;
        }

        records.add({
          'docId': doc.id,
          'dateStr': d['dateStr'] ?? '—',
          'date': d['date'],
          'subjectCode': subCode,
          'subjectName': subName,
          'present': isPresent,
          'periods': d['periods'],
          'ltpType': d['ltpType'],
          'topicCovered': d['topicCovered'],
        });
      }

      records.sort((a, b) {
        final at = a['date'] as Timestamp?;
        final bt = b['date'] as Timestamp?;
        if (at == null) return 1;
        if (bt == null) return -1;
        return bt.compareTo(at);
      });

      setState(() {
        _subjectStats = stats;
        _allRecords = records;
      });
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // search bar
        Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: _rollCtrl,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  hintText: 'Enter Roll Number (e.g. 22B01A0501)',
                  border: OutlineInputBorder(),
                  isDense: true,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                onSubmitted: (_) => _search(),
              ),
            ),
            const SizedBox(width: 10),
            ElevatedButton.icon(
              onPressed: _loading ? null : _search,
              icon: const Icon(Icons.search, size: 16),
              label: const Text('Search'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1e3a5f),
                  foregroundColor: Colors.white),
            ),
          ]),
        ),

        if (_loading)
          const Expanded(child: Center(child: CircularProgressIndicator()))
        else if (_error != null)
          Expanded(
              child: Center(
                  child:
                      Text(_error!, style: const TextStyle(color: Colors.red))))
        else if (_studentName != null)
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // student info card
                  Card(
                    color: const Color(0xFF1e3a5f).withOpacity(0.07),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(children: [
                        const Icon(Icons.person,
                            size: 40, color: Color(0xFF1e3a5f)),
                        const SizedBox(width: 14),
                        Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_studentName!,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16)),
                              Text(
                                  'Roll: ${_rollCtrl.text.trim().toUpperCase()}  •  Batch: $_batchNumber',
                                  style: const TextStyle(fontSize: 13)),
                              Text('Hall Ticket: $_hallTicket',
                                  style: const TextStyle(fontSize: 13)),
                            ]),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // subject-wise stats
                  const Text('Subject-wise Attendance',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 8),
                  if (_subjectStats.isEmpty)
                    const Text('No records found.',
                        style: TextStyle(color: Colors.grey))
                  else
                    ..._subjectStats.entries.map((e) {
                      final sub = e.key;
                      final held = e.value['held'] ?? 0;
                      final present = e.value['present'] ?? 0;
                      final pct = held > 0 ? (present / held * 100) : 0.0;
                      final color = pct >= 75
                          ? Colors.green
                          : pct >= 60
                              ? Colors.orange
                              : Colors.red;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          child: Row(children: [
                            Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(sub,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13)),
                                    const SizedBox(height: 4),
                                    LinearProgressIndicator(
                                      value: held > 0 ? present / held : 0,
                                      backgroundColor: color.withOpacity(0.2),
                                      color: color,
                                    ),
                                    const SizedBox(height: 4),
                                    Text('$present / $held classes attended',
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey.shade700)),
                                  ]),
                            ),
                            const SizedBox(width: 14),
                            Column(children: [
                              Text('${pct.toStringAsFixed(1)}%',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                      color: color)),
                              Text('attendance',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade600)),
                            ]),
                          ]),
                        ),
                      );
                    }),

                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Attendance History',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15)),
                      Row(children: [
                        OutlinedButton.icon(
                          onPressed: _editByDate,
                          icon: const Icon(Icons.edit_calendar,
                              size: 16, color: Color(0xFF1e3a5f)),
                          label: const Text('Edit by Date',
                              style: TextStyle(color: Color(0xFF1e3a5f))),
                          style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFF1e3a5f)),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8)),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: _addAttendance,
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('Add Attendance'),
                          style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1e3a5f),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8)),
                        ),
                      ]),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // detailed history table
                  _historyTable(),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          )
        else
          Expanded(
            child: Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.person_search,
                    size: 64, color: Colors.grey.shade300),
                const SizedBox(height: 12),
                Text('Enter a roll number to view attendance.',
                    style:
                        TextStyle(fontSize: 15, color: Colors.grey.shade500)),
              ]),
            ),
          ),
      ],
    );
  }

  Widget _historyTable() {
    if (_allRecords.isEmpty) {
      return const Text('No history.', style: TextStyle(color: Colors.grey));
    }
    const hStyle = TextStyle(
        fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white);

    return Column(
      children: [
        Container(
          color: const Color(0xFF1e3a5f),
          child: Row(children: [
            SizedBox(
                width: 30,
                child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Text('#', style: hStyle))),
            SizedBox(
                width: 90,
                child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Text('Date', style: hStyle))),
            SizedBox(
                width: 80,
                child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Text('Subject', style: hStyle))),
            SizedBox(
                width: 40,
                child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Text('L/T', style: hStyle))),
            Expanded(
                child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Text('Topic', style: hStyle))),
            SizedBox(
                width: 60,
                child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Text('Status', style: hStyle))),
            SizedBox(
                width: 44,
                child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Text('Edit', style: hStyle))),
          ]),
        ),
        ..._allRecords.asMap().entries.map((entry) {
          final i = entry.key;
          final r = entry.value;
          final isPresent = r['present'] as bool;
          final isEven = i % 2 == 0;

          return Container(
            color: isEven ? Colors.white : Colors.grey.shade50,
            child: Row(children: [
              SizedBox(
                  width: 30,
                  child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Text('${i + 1}',
                          style: const TextStyle(fontSize: 11)))),
              SizedBox(
                  width: 90,
                  child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Text(r['dateStr'] as String,
                          style: const TextStyle(fontSize: 11)))),
              SizedBox(
                  width: 80,
                  child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Text(r['subjectCode'] as String,
                          style: const TextStyle(fontSize: 11)))),
              SizedBox(
                  width: 40,
                  child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Text(r['ltpType'] as String? ?? '—',
                          style: const TextStyle(fontSize: 11)))),
              Expanded(
                  child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Text(r['topicCovered'] as String? ?? '—',
                          style: const TextStyle(fontSize: 11),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis))),
              SizedBox(
                width: 60,
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isPresent
                          ? Colors.green.withOpacity(0.15)
                          : Colors.red.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      isPresent ? 'Present' : 'Absent',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isPresent ? Colors.green : Colors.red),
                    ),
                  ),
                ),
              ),
              SizedBox(
                width: 44,
                child: IconButton(
                  icon: const Icon(Icons.edit,
                      size: 15, color: Color(0xFF1e3a5f)),
                  tooltip: 'Edit attendance',
                  onPressed: () => _editStudentAttendance(r),
                ),
              ),
            ]),
          );
        }),
      ],
    );
  }

  /// Let admin pick a date then edit this student's attendance for every
  /// subject that was recorded on that day.
  /// Admin manually adds an attendance record for this student on any date
  /// and for any subject — even if the faculty never submitted one.
  Future<void> _addAttendance({DateTime? initialDate}) async {
    final roll = _rollCtrl.text.trim().toUpperCase();
    if (roll.isEmpty || _studentName == null) return;

    // ── 1. Fetch this student's assigned subjects from facultyAssignments ──
    List<Map<String, dynamic>> assignments = [];
    try {
      final snap = await widget.firestore
          .collection('facultyAssignments')
          .where('assignedBatches', arrayContains: _batchNumber ?? '')
          .get();
      for (final doc in snap.docs) {
        final d = doc.data();
        final code = (d['subjectCode'] as String? ?? '').trim();
        if (code.isEmpty) continue;
        assignments.add({
          'subjectCode': code,
          'subjectName': d['subjectName'] as String? ?? '',
          'facultyId': d['facultyId'] as String? ?? 'ADMIN',
          'department': d['department'] as String? ?? '',
          'year': d['year'] is int
              ? d['year'] as int
              : int.tryParse('${d['year']}') ?? 0,
          'semester': d['semester'] as String? ?? '',
          'batches':
              List<String>.from(d['assignedBatches'] ?? [_batchNumber ?? '']),
        });
      }
      // Sort alphabetically by subject code
      assignments.sort((a, b) =>
          (a['subjectCode'] as String).compareTo(b['subjectCode'] as String));
    } catch (_) {}

    if (!mounted) return;

    // ── 2. Dialog state ─────────────────────────────────────────────────────
    DateTime selectedDate = initialDate ?? DateTime.now();
    Map<String, dynamic>? selectedAssignment =
        assignments.isNotEmpty ? assignments.first : null;
    final topicCtrl = TextEditingController();
    String? ltpType;
    String? unitExpNo;
    bool isPresent = true;
    final List<bool> periodsSelected = List.filled(9, false);

    const periodLabels = [
      '09-10',
      '10-11',
      '11-12',
      '12-01',
      '01-02',
      '02-03',
      '03-04',
      '04-05',
      '05-06',
    ];

    // Manual-entry controllers (used when no assignments found)
    final manualCodeCtrl = TextEditingController();
    final manualNameCtrl = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: Text('Add Attendance for $_studentName'),
          content: SizedBox(
            width: 540,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Date ─────────────────────────────────────────────
                  const Text('Date',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: () async {
                      final d = await showDatePicker(
                        context: ctx,
                        initialDate: selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2099),
                      );
                      if (d != null) setDlg(() => selectedDate = d);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(children: [
                        const Icon(Icons.calendar_today,
                            size: 16, color: Colors.grey),
                        const SizedBox(width: 8),
                        Text(DateFormat('dd-MM-yyyy').format(selectedDate)),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // ── Subject dropdown (pre-loaded from facultyAssignments) ──
                  const Text('Subject *',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  if (assignments.isNotEmpty) ...[
                    DropdownButtonFormField<Map<String, dynamic>>(
                      value: selectedAssignment,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        isDense: true,
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      ),
                      items: assignments.map((a) {
                        final code = a['subjectCode'] as String;
                        final name = a['subjectName'] as String;
                        return DropdownMenuItem(
                          value: a,
                          child: Text(
                            name.isNotEmpty ? '$code  —  $name' : code,
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (v) => setDlg(() => selectedAssignment = v),
                    ),
                    // Show auto-filled meta below dropdown
                    if (selectedAssignment != null) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1e3a5f).withOpacity(0.06),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Wrap(spacing: 16, runSpacing: 4, children: [
                          _metaChip('Faculty',
                              selectedAssignment!['facultyId'] as String),
                          _metaChip('Dept',
                              selectedAssignment!['department'] as String),
                          _metaChip('Year', 'Y${selectedAssignment!['year']}'),
                          _metaChip(
                              'Sem', selectedAssignment!['semester'] as String),
                        ]),
                      ),
                    ],
                  ] else ...[
                    // Fallback: manual entry if no assignments found
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                        border:
                            Border.all(color: Colors.orange.withOpacity(0.4)),
                      ),
                      child: const Text(
                        '⚠  No faculty assignments found for this batch. '
                        'Enter subject details manually.',
                        style:
                            TextStyle(fontSize: 12, color: Colors.deepOrange),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(children: [
                      Expanded(
                        child: TextField(
                          controller: manualCodeCtrl,
                          textCapitalization: TextCapitalization.characters,
                          decoration: const InputDecoration(
                            labelText: 'Subject Code *',
                            border: OutlineInputBorder(),
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 10, vertical: 10),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: manualNameCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Subject Name',
                            border: OutlineInputBorder(),
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 10, vertical: 10),
                          ),
                        ),
                      ),
                    ]),
                  ],
                  const SizedBox(height: 14),

                  // ── L/T/P + Unit/Exp ──────────────────────────────────
                  Row(children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('L / T / P',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<String>(
                            value: ltpType,
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 10),
                            ),
                            hint: const Text('Select'),
                            items: const ['L', 'T', 'P']
                                .map((v) =>
                                    DropdownMenuItem(value: v, child: Text(v)))
                                .toList(),
                            onChanged: (v) => setDlg(() => ltpType = v),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Unit / Exp No.',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<String>(
                            value: unitExpNo,
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 10),
                            ),
                            hint: const Text('Select'),
                            items: List.generate(
                                6,
                                (i) => DropdownMenuItem(
                                    value: '${i + 1}',
                                    child: Text('${i + 1}'))).toList(),
                            onChanged: (v) => setDlg(() => unitExpNo = v),
                          ),
                        ],
                      ),
                    ),
                  ]),
                  const SizedBox(height: 12),

                  // ── Topic ─────────────────────────────────────────────
                  const Text('Topic Covered',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: topicCtrl,
                    decoration: const InputDecoration(
                      hintText: 'Optional',
                      border: OutlineInputBorder(),
                      isDense: true,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ── Periods ───────────────────────────────────────────
                  const Text('Periods',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: List.generate(9, (i) {
                      return FilterChip(
                        label: Text(periodLabels[i],
                            style: const TextStyle(fontSize: 11)),
                        selected: periodsSelected[i],
                        selectedColor:
                            const Color(0xFF1e3a5f).withOpacity(0.18),
                        checkmarkColor: const Color(0xFF1e3a5f),
                        onSelected: (v) => setDlg(() => periodsSelected[i] = v),
                      );
                    }),
                  ),
                  const SizedBox(height: 12),

                  // ── Status ────────────────────────────────────────────
                  const Text('Status',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Row(children: [
                    ChoiceChip(
                      label: const Text('Present'),
                      selected: isPresent,
                      selectedColor: Colors.green.withOpacity(0.2),
                      onSelected: (_) => setDlg(() => isPresent = true),
                    ),
                    const SizedBox(width: 10),
                    ChoiceChip(
                      label: const Text('Absent'),
                      selected: !isPresent,
                      selectedColor: Colors.red.withOpacity(0.2),
                      onSelected: (_) => setDlg(() => isPresent = false),
                    ),
                  ]),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                final needsManual = assignments.isEmpty;
                if (needsManual && manualCodeCtrl.text.trim().isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(
                        content: Text('Subject Code is required.'),
                        backgroundColor: Colors.orange),
                  );
                  return;
                }
                if (!needsManual && selectedAssignment == null) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(
                        content: Text('Please select a subject.'),
                        backgroundColor: Colors.orange),
                  );
                  return;
                }
                Navigator.pop(ctx, true);
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1e3a5f)),
              child: const Text('Save', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;

    try {
      // Resolve subject details from selection or manual entry
      final String subCode;
      final String subName;
      final String facultyId;
      final String department;
      final int year;
      final String semester;
      final List<String> batches;

      if (assignments.isNotEmpty && selectedAssignment != null) {
        subCode = selectedAssignment!['subjectCode'] as String;
        subName = selectedAssignment!['subjectName'] as String;
        facultyId = selectedAssignment!['facultyId'] as String;
        department = selectedAssignment!['department'] as String;
        year = selectedAssignment!['year'] as int;
        semester = selectedAssignment!['semester'] as String;
        batches = selectedAssignment!['batches'] as List<String>;
      } else {
        subCode = manualCodeCtrl.text.trim().toUpperCase();
        subName = manualNameCtrl.text.trim();
        facultyId = 'ADMIN';
        department = '';
        year = 0;
        semester = '';
        batches = [_batchNumber ?? ''];
      }

      final dateStr = DateFormat('dd-MM-yyyy').format(selectedDate);
      final periods = <int>[];
      for (var i = 0; i < periodsSelected.length; i++) {
        if (periodsSelected[i]) periods.add(i + 1);
      }

      await widget.firestore.collection('attendance').add({
        'dateStr': dateStr,
        'date': Timestamp.fromDate(
            DateTime(selectedDate.year, selectedDate.month, selectedDate.day)),
        'facultyId': facultyId,
        'subjectCode': subCode,
        'subjectName': subName,
        'department': department,
        'year': year,
        'semester': semester,
        'batches': batches,
        'ltpType': ltpType ?? '',
        'topicCovered': topicCtrl.text.trim(),
        'unitExpNo': unitExpNo ?? '',
        'periods': periods,
        'students': [
          {
            'rollNo': roll,
            'name': _studentName ?? '',
            'hallTicketNumber': _hallTicket ?? '',
            'batchNumber': _batchNumber ?? '',
            'present': isPresent,
          }
        ],
        'totalStudents': 1,
        'presentCount': isPresent ? 1 : 0,
        'absentCount': isPresent ? 0 : 1,
        'adminAdded': true,
        'submittedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Attendance added: $subCode  $dateStr  —  '
              '${isPresent ? 'Present' : 'Absent'}'),
          backgroundColor: Colors.green,
        ));
        _search();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  // Small label+value chip used inside the assignment meta row
  Widget _metaChip(String label, String value) => RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 11, color: Colors.black87),
          children: [
            TextSpan(
                text: '$label: ',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            TextSpan(text: value.isEmpty ? '—' : value),
          ],
        ),
      );

  Future<void> _editByDate() async {
    final roll = _rollCtrl.text.trim().toUpperCase();
    if (roll.isEmpty || _studentName == null) return;

    // 1 ── pick a date ───────────────────────────────────────────────────
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2099),
    );
    if (picked == null) return;

    final pickedStr = DateFormat('dd-MM-yyyy').format(picked);

    // 2 ── filter loaded records for that date ──────────────────────────
    final dayRecords = _allRecords
        .where((r) => (r['dateStr'] as String?) == pickedStr)
        .toList();

    if (dayRecords.isEmpty) {
      // No faculty record for this date — ask if admin wants to add one
      if (!mounted) return;
      final wantAdd = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('No Records on $pickedStr'),
          content: Text(
            'No attendance was submitted by faculty for $roll on $pickedStr.\n\n'
            'Would you like to add attendance for this date manually?',
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1e3a5f)),
              child: const Text('Add Attendance',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
      if (wantAdd == true) _addAttendance(initialDate: picked);
      return;
    }

    // 3 ── build mutable present-map  docId → isPresent ─────────────────
    final Map<String, bool> presentMap = {
      for (final r in dayRecords) r['docId'] as String: r['present'] as bool,
    };

    // 4 ── show edit dialog ──────────────────────────────────────────────
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: Text('Attendance on $pickedStr'),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Student: $_studentName  ($roll)',
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 14),
                  const Divider(height: 1),
                  ...dayRecords.map((r) {
                    final docId = r['docId'] as String;
                    final subCode = r['subjectCode'] as String;
                    final subName = r['subjectName'] as String? ?? '';
                    final ltp = r['ltpType'] as String? ?? '—';
                    final topic = r['topicCovered'] as String? ?? '—';
                    final isPresent = presentMap[docId]!;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '$subCode${subName.isNotEmpty ? '  —  $subName' : ''}',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'L/T/P: $ltp  •  Topic: $topic',
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey.shade600),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Row(children: [
                                ChoiceChip(
                                  label: const Text('Present'),
                                  selected: isPresent,
                                  selectedColor: Colors.green.withOpacity(0.2),
                                  onSelected: (_) =>
                                      setDlg(() => presentMap[docId] = true),
                                ),
                                const SizedBox(width: 6),
                                ChoiceChip(
                                  label: const Text('Absent'),
                                  selected: !isPresent,
                                  selectedColor: Colors.red.withOpacity(0.2),
                                  onSelected: (_) =>
                                      setDlg(() => presentMap[docId] = false),
                                ),
                              ]),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Divider(height: 1),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1e3a5f)),
              child:
                  const Text('Save All', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;

    // 5 ── persist changes ───────────────────────────────────────────────
    try {
      for (final r in dayRecords) {
        final docId = r['docId'] as String;
        final newPresent = presentMap[docId]!;
        if (newPresent == (r['present'] as bool)) continue; // no change

        final docSnap =
            await widget.firestore.collection('attendance').doc(docId).get();
        if (!docSnap.exists) continue;

        final data = docSnap.data()!;
        final students = List<Map<String, dynamic>>.from(
            (data['students'] as List)
                .map((s) => Map<String, dynamic>.from(s as Map)));

        for (final s in students) {
          if ((s['rollNo'] as String?)?.toUpperCase() == roll) {
            s['present'] = newPresent;
            break;
          }
        }

        final presentCount = students.where((s) => s['present'] == true).length;
        final absentCount = students.length - presentCount;

        await widget.firestore.collection('attendance').doc(docId).update({
          'students': students,
          'presentCount': presentCount,
          'absentCount': absentCount,
          'adminEditedAt': FieldValue.serverTimestamp(),
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'Attendance updated for $pickedStr (${dayRecords.length} record(s)).'),
          backgroundColor: Colors.green,
        ));
        _search();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  /// Show a dialog to flip present/absent for this student in one record
  /// and persist the change to Firestore.
  Future<void> _editStudentAttendance(Map<String, dynamic> record) async {
    final roll = _rollCtrl.text.trim().toUpperCase();
    final docId = record['docId'] as String;
    bool isPresent = record['present'] as bool;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDlg) => AlertDialog(
            title:
                Text('Edit: ${record['subjectCode']}  •  ${record['dateStr']}'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Student: $_studentName  ($roll)',
                    style: const TextStyle(fontSize: 13)),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Text('Status:', style: TextStyle(fontSize: 14)),
                    const SizedBox(width: 16),
                    ChoiceChip(
                      label: const Text('Present'),
                      selected: isPresent,
                      selectedColor: Colors.green.withOpacity(0.2),
                      onSelected: (_) => setDlg(() => isPresent = true),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('Absent'),
                      selected: !isPresent,
                      selectedColor: Colors.red.withOpacity(0.2),
                      onSelected: (_) => setDlg(() => isPresent = false),
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1e3a5f)),
                child:
                    const Text('Save', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
      },
    );

    if (confirmed != true) return;

    try {
      // Fetch the full attendance doc, flip this student's present flag
      final docSnap =
          await widget.firestore.collection('attendance').doc(docId).get();
      if (!docSnap.exists) return;
      final data = docSnap.data()!;
      final students = List<Map<String, dynamic>>.from(
          (data['students'] as List)
              .map((s) => Map<String, dynamic>.from(s as Map)));

      for (final s in students) {
        if ((s['rollNo'] as String?)?.toUpperCase() == roll) {
          s['present'] = isPresent;
          break;
        }
      }

      final presentCount = students.where((s) => s['present'] == true).length;
      final absentCount = students.length - presentCount;

      await widget.firestore.collection('attendance').doc(docId).update({
        'students': students,
        'presentCount': presentCount,
        'absentCount': absentCount,
        'adminEditedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              '${record['subjectCode']} ${record['dateStr']}: marked ${isPresent ? 'Present' : 'Absent'}'),
          backgroundColor: isPresent ? Colors.green : Colors.red,
        ));
        // Refresh the entire student search to reflect updated stats
        _search();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// TAB 3 — Faculty Edit Requests (approve / reject)
// ═══════════════════════════════════════════════════════════════════════════

class _RequestsTab extends StatefulWidget {
  const _RequestsTab({required this.firestore});
  final FirebaseFirestore firestore;
  @override
  State<_RequestsTab> createState() => _RequestsTabState();
}

class _RequestsTabState extends State<_RequestsTab>
    with SingleTickerProviderStateMixin {
  late TabController _inner;

  @override
  void initState() {
    super.initState();
    _inner = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _inner.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Material(
          color: Colors.grey.shade200,
          child: TabBar(
            controller: _inner,
            indicatorColor: const Color(0xFF1e3a5f),
            labelColor: const Color(0xFF1e3a5f),
            unselectedLabelColor: Colors.grey,
            tabs: const [
              Tab(text: 'Pending'),
              Tab(text: 'History'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _inner,
            children: [
              _RequestList(
                  firestore: widget.firestore,
                  statusFilter: 'pending',
                  emptyMessage: 'No pending edit requests.',
                  showActions: true),
              _RequestList(
                  firestore: widget.firestore,
                  statusFilter: null,
                  emptyMessage: 'No past requests.',
                  showActions: false),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Reusable request list (pending / history)
// ─────────────────────────────────────────────────────────────────────────────

class _RequestList extends StatefulWidget {
  const _RequestList({
    required this.firestore,
    required this.statusFilter,
    required this.emptyMessage,
    required this.showActions,
  });

  final FirebaseFirestore firestore;
  final String? statusFilter;
  final String emptyMessage;
  final bool showActions;

  @override
  State<_RequestList> createState() => _RequestListState();
}

class _RequestListState extends State<_RequestList> {
  late final Stream<QuerySnapshot> _stream;

  @override
  void initState() {
    super.initState();
    final col = widget.firestore.collection('attendanceEditRequests');
    if (widget.statusFilter != null) {
      _stream = col.where('status', isEqualTo: widget.statusFilter).snapshots();
    } else {
      _stream =
          col.where('status', whereIn: ['approved', 'rejected']).snapshots();
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _stream,
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(child: Text('Error: ${snap.error}'));
        }
        final docs = List<QueryDocumentSnapshot>.from(snap.data?.docs ?? []);
        docs.sort((a, b) {
          final aTs = (a.data() as Map<String, dynamic>)['requestedAt'];
          final bTs = (b.data() as Map<String, dynamic>)['requestedAt'];
          if (aTs == null && bTs == null) return 0;
          if (aTs == null) return 1;
          if (bTs == null) return -1;
          return (bTs as Timestamp).compareTo(aTs as Timestamp);
        });
        if (docs.isEmpty) {
          return Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.assignment_outlined,
                  size: 64, color: Colors.grey.shade400),
              const SizedBox(height: 12),
              Text(widget.emptyMessage,
                  style: TextStyle(fontSize: 15, color: Colors.grey.shade600)),
            ]),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          itemBuilder: (ctx, i) => _RequestCard(
            doc: docs[i],
            showActions: widget.showActions,
            firestore: widget.firestore,
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Card for a single edit request
// ─────────────────────────────────────────────────────────────────────────────

class _RequestCard extends StatelessWidget {
  const _RequestCard({
    required this.doc,
    required this.showActions,
    required this.firestore,
  });

  final QueryDocumentSnapshot doc;
  final bool showActions;
  final FirebaseFirestore firestore;

  Map<String, dynamic> get _data => doc.data() as Map<String, dynamic>;

  String get _facultyId => _data['facultyId'] as String? ?? '—';
  String get _subjectCode => _data['subjectCode'] as String? ?? '—';
  String get _subjectName => _data['subjectName'] as String? ?? '';
  String get _fromDateStr => _data['fromDateStr'] as String? ?? '—';
  String get _toDateStr => _data['toDateStr'] as String? ?? '—';
  String get _reason => _data['reason'] as String? ?? '—';
  String get _status => _data['status'] as String? ?? 'pending';
  String get _adminNote => _data['adminNote'] as String? ?? '';
  Timestamp? get _requestedAt => _data['requestedAt'] as Timestamp?;

  Color get _statusColor {
    switch (_status) {
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  String get _statusLabel {
    switch (_status) {
      case 'approved':
        return 'Approved';
      case 'rejected':
        return 'Rejected';
      default:
        return 'Pending';
    }
  }

  @override
  Widget build(BuildContext context) {
    final submittedAt = _requestedAt != null
        ? DateFormat('dd-MM-yyyy HH:mm').format(_requestedAt!.toDate())
        : '—';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$_subjectCode${_subjectName.isNotEmpty ? ' — $_subjectName' : ''}',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 2),
                    Text('Faculty: $_facultyId',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade700)),
                  ]),
            ),
            _statusChip(_statusLabel, _statusColor),
          ]),
          const SizedBox(height: 10),
          _infoRow(
              Icons.date_range, 'Date range: $_fromDateStr  →  $_toDateStr'),
          _infoRow(Icons.access_time, 'Requested: $submittedAt'),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(6),
            ),
            child:
                Text('Reason: $_reason', style: const TextStyle(fontSize: 13)),
          ),
          if (_adminNote.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _statusColor.withOpacity(0.08),
                border: Border.all(color: _statusColor.withOpacity(0.3)),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text('Admin note: $_adminNote',
                  style: TextStyle(
                      fontSize: 13, color: _statusColor.withOpacity(0.9))),
            ),
          ],
          if (showActions) ...[
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              OutlinedButton.icon(
                onPressed: () => _showActionDialog(context, false),
                icon: const Icon(Icons.close, size: 16),
                label: const Text('Reject'),
                style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red)),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: () => _showActionDialog(context, true),
                icon: const Icon(Icons.check, size: 16),
                label: const Text('Approve'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white),
              ),
            ]),
          ],
        ]),
      ),
    );
  }

  Future<void> _showActionDialog(BuildContext context, bool approve) async {
    final noteCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(approve ? 'Approve Request' : 'Reject Request'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(
            approve
                ? 'Allow $_facultyId to edit $_subjectCode from $_fromDateStr to $_toDateStr?'
                : 'Reject edit request from $_facultyId for $_subjectCode?',
            style: const TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: noteCtrl,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: approve ? 'Note (optional)' : 'Reason for rejection *',
              border: const OutlineInputBorder(),
            ),
          ),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: approve ? Colors.green : Colors.red),
            child: Text(approve ? 'Approve' : 'Reject',
                style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await firestore.collection('attendanceEditRequests').doc(doc.id).update({
        'status': approve ? 'approved' : 'rejected',
        'adminNote': noteCtrl.text.trim(),
        'resolvedAt': FieldValue.serverTimestamp(),
      });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(approve ? 'Request approved.' : 'Request rejected.'),
          backgroundColor: approve ? Colors.green : Colors.red,
        ));
      }
    }
  }

  Widget _statusChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        border: Border.all(color: color.withOpacity(0.5)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 12, fontWeight: FontWeight.bold)),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(children: [
        Icon(icon, size: 14, color: Colors.grey),
        const SizedBox(width: 6),
        Expanded(
            child: Text(text,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700))),
      ]),
    );
  }
}
