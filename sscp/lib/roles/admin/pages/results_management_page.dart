import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

/// Admin page — 4 tabs:
///   1. Upload Results  — enter per-student subject marks for an exam session
///   2. Backlogs        — view / clear backlogs for any student
///   3. Supply Windows  — create / enable / disable supply exam windows
///   4. Registrations   — view who registered for each supply window
class ResultsManagementPage extends StatefulWidget {
  const ResultsManagementPage({super.key});

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
    _tab = TabController(length: 4, vsync: this);
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
        title: const Text('Results & Backlogs Management'),
        backgroundColor: const Color(0xFF1e3a5f),
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tab,
          indicatorColor: Colors.yellow,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          isScrollable: true,
          tabs: const [
            Tab(icon: Icon(Icons.upload_file), text: 'Upload Results'),
            Tab(icon: Icon(Icons.warning_amber), text: 'Backlogs'),
            Tab(icon: Icon(Icons.event_note), text: 'Supply Windows'),
            Tab(icon: Icon(Icons.how_to_reg), text: 'Registrations'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _UploadResultsTab(firestore: _firestore),
          _BacklogsTab(firestore: _firestore),
          _SupplyWindowsTab(firestore: _firestore),
          _RegistrationsTab(firestore: _firestore),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// TAB 1 — Upload Results
// ═══════════════════════════════════════════════════════════════════════════

class _UploadResultsTab extends StatefulWidget {
  final FirebaseFirestore firestore;
  const _UploadResultsTab({required this.firestore});

  @override
  State<_UploadResultsTab> createState() => _UploadResultsTabState();
}

class _UploadResultsTabState extends State<_UploadResultsTab> {
  // Step 1 — session meta
  final _sessionCtrl = TextEditingController(); // e.g., NOV-2025
  String _examType = 'Regular';
  String? _year;
  String? _semester;
  String? _department;
  final _depts = ['CSE', 'ECE', 'EEE', 'MECH', 'CIVIL', 'IT', 'AIDS', 'AIML'];
  final _years = ['1', '2', '3', '4'];
  final _sems = ['1', '2'];

  // Step 2 — subjects for this session
  final List<Map<String, dynamic>> _subjects = [];
  final _subCodeCtrl = TextEditingController();
  final _subNameCtrl = TextEditingController();

  // Step 3 — student marks
  final List<Map<String, dynamic>> _students = []; // loaded from Firestore
  bool _loadingStudents = false;

  // Each entry: { rollNo, name, marks: { subCode: {internal, external} } }
  final List<Map<String, dynamic>> _marksData = [];

  int _step = 0; // 0=session, 1=subjects, 2=students/marks, 3=done

  @override
  void dispose() {
    _sessionCtrl.dispose();
    _subCodeCtrl.dispose();
    _subNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadStudents() async {
    if (_year == null || _department == null) return;
    setState(() => _loadingStudents = true);
    try {
      final snap = await widget.firestore
          .collection('students')
          .where('year', isEqualTo: int.tryParse(_year!) ?? 0)
          .where('department', isEqualTo: _department)
          .get();
      _students.clear();
      _marksData.clear();
      for (final doc in snap.docs) {
        final d = doc.data();
        _students.add({'rollNo': doc.id, 'name': d['name'] ?? ''});
        final marks = <String, dynamic>{};
        for (final sub in _subjects) {
          marks[sub['code']] = {'internal': '', 'external': ''};
        }
        _marksData
            .add({'rollNo': doc.id, 'name': d['name'] ?? '', 'marks': marks});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _loadingStudents = false);
    }
  }

  Future<void> _submitResults() async {
    if (_sessionCtrl.text.trim().isEmpty) return;
    final session = _sessionCtrl.text.trim().toUpperCase();
    final batch = widget.firestore.batch();
    int backlogs = 0;
    int cleared = 0;

    for (final student in _marksData) {
      final rollNo = student['rollNo'] as String;
      final name = student['name'] as String;
      final marks = student['marks'] as Map<String, dynamic>;

      final subjectResults = <Map<String, dynamic>>[];
      bool allPassed = true;

      for (final sub in _subjects) {
        final code = sub['code'] as String;
        final subMarks = marks[code] as Map<String, dynamic>;
        final internal = int.tryParse('${subMarks['internal']}') ?? 0;
        final external = int.tryParse('${subMarks['external']}') ?? 0;
        final total = internal + external;
        final passed =
            external >= 28 && total >= 45; // typical R20 pass criteria
        final grade = _computeGrade(total);

        subjectResults.add({
          'code': code,
          'name': sub['name'],
          'internalMarks': internal,
          'externalMarks': external,
          'totalMarks': total,
          'grade': grade,
          'result': passed ? 'Pass' : 'Fail',
        });

        if (!passed) {
          allPassed = false;
          if (_examType == 'Regular') {
            // Create/update backlog
            final backlogSnap = await widget.firestore
                .collection('backlogs')
                .where('rollNo', isEqualTo: rollNo)
                .where('subjectCode', isEqualTo: code)
                .where('status', isEqualTo: 'active')
                .limit(1)
                .get();
            if (backlogSnap.docs.isEmpty) {
              final ref = widget.firestore.collection('backlogs').doc();
              batch.set(ref, {
                'rollNo': rollNo,
                'studentName': name,
                'subjectCode': code,
                'subjectName': sub['name'],
                'year': int.tryParse(_year!) ?? 0,
                'semester': _semester ?? '',
                'examSession': session,
                'status': 'active',
                'clearedExamSession': null,
                'clearedAt': null,
                'createdAt': FieldValue.serverTimestamp(),
              });
              backlogs++;
            }
          } else {
            // Supply exam — subject still failed, backlog remains
          }
        } else if (passed && _examType == 'Supply') {
          // Clear backlog for this supply subject
          final backlogSnap = await widget.firestore
              .collection('backlogs')
              .where('rollNo', isEqualTo: rollNo)
              .where('subjectCode', isEqualTo: code)
              .where('status', isEqualTo: 'active')
              .get();
          for (final bdoc in backlogSnap.docs) {
            batch.update(bdoc.reference, {
              'status': 'cleared',
              'clearedExamSession': session,
              'clearedAt': FieldValue.serverTimestamp(),
            });
            cleared++;
          }
        }
      }

      // Save result doc
      final resultRef = widget.firestore
          .collection('semResults')
          .doc('${rollNo}_${session}_${_examType}');
      batch.set(
          resultRef,
          {
            'rollNo': rollNo,
            'studentName': name,
            'year': int.tryParse(_year!) ?? 0,
            'semester': _semester ?? '',
            'department': _department ?? '',
            'examSession': session,
            'examType': _examType,
            'subjects': subjectResults,
            'allPassed': allPassed,
            'uploadedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true));
    }

    try {
      await batch.commit();
      if (mounted) {
        setState(() => _step = 3);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'Results saved. $backlogs new backlogs created, $cleared backlogs cleared.'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 4),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error saving: $e')));
      }
    }
  }

  String _computeGrade(int total) {
    if (total >= 90) return 'O';
    if (total >= 80) return 'A+';
    if (total >= 70) return 'A';
    if (total >= 60) return 'B+';
    if (total >= 55) return 'B';
    if (total >= 50) return 'C';
    if (total >= 45) return 'D';
    return 'F';
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: [
        _buildStep0(),
        _buildStep1(),
        _buildStep2(),
        _buildStep3(),
      ][_step],
    );
  }

  // ── Step 0 — Session meta ─────────────────────────────────────────────
  Widget _buildStep0() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('1. Exam Session Details'),
        const SizedBox(height: 16),
        TextField(
          controller: _sessionCtrl,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(
            labelText: 'Exam Session (e.g., NOV-2025, APR-2026)',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.calendar_month),
          ),
        ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: DropdownButtonFormField<String>(
              value: _examType,
              decoration: const InputDecoration(
                  labelText: 'Exam Type', border: OutlineInputBorder()),
              items: ['Regular', 'Supply']
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: (v) => setState(() => _examType = v!),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonFormField<String>(
              value: _year,
              decoration: const InputDecoration(
                  labelText: 'Year', border: OutlineInputBorder()),
              items: _years
                  .map(
                      (e) => DropdownMenuItem(value: e, child: Text('Year $e')))
                  .toList(),
              onChanged: (v) => setState(() => _year = v),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonFormField<String>(
              value: _semester,
              decoration: const InputDecoration(
                  labelText: 'Semester', border: OutlineInputBorder()),
              items: _sems
                  .map((e) => DropdownMenuItem(value: e, child: Text('Sem $e')))
                  .toList(),
              onChanged: (v) => setState(() => _semester = v),
            ),
          ),
        ]),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: _department,
          decoration: const InputDecoration(
              labelText: 'Department', border: OutlineInputBorder()),
          items: _depts
              .map((e) => DropdownMenuItem(value: e, child: Text(e)))
              .toList(),
          onChanged: (v) => setState(() => _department = v),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: (_sessionCtrl.text.trim().isNotEmpty &&
                    _year != null &&
                    _semester != null &&
                    _department != null)
                ? () => setState(() => _step = 1)
                : null,
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1e3a5f),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14)),
            child: const Text('Next: Add Subjects →'),
          ),
        ),
      ],
    );
  }

  // ── Step 1 — Add subjects ─────────────────────────────────────────────
  Widget _buildStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('2. Add Subjects for this Session'),
        const SizedBox(height: 4),
        Text(
          '${_sessionCtrl.text.trim()} • Year $_year • Sem $_semester • $_department • $_examType',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
        ),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(
            child: TextField(
              controller: _subCodeCtrl,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                  labelText: 'Subject Code', border: OutlineInputBorder()),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: TextField(
              controller: _subNameCtrl,
              decoration: const InputDecoration(
                  labelText: 'Subject Name', border: OutlineInputBorder()),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            onPressed: () {
              final code = _subCodeCtrl.text.trim().toUpperCase();
              final name = _subNameCtrl.text.trim();
              if (code.isEmpty || name.isEmpty) return;
              setState(() {
                _subjects.add({'code': code, 'name': name});
                _subCodeCtrl.clear();
                _subNameCtrl.clear();
              });
            },
            icon: const Icon(Icons.add),
            style: IconButton.styleFrom(
                backgroundColor: const Color(0xFF1e3a5f),
                foregroundColor: Colors.white),
          ),
        ]),
        const SizedBox(height: 12),
        if (_subjects.isEmpty)
          _emptyHint('No subjects added yet. Add at least one subject.')
        else
          ...List.generate(_subjects.length, (i) {
            final s = _subjects[i];
            return ListTile(
              dense: true,
              leading: CircleAvatar(
                backgroundColor: const Color(0xFF1e3a5f),
                radius: 14,
                child: Text('${i + 1}',
                    style: const TextStyle(color: Colors.white, fontSize: 11)),
              ),
              title: Text('${s['code']} — ${s['name']}'),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline,
                    color: Colors.red, size: 18),
                onPressed: () => setState(() => _subjects.removeAt(i)),
              ),
            );
          }),
        const SizedBox(height: 20),
        Row(children: [
          OutlinedButton(
              onPressed: () => setState(() => _step = 0),
              child: const Text('← Back')),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: _subjects.isNotEmpty
                  ? () async {
                      await _loadStudents();
                      if (mounted) setState(() => _step = 2);
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1e3a5f),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14)),
              child: const Text('Next: Enter Marks →'),
            ),
          ),
        ]),
      ],
    );
  }

  // ── Step 2 — Enter marks ──────────────────────────────────────────────
  Widget _buildStep2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('3. Enter Marks'),
        const SizedBox(height: 4),
        Text(
          '${_sessionCtrl.text.trim()} • Year $_year Sem $_semester • $_department • $_examType',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
        ),
        const SizedBox(height: 12),
        if (_loadingStudents)
          const Center(child: CircularProgressIndicator())
        else if (_marksData.isEmpty)
          _emptyHint('No students found for Year $_year, $_department.')
        else ...[
          Text('${_marksData.length} students found',
              style: const TextStyle(fontSize: 12, color: Colors.green)),
          const SizedBox(height: 8),
          ...List.generate(_marksData.length, (si) {
            final student = _marksData[si];
            final marks = student['marks'] as Map<String, dynamic>;
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ExpansionTile(
                title: Text('${student['rollNo']} — ${student['name']}',
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600)),
                children: _subjects.map((sub) {
                  final code = sub['code'] as String;
                  final subMarks = marks[code] as Map<String, dynamic>;
                  return Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    child: Row(children: [
                      Expanded(
                        flex: 2,
                        child: Text('${sub['code']}\n${sub['name']}',
                            style: const TextStyle(fontSize: 12)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _marksField(
                          label: 'Internal (/30)',
                          value: '${subMarks['internal']}',
                          onChanged: (v) =>
                              setState(() => subMarks['internal'] = v),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _marksField(
                          label: 'External (/70)',
                          value: '${subMarks['external']}',
                          onChanged: (v) =>
                              setState(() => subMarks['external'] = v),
                        ),
                      ),
                    ]),
                  );
                }).toList(),
              ),
            );
          }),
          const SizedBox(height: 20),
          Row(children: [
            OutlinedButton(
                onPressed: () => setState(() => _step = 1),
                child: const Text('← Back')),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: _submitResults,
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14)),
                child: const Text('Submit Results'),
              ),
            ),
          ]),
        ],
      ],
    );
  }

  Widget _marksField(
      {required String label,
      required String value,
      required ValueChanged<String> onChanged}) {
    return TextFormField(
      initialValue: value == '0' ? '' : value,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        isDense: true,
      ),
      onChanged: onChanged,
    );
  }

  // ── Step 3 — Done ─────────────────────────────────────────────────────
  Widget _buildStep3() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 72),
            const SizedBox(height: 16),
            const Text('Results Uploaded Successfully!',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              '${_sessionCtrl.text.trim()} results for Year $_year Sem $_semester ($_department) saved.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => setState(() {
                _step = 0;
                _subjects.clear();
                _marksData.clear();
                _students.clear();
                _sessionCtrl.clear();
                _year = null;
                _semester = null;
                _department = null;
                _examType = 'Regular';
              }),
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1e3a5f),
                  foregroundColor: Colors.white),
              child: const Text('Upload Another Session'),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// TAB 2 — Backlogs
