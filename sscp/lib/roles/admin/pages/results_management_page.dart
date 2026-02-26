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
    _tab =
        TabController(length: 4, vsync: this, initialIndex: widget.initialTab);
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
            Tab(icon: Icon(Icons.grade), text: 'Supply Marks'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _BacklogsTab(firestore: _firestore),
          _SupplyWindowsTab(firestore: _firestore),
          _RegistrationsTab(firestore: _firestore),
          _SupplyMarksTab(firestore: _firestore),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Backlog data model + derivation helper (admin-side)
// ═══════════════════════════════════════════════════════════════════════════

class _AdminBacklogItem {
  final String rollNo;
  final String subjectCode;
  final String subjectName;
  final String year;
  final String semester;
  final String failedExamSession;
  final String status; // 'active' | 'cleared'
  final String? clearedExamSession;

  const _AdminBacklogItem({
    required this.rollNo,
    required this.subjectCode,
    required this.subjectName,
    required this.year,
    required this.semester,
    required this.failedExamSession,
    required this.status,
    this.clearedExamSession,
  });
}

String _normSem(String s) {
  const m = {'i': '1', 'ii': '2', 'iii': '3', 'iv': '4'};
  return m[s.toLowerCase().trim()] ?? s.trim();
}

Future<List<_AdminBacklogItem>> _deriveAdminBacklogs(
    FirebaseFirestore db, String rollNo) async {
  final relSnap = await db.collection('cieMemoReleases').get();
  final releaseMap = <String, Map<String, dynamic>>{};
  for (final d in relSnap.docs) {
    final r = d.data();
    final key = '${r['year']}_${_normSem(r['semester']?.toString() ?? '')}';
    releaseMap[key] = {
      'examSession': (r['examSession'] ?? '').toString(),
      'minPassMarks': (r['minPassMarks'] is int)
          ? r['minPassMarks'] as int
          : int.tryParse(r['minPassMarks']?.toString() ?? '') ?? 40,
    };
  }

  // Also check supply exam PASS results to determine cleared status
  final supplySnap = await db
      .collection('supplyMarks')
      .where('rollNo', isEqualTo: rollNo)
      .get();
  final supplyPassMap = <String, String>{};
  for (final d in supplySnap.docs) {
    final data = d.data();
    if ((data['result'] as String? ?? '') == 'PASS') {
      final code = data['subjectCode']?.toString() ?? '';
      if (code.isNotEmpty) {
        supplyPassMap[code] = data['examSession']?.toString() ?? 'Supply Exam';
      }
    }
  }

  final marksSnap = await db
      .collection('studentMarks')
      .where('studentId', isEqualTo: rollNo)
      .get();

  final bySubject = <String, List<Map<String, dynamic>>>{};
  for (final doc in marksSnap.docs) {
    final d = Map<String, dynamic>.from(doc.data());
    final code = d['subjectCode']?.toString() ?? '';
    if (code.isEmpty) continue;
    bySubject.putIfAbsent(code, () => []).add(d);
  }

  final items = <_AdminBacklogItem>[];
  bySubject.forEach((code, entries) {
    entries.sort((a, b) {
      final ya = int.tryParse(a['year']?.toString() ?? '') ?? 0;
      final yb = int.tryParse(b['year']?.toString() ?? '') ?? 0;
      if (ya != yb) return ya.compareTo(yb);
      return _normSem(a['semester']?.toString() ?? '')
          .compareTo(_normSem(b['semester']?.toString() ?? ''));
    });

    for (int i = 0; i < entries.length; i++) {
      final e = entries[i];
      final yearStr = e['year']?.toString() ?? '';
      final semStr = _normSem(e['semester']?.toString() ?? '');
      final key = '${yearStr}_$semStr';
      final release = releaseMap[key];
      final minPass = (release?['minPassMarks'] as int?) ?? 40;
      final examSession = (release?['examSession'] as String?) ?? '';

      final raw = e['componentMarks'] as Map<String, dynamic>? ?? {};
      int grandTotal = 0;
      for (final v in raw.values) {
        grandTotal += (v is int) ? v : int.tryParse(v.toString()) ?? 0;
      }

      if (grandTotal < minPass) {
        bool clearedLater = false;
        String clearedSession = '';
        for (int j = i + 1; j < entries.length; j++) {
          final later = entries[j];
          final lKey =
              '${later['year']}_${_normSem(later['semester']?.toString() ?? '')}';
          final lRelease = releaseMap[lKey];
          final lMinPass = (lRelease?['minPassMarks'] as int?) ?? 40;
          final lRaw =
              later['componentMarks'] as Map<String, dynamic>? ?? {};
          int lTotal = 0;
          for (final v in lRaw.values) {
            lTotal += (v is int) ? v : int.tryParse(v.toString()) ?? 0;
          }
          if (lTotal >= lMinPass) {
            clearedLater = true;
            clearedSession =
                (lRelease?['examSession'] as String?) ?? '';
            break;
          }
        }
        // Also check if cleared via supply exam
        if (!clearedLater && supplyPassMap.containsKey(code)) {
          clearedLater = true;
          clearedSession = supplyPassMap[code]!;
        }
        final alreadyAdded = items.any((x) =>
            x.subjectCode == code && x.failedExamSession == examSession);
        if (!alreadyAdded) {
          items.add(_AdminBacklogItem(
            rollNo: rollNo,
            subjectCode: code,
            subjectName: e['subjectName']?.toString() ?? code,
            year: yearStr,
            semester: e['semester']?.toString() ?? semStr,
            failedExamSession: examSession,
            status: clearedLater ? 'cleared' : 'active',
            clearedExamSession: clearedLater ? clearedSession : null,
          ));
        }
      }
    }
  });

  items.sort((a, b) {
    if (a.status != b.status) return a.status == 'active' ? -1 : 1;
    return (int.tryParse(a.year) ?? 0).compareTo(int.tryParse(b.year) ?? 0);
  });
  return items;
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
  String _searchedRoll = '';
  Future<List<_AdminBacklogItem>>? _future;

  void _search() {
    final roll = _searchCtrl.text.trim().toUpperCase();
    if (roll.isEmpty) return;
    setState(() {
      _searchedRoll = roll;
      _future = _deriveAdminBacklogs(widget.firestore, roll);
    });
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
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  labelText: 'Enter Roll Number',
                  prefixIcon: const Icon(Icons.search),
                  border: const OutlineInputBorder(),
                  isDense: true,
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.arrow_forward),
                    onPressed: _search,
                  ),
                ),
                textCapitalization: TextCapitalization.characters,
                onSubmitted: (_) => _search(),
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
        Expanded(child: _buildBody()),
      ],
    );
  }

  Widget _buildBody() {
    if (_future == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.manage_search, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              'Enter a student roll number and press ↵ to view their backlogs.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return FutureBuilder<List<_AdminBacklogItem>>(
      future: _future,
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(child: Text('Error: ${snap.error}'));
        }

        var items = snap.data ?? [];
        if (_filter == 'active') {
          items = items.where((i) => i.status == 'active').toList();
        } else if (_filter == 'cleared') {
          items = items.where((i) => i.status == 'cleared').toList();
        }

        if (items.isEmpty) {
          return Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.check_circle_outline,
                  size: 64, color: Colors.green.shade400),
              const SizedBox(height: 12),
              Text(
                _filter == 'active'
                    ? '$_searchedRoll has no active backlogs.'
                    : '$_searchedRoll has no $_filter backlogs.',
                style:
                    TextStyle(fontSize: 15, color: Colors.grey.shade600),
              ),
            ]),
          );
        }

        return RefreshIndicator(
          onRefresh: () async => setState(() {
            _future = _deriveAdminBacklogs(widget.firestore, _searchedRoll);
          }),
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: items.length,
            itemBuilder: (_, i) => _AdminBacklogCard(
              item: items[i],
              firestore: widget.firestore,
              onCleared: () => setState(() {
                _future =
                    _deriveAdminBacklogs(widget.firestore, _searchedRoll);
              }),
            ),
          ),
        );
      },
    );
  }
}

