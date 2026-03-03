import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

/// Admin: Makeup Mid Exam Management
/// - Tab 1 (Windows): create/edit makeup mid windows, assign faculty per subject
/// - Tab 2 (Registrations): view student registrations per window
/// - Tab 3 (Marks): view marks entered by faculty, release results
class MakeupMidManagementPage extends StatefulWidget {
  final int initialTab;
  const MakeupMidManagementPage({super.key, this.initialTab = 0});

  @override
  State<MakeupMidManagementPage> createState() =>
      _MakeupMidManagementPageState();
}

class _MakeupMidManagementPageState extends State<MakeupMidManagementPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _tabController =
        TabController(length: 3, vsync: this, initialIndex: widget.initialTab);
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
        title: const Text('Makeup Mid Exam Management'),
        backgroundColor: const Color(0xFF1e3a5f),
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Windows'),
            Tab(text: 'Registrations'),
            Tab(text: 'Marks'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _MakeupWindowsTab(firestore: _firestore),
          _MakeupRegistrationsTab(firestore: _firestore),
          _MakeupMarksTab(firestore: _firestore),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Tab 1 — Makeup Mid Windows
// ═══════════════════════════════════════════════════════════════════════════

class _MakeupWindowsTab extends StatelessWidget {
  final FirebaseFirestore firestore;
  const _MakeupWindowsTab({required this.firestore});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: firestore
          .collection('makeupMidWindows')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snap.data?.docs ?? [];
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const Text('Makeup Mid Windows',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  ElevatedButton.icon(
                    onPressed: () => _showCreateDialog(context, null),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('New Window'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1e3a5f),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            if (docs.isEmpty)
              const Expanded(
                child: Center(
                  child: Text('No makeup mid windows yet.\nCreate one above.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey)),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: docs.length,
                  itemBuilder: (_, i) => _MakeupWindowCard(
                    firestore: firestore,
                    doc: docs[i],
                    onEdit: () => _showCreateDialog(context, docs[i]),
                    onAssignFaculty: () =>
                        _showFacultyAssignDialog(context, docs[i]),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Future<void> _showCreateDialog(
      BuildContext context, QueryDocumentSnapshot? existing) async {
    final data = existing?.data() as Map<String, dynamic>?;
    final titleCtrl = TextEditingController(text: data?['title'] ?? '');
    final sessionCtrl = TextEditingController(text: data?['examSession'] ?? '');
    final maxMarksCtrl = TextEditingController(
        text: (data?['maxMarks'] as num?)?.toString() ?? '30');
    DateTime? startDate = (data?['startDate'] as Timestamp?)?.toDate();
    DateTime? endDate = (data?['endDate'] as Timestamp?)?.toDate();
    bool isActive = data?['isActive'] as bool? ?? true;
    int? targetYear = (data?['targetYear'] as num?)?.toInt();
    String? targetSemester = data?['targetSemester'] as String?;

    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: Text(existing == null
              ? 'Create Makeup Mid Window'
              : 'Edit Makeup Mid Window'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Window Title *'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: sessionCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Exam Session *'),
                ),
                const SizedBox(height: 10),
                // Year dropdown
                DropdownButtonFormField<int>(
                  value: targetYear,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Target Year *',
                    helperText: 'Which year students can register',
                    border: UnderlineInputBorder(),
                    contentPadding: EdgeInsets.zero,
                  ),
                  items: const [
                    DropdownMenuItem(value: 1, child: Text('Year 1')),
                    DropdownMenuItem(value: 2, child: Text('Year 2')),
                    DropdownMenuItem(value: 3, child: Text('Year 3')),
                    DropdownMenuItem(value: 4, child: Text('Year 4')),
                  ],
                  onChanged: (v) => setSt(() => targetYear = v),
                ),
                const SizedBox(height: 10),
                // Semester dropdown
                DropdownButtonFormField<String>(
                  value: targetSemester,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Target Semester *',
                    helperText: 'Which semester this makeup mid is for',
                    border: UnderlineInputBorder(),
                    contentPadding: EdgeInsets.zero,
                  ),
                  items: const [
                    DropdownMenuItem(value: '1', child: Text('Semester 1')),
                    DropdownMenuItem(value: '2', child: Text('Semester 2')),
                    DropdownMenuItem(value: '3', child: Text('Semester 3')),
                    DropdownMenuItem(value: '4', child: Text('Semester 4')),
                    DropdownMenuItem(value: '5', child: Text('Semester 5')),
                    DropdownMenuItem(value: '6', child: Text('Semester 6')),
                    DropdownMenuItem(value: '7', child: Text('Semester 7')),
                    DropdownMenuItem(value: '8', child: Text('Semester 8')),
                  ],
                  onChanged: (v) => setSt(() => targetSemester = v),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: maxMarksCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      labelText: 'Max Marks (e.g. 30)',
                      helperText: 'Maximum marks for the mid exam'),
                ),
                const SizedBox(height: 10),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(startDate == null
                      ? 'Start Date *'
                      : 'Start: ${DateFormat('dd MMM yyyy').format(startDate!)}'),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final d = await showDatePicker(
                      context: ctx,
                      initialDate: startDate ?? DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (d != null) setSt(() => startDate = d);
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(endDate == null
                      ? 'End Date *'
                      : 'End: ${DateFormat('dd MMM yyyy').format(endDate!)}'),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final d = await showDatePicker(
                      context: ctx,
                      initialDate: endDate ?? DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (d != null) setSt(() => endDate = d);
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Registration Open'),
                  value: isActive,
                  onChanged: (v) => setSt(() => isActive = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final title = titleCtrl.text.trim();
                final session = sessionCtrl.text.trim();
                if (title.isEmpty ||
                    session.isEmpty ||
                    startDate == null ||
                    endDate == null ||
                    targetYear == null ||
                    targetSemester == null) {
                  ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                      content: Text(
                          'Please fill all fields including year and semester.')));
                  return;
                }
                final maxMarks = int.tryParse(maxMarksCtrl.text.trim()) ?? 30;
                final payload = {
                  'title': title,
                  'examSession': session,
                  'targetYear': targetYear,
                  'targetSemester': targetSemester,
                  'maxMarks': maxMarks,
                  'startDate': Timestamp.fromDate(startDate!),
                  'endDate': Timestamp.fromDate(endDate!),
                  'isActive': isActive,
                };
                if (existing == null) {
                  payload['createdAt'] = FieldValue.serverTimestamp();
                  await firestore.collection('makeupMidWindows').add(payload);
                } else {
                  payload['updatedAt'] = FieldValue.serverTimestamp();
                  await firestore
                      .collection('makeupMidWindows')
                      .doc(existing.id)
                      .update(payload);
                }
                if (ctx.mounted) Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1e3a5f),
                  foregroundColor: Colors.white),
              child: Text(existing == null ? 'Create' : 'Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showFacultyAssignDialog(
      BuildContext context, QueryDocumentSnapshot windowDoc) async {
    final winData = windowDoc.data() as Map<String, dynamic>;
    final searchCtrl = TextEditingController();
    final subjectCodeCtrl = TextEditingController();
    final subjectNameCtrl = TextEditingController();
    final facultyIdCtrl = TextEditingController();
    bool saving = false;
    bool listLoading = true;
    String? selectedCode;
    String? fetchedYear;
    String? fetchedSem;
    String? fetchedFacultyName;

    // All active faculty assignments loaded once
    List<Map<String, dynamic>> allAssignments = [];
    List<Map<String, dynamic>> filteredAssignments = [];

    // Load all active assignments up-front (outside StatefulBuilder)
    final snap = await firestore
        .collection('facultyAssignments')
        .where('isActive', isEqualTo: true)
        .get();
    allAssignments = snap.docs.map((d) => d.data()).toList();
    // Deduplicate by subjectCode, keep latest
    final Map<String, Map<String, dynamic>> deduped = {};
    for (final a in allAssignments) {
      final code = (a['subjectCode'] ?? '').toString();
      if (code.isNotEmpty) deduped[code] = a;
    }
    allAssignments = deduped.values.toList()
      ..sort((a, b) => (a['subjectCode'] ?? '')
          .toString()
          .compareTo((b['subjectCode'] ?? '').toString()));
    filteredAssignments = List.from(allAssignments);
    listLoading = false;

    void applyFilter(String query, StateSetter setSt) {
      final q = query.trim().toLowerCase();
      setSt(() {
        filteredAssignments = q.isEmpty
            ? List.from(allAssignments)
            : allAssignments.where((a) {
                final code = (a['subjectCode'] ?? '').toString().toLowerCase();
                final name = (a['subjectName'] ?? '').toString().toLowerCase();
                return code.contains(q) || name.contains(q);
              }).toList();
      });
    }

    void selectAssignment(Map<String, dynamic> a, StateSetter setSt) {
      final code = (a['subjectCode'] ?? '').toString().toUpperCase();
      final name = (a['subjectName'] ?? '').toString();
      final fid = (a['facultyId'] ?? '').toString().toUpperCase();
      final fname = (a['facultyName'] ?? '').toString();
      final yr = a['year']?.toString();
      final sem = a['semester']?.toString();
      subjectCodeCtrl.text = code;
      subjectNameCtrl.text = name;
      facultyIdCtrl.text = fid;
      setSt(() {
        selectedCode = code;
        fetchedYear = yr;
        fetchedSem = sem;
        fetchedFacultyName = fname;
      });
    }

    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: Text('Assign Faculty — ${winData['title'] ?? windowDoc.id}',
              style: const TextStyle(fontSize: 14)),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _FacultyAssignmentsSummaryMid(
                      firestore: firestore, windowId: windowDoc.id),
                  const Divider(),
                  // ── Search box ──
                  TextField(
                    controller: searchCtrl,
                    decoration: InputDecoration(
                      labelText: 'Search Subject (code or name)',
                      isDense: true,
                      prefixIcon: const Icon(Icons.search, size: 18),
                      suffixIcon: searchCtrl.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 16),
                              onPressed: () {
                                searchCtrl.clear();
                                applyFilter('', setSt);
                              })
                          : null,
                    ),
                    onChanged: (v) => applyFilter(v, setSt),
                  ),
                  const SizedBox(height: 6),
                  // ── Subject list ──
                  if (listLoading)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (filteredAssignments.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text('No subjects found.',
                          style: TextStyle(fontSize: 12, color: Colors.grey)),
                    )
                  else
                    Container(
                      height: 200,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: ListView.builder(
                        itemCount: filteredAssignments.length,
                        itemBuilder: (_, i) {
                          final a = filteredAssignments[i];
                          final code = (a['subjectCode'] ?? '').toString();
                          final name = (a['subjectName'] ?? '').toString();
                          final yr = a['year']?.toString() ?? '';
                          final sem = (a['semester'] ?? '').toString();
                          final fname = (a['facultyName'] ?? '').toString();
                          final isSelected = selectedCode == code;
                          return ListTile(
                            dense: true,
                            selected: isSelected,
                            selectedTileColor:
                                const Color(0xFF1e3a5f).withOpacity(0.08),
                            title: Text(
                              '$code — $name',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color:
                                    isSelected ? const Color(0xFF1e3a5f) : null,
                              ),
                            ),
                            subtitle: Text(
                              'Year $yr  •  Sem $sem  •  $fname',
                              style: const TextStyle(
                                  fontSize: 11, color: Colors.grey),
                            ),
                            trailing: isSelected
                                ? const Icon(Icons.check_circle,
                                    color: Colors.green, size: 18)
                                : null,
                            onTap: () => selectAssignment(a, setSt),
                          );
                        },
                      ),
                    ),
                  // ── Info chips for selected ──
                  if (selectedCode != null) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      children: [
                        if (fetchedYear != null)
                          Chip(
                            label: Text('Year $fetchedYear',
                                style: const TextStyle(fontSize: 11)),
                            backgroundColor:
                                const Color(0xFF1e3a5f).withOpacity(0.1),
                            padding: const EdgeInsets.all(2),
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ),
                        if (fetchedSem != null)
                          Chip(
                            label: Text('Sem $fetchedSem',
                                style: const TextStyle(fontSize: 11)),
                            backgroundColor: Colors.teal.withOpacity(0.1),
                            padding: const EdgeInsets.all(2),
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ),
                        if (fetchedFacultyName != null &&
                            fetchedFacultyName!.isNotEmpty)
                          Chip(
                            avatar: const Icon(Icons.person,
                                size: 14, color: Colors.green),
                            label: Text(fetchedFacultyName!,
                                style: const TextStyle(fontSize: 11)),
                            backgroundColor: Colors.green.withOpacity(0.1),
                            padding: const EdgeInsets.all(2),
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 10),
                  const Divider(),
                  const Text('Auto-filled fields (editable):',
                      style: TextStyle(fontSize: 11, color: Colors.grey)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: subjectCodeCtrl,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                        labelText: 'Subject Code *', isDense: true),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: subjectNameCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Subject Name *', isDense: true),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: facultyIdCtrl,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                        labelText: 'Faculty ID *', isDense: true),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Close')),
            ElevatedButton(
              onPressed: saving
                  ? null
                  : () async {
                      final code = subjectCodeCtrl.text.trim().toUpperCase();
                      final name = subjectNameCtrl.text.trim();
                      final fid = facultyIdCtrl.text.trim().toUpperCase();
                      if (code.isEmpty || name.isEmpty || fid.isEmpty) {
                        ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                            content: Text('All fields required.')));
                        return;
                      }
                      setSt(() => saving = true);
                      final docId = '${windowDoc.id}_$code';
                      await firestore
                          .collection('makeupMidSubjectAssignments')
                          .doc(docId)
                          .set({
                        'windowId': windowDoc.id,
                        'examSession': winData['examSession'],
                        'subjectCode': code,
                        'subjectName': name,
                        'facultyId': fid,
                        'updatedAt': FieldValue.serverTimestamp(),
                      });
                      subjectCodeCtrl.clear();
                      subjectNameCtrl.clear();
                      facultyIdCtrl.clear();
                      setSt(() => saving = false);
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                            content: Text('Faculty assigned.'),
                            backgroundColor: Colors.green));
                      }
                    },
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1e3a5f),
                  foregroundColor: Colors.white),
              child: saving
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Text('Assign'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Small widget: lists existing faculty assignments for a window
// ─────────────────────────────────────────────────────────────────────────
class _FacultyAssignmentsSummaryMid extends StatelessWidget {
  final FirebaseFirestore firestore;
  final String windowId;
  const _FacultyAssignmentsSummaryMid(
      {required this.firestore, required this.windowId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: firestore
          .collection('makeupMidSubjectAssignments')
          .where('windowId', isEqualTo: windowId)
          .snapshots(),
      builder: (_, snap) {
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 4),
            child: Text('No assignments yet.',
                style: TextStyle(fontSize: 12, color: Colors.grey)),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: _buildAssignmentRows(docs),
        );
      },
    );
  }

  List<Widget> _buildAssignmentRows(List<QueryDocumentSnapshot> docs) {
    final rows = <Widget>[];
    for (final doc in docs) {
      final d = doc.data() as Map<String, dynamic>;
      rows.add(Row(
        children: [
          Expanded(
            child: Text(
              '${d['subjectCode']} — ${d['subjectName']}  →  ${d['facultyId']}',
              style: const TextStyle(fontSize: 11),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete, size: 16, color: Colors.red),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () => doc.reference.delete(),
          ),
        ],
      ));
    }
    return rows;
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Window Card
// ─────────────────────────────────────────────────────────────────────────
class _MakeupWindowCard extends StatelessWidget {
  final FirebaseFirestore firestore;
  final QueryDocumentSnapshot doc;
  final VoidCallback onEdit;
  final VoidCallback onAssignFaculty;

  const _MakeupWindowCard({
    required this.firestore,
    required this.doc,
    required this.onEdit,
    required this.onAssignFaculty,
  });

  @override
  Widget build(BuildContext context) {
    final data = doc.data() as Map<String, dynamic>;
    final isActive = data['isActive'] as bool? ?? false;
    final start = (data['startDate'] as Timestamp?)?.toDate();
    final end = (data['endDate'] as Timestamp?)?.toDate();

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: isActive ? const Color(0xFF1e3a5f) : Colors.grey[700],
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(10)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(data['title'] ?? doc.id,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14)),
                      Text(data['examSession'] ?? '',
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isActive ? Colors.green : Colors.grey[500],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isActive ? 'OPEN' : 'CLOSED',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _infoRow('Max Marks:', '${data['maxMarks'] ?? 30}'),
                if (data['targetYear'] != null)
                  _infoRow('Year / Sem:',
                      'Year ${data['targetYear']}  —  Sem ${data['targetSemester'] ?? '—'}'),
                if (start != null)
                  _infoRow('Start:', DateFormat('dd MMM yyyy').format(start)),
                if (end != null)
                  _infoRow('End:', DateFormat('dd MMM yyyy').format(end)),
                _FacultyAssignmentsSummaryMid(
                    firestore: firestore, windowId: doc.id),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit, size: 14),
                      label: const Text('Edit'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _toggleActive(context, isActive),
                      icon: Icon(isActive ? Icons.lock : Icons.lock_open,
                          size: 14),
                      label: Text(isActive ? 'Close' : 'Open'),
                    ),
                    ElevatedButton.icon(
                      onPressed: onAssignFaculty,
                      icon: const Icon(Icons.person_add, size: 14),
                      label: const Text('Faculty'),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1e3a5f),
                          foregroundColor: Colors.white),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Text(label,
              style:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(width: 6),
          Text(value, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  Future<void> _toggleActive(BuildContext context, bool current) async {
    await firestore.collection('makeupMidWindows').doc(doc.id).update({
      'isActive': !current,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Tab 2 — Registrations
// ═══════════════════════════════════════════════════════════════════════════

class _MakeupRegistrationsTab extends StatefulWidget {
  final FirebaseFirestore firestore;
  const _MakeupRegistrationsTab({required this.firestore});

  @override
  State<_MakeupRegistrationsTab> createState() =>
      _MakeupRegistrationsTabState();
}

class _MakeupRegistrationsTabState extends State<_MakeupRegistrationsTab> {
  String? _selectedWindowId;
  final _searchCtrl = TextEditingController();
  late final Stream<QuerySnapshot> _windowsStream;
  Stream<QuerySnapshot>? _registrationsStream;

  @override
  void initState() {
    super.initState();
    _windowsStream = widget.firestore
        .collection('makeupMidWindows')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: StreamBuilder<QuerySnapshot>(
            stream: _windowsStream,
            builder: (ctx, snap) {
              final docs = snap.data?.docs ?? [];
              if (docs.isEmpty) {
                return const Text('No makeup mid windows created yet.',
                    style: TextStyle(color: Colors.grey));
              }
              return DropdownButtonFormField<String>(
                value: _selectedWindowId,
                isExpanded: true,
                decoration: const InputDecoration(
                    labelText: 'Select Makeup Mid Window',
                    border: OutlineInputBorder(),
                    isDense: true),
                items: _buildWindowItems(docs),
                onChanged: (v) => setState(() {
                  _selectedWindowId = v;
                  if (v != null) {
                    _registrationsStream = widget.firestore
                        .collection('makeupMidRegistrations')
                        .where('makeupWindowId', isEqualTo: v)
                        .snapshots();
                  } else {
                    _registrationsStream = null;
                  }
                }),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            controller: _searchCtrl,
            decoration: const InputDecoration(
              labelText: 'Search by Roll No',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),
        if (_selectedWindowId == null)
          const Expanded(
            child: Center(
              child: Text('Select a window above to view registrations.',
                  style: TextStyle(color: Colors.grey)),
            ),
          )
        else
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _registrationsStream,
              builder: (ctx, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                var docs = List.from(snap.data?.docs ?? []);
                docs.sort((a, b) {
                  final aTs = (a.data() as Map<String, dynamic>)['registeredAt']
                      as Timestamp?;
                  final bTs = (b.data() as Map<String, dynamic>)['registeredAt']
                      as Timestamp?;
                  if (aTs == null && bTs == null) return 0;
                  if (aTs == null) return 1;
                  if (bTs == null) return -1;
                  return bTs.compareTo(aTs);
                });
                final q = _searchCtrl.text.trim().toUpperCase();
                if (q.isNotEmpty) {
                  docs = docs.where((d) {
                    final data = d.data() as Map<String, dynamic>;
                    return (data['rollNo'] as String? ?? '')
                        .toUpperCase()
                        .contains(q);
                  }).toList();
                }
                if (docs.isEmpty) {
                  return const Center(
                    child: Text('No registrations yet for this window.',
                        style: TextStyle(color: Colors.grey)),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: docs.length,
                  itemBuilder: (_, i) {
                    final data = docs[i].data() as Map<String, dynamic>;
                    final subjects = List<Map<String, dynamic>>.from(
                        (data['subjects'] as List? ?? [])
                            .map((s) => Map<String, dynamic>.from(s as Map)));
                    final regAt =
                        (data['registeredAt'] as Timestamp?)?.toDate();
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: Text(
                          '${data['rollNo']} — ${data['studentName'] ?? ''}',
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          '${subjects.length} subject(s): ${subjects.map((s) => s['subjectCode']).join(', ')}'
                          '\nRegistered: ${regAt != null ? DateFormat('dd MMM yyyy').format(regAt) : '—'}',
                        ),
                        isThreeLine: true,
                      ),
                    );
                  },
                );
              },
            ),
          ),
      ],
    );
  }

  List<DropdownMenuItem<String>> _buildWindowItems(
      List<QueryDocumentSnapshot> docs) {
    final items = <DropdownMenuItem<String>>[];
    for (final d in docs) {
      final data = d.data() as Map<String, dynamic>;
      items.add(DropdownMenuItem(
        value: d.id,
        child: Text(data['title'] as String? ?? d.id,
            overflow: TextOverflow.ellipsis),
      ));
    }
    return items;
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Tab 3 — Marks (view + release)
// ═══════════════════════════════════════════════════════════════════════════

class _MakeupMarksTab extends StatefulWidget {
  final FirebaseFirestore firestore;
  const _MakeupMarksTab({required this.firestore});

  @override
  State<_MakeupMarksTab> createState() => _MakeupMarksTabState();
}

class _MakeupMarksTabState extends State<_MakeupMarksTab> {
  late final Stream<QuerySnapshot> _windowsStream;
  String? _selectedWindowId;
  final _searchCtrl = TextEditingController();
  bool _releasing = false;

  @override
  void initState() {
    super.initState();
    _windowsStream =
        widget.firestore.collection('makeupMidWindows').snapshots();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _toggleRelease(String windowId, bool currentlyReleased) async {
    final newValue = !currentlyReleased;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(newValue ? 'Release Results?' : 'Withdraw Release?'),
        content: Text(newValue
            ? 'Students will immediately see their makeup mid marks.'
            : 'Results will be hidden from students until released again.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor:
                    newValue ? Colors.green[700] : Colors.orange[700]),
            onPressed: () => Navigator.pop(context, true),
            child: Text(newValue ? 'Release' : 'Withdraw',
                style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    setState(() => _releasing = true);
    try {
      await widget.firestore
          .collection('makeupMidWindows')
          .doc(windowId)
          .update({
        'resultsReleased': newValue,
        if (newValue)
          'resultsReleasedAt': FieldValue.serverTimestamp()
        else
          'resultsReleasedAt': FieldValue.delete(),
      });
      // Batch-update all marks docs
      final markDocs = await widget.firestore
          .collection('makeupMidMarks')
          .where('windowId', isEqualTo: windowId)
          .get();
      const batchSize = 400;
      for (var start = 0; start < markDocs.docs.length; start += batchSize) {
        final batch = widget.firestore.batch();
        final end = (start + batchSize).clamp(0, markDocs.docs.length);
        for (final doc in markDocs.docs.sublist(start, end)) {
          batch.update(doc.reference, {'resultsReleased': newValue});
        }
        await batch.commit();
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(newValue
              ? 'Marks released — students can now view makeup mid results.'
              : 'Results withdrawn from student view.'),
          backgroundColor: newValue ? Colors.green[700] : Colors.orange[700],
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
    if (mounted) setState(() => _releasing = false);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _windowsStream,
      builder: (ctx, windowSnap) {
        if (windowSnap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final windows = windowSnap.data?.docs ?? [];
        if (windows.isEmpty) {
          return const Center(
            child: Text('No makeup mid windows found.',
                style: TextStyle(color: Colors.grey)),
          );
        }

        Map<String, dynamic>? selectedWindowData;
        if (_selectedWindowId != null) {
          final found = windows.where((d) => d.id == _selectedWindowId);
          if (found.isNotEmpty) {
            selectedWindowData = found.first.data() as Map<String, dynamic>;
          }
        }
        final isReleased =
            selectedWindowData?['resultsReleased'] as bool? ?? false;

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              child: DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Select Makeup Mid Window',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                value: _selectedWindowId,
                isExpanded: true,
                items: _buildWindowDropdown(windows),
                onChanged: (v) => setState(() => _selectedWindowId = v),
              ),
            ),
            if (_selectedWindowId != null) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color:
                              isReleased ? Colors.green[50] : Colors.orange[50],
                          border: Border.all(
                              color: isReleased ? Colors.green : Colors.orange),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          isReleased
                              ? 'Results RELEASED — visible to students'
                              : 'Results HELD — not visible to students',
                          style: TextStyle(
                              color: isReleased
                                  ? Colors.green[800]
                                  : Colors.orange[800],
                              fontWeight: FontWeight.w600,
                              fontSize: 13),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _releasing
                          ? null
                          : () =>
                              _toggleRelease(_selectedWindowId!, isReleased),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            isReleased ? Colors.orange[700] : Colors.green[700],
                        foregroundColor: Colors.white,
                      ),
                      child: _releasing
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                          : Text(isReleased ? 'Withdraw' : 'Release'),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: TextField(
                  controller: _searchCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Search by Roll No / Subject Code',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              Expanded(
                child: _buildMarksList(),
              ),
            ] else
              const Expanded(
                child: Center(
                  child: Text('Select a window above to view marks.',
                      style: TextStyle(color: Colors.grey)),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildMarksList() {
    return StreamBuilder<QuerySnapshot>(
      stream: widget.firestore
          .collection('makeupMidMarks')
          .where('windowId', isEqualTo: _selectedWindowId)
          .snapshots(),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        var docs = List.from(snap.data?.docs ?? []);
        final q = _searchCtrl.text.trim().toUpperCase();
        if (q.isNotEmpty) {
          docs = docs.where((d) {
            final data = d.data() as Map<String, dynamic>;
            return (data['rollNo'] as String? ?? '')
                    .toUpperCase()
                    .contains(q) ||
                (data['subjectCode'] as String? ?? '')
                    .toUpperCase()
                    .contains(q);
          }).toList();
        }
        if (docs.isEmpty) {
          return const Center(
            child: Text('No marks entered yet for this window.',
                style: TextStyle(color: Colors.grey)),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          itemBuilder: (_, i) {
            final data = docs[i].data() as Map<String, dynamic>;
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(
                  '${data['rollNo']} — ${data['studentName'] ?? ''}',
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  '${data['subjectCode']} — ${data['subjectName']}\n'
                  'Mid Marks: ${data['midMarks']}/${data['maxMarks'] ?? 30}  •  Faculty: ${data['facultyId']}',
                ),
                isThreeLine: true,
                trailing: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.blue),
                  ),
                  child: Text(
                    '${data['midMarks']}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.blue),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  List<DropdownMenuItem<String>> _buildWindowDropdown(
      List<QueryDocumentSnapshot> windows) {
    final items = <DropdownMenuItem<String>>[];
    for (final doc in windows) {
      final d = doc.data() as Map<String, dynamic>;
      final released = d['resultsReleased'] as bool? ?? false;
      items.add(DropdownMenuItem(
        value: doc.id,
        child: Row(
          children: [
            Expanded(
              child: Text(
                '${d['title'] ?? doc.id}  (${d['examSession'] ?? ''})',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13),
              ),
            ),
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: released ? Colors.green[100] : Colors.orange[100],
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                released ? 'RELEASED' : 'HELD',
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: released ? Colors.green[800] : Colors.orange[800]),
              ),
            ),
          ],
        ),
      ));
    }
    return items;
  }
}
