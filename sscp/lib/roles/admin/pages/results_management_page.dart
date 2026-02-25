import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

/// Admin Supply Management — 3 tabs:
///   1. Backlogs         — view / clear backlogs for any student
///   2. Supply Windows   — create / enable / disable + assign faculty per subject
///   3. Registrations    — view who registered for each supply window
class ResultsManagementPage extends StatefulWidget {
  const ResultsManagementPage({super.key, this.initialTab = 0});
  final int initialTab;

  @override
  State<ResultsManagementPage> createState() => _ResultsManagementPageState();
}

class _ResultsManagementPageState extends State<ResultsManagementPage>
    with SingleTickerProviderStateMixin {
  final _firestore = FirebaseFirestore.instance;
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(
        length: 3, vsync: this, initialIndex: widget.initialTab);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Supply Exam Management'),
        backgroundColor: const Color(0xFF1e3a5f),
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tab,
          indicatorColor: Colors.yellow,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          isScrollable: true,
          tabs: const [
            Tab(icon: Icon(Icons.warning_amber), text: 'Backlogs'),
            Tab(icon: Icon(Icons.event_note), text: 'Supply Windows'),
            Tab(icon: Icon(Icons.how_to_reg), text: 'Registrations'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _BacklogsTab(firestore: _firestore),
          _SupplyWindowsTab(firestore: _firestore),
          _RegistrationsTab(firestore: _firestore),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// TAB 1 — Backlogs
// ═══════════════════════════════════════════════════════════════════════════

class _BacklogsTab extends StatefulWidget {
  final FirebaseFirestore firestore;
  const _BacklogsTab({required this.firestore});

  @override
  State<_BacklogsTab> createState() => _BacklogsTabState();
}

class _BacklogsTabState extends State<_BacklogsTab> {
  String _filter = 'active';
  final _searchCtrl = TextEditingController();

  Stream<QuerySnapshot> get _stream {
    var q = widget.firestore
        .collection('backlogs')
        .orderBy('createdAt', descending: true);
    if (_filter != 'all') {
      return q.where('status', isEqualTo: _filter).snapshots();
    }
    return q.snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: _searchCtrl,
                decoration: const InputDecoration(
                  labelText: 'Search by Roll No or Subject',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: 10),
            DropdownButton<String>(
              value: _filter,
              underline: const SizedBox(),
              items: const [
                DropdownMenuItem(value: 'active', child: Text('Active')),
                DropdownMenuItem(value: 'cleared', child: Text('Cleared')),
                DropdownMenuItem(value: 'all', child: Text('All')),
              ],
              onChanged: (v) => setState(() => _filter = v!),
            ),
          ]),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _stream,
            builder: (ctx, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              var docs = snap.data?.docs ?? [];
              final q = _searchCtrl.text.trim().toUpperCase();
              if (q.isNotEmpty) {
                docs = docs.where((d) {
                  final data = d.data() as Map<String, dynamic>;
                  return (data['rollNo'] as String? ?? '')
                          .toUpperCase()
                          .contains(q) ||
                      (data['subjectCode'] as String? ?? '')
                          .toUpperCase()
                          .contains(q) ||
                      (data['subjectName'] as String? ?? '')
                          .toUpperCase()
                          .contains(q);
                }).toList();
              }
              if (docs.isEmpty) return _emptyHint('No backlog records found.');
              return ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: docs.length,
                itemBuilder: (_, i) {
                  final data = docs[i].data() as Map<String, dynamic>;
                  return _BacklogCard(
                      doc: docs[i], data: data, firestore: widget.firestore);
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _BacklogCard extends StatelessWidget {
  final QueryDocumentSnapshot doc;
  final Map<String, dynamic> data;
  final FirebaseFirestore firestore;
  const _BacklogCard(
      {required this.doc, required this.data, required this.firestore});

  @override
  Widget build(BuildContext context) {
    final isActive = (data['status'] as String? ?? 'active') == 'active';
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor:
              isActive ? Colors.red.shade100 : Colors.green.shade100,
          child: Icon(isActive ? Icons.warning_amber : Icons.check_circle,
              color: isActive ? Colors.red : Colors.green, size: 20),
        ),
        title: Text('${data['rollNo']} — ${data['subjectCode']}',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
        subtitle: Text(
          '${data['subjectName']}\n'
          'Year ${data['year']} • Sem ${data['semester']} • Failed: ${data['examSession']}'
          '${!isActive ? '\nCleared: ${data['clearedExamSession'] ?? '—'}' : ''}',
          style: const TextStyle(fontSize: 12),
        ),
        isThreeLine: true,
        trailing: isActive
            ? IconButton(
                icon: const Icon(Icons.clear_all, color: Colors.green),
                tooltip: 'Manually clear backlog',
                onPressed: () => _manualClear(context),
              )
            : Chip(
                label: const Text('Cleared',
                    style: TextStyle(fontSize: 10, color: Colors.white)),
                backgroundColor: Colors.green),
      ),
    );
  }

  Future<void> _manualClear(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Clear Backlog'),
        content: Text(
            'Manually clear backlog for ${data['rollNo']} — ${data['subjectCode']}?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: const Text('Clear', style: TextStyle(color: Colors.white))),
        ],
      ),
    );
    if (ok == true) {
      await firestore.collection('backlogs').doc(doc.id).update({
        'status': 'cleared',
        'clearedExamSession': 'MANUAL',
        'clearedAt': FieldValue.serverTimestamp(),
      });
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// TAB 2 — Supply Windows (+ faculty assignment)
// ═══════════════════════════════════════════════════════════════════════════

class _SupplyWindowsTab extends StatefulWidget {
  final FirebaseFirestore firestore;
  const _SupplyWindowsTab({required this.firestore});

  @override
  State<_SupplyWindowsTab> createState() => _SupplyWindowsTabState();
}

class _SupplyWindowsTabState extends State<_SupplyWindowsTab> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              const Text('Supply Exam Windows',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () => _showCreateDialog(context),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('New Window'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1e3a5f),
                    foregroundColor: Colors.white),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: widget.firestore
                .collection('supplyWindows')
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (ctx, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs = snap.data?.docs ?? [];
              if (docs.isEmpty) {
                return _emptyHint(
                    'No supply windows yet. Click "New Window" to create one.');
              }
              return ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: docs.length,
                itemBuilder: (_, i) {
                  final data = docs[i].data() as Map<String, dynamic>;
                  return _SupplyWindowCard(
                    doc: docs[i],
                    data: data,
                    firestore: widget.firestore,
                    onEdit: () => _showCreateDialog(context, existing: docs[i]),
                    onAssignFaculty: () =>
                        _showFacultyAssignDialog(context, docs[i]),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _showCreateDialog(BuildContext context,
      {QueryDocumentSnapshot? existing}) async {
    final data = existing?.data() as Map<String, dynamic>?;
    final titleCtrl = TextEditingController(text: data?['title'] ?? '');
    final sessionCtrl =
        TextEditingController(text: data?['examSession'] ?? '');
    DateTime? startDate = (data?['startDate'] as Timestamp?)?.toDate();
    DateTime? endDate = (data?['endDate'] as Timestamp?)?.toDate();
    bool isActive = data?['isActive'] ?? false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text(
              existing == null ? 'Create Supply Window' : 'Edit Window'),
          scrollable: true,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(
                    labelText: 'Window Title (e.g., Supply Nov 2025)',
                    border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: sessionCtrl,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                    labelText: 'Exam Session (e.g., NOV-2025-SUPPLY)',
                    border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () async {
                  final p = await showDatePicker(
                    context: ctx,
                    initialDate: startDate ?? DateTime.now(),
                    firstDate: DateTime.now(),
                    lastDate:
                        DateTime.now().add(const Duration(days: 365)),
                  );
                  if (p != null) setS(() => startDate = p);
                },
                icon: const Icon(Icons.calendar_today, size: 14),
                label: Text(startDate != null
                    ? 'Opens: ${DateFormat('dd-MM-yyyy').format(startDate!)}'
                    : 'Set Registration Opens *'),
              ),
              const SizedBox(height: 6),
              OutlinedButton.icon(
                onPressed: () async {
                  final p = await showDatePicker(
                    context: ctx,
                    initialDate: endDate ?? (startDate ?? DateTime.now()),
                    firstDate: startDate ?? DateTime.now(),
                    lastDate:
                        DateTime.now().add(const Duration(days: 365)),
                  );
                  if (p != null) setS(() => endDate = p);
                },
                icon: const Icon(Icons.calendar_today, size: 14),
                label: Text(endDate != null
                    ? 'Closes: ${DateFormat('dd-MM-yyyy').format(endDate!)}'
                    : 'Set Registration Closes *'),
              ),
              const SizedBox(height: 10),
              SwitchListTile(
                title: const Text('Active (visible to students)'),
                value: isActive,
                onChanged: (v) => setS(() => isActive = v),
                activeColor: Colors.green,
                dense: true,
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                final winData = {
                  'title': titleCtrl.text.trim(),
                  'examSession': sessionCtrl.text.trim().toUpperCase(),
                  'startDate': startDate != null
                      ? Timestamp.fromDate(startDate!)
                      : null,
                  'endDate': endDate != null
                      ? Timestamp.fromDate(endDate!)
                      : null,
                  'isActive': isActive,
                  'createdAt': FieldValue.serverTimestamp(),
                };
                if (existing != null) {
                  await widget.firestore
                      .collection('supplyWindows')
                      .doc(existing.id)
                      .update(winData);
                } else {
                  await widget.firestore
                      .collection('supplyWindows')
                      .add(winData);
                }
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

  // ── Faculty Assignment Dialog ─────────────────────────────────────────────
  Future<void> _showFacultyAssignDialog(
      BuildContext context, QueryDocumentSnapshot windowDoc) async {
    final winData = windowDoc.data() as Map<String, dynamic>;
    final windowId = windowDoc.id;

    // Load registered subjects for this window
    final regSnap = await widget.firestore
        .collection('supplyRegistrations')
        .where('supplyWindowId', isEqualTo: windowId)
        .get();

    // Collect unique subjects: code → name
    final subjectMap = <String, String>{};
    for (final doc in regSnap.docs) {
      final d = doc.data();
      final subjects = List<Map<String, dynamic>>.from(
          (d['subjects'] as List? ?? [])
              .map((s) => Map<String, dynamic>.from(s as Map)));
      for (final s in subjects) {
        final code = s['subjectCode']?.toString() ?? '';
        final name = s['subjectName']?.toString() ?? code;
        if (code.isNotEmpty) subjectMap[code] = name;
      }
    }

    if (subjectMap.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'No registrations yet — no subjects to assign faculty for.')));
      }
      return;
    }

    // Load faculty list
    final facSnap = await widget.firestore.collection('faculty').get();
    final facultyList = facSnap.docs
        .map((d) => {
              'id': d.id,
              'name': (d.data()['name'] ?? d.id).toString(),
            })
        .toList();
    facultyList.sort((a, b) => (a['name'] ?? '').compareTo(b['name'] ?? ''));

    // Load existing assignments
    final existingSnap = await widget.firestore
        .collection('supplySubjectAssignments')
        .where('windowId', isEqualTo: windowId)
        .get();
    final existingMap = <String, String>{};
    for (final d in existingSnap.docs) {
      final data = d.data();
      existingMap[data['subjectCode']?.toString() ?? ''] =
          data['facultyId']?.toString() ?? '';
    }

    // Build per-subject selections
    final selections = <String, String?>{};
    for (final code in subjectMap.keys) {
      selections[code] = existingMap[code];
    }

    if (!context.mounted) return;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text('Assign Faculty — ${winData['title'] ?? windowId}'),
          scrollable: true,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                  'Assign a faculty member to each supply exam subject.',
                  style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 12),
              ...subjectMap.entries.map((entry) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${entry.key} — ${entry.value}',
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        value: selections[entry.key],
                        decoration: const InputDecoration(
                            labelText: 'Select Faculty',
                            border: OutlineInputBorder(),
                            isDense: true),
                        isExpanded: true,
                        items: [
                          const DropdownMenuItem(
                              value: null, child: Text('— Not Assigned —')),
                          ...facultyList.map((f) => DropdownMenuItem(
                                value: f['id'],
                                child: Text(
                                    '${f['name']} (${f['id']})',
                                    overflow: TextOverflow.ellipsis),
                              )),
                        ],
                        onChanged: (v) =>
                            setS(() => selections[entry.key] = v),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                final batch = widget.firestore.batch();
                for (final entry in selections.entries) {
                  final docId = '${windowId}_${entry.key}';
                  final ref = widget.firestore
                      .collection('supplySubjectAssignments')
                      .doc(docId);
                  if (entry.value == null) {
                    batch.delete(ref);
                  } else {
                    final facName = facultyList.firstWhere(
                            (f) => f['id'] == entry.value,
                            orElse: () => {'name': entry.value!})['name'] ??
                        entry.value!;
                    batch.set(ref, {
                      'windowId': windowId,
                      'examSession': winData['examSession'] ?? '',
                      'subjectCode': entry.key,
                      'subjectName': subjectMap[entry.key] ?? '',
                      'facultyId': entry.value,
                      'facultyName': facName,
                      'updatedAt': FieldValue.serverTimestamp(),
                    });
                  }
                }
                await batch.commit();
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                      content: Text('Faculty assignments saved.'),
                      backgroundColor: Colors.green));
                }
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1e3a5f),
                  foregroundColor: Colors.white),
              child: const Text('Save Assignments'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SupplyWindowCard extends StatelessWidget {
  final QueryDocumentSnapshot doc;
  final Map<String, dynamic> data;
  final FirebaseFirestore firestore;
  final VoidCallback onEdit;
  final VoidCallback onAssignFaculty;

  const _SupplyWindowCard({
    required this.doc,
    required this.data,
    required this.firestore,
    required this.onEdit,
    required this.onAssignFaculty,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = data['isActive'] as bool? ?? false;
    final start = (data['startDate'] as Timestamp?)?.toDate();
    final end = (data['endDate'] as Timestamp?)?.toDate();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
            color: isActive ? Colors.green : Colors.grey.shade300, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    data['title'] as String? ?? '—',
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
                _statusChip(isActive),
              ],
            ),
            const SizedBox(height: 6),
            Text('Session: ${data['examSession'] ?? '—'}',
                style: const TextStyle(fontSize: 12)),
            if (start != null && end != null)
              Text(
                  'Registration: ${DateFormat('dd MMM yyyy').format(start)} – ${DateFormat('dd MMM yyyy').format(end)}',
                  style: const TextStyle(fontSize: 12)),

            // Faculty assignments live summary
            StreamBuilder<QuerySnapshot>(
              stream: firestore
                  .collection('supplySubjectAssignments')
                  .where('windowId', isEqualTo: doc.id)
                  .snapshots(),
              builder: (ctx, snap) {
                final assignments = snap.data?.docs ?? [];
                if (assignments.isEmpty) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Faculty Assignments:',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.blueGrey)),
                      ...assignments.map((a) {
                        final d = a.data() as Map<String, dynamic>;
                        return Text(
                          '• ${d['subjectCode']} → ${d['facultyName']}',
                          style: const TextStyle(
                              fontSize: 11, color: Colors.black87),
                        );
                      }),
                    ],
                  ),
                );
              },
            ),

            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                OutlinedButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit, size: 14),
                  label: const Text('Edit'),
                ),
                OutlinedButton.icon(
                  onPressed: onAssignFaculty,
                  icon: const Icon(Icons.person_add, size: 14),
                  label: const Text('Assign Faculty'),
                  style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.indigo),
                ),
                ElevatedButton.icon(
                  onPressed: () async {
                    await firestore
                        .collection('supplyWindows')
                        .doc(doc.id)
                        .update({'isActive': !isActive});
                  },
                  icon: Icon(
                      isActive ? Icons.lock : Icons.lock_open, size: 14),
                  label: Text(isActive ? 'Disable' : 'Enable'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isActive ? Colors.red : Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  tooltip: 'Delete window',
                  onPressed: () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('Delete Supply Window'),
                        content: const Text(
                            'Delete this supply window? Registrations will remain.'),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Cancel')),
                          ElevatedButton(
                              onPressed: () => Navigator.pop(context, true),
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red),
                              child: const Text('Delete',
                                  style: TextStyle(color: Colors.white))),
                        ],
                      ),
                    );
                    if (ok == true) {
                      await firestore
                          .collection('supplyWindows')
                          .doc(doc.id)
                          .delete();
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusChip(bool active) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: active ? Colors.green.shade50 : Colors.grey.shade100,
        border: Border.all(
            color: active ? Colors.green : Colors.grey.shade400),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        active ? 'OPEN' : 'CLOSED',
        style: TextStyle(
          color: active ? Colors.green : Colors.grey.shade600,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// TAB 3 — Supply Registrations
// ═══════════════════════════════════════════════════════════════════════════

class _RegistrationsTab extends StatefulWidget {
  final FirebaseFirestore firestore;
  const _RegistrationsTab({required this.firestore});

  @override
  State<_RegistrationsTab> createState() => _RegistrationsTabState();
}

class _RegistrationsTabState extends State<_RegistrationsTab> {
  String? _selectedWindowId;
  final _searchCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: StreamBuilder<QuerySnapshot>(
            stream: widget.firestore
                .collection('supplyWindows')
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (ctx, snap) {
              final docs = snap.data?.docs ?? [];
              if (docs.isEmpty) {
                return const Text('No supply windows created yet.',
                    style: TextStyle(color: Colors.grey));
              }
              return DropdownButtonFormField<String>(
                value: _selectedWindowId,
                decoration: const InputDecoration(
                    labelText: 'Select Supply Window',
                    border: OutlineInputBorder()),
                items: docs.map((d) {
                  final data = d.data() as Map<String, dynamic>;
                  return DropdownMenuItem(
                      value: d.id,
                      child: Text(data['title'] as String? ?? d.id));
                }).toList(),
                onChanged: (v) => setState(() => _selectedWindowId = v),
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
                  child: Text(
                      'Select a supply window above to view registrations.')))
        else
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: widget.firestore
                  .collection('supplyRegistrations')
                  .where('supplyWindowId', isEqualTo: _selectedWindowId)
                  .orderBy('registeredAt', descending: true)
                  .snapshots(),
              builder: (ctx, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                var docs = snap.data?.docs ?? [];
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
                  return _emptyHint(
                      'No registrations yet for this window.');
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: docs.length,
                  itemBuilder: (_, i) {
                    final data = docs[i].data() as Map<String, dynamic>;
                    final subjects = List<Map<String, dynamic>>.from(
                        (data['subjects'] as List? ?? [])
                            .map((s) =>
                                Map<String, dynamic>.from(s as Map)));
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: Text(
                          '${data['rollNo']} — ${data['studentName'] ?? ''}',
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          '${subjects.length} subject(s): ${subjects.map((s) => s['subjectCode']).join(', ')}\n'
                          'Registered: ${data['registeredAt'] != null ? DateFormat('dd MMM yyyy').format((data['registeredAt'] as Timestamp).toDate()) : '—'}',
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
}

// ═══════════════════════════════════════════════════════════════════════════
// Shared helpers
// ═══════════════════════════════════════════════════════════════════════════

Widget _sectionTitle(String t) =>
    Text(t, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold));

Widget _emptyHint(String msg) => Padding(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Text(msg,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey)),
      ),
    );
