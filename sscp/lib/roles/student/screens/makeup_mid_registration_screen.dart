import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

/// Normalises semester values so numeric ("1") and Roman ("I") match.
String _normSem(String? s) {
  if (s == null || s.isEmpty) return '';
  const roman = {
    'I': '1',
    'II': '2',
    'III': '3',
    'IV': '4',
    'V': '5',
    'VI': '6',
    'VII': '7',
    'VIII': '8'
  };
  final up = s.trim().toUpperCase();
  return roman[up] ?? s.trim();
}

/// Student: Makeup Mid Exam Registration & Results
/// - Shows active makeup mid windows
/// - Student registers for subjects from their enrolled courses
/// - Displays registration status and marks (once released by admin)
class MakeupMidRegistrationScreen extends StatefulWidget {
  const MakeupMidRegistrationScreen({super.key});

  @override
  State<MakeupMidRegistrationScreen> createState() =>
      _MakeupMidRegistrationScreenState();
}

class _MakeupMidRegistrationScreenState
    extends State<MakeupMidRegistrationScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final String _rollNo;
  late final Stream<QuerySnapshot> _activeWindowsStream;
  String? _studentYear;
  String? _studentSemester;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    final email = FirebaseAuth.instance.currentUser?.email ?? '';
    _rollNo = email.split('@')[0].toUpperCase();
    _activeWindowsStream = FirebaseFirestore.instance
        .collection('makeupMidWindows')
        .where('isActive', isEqualTo: true)
        .snapshots();
    _loadStudentProfile();
  }

  Future<void> _loadStudentProfile() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('students')
          .doc(_rollNo)
          .get();
      if (doc.exists && mounted) {
        final d = doc.data()!;
        setState(() {
          _studentYear = d['year']?.toString();
          _studentSemester = d['semester']?.toString();
        });
      }
    } catch (_) {}
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
        title: const Text('Makeup Mid Exam'),
        backgroundColor: const Color(0xFF1e3a5f),
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Registration'),
            Tab(text: 'My Results'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _RegistrationTab(
              rollNo: _rollNo,
              windowsStream: _activeWindowsStream,
              studentYear: _studentYear,
              studentSemester: _studentSemester),
          _ResultsTab(rollNo: _rollNo),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Tab 1 — Registration
// ═══════════════════════════════════════════════════════════════════════════

class _RegistrationTab extends StatelessWidget {
  final String rollNo;
  final Stream<QuerySnapshot> windowsStream;
  final String? studentYear;
  final String? studentSemester;

  const _RegistrationTab(
      {required this.rollNo,
      required this.windowsStream,
      this.studentYear,
      this.studentSemester});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: windowsStream,
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
          if (!now.isAfter(start) || !now.isBefore(end)) return false;
          // Filter by student's year and semester if window specifies them
          final ty = d['targetYear'];
          final ts = d['targetSemester']?.toString();
          if (ty != null && studentYear != null) {
            if (ty.toString() != studentYear) return false;
          }
          if (ts != null && studentSemester != null) {
            if (_normSem(ts) != _normSem(studentSemester)) return false;
          }
          return true;
        }).toList();

        if (windows.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                studentYear != null
                    ? 'No makeup mid windows open for Year $studentYear, Semester $studentSemester right now.'
                    : 'No makeup mid registration windows are open right now.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey, fontSize: 14),
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: windows.length,
          itemBuilder: (_, i) => _MakeupWindowWidget(
            windowDoc: windows[i],
            rollNo: rollNo,
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Widget for a single active makeup mid window
// ─────────────────────────────────────────────────────────────────────────
class _MakeupWindowWidget extends StatefulWidget {
  final QueryDocumentSnapshot windowDoc;
  final String rollNo;

  const _MakeupWindowWidget({required this.windowDoc, required this.rollNo});

  @override
  State<_MakeupWindowWidget> createState() => _MakeupWindowWidgetState();
}

class _MakeupWindowWidgetState extends State<_MakeupWindowWidget> {
  List<Map<String, dynamic>> _enrolledSubjects = [];
  Map<String, dynamic>? _existingRegistration;
  bool _loading = true;
  bool _saving = false;
  final Set<int> _selected = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = FirebaseFirestore.instance;

    final results = await Future.wait([
      // Enrolled subjects filtered by this window's target year+semester
      db
          .collection('studentMarks')
          .where('studentId', isEqualTo: widget.rollNo)
          .get(),
      // Existing registration for this window
      db
          .collection('makeupMidRegistrations')
          .where('rollNo', isEqualTo: widget.rollNo)
          .where('makeupWindowId', isEqualTo: widget.windowDoc.id)
          .limit(1)
          .get(),
    ]);

    if (!mounted) return;

    final marksSnap = results[0] as QuerySnapshot;
    final regSnap = results[1] as QuerySnapshot;

    final winData = widget.windowDoc.data() as Map<String, dynamic>;
    final targetYear = winData['targetYear']?.toString();
    final targetSemester = winData['targetSemester']?.toString();

    final subjects = <Map<String, dynamic>>[];
    for (final doc in marksSnap.docs) {
      final d = doc.data() as Map<String, dynamic>;
      final docYear = d['year']?.toString();
      final docSem = d['semester']?.toString();
      // Only show subjects matching the window's target year & semester
      if (targetYear != null && docYear != targetYear) continue;
      if (targetSemester != null &&
          _normSem(docSem) != _normSem(targetSemester)) continue;
      subjects.add({
        'subjectCode': d['subjectCode']?.toString() ?? '',
        'subjectName': d['subjectName']?.toString() ?? '',
        'year': d['year'],
        'semester': d['semester']?.toString() ?? '',
      });
    }
    subjects.sort((a, b) =>
        (a['subjectCode'] as String).compareTo(b['subjectCode'] as String));

    final regDocs = regSnap.docs;
    setState(() {
      _enrolledSubjects = subjects;
      _existingRegistration = regDocs.isNotEmpty
          ? regDocs.first.data() as Map<String, dynamic>?
          : null;
      _loading = false;
    });
  }

  Future<void> _register() async {
    if (_selected.isEmpty) return;
    final winData = widget.windowDoc.data() as Map<String, dynamic>;

    final subjects = _selected.map((i) {
      final s = _enrolledSubjects[i];
      return {
        'subjectCode': s['subjectCode'],
        'subjectName': s['subjectName'],
        'year': s['year'],
        'semester': s['semester'],
      };
    }).toList();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirm Registration'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: _buildSubjectList(subjects),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1e3a5f),
                foregroundColor: Colors.white),
            child: const Text('Register'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance
          .collection('makeupMidRegistrations')
          .add({
        'rollNo': widget.rollNo,
        'studentName': '',
        'makeupWindowId': widget.windowDoc.id,
        'examSession': winData['examSession'],
        'subjects': subjects,
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

  List<Widget> _buildSubjectList(List<Map<String, dynamic>> subjects) {
    final rows = <Widget>[];
    for (final s in subjects) {
      rows.add(Text('• ${s['subjectCode']} — ${s['subjectName']}'));
    }
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    final winData = widget.windowDoc.data() as Map<String, dynamic>;
    final end = (winData['endDate'] as Timestamp?)?.toDate();
    final maxMarks = (winData['maxMarks'] as num?)?.toInt() ?? 30;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      elevation: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildWindowHeader(winData, end, maxMarks),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_existingRegistration != null)
            _buildAlreadyRegistered()
          else if (_enrolledSubjects.isEmpty)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Center(
                child: Text(
                  'No enrolled subjects found for you.',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            )
          else
            _buildSelectionArea(),
        ],
      ),
    );
  }

  Widget _buildWindowHeader(
      Map<String, dynamic> winData, DateTime? end, int maxMarks) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: const BoxDecoration(
        color: Color(0xFF1e3a5f),
        borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(winData['title'] ?? 'Makeup Mid Window',
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15)),
          Text(winData['examSession'] ?? '',
              style: const TextStyle(color: Colors.white70, fontSize: 12)),
          if (winData['targetYear'] != null)
            Text(
              'Year ${winData['targetYear']}  —  Semester ${winData['targetSemester'] ?? '—'}',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          if (end != null)
            Text(
                'Registration closes: ${DateFormat('dd MMM yyyy').format(end)}',
                style: const TextStyle(color: Colors.yellow, fontSize: 12)),
          Text('Max marks: $maxMarks',
              style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildAlreadyRegistered() {
    final reg = _existingRegistration!;
    final subjects = List<Map<String, dynamic>>.from(
        (reg['subjects'] as List? ?? [])
            .map((s) => Map<String, dynamic>.from(s as Map)));
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.blue[50],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.blue),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Already Registered',
                style:
                    TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
            const SizedBox(height: 6),
            ..._buildRegisteredSubjects(subjects),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildRegisteredSubjects(List<Map<String, dynamic>> subjects) {
    final rows = <Widget>[];
    for (final s in subjects) {
      rows.add(Text('• ${s['subjectCode']} — ${s['subjectName']}',
          style: const TextStyle(fontSize: 12)));
    }
    return rows;
  }

  Widget _buildSelectionArea() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(14, 12, 14, 4),
          child: Text(
            'Select subjects for makeup mid exam:',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
        ..._buildSubjectCheckboxes(),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: (_selected.isEmpty || _saving) ? null : _register,
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
    );
  }

  List<Widget> _buildSubjectCheckboxes() {
    final boxes = <Widget>[];
    for (int i = 0; i < _enrolledSubjects.length; i++) {
      final s = _enrolledSubjects[i];
      boxes.add(CheckboxListTile(
        title: Text('${s['subjectCode']} — ${s['subjectName']}',
            style: const TextStyle(fontSize: 13)),
        subtitle: Text('Year ${s['year']}  Sem ${s['semester']}',
            style: const TextStyle(fontSize: 11)),
        value: _selected.contains(i),
        onChanged: (v) => setState(() {
          if (v == true) {
            _selected.add(i);
          } else {
            _selected.remove(i);
          }
        }),
      ));
    }
    return boxes;
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Tab 2 — My Results (shows released makeup mid marks)
// ═══════════════════════════════════════════════════════════════════════════

class _ResultsTab extends StatefulWidget {
  final String rollNo;
  const _ResultsTab({required this.rollNo});

  @override
  State<_ResultsTab> createState() => _ResultsTabState();
}

class _ResultsTabState extends State<_ResultsTab> {
  late final Stream<QuerySnapshot> _marksStream;

  @override
  void initState() {
    super.initState();
    _marksStream = FirebaseFirestore.instance
        .collection('makeupMidMarks')
        .where('rollNo', isEqualTo: widget.rollNo)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _marksStream,
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'No makeup mid results available yet.\n'
                'Results will appear here once your faculty has entered marks.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          itemBuilder: (_, i) {
            final data = docs[i].data() as Map<String, dynamic>;
            return _buildResultCard(data);
          },
        );
      },
    );
  }

  Widget _buildResultCard(Map<String, dynamic> data) {
    final midMarks = (data['midMarks'] as num?)?.toDouble() ?? 0;
    final maxMarks = (data['maxMarks'] as num?)?.toInt() ?? 30;
    final cieUpdated = data['cieUpdated'] as bool? ?? false;
    final updatedComponent = data['updatedComponent'] as String?;
    final oldValue = (data['oldValue'] as num?)?.toInt();
    final newValue = (data['newValue'] as num?)?.toInt();
    final pct =
        maxMarks > 0 ? (midMarks / maxMarks * 100).toStringAsFixed(1) : '—';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      elevation: 2,
      child: Column(
        children: [
          Container(
            decoration: const BoxDecoration(
              color: Color(0xFF1e3a5f),
              borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${data['subjectCode']} — ${data['subjectName']}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14),
                      ),
                      Text(data['examSession'] ?? '',
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '${midMarks.toStringAsFixed(0)}/$maxMarks',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Color(0xFF1e3a5f),
                        ),
                      ),
                      Text(
                        '$pct%',
                        style:
                            const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(Icons.person, size: 14, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text('Faculty: ${data['facultyId'] ?? '—'}',
                        style: const TextStyle(fontSize: 12)),
                    const Spacer(),
                    if (cieUpdated) ...[
                      const Icon(Icons.check_circle,
                          size: 14, color: Colors.green),
                      const SizedBox(width: 4),
                      const Text('CIE Updated',
                          style: TextStyle(
                              fontSize: 11,
                              color: Colors.green,
                              fontWeight: FontWeight.w600)),
                    ] else ...[
                      const Icon(Icons.info_outline,
                          size: 14, color: Colors.orange),
                      const SizedBox(width: 4),
                      const Text('Not higher than existing',
                          style: TextStyle(fontSize: 11, color: Colors.orange)),
                    ],
                  ],
                ),
                if (cieUpdated &&
                    updatedComponent != null &&
                    oldValue != null &&
                    newValue != null) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.trending_up,
                            size: 12, color: Colors.green),
                        const SizedBox(width: 4),
                        Text(
                          '$updatedComponent: $oldValue → $newValue',
                          style: TextStyle(
                              fontSize: 11,
                              color: Colors.green.shade800,
                              fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
