import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../../widgets/app_header.dart';

class ViewUpdateDeleteAttendanceScreen extends StatefulWidget {
  const ViewUpdateDeleteAttendanceScreen({super.key});

  @override
  State<ViewUpdateDeleteAttendanceScreen> createState() =>
      _ViewUpdateDeleteAttendanceScreenState();
}

class _ViewUpdateDeleteAttendanceScreenState
    extends State<ViewUpdateDeleteAttendanceScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  DateTime _selectedDate = DateTime.now();

  /// All attendance docs (facultyId == me) for _selectedDate
  List<QueryDocumentSnapshot> _docs = [];
  bool _isLoading = false;

  /// Currently-expanded doc id (for inline edit)
  String? _expandedDocId;

  /// Edited student attendance map: docId -> rollNo -> present
  final Map<String, Map<String, bool>> _editedAttendance = {};

  String get _facultyId =>
      FirebaseAuth.instance.currentUser?.email?.split('@')[0].toUpperCase() ??
      '';

  String _dateStr(DateTime d) => DateFormat('dd-MM-yyyy').format(d);

  bool get _isToday {
    final n = DateTime.now();
    return _selectedDate.year == n.year &&
        _selectedDate.month == n.month &&
        _selectedDate.day == n.day;
  }

  bool get _canEdit => _isToday && DateTime.now().hour < 18;

  @override
  @override
  void initState() {
    super.initState();
    _loadDocs();
  }

  Future<void> _loadDocs() async {
    setState(() => _isLoading = true);
    try {
      final snap = await _firestore
          .collection('attendance')
          .where('facultyId', isEqualTo: _facultyId)
          .where('dateStr', isEqualTo: _dateStr(_selectedDate))
          .get();
      setState(() {
        _docs = snap.docs;
        _expandedDocId = null;
        _editedAttendance.clear();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error loading records: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── helpers ──────────────────────────────────────────────────────────────

  String _timeLeftStr() {
    final now = DateTime.now();
    final cutoff = DateTime(now.year, now.month, now.day, 18);
    final diff = cutoff.difference(now);
    if (diff.isNegative) return '';
    final h = diff.inHours;
    final m = diff.inMinutes.remainder(60);
    return h > 0 ? '${h}h ${m}m left' : '${m}m left';
  }

  // ── build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('View | Update | Delete Attendance'),
        backgroundColor: const Color(0xFF1e3a5f),
        foregroundColor: Colors.white,
        actions: [
          if (!_isToday)
            Tooltip(
              message: 'Request edit access for past dates',
              child: IconButton(
                icon: const Icon(Icons.edit_calendar),
                onPressed: _showRequestAccessDialog,
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AppHeader(),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDatePicker(),
                  const SizedBox(height: 12),
                  if (_isToday && !_canEdit) _buildAfter6Banner(),
                  if (_isToday && _canEdit) _buildEditWindowBanner(),
                  if (!_isToday) _buildPastDateBanner(),
                  const SizedBox(height: 12),
                  if (_isLoading)
                    const Center(child: CircularProgressIndicator())
                  else if (_docs.isEmpty)
                    _buildEmptyState()
                  else
                    ..._docs.map((doc) => _buildDocCard(doc)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── date picker ──────────────────────────────────────────────────────────

  Widget _buildDatePicker() {
    return Card(
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: _pickDate,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              const Icon(Icons.calendar_today, color: Color(0xFF1e3a5f)),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  DateFormat('EEEE, d MMMM yyyy').format(_selectedDate),
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
              if (_isToday)
                _chip('TODAY', Colors.green)
              else
                _chip(
                    DateFormat('MMM d').format(_selectedDate), Colors.blueGrey),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: Color(0xFF1e3a5f)),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
      _loadDocs();
    }
  }

  // ── banners ──────────────────────────────────────────────────────────────

  Widget _buildEditWindowBanner() {
    return _banner(
      color: Colors.green.shade50,
      borderColor: Colors.green,
      icon: Icons.lock_open,
      iconColor: Colors.green,
      text:
          'Today\'s attendance can be edited until 6:00 PM  •  ${_timeLeftStr()}',
    );
  }

  Widget _buildAfter6Banner() {
    return _banner(
      color: Colors.orange.shade50,
      borderColor: Colors.orange,
      icon: Icons.lock,
      iconColor: Colors.orange,
      text:
          'Edit window has closed for today (after 6:00 PM). You can view records only.',
    );
  }

  Widget _buildPastDateBanner() {
    return _banner(
      color: Colors.blue.shade50,
      borderColor: Colors.blue,
      icon: Icons.info_outline,
      iconColor: Colors.blue,
      text:
          'Past date — view only. Use ✏ button in the app bar to request edit access from admin.',
    );
  }

  Widget _banner({
    required Color color,
    required Color borderColor,
    required IconData icon,
    required Color iconColor,
    required String text,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color,
        border: Border.all(color: borderColor.withOpacity(0.4)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(children: [
        Icon(icon, color: iconColor, size: 18),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
      ]),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Column(
          children: [
            Icon(Icons.assignment_outlined,
                size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text('No attendance records found for this date.',
                style: TextStyle(fontSize: 15, color: Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }

  // ── doc card ─────────────────────────────────────────────────────────────

  Widget _buildDocCard(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final subjectCode = data['subjectCode'] as String? ?? '';
    final subjectName = data['subjectName'] as String? ?? '';
    final batches = List<String>.from(data['batches'] as List? ?? []);
    final periods = List<dynamic>.from(data['periods'] as List? ?? []);
    final ltpType = data['ltpType'] as String? ?? '';
    final topicCovered = data['topicCovered'] as String? ?? '';
    final present = (data['presentCount'] as int?) ?? 0;
    final absent = (data['absentCount'] as int?) ?? 0;
    final total = present + absent;

    final isExpanded = _expandedDocId == doc.id;
    final isEditing = _editedAttendance.containsKey(doc.id);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Column(
        children: [
          // ── header row ─────────────────────────────────────────────────
          InkWell(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
            onTap: () =>
                setState(() => _expandedDocId = isExpanded ? null : doc.id),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '$subjectCode — $subjectName',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ),
                      Icon(
                        isExpanded ? Icons.expand_less : Icons.expand_more,
                        color: Colors.grey,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      _chip(ltpType, const Color(0xFF1e3a5f)),
                      ...periods.map((p) => _chip('P$p', Colors.teal)),
                      ...batches.map((b) => _chip(b, Colors.indigo)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _statBadge('P', '$present', Colors.green),
                      const SizedBox(width: 8),
                      _statBadge('A', '$absent', Colors.red),
                      const SizedBox(width: 8),
                      _statBadge('T', '$total', Colors.blueGrey),
                      const Spacer(),
                      if (total > 0)
                        Text(
                          '${(present / total * 100).toStringAsFixed(0)}%',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1e3a5f)),
                        ),
                    ],
                  ),
                  if (topicCovered.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text('Topic: $topicCovered',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade700)),
                  ],
                ],
              ),
            ),
          ),

          // ── action buttons (today-only) ─────────────────────────────
          if (_isToday && _canEdit)
            Container(
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextButton.icon(
                      onPressed: () => _startEdit(doc),
                      icon: const Icon(Icons.edit, size: 16),
                      label: const Text('Update'),
                      style:
                          TextButton.styleFrom(foregroundColor: Colors.orange),
                    ),
                  ),
                  Container(width: 1, height: 36, color: Colors.grey.shade200),
                  Expanded(
                    child: TextButton.icon(
                      onPressed: () => _showDeleteDialog(doc),
                      icon: const Icon(Icons.delete_outline, size: 16),
                      label: const Text('Delete'),
                      style: TextButton.styleFrom(foregroundColor: Colors.red),
                    ),
                  ),
                ],
              ),
            ),

          // ── expanded student list ────────────────────────────────────
          if (isExpanded) _buildStudentList(doc, isEditing),
        ],
      ),
    );
  }

  // ── student list ─────────────────────────────────────────────────────────

  Widget _buildStudentList(QueryDocumentSnapshot doc, bool isEditing) {
    final data = doc.data() as Map<String, dynamic>;
    final rawStudents = List<Map<String, dynamic>>.from(
        (data['students'] as List? ?? [])
            .map((s) => Map<String, dynamic>.from(s as Map)));

    // Build editable map if needed
    final editMap = _editedAttendance[doc.id];

    return Column(
      children: [
        Divider(height: 1, color: Colors.grey.shade200),
        if (isEditing)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              children: [
                const Expanded(
                  child: Text('Editing — tap to toggle presence',
                      style: TextStyle(fontSize: 12, color: Colors.orange)),
                ),
                TextButton(
                    onPressed: () => _saveEdit(doc), child: const Text('Save')),
                TextButton(
                    onPressed: () =>
                        setState(() => _editedAttendance.remove(doc.id)),
                    child: const Text('Cancel',
                        style: TextStyle(color: Colors.grey))),
              ],
            ),
          ),
        ...rawStudents.map((s) {
          final rollNo = s['rollNo'] as String? ?? '';
          final name = s['name'] as String? ?? '';
          final ht = s['hallTicketNumber'] as String? ?? '';
          final batch = s['batchNumber'] as String? ?? '';
          final present = editMap != null
              ? (editMap[rollNo] ?? (s['present'] as bool? ?? false))
              : (s['present'] as bool? ?? false);

          return ListTile(
            dense: true,
            leading: CircleAvatar(
              radius: 16,
              backgroundColor: present ? Colors.green : Colors.red,
              child: Icon(
                present ? Icons.check : Icons.close,
                size: 14,
                color: Colors.white,
              ),
            ),
            title: Text(name, style: const TextStyle(fontSize: 13)),
            subtitle: Text('$rollNo  •  $ht  •  Batch $batch',
                style: const TextStyle(fontSize: 11)),
            trailing: isEditing
                ? Switch(
                    value: present,
                    activeColor: Colors.green,
                    onChanged: (v) {
                      setState(() {
                        _editedAttendance[doc.id]![rollNo] = v;
                      });
                    },
                  )
                : _chip(
                    present ? 'P' : 'A', present ? Colors.green : Colors.red),
          );
        }),
        const SizedBox(height: 8),
      ],
    );
  }

  // ── edit ─────────────────────────────────────────────────────────────────

  void _startEdit(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final students = List<Map<String, dynamic>>.from(
        (data['students'] as List? ?? [])
            .map((s) => Map<String, dynamic>.from(s as Map)));
    final map = <String, bool>{};
    for (final s in students) {
      final rollNo = s['rollNo'] as String? ?? '';
      map[rollNo] = s['present'] as bool? ?? false;
    }
    setState(() {
      _editedAttendance[doc.id] = map;
      _expandedDocId = doc.id;
    });
  }

  Future<void> _saveEdit(QueryDocumentSnapshot doc) async {
    final editMap = _editedAttendance[doc.id];
    if (editMap == null) return;

    final data = doc.data() as Map<String, dynamic>;
    final students = List<Map<String, dynamic>>.from(
        (data['students'] as List? ?? [])
            .map((s) => Map<String, dynamic>.from(s as Map)));

    for (final s in students) {
      final rollNo = s['rollNo'] as String? ?? '';
      if (editMap.containsKey(rollNo)) {
        s['present'] = editMap[rollNo];
      }
    }

    final presentCount = students.where((s) => s['present'] == true).length;
    final absentCount = students.length - presentCount;

    try {
      await _firestore.collection('attendance').doc(doc.id).update({
        'students': students,
        'presentCount': presentCount,
        'absentCount': absentCount,
        'lastModifiedAt': FieldValue.serverTimestamp(),
        'lastModifiedBy': _facultyId,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Attendance updated successfully.'),
          backgroundColor: Colors.green,
        ));
      }
      _editedAttendance.remove(doc.id);
      _loadDocs();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Update failed: $e')));
      }
    }
  }

  // ── delete ────────────────────────────────────────────────────────────────

  Future<void> _showDeleteDialog(QueryDocumentSnapshot doc) async {
    final data = doc.data() as Map<String, dynamic>;
    final batches = List<String>.from(data['batches'] as List? ?? []);
    final subjectCode = data['subjectCode'] as String? ?? '';

    if (batches.length == 1) {
      // Single batch → confirm full delete
      final ok = await _confirmDialog(
        title: 'Delete Attendance',
        content:
            'Delete all attendance for $subjectCode / ${batches.first}?\nThis cannot be undone.',
      );
      if (ok == true) await _deleteDoc(doc);
      return;
    }

    // Multiple batches → let faculty choose which batch to remove
    String? chosenBatch;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) {
        return AlertDialog(
          title: const Text('Select Batch to Delete'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: batches.map((b) {
              return RadioListTile<String>(
                title: Text(b),
                value: b,
                groupValue: chosenBatch,
                onChanged: (v) => setS(() => chosenBatch = v),
              );
            }).toList(),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed:
                  chosenBatch != null ? () => Navigator.pop(ctx, true) : null,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Delete Batch'),
            ),
          ],
        );
      }),
    );

    if (ok == true && chosenBatch != null) {
      await _deleteBatchFromDoc(doc, chosenBatch!);
    }
  }

  Future<void> _deleteDoc(QueryDocumentSnapshot doc) async {
    try {
      await _firestore.collection('attendance').doc(doc.id).delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Attendance record deleted.'),
          backgroundColor: Colors.green,
        ));
      }
      _loadDocs();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Delete failed: $e')));
      }
    }
  }

  Future<void> _deleteBatchFromDoc(
      QueryDocumentSnapshot doc, String batch) async {
    final data = doc.data() as Map<String, dynamic>;
    final batches = List<String>.from(data['batches'] as List? ?? [])
      ..remove(batch);
    final students = List<Map<String, dynamic>>.from(
        (data['students'] as List? ?? [])
            .map((s) => Map<String, dynamic>.from(s as Map)))
      ..removeWhere((s) => s['batchNumber'] == batch);
    final presentCount = students.where((s) => s['present'] == true).length;
    final absentCount = students.length - presentCount;

    try {
      await _firestore.collection('attendance').doc(doc.id).update({
        'batches': batches,
        'students': students,
        'presentCount': presentCount,
        'absentCount': absentCount,
        'lastModifiedAt': FieldValue.serverTimestamp(),
        'lastModifiedBy': _facultyId,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Batch $batch removed.'),
          backgroundColor: Colors.green,
        ));
      }
      _loadDocs();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Delete failed: $e')));
      }
    }
  }

  Future<bool?> _confirmDialog(
      {required String title, required String content}) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  // ── admin edit request ────────────────────────────────────────────────────

  Future<void> _showRequestAccessDialog() async {
    final reasonCtrl = TextEditingController();
    String? selectedSubject;
    DateTime? fromDate;
    DateTime? toDate;

    // Gather subjects the faculty has submitted before
    final subjectsSnap = await _firestore
        .collection('attendance')
        .where('facultyId', isEqualTo: _facultyId)
        .get();
    final subjects = <String>{};
    for (final d in subjectsSnap.docs) {
      final data = d.data();
      final code = data['subjectCode'] as String?;
      if (code != null) subjects.add(code);
    }

    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) {
        return AlertDialog(
          title: const Text('Request Edit Access'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Request admin permission to edit past attendance records.',
                  style: TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 16),
                // Subject dropdown
                DropdownButtonFormField<String>(
                  value: selectedSubject,
                  decoration: const InputDecoration(
                    labelText: 'Subject *',
                    border: OutlineInputBorder(),
                  ),
                  items: subjects.map((s) {
                    return DropdownMenuItem(value: s, child: Text(s));
                  }).toList(),
                  onChanged: (v) => setS(() => selectedSubject = v),
                ),
                const SizedBox(height: 12),
                // From Date
                OutlinedButton.icon(
                  onPressed: () async {
                    final p = await showDatePicker(
                      context: ctx,
                      initialDate: fromDate ??
                          DateTime.now().subtract(const Duration(days: 7)),
                      firstDate:
                          DateTime.now().subtract(const Duration(days: 365)),
                      lastDate:
                          DateTime.now().subtract(const Duration(days: 1)),
                    );
                    if (p != null) setS(() => fromDate = p);
                  },
                  icon: const Icon(Icons.calendar_today, size: 16),
                  label: Text(fromDate != null
                      ? 'From: ${DateFormat('dd-MM-yyyy').format(fromDate!)}'
                      : 'Select From Date *'),
                ),
                const SizedBox(height: 8),
                // To Date
                OutlinedButton.icon(
                  onPressed: () async {
                    final p = await showDatePicker(
                      context: ctx,
                      initialDate: toDate ?? (fromDate ?? DateTime.now()),
                      firstDate: fromDate ??
                          DateTime.now().subtract(const Duration(days: 365)),
                      lastDate:
                          DateTime.now().subtract(const Duration(days: 1)),
                    );
                    if (p != null) setS(() => toDate = p);
                  },
                  icon: const Icon(Icons.calendar_today, size: 16),
                  label: Text(toDate != null
                      ? 'To: ${DateFormat('dd-MM-yyyy').format(toDate!)}'
                      : 'Select To Date *'),
                ),
                const SizedBox(height: 12),
                // Reason
                TextField(
                  controller: reasonCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Reason *',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1e3a5f)),
              onPressed: (selectedSubject != null &&
                      fromDate != null &&
                      toDate != null &&
                      reasonCtrl.text.trim().isNotEmpty)
                  ? () async {
                      Navigator.pop(ctx);
                      await _submitEditRequest(
                        subjectCode: selectedSubject!,
                        fromDate: fromDate!,
                        toDate: toDate!,
                        reason: reasonCtrl.text.trim(),
                      );
                    }
                  : null,
              child:
                  const Text('Submit', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      }),
    );
  }

  Future<void> _submitEditRequest({
    required String subjectCode,
    required DateTime fromDate,
    required DateTime toDate,
    required String reason,
  }) async {
    try {
      // Fetch subjectName
      final assignSnap = await _firestore
          .collection('facultyAssignments')
          .where('facultyId', isEqualTo: _facultyId)
          .where('subjectCode', isEqualTo: subjectCode)
          .limit(1)
          .get();
      final subjectName = assignSnap.docs.isNotEmpty
          ? (assignSnap.docs.first.data()['subjectName'] as String? ?? '')
          : '';

      await _firestore.collection('attendanceEditRequests').add({
        'facultyId': _facultyId,
        'subjectCode': subjectCode,
        'subjectName': subjectName,
        'fromDateStr': _dateStr(fromDate),
        'toDateStr': _dateStr(toDate),
        'fromDate': Timestamp.fromDate(fromDate),
        'toDate': Timestamp.fromDate(toDate),
        'reason': reason,
        'status': 'pending',
        'requestedAt': FieldValue.serverTimestamp(),
        'adminNote': '',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Edit access request sent to admin.'),
          backgroundColor: Colors.green,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Request failed: $e')));
      }
    }
  }

  // ── small helpers ────────────────────────────────────────────────────────

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(label,
          style: const TextStyle(
              color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }

  Widget _statBadge(String prefix, String value, Color color) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Text(prefix,
          style: TextStyle(
              fontSize: 12, color: color, fontWeight: FontWeight.bold)),
      const SizedBox(width: 2),
      Text(value,
          style: TextStyle(
              fontSize: 14, fontWeight: FontWeight.bold, color: color)),
    ]);
  }
}