// ═══════════════════════════════════════════════════════════════════════════

class _BacklogsTab extends StatefulWidget {
  final FirebaseFirestore firestore;
  const _BacklogsTab({required this.firestore});

  @override
  State<_BacklogsTab> createState() => _BacklogsTabState();
}

class _BacklogsTabState extends State<_BacklogsTab> {
  String _filter = 'active'; // active | cleared | all
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
              if (docs.isEmpty) {
                return _emptyHint('No backlog records found.');
              }
              return ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: docs.length,
                itemBuilder: (_, i) {
                  final data = docs[i].data() as Map<String, dynamic>;
                  return _BacklogCard(
                    doc: docs[i],
                    data: data,
                    firestore: widget.firestore,
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

class _BacklogCard extends StatelessWidget {
  final QueryDocumentSnapshot doc;
  final Map<String, dynamic> data;
  final FirebaseFirestore firestore;

  const _BacklogCard(
      {required this.doc, required this.data, required this.firestore});

  @override
  Widget build(BuildContext context) {
    final status = data['status'] as String? ?? 'active';
    final isActive = status == 'active';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor:
              isActive ? Colors.red.shade100 : Colors.green.shade100,
          child: Icon(
            isActive ? Icons.warning_amber : Icons.check_circle,
            color: isActive ? Colors.red : Colors.green,
            size: 20,
          ),
        ),
        title: Text(
          '${data['rollNo']} — ${data['subjectCode']}',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
        ),
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
                tooltip: 'Manually clear this backlog',
                onPressed: () => _manualClear(context),
              )
            : Chip(
                label: const Text('Cleared',
                    style: TextStyle(fontSize: 10, color: Colors.white)),
                backgroundColor: Colors.green,
              ),
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
              child:
                  const Text('Clear', style: TextStyle(color: Colors.white))),
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
// TAB 3 — Supply Windows
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
                    'No supply windows created yet. Click "New Window" to create one.');
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
    final feeCtrl = TextEditingController(text: '${data?['fee'] ?? ''}');
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
              TextField(
                controller: feeCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: 'Registration Fee (₹ per subject)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.currency_rupee)),
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
                    ? 'Start: ${DateFormat('dd-MM-yyyy').format(startDate!)}'
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
                    ? 'End: ${DateFormat('dd-MM-yyyy').format(endDate!)}'
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
                  'fee': int.tryParse(feeCtrl.text.trim()) ?? 0,
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
}

class _SupplyWindowCard extends StatelessWidget {
  final QueryDocumentSnapshot doc;
  final Map<String, dynamic> data;
  final FirebaseFirestore firestore;
  final VoidCallback onEdit;

