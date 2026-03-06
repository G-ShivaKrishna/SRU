import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../../widgets/app_header.dart';
import '../../../services/user_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Student Results Screen – Results / Backlogs / Supply Exam tabs
// ─────────────────────────────────────────────────────────────────────────────

class ResultsScreen extends StatefulWidget {
  const ResultsScreen({super.key, this.initialTab = 0});
  final int initialTab;

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  late String _rollNo;

  @override
  void initState() {
    super.initState();
    _tab =
        TabController(length: 2, vsync: this, initialIndex: widget.initialTab);
    final email = FirebaseAuth.instance.currentUser?.email ?? '';
    _rollNo = UserService.getCurrentUserId() ?? email.split('@')[0].toUpperCase();
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
        title: const Text('Results & Backlogs'),
        backgroundColor: const Color(0xFF1e3a5f),
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tab,
          labelColor: Colors.yellow,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.yellow,
          tabs: const [
            Tab(text: 'Backlogs'),
            Tab(text: 'Supply Exam'),
          ],
        ),
      ),
      body: Column(
        children: [
          const AppHeader(),
          Expanded(
            child: TabBarView(
              controller: _tab,
              children: [
                _BacklogsTab(rollNo: _rollNo),
                _SupplyExamTab(rollNo: _rollNo),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab 1 – Results
// ─────────────────────────────────────────────────────────────────────────────

class _ResultsTab extends StatefulWidget {
  const _ResultsTab({required this.rollNo});
  final String rollNo;

  @override
  State<_ResultsTab> createState() => _ResultsTabState();
}

class _ResultsTabState extends State<_ResultsTab> {
  late final Stream<QuerySnapshot> _stream;

  @override
  void initState() {
    super.initState();
    _stream = FirebaseFirestore.instance
        .collection('semResults')
        .where('rollNo', isEqualTo: widget.rollNo)
        .orderBy('uploadedAt', descending: true)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _stream,
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snap.hasData || snap.data!.docs.isEmpty) {
          return const Center(child: Text('No results uploaded yet.'));
        }
        final docs = snap.data!.docs;
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          itemBuilder: (_, i) => _ResultCard(doc: docs[i]),
        );
      },
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.doc});
  final QueryDocumentSnapshot doc;

  @override
  Widget build(BuildContext context) {
    final data = doc.data() as Map<String, dynamic>;
    final subjects = List<Map<String, dynamic>>.from(data['subjects'] ?? []);
    final allPassed = data['allPassed'] ?? false;

    final passed = subjects.where((s) => s['result'] == 'PASS').length;
    final failed = subjects.length - passed;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      elevation: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFF1e3a5f),
              borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${data['examSession']} — ${data['examType']}',
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: allPassed ? Colors.green : Colors.red,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    allPassed ? 'PASS' : 'FAIL',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          // Sub-header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: Text(
              'Year ${data['year']}  •  Sem ${data['semester']}  •  ${data['department']}',
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ),
          // Subjects table
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(Colors.grey[100]),
              columnSpacing: 16,
              columns: const [
                DataColumn(label: Text('Subject')),
                DataColumn(label: Text('Int')),
                DataColumn(label: Text('Ext')),
                DataColumn(label: Text('Tot')),
                DataColumn(label: Text('Grade')),
                DataColumn(label: Text('Result')),
              ],
              rows: subjects.map((s) {
                final pass = s['result'] == 'PASS';
                return DataRow(cells: [
                  DataCell(
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s['subjectCode'] ?? '',
                            style: const TextStyle(
                                fontSize: 11, fontWeight: FontWeight.bold)),
                        Text(s['subjectName'] ?? '',
                            style: const TextStyle(fontSize: 11)),
                      ],
                    ),
                  ),
                  DataCell(Text('${s['internalMarks'] ?? '-'}')),
                  DataCell(Text('${s['externalMarks'] ?? '-'}')),
                  DataCell(Text('${s['totalMarks'] ?? '-'}')),
                  DataCell(Text(s['grade'] ?? '-')),
                  DataCell(Text(
                    s['result'] ?? '-',
                    style: TextStyle(
                      color: pass ? Colors.green : Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  )),
                ]);
              }).toList(),
            ),
          ),
          // Footer
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$passed Passed  •  $failed Failed',
                  style: const TextStyle(fontSize: 12),
                ),
                OutlinedButton.icon(
                  onPressed: () => _showMemo(context, data, subjects),
                  icon: const Icon(Icons.print, size: 16),
                  label: const Text('Print Memo'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showMemo(BuildContext context, Map<String, dynamic> data,
      List<Map<String, dynamic>> subjects) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('${data['examSession']} — ${data['examType']} Memo'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Student: ${data['studentName']}  (${data['rollNo']})'),
              Text(
                  'Year ${data['year']}  •  Sem ${data['semester']}  •  ${data['department']}'),
              const Divider(),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columnSpacing: 12,
                  columns: const [
                    DataColumn(label: Text('Code')),
                    DataColumn(label: Text('Subject')),
                    DataColumn(label: Text('Int')),
                    DataColumn(label: Text('Ext')),
                    DataColumn(label: Text('Tot')),
                    DataColumn(label: Text('Grade')),
                    DataColumn(label: Text('Result')),
                  ],
                  rows: subjects
                      .map((s) => DataRow(cells: [
                            DataCell(Text(s['subjectCode'] ?? '')),
                            DataCell(Text(s['subjectName'] ?? '')),
                            DataCell(Text('${s['internalMarks'] ?? '-'}')),
                            DataCell(Text('${s['externalMarks'] ?? '-'}')),
                            DataCell(Text('${s['totalMarks'] ?? '-'}')),
                            DataCell(Text(s['grade'] ?? '-')),
                            DataCell(Text(
                              s['result'] ?? '-',
                              style: TextStyle(
                                color: s['result'] == 'PASS'
                                    ? Colors.green
                                    : Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            )),
                          ]))
                      .toList(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close')),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Backlog data model – derived from studentMarks
// ─────────────────────────────────────────────────────────────────────────────

class _BacklogItem {
  final String subjectCode;
  final String subjectName;
  final String year;
  final String semester;
  final String failedExamSession;
  final String status; // 'active' | 'cleared'
  final String? clearedExamSession;

  const _BacklogItem({
    required this.subjectCode,
    required this.subjectName,
    required this.year,
    required this.semester,
    required this.failedExamSession,
    required this.status,
    this.clearedExamSession,
  });
}

/// Derives backlogs for [rollNo] by reading `studentMarks` and `cieMemoReleases`.
/// A subject is an *active* backlog if the latest entry for it is a fail.
/// A subject is *cleared* if a later passing entry exists.
Future<List<_BacklogItem>> _deriveBacklogs(String rollNo) async {
  final db = FirebaseFirestore.instance;

  // Normalise roman/arabic semester strings to '1'/'2'/'3'/'4'
  String normSem(String s) {
    const m = {'i': '1', 'ii': '2', 'iii': '3', 'iv': '4'};
    return m[s.toLowerCase().trim()] ?? s.trim();
  }

  // 1. Load all cieMemoReleases to get examSession + minPassMarks per year/sem
  final relSnap = await db.collection('cieMemoReleases').get();
  final releaseMap = <String, Map<String, dynamic>>{};
  for (final d in relSnap.docs) {
    final r = d.data();
    final key = '${r['year']}_${normSem(r['semester']?.toString() ?? '')}';
    releaseMap[key] = {
      'examSession': (r['examSession'] ?? '').toString(),
      'minPassMarks': (r['minPassMarks'] is int)
          ? r['minPassMarks'] as int
          : int.tryParse(r['minPassMarks']?.toString() ?? '') ?? 40,
    };
  }

  // 2. Load supply exam PASS records for this student (cleared via supply exam)
  final supplySnap = await db
      .collection('supplyMarks')
      .where('rollNo', isEqualTo: rollNo)
      .get();
  // Map: subjectCode -> examSession (only PASS results)
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

  // 3. Load all marks for this student
  final marksSnap = await db
      .collection('studentMarks')
      .where('studentId', isEqualTo: rollNo)
      .get();

  // 4. Group by subjectCode
  final bySubject = <String, List<Map<String, dynamic>>>{};
  for (final doc in marksSnap.docs) {
    final d = Map<String, dynamic>.from(doc.data());
    final code = d['subjectCode']?.toString() ?? '';
    if (code.isEmpty) continue;
    bySubject.putIfAbsent(code, () => []).add(d);
  }

  // 4. For each subject, sort chronologically then find fails
  final items = <_BacklogItem>[];
  bySubject.forEach((code, entries) {
    entries.sort((a, b) {
      final ya = int.tryParse(a['year']?.toString() ?? '') ?? 0;
      final yb = int.tryParse(b['year']?.toString() ?? '') ?? 0;
      if (ya != yb) return ya.compareTo(yb);
      return normSem(a['semester']?.toString() ?? '')
          .compareTo(normSem(b['semester']?.toString() ?? ''));
    });

    for (int i = 0; i < entries.length; i++) {
      final e = entries[i];
      final yearStr = e['year']?.toString() ?? '';
      final semStr = normSem(e['semester']?.toString() ?? '');
      final key = '${yearStr}_$semStr';
      final release = releaseMap[key];
      final minPass = (release?['minPassMarks'] as int?) ?? 40;
      final examSession = (release?['examSession'] as String?) ?? '';

      // Compute grandTotal from componentMarks
      final raw = e['componentMarks'] as Map<String, dynamic>? ?? {};
      int grandTotal = 0;
      for (final v in raw.values) {
        grandTotal += (v is int) ? v : int.tryParse(v.toString()) ?? 0;
      }

      if (grandTotal < minPass) {
        // Failed — check if any later entry passes
        bool clearedLater = false;
        String clearedSession = '';
        for (int j = i + 1; j < entries.length; j++) {
          final later = entries[j];
          final lKey =
              '${later['year']}_${normSem(later['semester']?.toString() ?? '')}';
          final lRelease = releaseMap[lKey];
          final lMinPass = (lRelease?['minPassMarks'] as int?) ?? 40;
          final lRaw = later['componentMarks'] as Map<String, dynamic>? ?? {};
          int lTotal = 0;
          for (final v in lRaw.values) {
            lTotal += (v is int) ? v : int.tryParse(v.toString()) ?? 0;
          }
          if (lTotal >= lMinPass) {
            clearedLater = true;
            clearedSession = (lRelease?['examSession'] as String?) ?? '';
            break;
          }
        }
        // Also check if cleared via supply exam
        if (!clearedLater && supplyPassMap.containsKey(code)) {
          clearedLater = true;
          clearedSession = supplyPassMap[code]!;
        }
        // Avoid duplicate entries for the same fail session
        final alreadyAdded = items.any(
            (x) => x.subjectCode == code && x.failedExamSession == examSession);
        if (!alreadyAdded) {
          items.add(_BacklogItem(
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

  // Active backlogs first, then by year
  items.sort((a, b) {
    if (a.status != b.status) return a.status == 'active' ? -1 : 1;
    return (int.tryParse(a.year) ?? 0).compareTo(int.tryParse(b.year) ?? 0);
  });
  return items;
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab 2 – Backlogs
// ─────────────────────────────────────────────────────────────────────────────

class _BacklogsTab extends StatefulWidget {
  const _BacklogsTab({required this.rollNo});
  final String rollNo;

  @override
  State<_BacklogsTab> createState() => _BacklogsTabState();
}

class _BacklogsTabState extends State<_BacklogsTab> {
  String _filter = 'All';
  late Future<List<_BacklogItem>> _future;

  @override
  void initState() {
    super.initState();
    _future = _deriveBacklogs(widget.rollNo);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: Row(
            children: ['All', 'Active', 'Cleared'].map((f) {
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(f),
                  selected: _filter == f,
                  onSelected: (_) => setState(() => _filter = f),
                ),
              );
            }).toList(),
          ),
        ),
        Expanded(
          child: FutureBuilder<List<_BacklogItem>>(
            future: _future,
            builder: (ctx, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snap.hasError) {
                return Center(child: Text('Error: ${snap.error}'));
              }
              var items = snap.data ?? [];
              if (_filter == 'Active') {
                items = items.where((i) => i.status == 'active').toList();
              } else if (_filter == 'Cleared') {
                items = items.where((i) => i.status == 'cleared').toList();
              }
              if (items.isEmpty) {
                return Center(
                    child: Text(_filter == 'All'
                        ? 'No backlogs found.'
                        : 'No $_filter backlogs.'));
              }
              return RefreshIndicator(
                onRefresh: () async {
                  setState(() {
                    _future = _deriveBacklogs(widget.rollNo);
                  });
                },
                child: ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: items.length,
                  itemBuilder: (_, i) => _BacklogCard(item: items[i]),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _BacklogCard extends StatelessWidget {
  const _BacklogCard({required this.item});
  final _BacklogItem item;

  @override
  Widget build(BuildContext context) {
    final cleared = item.status == 'cleared';
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: cleared ? Colors.green : Colors.red,
          width: 1.5,
        ),
      ),
      child: ListTile(
        leading: Icon(
          cleared ? Icons.check_circle : Icons.warning,
          color: cleared ? Colors.green : Colors.red,
        ),
        title: Text('${item.subjectCode} — ${item.subjectName}'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Year ${item.year}  •  Sem ${item.semester}'),
            if (item.failedExamSession.isNotEmpty)
              Text('Failed in: ${item.failedExamSession}'),
            if (cleared && item.clearedExamSession != null)
              Text(
                'Cleared in: ${item.clearedExamSession}',
                style: const TextStyle(
                    color: Colors.green, fontWeight: FontWeight.bold),
              ),
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: cleared ? Colors.green : Colors.red,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            cleared ? 'CLEARED' : 'BACKLOG',
            style: const TextStyle(
                color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ),
        isThreeLine: true,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab 3 – Supply Exam Registration
// ─────────────────────────────────────────────────────────────────────────────

class _SupplyExamTab extends StatefulWidget {
  const _SupplyExamTab({required this.rollNo});
  final String rollNo;

  @override
  State<_SupplyExamTab> createState() => _SupplyExamTabState();
}

class _SupplyExamTabState extends State<_SupplyExamTab> {
  late final Stream<QuerySnapshot> _stream;

  @override
  void initState() {
    super.initState();
    _stream = FirebaseFirestore.instance
        .collection('supplyWindows')
        .where('isActive', isEqualTo: true)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _stream,
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final now = DateTime.now();
        final windows = (snap.data?.docs ?? []).where((doc) {
          final d = doc.data() as Map<String, dynamic>;
          final start = (d['startDate'] as Timestamp?)?.toDate();
          final end = (d['endDate'] as Timestamp?)?.toDate();
          if (start == null || end == null) return false;
          return now.isAfter(start) && now.isBefore(end);
        }).toList();

        if (windows.isEmpty) {
          return const Center(
              child: Text(
                  'No supply exam registration windows are open right now.'));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: windows.length,
          itemBuilder: (_, i) => _SupplyWindowWidget(
            windowDoc: windows[i],
            rollNo: widget.rollNo,
          ),
        );
      },
    );
  }
}

class _SupplyWindowWidget extends StatefulWidget {
  const _SupplyWindowWidget({required this.windowDoc, required this.rollNo});
  final QueryDocumentSnapshot windowDoc;
  final String rollNo;

  @override
  State<_SupplyWindowWidget> createState() => _SupplyWindowWidgetState();
}

class _SupplyWindowWidgetState extends State<_SupplyWindowWidget> {
  List<Map<String, dynamic>> _backlogs = [];
  Map<String, dynamic>? _existing;
  bool _feePaid = false;
  bool _loading = true;
  final Set<int> _selected = {};
  bool _saving = false;
  late Stream<DocumentSnapshot<Map<String, dynamic>>> _paymentStream;

  @override
  void initState() {
    super.initState();
    _paymentStream = FirebaseFirestore.instance
        .collection('feePayments')
        .doc('supply_${widget.windowDoc.id}_${widget.rollNo}')
        .snapshots();
    _load();
  }

  Future<void> _load() async {
    final db = FirebaseFirestore.instance;
    final results = await Future.wait([
      _deriveBacklogs(widget.rollNo),
      db
          .collection('supplyRegistrations')
          .where('rollNo', isEqualTo: widget.rollNo)
          .where('supplyWindowId', isEqualTo: widget.windowDoc.id)
          .limit(1)
          .get(),
    ]);
    if (!mounted) return;
    final activeBacklogs = (results[0] as List<_BacklogItem>)
        .where((b) => b.status == 'active')
        .map((b) => {
              'subjectCode': b.subjectCode,
              'subjectName': b.subjectName,
              'year': b.year,
              'semester': b.semester,
            })
        .toList();
    final regDocs = (results[1] as QuerySnapshot).docs;
    setState(() {
      _backlogs = activeBacklogs;
      _existing = regDocs.isNotEmpty
          ? regDocs.first.data() as Map<String, dynamic>?
          : null;
      _loading = false;
    });
  }

  Future<bool> _ensurePaymentConfirmed() async {
    final paymentDocId = 'supply_${widget.windowDoc.id}_${widget.rollNo}';
    final doc = await FirebaseFirestore.instance
        .collection('feePayments')
        .doc(paymentDocId)
        .get();
    final paid =
        (doc.data()?['status']?.toString().toLowerCase() ?? '') == 'paid';
    return paid;
  }

  Future<void> _refreshPaymentStatus() async {
    setState(() => _loading = true);
    await Future.delayed(const Duration(milliseconds: 500));
    setState(() => _loading = false);
  }

  Future<void> _showFeePendingDialog() async {
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Fee Payment Required'),
        content: const Text(
          'Please pay the required fee at the office. Registration will be enabled only after Fee Payment staff marks your payment as PAID.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _register() async {
    if (_selected.isEmpty) return;

    final paid = await _ensurePaymentConfirmed();
    if (!paid) {
      if (mounted) {
        await _showFeePendingDialog();
      }
      return;
    }

    final winData = widget.windowDoc.data() as Map<String, dynamic>;
    final fee = (winData['fee'] as num?)?.toInt() ?? 0;
    final subjects = _selected
        .map((i) => {
              'subjectCode': _backlogs[i]['subjectCode'],
              'subjectName': _backlogs[i]['subjectName'],
              'year': _backlogs[i]['year'],
              'semester': _backlogs[i]['semester'],
            })
        .toList();
    final total = fee * subjects.length;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirm Registration'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ...subjects.map(
                (s) => Text('• ${s['subjectCode']} — ${s['subjectName']}')),
            const SizedBox(height: 8),
            Text('Total fee: ₹$total'),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Register')),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance.collection('supplyRegistrations').add({
        'rollNo': widget.rollNo,
        'studentName':
            _backlogs.isNotEmpty ? _backlogs[0]['studentName'] ?? '' : '',
        'supplyWindowId': widget.windowDoc.id,
        'examSession': winData['examSession'],
        'subjects': subjects,
        'totalFee': total,
        'feePerSubject': fee,
        'paymentStatus': 'paid',
        'paymentId': 'supply_${widget.windowDoc.id}_${widget.rollNo}',
        'status': 'registered',
        'registeredAt': FieldValue.serverTimestamp(),
      });
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final winData = widget.windowDoc.data() as Map<String, dynamic>;
    final fee = (winData['fee'] as num?)?.toInt() ?? 0;
    final end = (winData['endDate'] as Timestamp?)?.toDate();

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _paymentStream,
      builder: (ctx, paymentSnap) {
        if (paymentSnap.hasData) {
          final paid =
              (paymentSnap.data?.data()?['status']?.toString().toLowerCase() ??
                      '') ==
                  'paid';
          if (mounted) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (_feePaid != paid) {
                setState(() => _feePaid = paid);
              }
            });
          }
        }
        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          elevation: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Window header
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: const BoxDecoration(
                  color: Color(0xFF1e3a5f),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(winData['title'] ?? 'Supply Window',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15)),
                    Text(winData['examSession'] ?? '',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12)),
                    if (end != null)
                      Text('Closes: ${end.day}/${end.month}/${end.year}',
                          style: const TextStyle(
                              color: Colors.yellow, fontSize: 12)),
                    Text('Fee: ₹$fee per subject',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12)),
                  ],
                ),
              ),

              if (_loading)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_existing != null)
                // Already registered
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue, width: 1),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Already Registered',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue)),
                        const SizedBox(height: 6),
                        ...List<Map<String, dynamic>>.from(
                                _existing!['subjects'] ?? [])
                            .map((s) => Text(
                                '• ${s['subjectCode']} — ${s['subjectName']}',
                                style: const TextStyle(fontSize: 12))),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Total: ₹${_existing!['totalFee']}'),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: _existing!['paymentStatus'] == 'paid'
                                    ? Colors.green
                                    : Colors.orange,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                (_existing!['paymentStatus'] == 'paid'
                                    ? 'PAID'
                                    : 'PAYMENT PENDING'),
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                )
              else if (_backlogs.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(
                    child: Text(
                      'No active backlogs — nothing to register.',
                      style: TextStyle(color: Colors.green),
                    ),
                  ),
                )
              else if (!_feePaid)
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.shade300),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.warning_amber_rounded,
                                color: Colors.orange, size: 18),
                            SizedBox(width: 6),
                            Text('Fee not confirmed',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Pay fee at the office. This page will work only after Fee Payment staff updates your payment to PAID.',
                          style: TextStyle(fontSize: 12),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _showFeePendingDialog,
                                icon: const Icon(Icons.info_outline),
                                label: const Text('Show Payment Info'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton.icon(
                              onPressed: _refreshPaymentStatus,
                              icon: const Icon(Icons.refresh, size: 16),
                              label: const Text('Check'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                )
              else
                // Show selection
                Column(
                  children: [
                    ..._backlogs.asMap().entries.map((e) {
                      final i = e.key;
                      final b = e.value;
                      return CheckboxListTile(
                        title: Text('${b['subjectCode']} — ${b['subjectName']}',
                            style: const TextStyle(fontSize: 13)),
                        subtitle: Text(
                            'Year ${b['year']}  Sem ${b['semester']}',
                            style: const TextStyle(fontSize: 11)),
                        value: _selected.contains(i),
                        onChanged: (v) => setState(() {
                          if (v == true) {
                            _selected.add(i);
                          } else {
                            _selected.remove(i);
                          }
                        }),
                      );
                    }),
                    if (_selected.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 2),
                        child: Text('Fee: ₹${fee * _selected.length}',
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed:
                              (_selected.isEmpty || _saving) ? null : _register,
                          style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1e3a5f)),
                          child: _saving
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2))
                              : const Text('Register',
                                  style: TextStyle(color: Colors.white)),
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }
}