class _AdminBacklogCard extends StatelessWidget {
  const _AdminBacklogCard({
    required this.item,
    required this.firestore,
    required this.onCleared,
  });

  final _AdminBacklogItem item;
  final FirebaseFirestore firestore;
  final VoidCallback onCleared;

  @override
  Widget build(BuildContext context) {
    final isActive = item.status == 'active';
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
            color: isActive ? Colors.red.shade300 : Colors.green.shade300,
            width: 1.2),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor:
              isActive ? Colors.red.shade100 : Colors.green.shade100,
          child: Icon(isActive ? Icons.warning_amber : Icons.check_circle,
              color: isActive ? Colors.red : Colors.green, size: 20),
        ),
        title: Text('${item.subjectCode} — ${item.subjectName}',
            style:
                const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
        subtitle: Text(
          'Roll: ${item.rollNo}  •  Year ${item.year}  •  Sem ${item.semester}\n'
          'Failed: ${item.failedExamSession.isNotEmpty ? item.failedExamSession : "—"}'
          '${!isActive ? '\nCleared: ${item.clearedExamSession ?? "—"}' : ''}',
          style: const TextStyle(fontSize: 12),
        ),
        isThreeLine: true,
        trailing: isActive
            ? IconButton(
                icon: const Icon(Icons.clear_all, color: Colors.green),
                tooltip: 'Manually mark as cleared',
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
            'Manually clear backlog for ${item.rollNo} — ${item.subjectCode}?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style:
                  ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: const Text('Clear',
                  style: TextStyle(color: Colors.white))),
        ],
      ),
    );
    if (ok == true) {
      // Write a cleared record to Firestore so supply exam registration
      // can reference it if needed.
      await firestore.collection('backlogs').add({
        'rollNo': item.rollNo,
        'subjectCode': item.subjectCode,
        'subjectName': item.subjectName,
        'year': item.year,
        'semester': item.semester,
        'examSession': item.failedExamSession,
        'status': 'cleared',
        'clearedExamSession': 'MANUAL',
        'clearedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      });
      onCleared();
    }
  }
}