  const _SupplyWindowCard(
      {required this.doc,
      required this.data,
      required this.firestore,
      required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final isActive = data['isActive'] as bool? ?? false;
    final start = (data['startDate'] as Timestamp?)?.toDate();
    final end = (data['endDate'] as Timestamp?)?.toDate();
    final fee = data['fee'] ?? 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
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
            Text('Fee: ₹$fee per subject',
                style: const TextStyle(fontSize: 12, color: Colors.blueGrey)),
            const SizedBox(height: 10),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit, size: 14),
                  label: const Text('Edit'),
                ),
                const SizedBox(width: 8),
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
                const Spacer(),
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
// TAB 4 — Supply Registrations
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
                    final payStatus =
                        data['paymentStatus'] as String? ?? 'pending';
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
                          'Fee: ₹${data['totalFee'] ?? 0}  •  Payment: $payStatus',
                        ),
                        isThreeLine: true,
                        trailing: payStatus == 'paid'
                            ? const Icon(Icons.check_circle,
                                color: Colors.green)
                            : OutlinedButton(
                                onPressed: () async {
                                  await widget.firestore
                                      .collection('supplyRegistrations')
                                      .doc(docs[i].id)
                                      .update({'paymentStatus': 'paid'});
                                },
                                child: const Text('Mark Paid'),
                              ),
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