class _SupplyWindowsTab extends StatefulWidget {
  final FirebaseFirestore firestore;
  const _SupplyWindowsTab({required this.firestore});

  @override
  State<_SupplyWindowsTab> createState() => _SupplyWindowsTabState();
}

class _SupplyWindowsTabState extends State<_SupplyWindowsTab> {
  late final Stream<QuerySnapshot> _stream;

  @override
  void initState() {
    super.initState();
    _stream = widget.firestore
        .collection('supplyWindows')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

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
            stream: _stream,
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
    final sessionCtrl = TextEditingController(text: data?['examSession'] ?? '');
    DateTime? startDate = (data?['startDate'] as Timestamp?)?.toDate();
    DateTime? endDate = (data?['endDate'] as Timestamp?)?.toDate();
    bool isActive = data?['isActive'] ?? false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title:
              Text(existing == null ? 'Create Supply Window' : 'Edit Window'),
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
                    lastDate: DateTime.now().add(const Duration(days: 365)),
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
                    lastDate: DateTime.now().add(const Duration(days: 365)),
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
                  'startDate':
                      startDate != null ? Timestamp.fromDate(startDate!) : null,
                  'endDate':
                      endDate != null ? Timestamp.fromDate(endDate!) : null,
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
              const Text('Assign a faculty member to each supply exam subject.',
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
                                child: Text('${f['name']} (${f['id']})',
                                    overflow: TextOverflow.ellipsis),
                              )),
                        ],
                        onChanged: (v) => setS(() => selections[entry.key] = v),
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

// Caches the facuty-assignments stream to avoid rapid subscribe/unsubscribe.
class _FacultyAssignmentsSummary extends StatefulWidget {
  const _FacultyAssignmentsSummary({
    required this.firestore,
    required this.windowId,
  });

  final FirebaseFirestore firestore;
  final String windowId;

  @override
  State<_FacultyAssignmentsSummary> createState() =>
      _FacultyAssignmentsSummaryState();
}

class _FacultyAssignmentsSummaryState
    extends State<_FacultyAssignmentsSummary> {
  late final Stream<QuerySnapshot> _stream;

  @override
  void initState() {
    super.initState();
    _stream = widget.firestore
        .collection('supplySubjectAssignments')
        .where('windowId', isEqualTo: widget.windowId)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _stream,
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
                  style: const TextStyle(fontSize: 11, color: Colors.black87),
                );
              }),
            ],
          ),
        );
      },
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
            _FacultyAssignmentsSummary(
              firestore: firestore,
              windowId: doc.id,
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
                  style:
                      OutlinedButton.styleFrom(foregroundColor: Colors.indigo),
                ),
                ElevatedButton.icon(
                  onPressed: () async {
                    await firestore
                        .collection('supplyWindows')
                        .doc(doc.id)
                        .update({'isActive': !isActive});
                  },
                  icon: Icon(isActive ? Icons.lock : Icons.lock_open, size: 14),
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
        border: Border.all(color: active ? Colors.green : Colors.grey.shade400),
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
  late final Stream<QuerySnapshot> _windowsStream;
  Stream<QuerySnapshot>? _registrationsStream;

  @override
  void initState() {
    super.initState();
    _windowsStream = widget.firestore
        .collection('supplyWindows')
        .orderBy('createdAt', descending: true)
        .snapshots();
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
                onChanged: (v) => setState(() {
                  _selectedWindowId = v;
                  if (v != null) {
                    // No orderBy here — avoids requiring a composite index.
                    // Sorting is done client-side after receiving results.
                    _registrationsStream = widget.firestore
                        .collection('supplyRegistrations')
                        .where('supplyWindowId', isEqualTo: v)
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
                  child: Text(
                      'Select a supply window above to view registrations.')))
        else
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _registrationsStream,
              builder: (ctx, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'Error loading registrations:\n${snap.error}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  );
                }
                var docs = List.from(snap.data?.docs ?? []);
                // Sort newest first client-side (avoids composite index requirement)
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
                  return _emptyHint('No registrations yet for this window.');
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: docs.length,
                  itemBuilder: (_, i) {
                    final data = docs[i].data() as Map<String, dynamic>;
                    final subjects = List<Map<String, dynamic>>.from(
                        (data['subjects'] as List? ?? [])
                            .map((s) => Map<String, dynamic>.from(s as Map)));
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
// Supply Marks Tab — view marks, release results per supply window
// ═══════════════════════════════════════════════════════════════════════════

class _SupplyMarksTab extends StatefulWidget {
  const _SupplyMarksTab({required this.firestore});
  final FirebaseFirestore firestore;

  @override
  State<_SupplyMarksTab> createState() => _SupplyMarksTabState();
}

class _SupplyMarksTabState extends State<_SupplyMarksTab> {
  late final Stream<QuerySnapshot> _windowsStream;
  String? _selectedWindowId;
  final _searchCtrl = TextEditingController();
  bool _releasing = false;

  @override
  void initState() {
    super.initState();
    _windowsStream = widget.firestore.collection('supplyWindows').snapshots();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  /// Flip resultsReleased on the window doc AND batch-update every supplyMarks
  /// doc under that window so the student filter works without a composite index.
  Future<void> _toggleRelease(String windowId, bool currentlyReleased) async {
    final newValue = !currentlyReleased;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(newValue ? 'Release Results?' : 'Withdraw Release?'),
        content: Text(newValue
            ? 'Students will immediately be able to see their supply exam results and download their memo.'
            : 'Results will be hidden from students until you release again.'),
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
      // 1. Update the window document
      await widget.firestore.collection('supplyWindows').doc(windowId).update({
        'resultsReleased': newValue,
        'resultsReleasedAt':
            newValue ? FieldValue.serverTimestamp() : FieldValue.delete(),
      });
      // 2. Batch-update all supplyMarks docs for this window
      final markDocs = await widget.firestore
          .collection('supplyMarks')
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
              ? 'Results released — students can now view marks and download memo.'
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
        final windows = windowSnap.data?.docs ?? [];
        if (windowSnap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (windows.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Text('No supply windows found.',
                  style: TextStyle(color: Colors.grey)),
            ),
          );
        }

        // Get data for the selected window
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
            // Window selector dropdown
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              child: DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Select Supply Window',
                  border: OutlineInputBorder(),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  isDense: true,
                ),
                value: _selectedWindowId,
                isExpanded: true,
                items: windows.map((doc) {
                  final d = doc.data() as Map<String, dynamic>;
                  final released = d['resultsReleased'] as bool? ?? false;
                  return DropdownMenuItem(
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
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: released
                                ? Colors.green[100]
                                : Colors.orange[100],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            released ? 'RELEASED' : 'HELD',
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: released
                                    ? Colors.green[800]
                                    : Colors.orange[800]),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (v) => setState(() {
                  _selectedWindowId = v;
                  _searchCtrl.clear();
                }),
              ),
            ),

            // Release toggle banner
            if (_selectedWindowId != null && selectedWindowData != null) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color:
                        isReleased ? Colors.green[50] : Colors.orange[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color:
                            isReleased ? Colors.green : Colors.orange),
                  ),
                  child: Row(
                    children: [
                      Icon(
                          isReleased
                              ? Icons.lock_open
                              : Icons.lock_outline,
                          color:
                              isReleased ? Colors.green[700] : Colors.orange[700],
                          size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isReleased
                                  ? 'Results are RELEASED'
                                  : 'Results are HELD (not visible to students)',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: isReleased
                                      ? Colors.green[800]
                                      : Colors.orange[800]),
                            ),
                            if (isReleased &&
                                selectedWindowData['resultsReleasedAt'] != null)
                              Text(
                                'Released on: ${DateFormat('dd MMM yyyy, hh:mm a').format((selectedWindowData['resultsReleasedAt'] as Timestamp).toDate())}',
                                style: const TextStyle(
                                    fontSize: 11, color: Colors.grey),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      _releasing
                          ? const SizedBox(
                              width: 28,
                              height: 28,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : ElevatedButton.icon(
                              icon: Icon(
                                  isReleased
                                      ? Icons.visibility_off
                                      : Icons.publish,
                                  size: 16),
                              label: Text(
                                  isReleased ? 'Withdraw' : 'Release Results',
                                  style: const TextStyle(fontSize: 12)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isReleased
                                    ? Colors.orange[700]
                                    : Colors.green[700],
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                              ),
                              onPressed: () => _toggleRelease(
                                  _selectedWindowId!, isReleased),
                            ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                child: TextField(
                  controller: _searchCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Search by Roll No',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    isDense: true,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              Expanded(
                child: _SupplyMarksList(
                  firestore: widget.firestore,
                  windowId: _selectedWindowId!,
                  searchQuery: _searchCtrl.text.trim().toUpperCase(),
                ),
              ),
            ] else
              const Expanded(
                child: Center(
                  child: Text('Select a supply window to view marks.',
                      style: TextStyle(color: Colors.grey)),
                ),
              ),
          ],
        );
      },
    );
  }
}

// ── Inner list widget (stateful so stream is cached and recreated on windowId change)

class _SupplyMarksList extends StatefulWidget {
  const _SupplyMarksList({
    required this.firestore,
    required this.windowId,
    required this.searchQuery,
  });
  final FirebaseFirestore firestore;
  final String windowId;
  final String searchQuery;

  @override
  State<_SupplyMarksList> createState() => _SupplyMarksListState();
}

class _SupplyMarksListState extends State<_SupplyMarksList> {
  late Stream<QuerySnapshot> _stream;
  late String _trackedWindowId;

  @override
  void initState() {
    super.initState();
    _trackedWindowId = widget.windowId;
    _stream = widget.firestore
        .collection('supplyMarks')
        .where('windowId', isEqualTo: widget.windowId)
        .snapshots();
  }

  @override
  void didUpdateWidget(_SupplyMarksList old) {
    super.didUpdateWidget(old);
    if (widget.windowId != _trackedWindowId) {
      _trackedWindowId = widget.windowId;
      _stream = widget.firestore
          .collection('supplyMarks')
          .where('windowId', isEqualTo: widget.windowId)
          .snapshots();
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
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Error loading marks:\n${snap.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red)),
            ),
          );
        }
        var docs = List.from(snap.data?.docs ?? []);
        // Sort by rollNo then subjectCode client-side
        docs.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          final rc = (aData['rollNo'] as String? ?? '')
              .compareTo(bData['rollNo'] as String? ?? '');
          if (rc != 0) return rc;
          return (aData['subjectCode'] as String? ?? '')
              .compareTo(bData['subjectCode'] as String? ?? '');
        });
        // Filter by search query
        if (widget.searchQuery.isNotEmpty) {
          docs = docs.where((d) {
            final data = d.data() as Map<String, dynamic>;
            return (data['rollNo'] as String? ?? '')
                .toUpperCase()
                .contains(widget.searchQuery);
          }).toList();
        }
        if (docs.isEmpty) {
          return _emptyHint(widget.searchQuery.isNotEmpty
              ? 'No marks found for "${widget.searchQuery}".'
              : 'No marks uploaded for this window yet.');
        }
        // Group by rollNo
        final Map<String, List<Map<String, dynamic>>> byRoll = {};
        for (final d in docs) {
          final data = d.data() as Map<String, dynamic>;
          byRoll
              .putIfAbsent(data['rollNo'] as String? ?? '?', () => [])
              .add(data);
        }
        final rolls = byRoll.keys.toList()..sort();
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: rolls.length,
          itemBuilder: (_, i) {
            final roll = rolls[i];
            final subjects = byRoll[roll]!;
            final studentName =
                subjects.first['studentName'] as String? ?? '';
            final released =
                subjects.first['resultsReleased'] as bool? ?? false;
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              elevation: 2,
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Student header
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    color: const Color(0xFF1e3a5f),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '$roll${studentName.isNotEmpty ? '  —  $studentName' : ''}',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: released
                                ? Colors.green
                                : Colors.orange[700],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            released ? 'RELEASED' : 'HELD',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Marks table
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Table(
                      columnWidths: const {
                        0: FlexColumnWidth(1.8),
                        1: FlexColumnWidth(3),
                        2: FlexColumnWidth(0.9),
                        3: FlexColumnWidth(0.9),
                        4: FlexColumnWidth(0.9),
                        5: FlexColumnWidth(0.9),
                        6: FlexColumnWidth(1.5),
                      },
                      border: TableBorder.all(
                          color: Colors.grey[300]!, width: 0.5),
                      children: [
                        TableRow(
                          decoration: BoxDecoration(color: Colors.grey[200]),
                          children: const [
                            _MarksTH('Code'),
                            _MarksTH('Subject'),
                            _MarksTH('Int'),
                            _MarksTH('Ext'),
                            _MarksTH('Tot'),
                            _MarksTH('Grd'),
                            _MarksTH('Result'),
                          ],
                        ),
                        ...subjects.map(
                          (s) => TableRow(children: [
                            _MarksTD(s['subjectCode'] ?? '—'),
                            _MarksTD(s['subjectName'] ?? '—',
                                align: TextAlign.left),
                            _MarksTD('${s['internalMarks'] ?? '—'}'),
                            _MarksTD('${s['externalMarks'] ?? '—'}'),
                            _MarksTD('${s['totalMarks'] ?? '—'}'),
                            _MarksTD('${s['grade'] ?? '—'}'),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 5, horizontal: 3),
                              child: Text(
                                s['result'] ?? '—',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: s['result'] == 'PASS'
                                      ? Colors.green[700]
                                      : Colors.red[700],
                                ),
                              ),
                            ),
                          ]),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _MarksTH extends StatelessWidget {
  const _MarksTH(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 3),
        child: Text(text,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center),
      );
}

class _MarksTD extends StatelessWidget {
  const _MarksTD(this.text, {this.align = TextAlign.center});
  final String text;
  final TextAlign align;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 3),
        child: Text(text,
            style: const TextStyle(fontSize: 11),
            textAlign: align,
            overflow: TextOverflow.ellipsis),
      );
}

// ═══════════════════════════════════════════════════════════════════════════
// Shared helpers
// ═══════════════════════════════════════════════════════════════════════════

Widget _emptyHint(String msg) => Padding(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Text(msg,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey)),
      ),
    );
