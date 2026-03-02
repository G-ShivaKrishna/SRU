import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Admin Lookup – view any student or faculty's full information
// ─────────────────────────────────────────────────────────────────────────────

class AdminLookupScreen extends StatefulWidget {
  const AdminLookupScreen({super.key});

  @override
  State<AdminLookupScreen> createState() => _AdminLookupScreenState();
}

class _AdminLookupScreenState extends State<AdminLookupScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Admin Lookup'),
        backgroundColor: const Color(0xFF1e3a5f),
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: Colors.yellow,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(icon: Icon(Icons.school), text: 'Student'),
            Tab(icon: Icon(Icons.person_pin), text: 'Faculty'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: const [
          _StudentLookupTab(),
          _FacultyLookupTab(),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Student Lookup Tab
// ─────────────────────────────────────────────────────────────────────────────

class _StudentLookupTab extends StatefulWidget {
  const _StudentLookupTab();

  @override
  State<_StudentLookupTab> createState() => _StudentLookupTabState();
}

class _StudentLookupTabState extends State<_StudentLookupTab> {
  final _fs = FirebaseFirestore.instance;
  final _searchCtrl = TextEditingController();

  bool _searching = false;
  String? _error;

  // List results (when searching by name)
  List<Map<String, dynamic>> _searchResults = [];
  bool _showResults = false;

  // Full single-student data
  Map<String, dynamic>? _studentData;
  String? _selectedRoll;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final q = _searchCtrl.text.trim().toUpperCase();
    if (q.isEmpty) return;
    setState(() {
      _searching = true;
      _error = null;
      _studentData = null;
      _selectedRoll = null;
      _showResults = false;
      _searchResults = [];
    });
    try {
      // Try exact doc ID (roll number) first
      final doc = await _fs.collection('students').doc(q).get();
      if (doc.exists) {
        final data = Map<String, dynamic>.from(doc.data()!);
        data['_rollNumber'] = doc.id;
        setState(() {
          _studentData = data;
          _selectedRoll = doc.id;
          _searching = false;
        });
        return;
      }

      // Fallback: query by name prefix (case-insensitive approximation)
      final snap = await _fs
          .collection('students')
          .where('name', isGreaterThanOrEqualTo: _searchCtrl.text.trim())
          .where('name',
              isLessThanOrEqualTo: '${_searchCtrl.text.trim()}\uf8ff')
          .limit(20)
          .get();

      if (snap.docs.isEmpty) {
        setState(() {
          _error = 'No student found for "$q"';
          _searching = false;
        });
        return;
      }

      if (snap.docs.length == 1) {
        final data = Map<String, dynamic>.from(snap.docs.first.data());
        data['_rollNumber'] = snap.docs.first.id;
        setState(() {
          _studentData = data;
          _selectedRoll = snap.docs.first.id;
          _searching = false;
        });
        return;
      }

      // Multiple results – show picker
      setState(() {
        _searchResults = snap.docs.map((d) {
          final m = Map<String, dynamic>.from(d.data());
          m['_rollNumber'] = d.id;
          return m;
        }).toList();
        _showResults = true;
        _searching = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _searching = false;
      });
    }
  }

  void _selectStudent(Map<String, dynamic> data) {
    setState(() {
      _studentData = data;
      _selectedRoll = data['_rollNumber']?.toString();
      _showResults = false;
      _searchResults = [];
    });
  }

  void _clear() {
    _searchCtrl.clear();
    setState(() {
      _studentData = null;
      _selectedRoll = null;
      _error = null;
      _searchResults = [];
      _showResults = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildSearchBar(),
        if (_searching) const LinearProgressIndicator(),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(_error!, style: const TextStyle(color: Colors.red)),
          ),
        if (_showResults) _buildResultsList(),
        if (_studentData != null && _selectedRoll != null)
          Expanded(
            child: _StudentDetailView(
              studentData: _studentData!,
              rollNumber: _selectedRoll!,
            ),
          ),
        if (!_searching &&
            _studentData == null &&
            !_showResults &&
            _error == null)
          const Expanded(child: _SearchPrompt(forStudent: true)),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Enter roll number or student name…',
                prefixIcon: const Icon(Icons.search),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                isDense: true,
              ),
              textCapitalization: TextCapitalization.characters,
              onSubmitted: (_) => _search(),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1e3a5f),
                foregroundColor: Colors.white),
            onPressed: _searching ? null : _search,
            child: const Text('Search'),
          ),
          if (_studentData != null || _showResults) ...[
            const SizedBox(width: 6),
            IconButton(
                onPressed: _clear,
                icon: const Icon(Icons.clear),
                tooltip: 'Clear'),
          ],
        ],
      ),
    );
  }

  Widget _buildResultsList() {
    return Container(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text('${_searchResults.length} results found',
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          ),
          ..._searchResults.map((s) {
            final roll = s['_rollNumber']?.toString() ?? '';
            final name = s['name']?.toString() ?? roll;
            final dept = s['department']?.toString() ?? '';
            return ListTile(
              leading:
                  const CircleAvatar(radius: 20, child: Icon(Icons.person)),
              title: Text(name),
              subtitle: Text('$roll  •  $dept'),
              onTap: () => _selectStudent(s),
            );
          }),
          const Divider(height: 1),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Student Detail – Tabbed view: Profile | Marks | Attendance | Memos
// ─────────────────────────────────────────────────────────────────────────────

class _StudentDetailView extends StatelessWidget {
  final Map<String, dynamic> studentData;
  final String rollNumber;

  const _StudentDetailView(
      {required this.studentData, required this.rollNumber});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Column(
        children: [
          Container(
            color: const Color(0xFF1e3a5f).withOpacity(0.07),
            child: const TabBar(
              labelColor: Color(0xFF1e3a5f),
              unselectedLabelColor: Colors.grey,
              indicatorColor: Color(0xFF1e3a5f),
              tabs: [
                Tab(text: 'Profile'),
                Tab(text: 'CIE Marks'),
                Tab(text: 'Attendance'),
                Tab(text: 'Memos'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _StudentProfileTab(data: studentData, roll: rollNumber),
                _StudentMarksTab(rollNumber: rollNumber),
                _StudentAttendanceTab(
                    rollNumber: rollNumber, studentData: studentData),
                _StudentMemosTab(
                    rollNumber: rollNumber, studentData: studentData),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Profile Tab ───────────────────────────────────────────────────────────────

class _StudentProfileTab extends StatelessWidget {
  final Map<String, dynamic> data;
  final String roll;
  const _StudentProfileTab({required this.data, required this.roll});

  @override
  Widget build(BuildContext context) {
    final fields = <_FieldEntry>[
      _FieldEntry('Roll Number', roll),
      _FieldEntry('Name', data['name']),
      _FieldEntry('Father\'s Name', data['fatherName']),
      _FieldEntry('Email', data['email']),
      _FieldEntry('Phone', data['phone'] ?? data['phoneNumber']),
      _FieldEntry('Department', data['department']),
      _FieldEntry('Program', data['program']),
      _FieldEntry('Year', data['year']?.toString()),
      _FieldEntry('Semester', data['semester']?.toString()),
      _FieldEntry('Batch', data['batchNumber'] ?? data['batch']),
      _FieldEntry('Section', data['section']),
      _FieldEntry('Hall Ticket No.', data['hallTicketNumber']),
      _FieldEntry('Admission No.', data['admissionNumber']),
      _FieldEntry('Status', data['status']),
      _FieldEntry('Academic Year', data['academicYear']),
    ];
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _profileHeader(data, roll),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: fields
                  .where((f) =>
                      f.value != null &&
                      f.value.toString().isNotEmpty &&
                      f.value.toString() != 'null')
                  .map((f) =>
                      _InfoRow(label: f.label, value: f.value!.toString()))
                  .toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _profileHeader(Map<String, dynamic> d, String roll) {
    final name = d['name']?.toString() ?? roll;
    final dept = d['department']?.toString().toUpperCase() ?? '';
    final prog = d['program']?.toString().toUpperCase() ?? '';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1e3a5f),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: Colors.white24,
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : 'S',
              style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(roll,
                    style:
                        const TextStyle(color: Colors.white70, fontSize: 13)),
                Text('$prog – $dept',
                    style:
                        const TextStyle(color: Colors.white60, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FieldEntry {
  final String label;
  final dynamic value;
  _FieldEntry(this.label, this.value);
}

// ── Marks Tab ─────────────────────────────────────────────────────────────────

class _StudentMarksTab extends StatefulWidget {
  final String rollNumber;
  const _StudentMarksTab({required this.rollNumber});
  @override
  State<_StudentMarksTab> createState() => _StudentMarksTabState();
}

class _StudentMarksTabState extends State<_StudentMarksTab> {
  final _fs = FirebaseFirestore.instance;
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _marks = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final snap = await _fs
          .collection('studentMarks')
          .where('studentId', isEqualTo: widget.rollNumber)
          .get();
      setState(() {
        _marks = snap.docs.map((d) => d.data()).toList()
          ..sort((a, b) {
            final yr = (a['year']?.toString() ?? '')
                .compareTo(b['year']?.toString() ?? '');
            if (yr != 0) return yr;
            return (a['semester']?.toString() ?? '')
                .compareTo(b['semester']?.toString() ?? '');
          });
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return _ErrorView(message: _error!);
    if (_marks.isEmpty) {
      return const _EmptyView(
          icon: Icons.grade_outlined, message: 'No marks records found.');
    }

    // Group by year-semester
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final m in _marks) {
      final key = 'Year ${m['year']} – Sem ${m['semester']}';
      grouped.putIfAbsent(key, () => []).add(m);
    }

    return ListView(
      padding: const EdgeInsets.all(12),
      children: grouped.entries.map((entry) {
        return _MarksGroup(groupKey: entry.key, rows: entry.value);
      }).toList(),
    );
  }
}

class _MarksGroup extends StatelessWidget {
  final String groupKey;
  final List<Map<String, dynamic>> rows;
  const _MarksGroup({required this.groupKey, required this.rows});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: const BoxDecoration(
              color: Color(0xFF1e3a5f),
              borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
            ),
            child: Text(groupKey,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13)),
          ),
          ...rows.map((m) {
            final compMarks =
                m['componentMarks'] as Map<String, dynamic>? ?? {};
            final total = m['totalMarks'];
            final maxM = m['maxMarks'];
            return Column(
              children: [
                ListTile(
                  dense: true,
                  title: Text(
                      '${m['subjectCode'] ?? ''} – ${m['subjectName'] ?? ''}',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 13)),
                  subtitle: Text(
                      compMarks.entries
                          .map((e) => '${e.key}: ${e.value}')
                          .join('   '),
                      style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  trailing: total != null
                      ? Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1e3a5f).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '$total${maxM != null ? ' / $maxM' : ''}',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: Color(0xFF1e3a5f)),
                          ),
                        )
                      : null,
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
              ],
            );
          }),
        ],
      ),
    );
  }
}

// ── Attendance Tab ────────────────────────────────────────────────────────────

class _StudentAttendanceTab extends StatefulWidget {
  final String rollNumber;
  final Map<String, dynamic> studentData;
  const _StudentAttendanceTab(
      {required this.rollNumber, required this.studentData});
  @override
  State<_StudentAttendanceTab> createState() => _StudentAttendanceTabState();
}

class _StudentAttendanceTabState extends State<_StudentAttendanceTab> {
  final _fs = FirebaseFirestore.instance;
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _records = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      // Try attendanceRecords collection first (most common pattern)
      QuerySnapshot snap = await _fs
          .collection('attendanceRecords')
          .where('studentId', isEqualTo: widget.rollNumber)
          .limit(200)
          .get();

      if (snap.docs.isEmpty) {
        // Try attendance collection
        snap = await _fs
            .collection('attendance')
            .where('studentId', isEqualTo: widget.rollNumber)
            .limit(200)
            .get();
      }

      setState(() {
        _records = snap.docs
            .map((d) => Map<String, dynamic>.from(d.data() as Map))
            .toList();
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return _ErrorView(message: _error!);

    // Show overall from student profile if available
    final overall = widget.studentData['attendance']?.toString() ?? '';

    if (_records.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (overall.isNotEmpty)
            Card(
              child: ListTile(
                leading: const Icon(Icons.pie_chart, color: Color(0xFF1e3a5f)),
                title: const Text('Overall Attendance',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                trailing: Text('$overall%',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: Color(0xFF1e3a5f))),
              ),
            ),
          const SizedBox(height: 16),
          const _EmptyView(
              icon: Icons.event_note_outlined,
              message:
                  'No detailed attendance records found in Firestore.\nThe overall % (from student profile) is shown above.'),
        ],
      );
    }

    // Group by subject
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final r in _records) {
      final key =
          '${r['subjectCode'] ?? r['courseCode'] ?? 'Unknown'} – ${r['subjectName'] ?? r['courseName'] ?? ''}';
      grouped.putIfAbsent(key, () => []).add(r);
    }

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        if (overall.isNotEmpty)
          Card(
            child: ListTile(
              leading: const Icon(Icons.pie_chart, color: Color(0xFF1e3a5f)),
              title: const Text('Overall Attendance',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              trailing: Text('$overall%',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Color(0xFF1e3a5f))),
            ),
          ),
        const SizedBox(height: 8),
        ...grouped.entries.map((e) {
          final held =
              e.value.fold<int>(0, (s, r) => s + _toInt(r['classesHeld']));
          final attended =
              e.value.fold<int>(0, (s, r) => s + _toInt(r['classesAttended']));
          final pct = held > 0 ? (attended / held * 100) : 0.0;
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              title: Text(e.key,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.bold)),
              subtitle: Text('Attended: $attended / $held',
                  style: const TextStyle(fontSize: 12)),
              trailing: _PctBadge(pct: pct),
            ),
          );
        }),
      ],
    );
  }

  int _toInt(dynamic v) =>
      v is int ? v : int.tryParse(v?.toString() ?? '') ?? 0;
}

// ── Memos Tab ─────────────────────────────────────────────────────────────────

class _StudentMemosTab extends StatefulWidget {
  final String rollNumber;
  final Map<String, dynamic> studentData;
  const _StudentMemosTab({required this.rollNumber, required this.studentData});
  @override
  State<_StudentMemosTab> createState() => _StudentMemosTabState();
}

class _StudentMemosTabState extends State<_StudentMemosTab> {
  final _fs = FirebaseFirestore.instance;
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _memos = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final snap = await _fs
          .collection('cieMemoReleases')
          .where('isActive', isEqualTo: true)
          .get();
      final branch =
          (widget.studentData['department'] ?? '').toString().toUpperCase();
      final memos = snap.docs.where((d) {
        final m = d.data();
        final br = (m['branch'] ?? 'ALL').toString().toUpperCase();
        return br == 'ALL' || br == branch;
      }).map((d) {
        final m = Map<String, dynamic>.from(d.data());
        m['_id'] = d.id;
        return m;
      }).toList()
        ..sort((a, b) {
          final yr = (b['year']?.toString() ?? '')
              .compareTo(a['year']?.toString() ?? '');
          if (yr != 0) return yr;
          return (b['semester']?.toString() ?? '')
              .compareTo(a['semester']?.toString() ?? '');
        });

      setState(() {
        _memos = memos;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return _ErrorView(message: _error!);
    if (_memos.isEmpty) {
      return const _EmptyView(
          icon: Icons.description_outlined,
          message: 'No memos released for this student\'s branch.');
    }

    return ListView(
      padding: const EdgeInsets.all(12),
      children: _memos.map((m) {
        final yr = m['year']?.toString() ?? '';
        final sem = m['semester']?.toString() ?? '';
        final session = m['examSession']?.toString() ?? '';
        final branch = m['branch']?.toString() ?? '';
        final releasedAt = m['releasedAt'];
        String dateStr = '';
        if (releasedAt is Timestamp) {
          final dt = releasedAt.toDate();
          dateStr = '${dt.day}/${dt.month}/${dt.year}';
        }
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF1e3a5f).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child:
                  const Icon(Icons.article_outlined, color: Color(0xFF1e3a5f)),
            ),
            title: Text('Year $yr – Semester $sem',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(
                '${m['academicYear'] ?? ''}  •  $session  •  Branch: $branch'),
            trailing: dateStr.isNotEmpty
                ? Text(dateStr,
                    style: const TextStyle(fontSize: 11, color: Colors.grey))
                : null,
            onTap: () => _viewMemoMarks(context, m),
          ),
        );
      }).toList(),
    );
  }

  void _viewMemoMarks(BuildContext context, Map<String, dynamic> memo) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => _AdminMemoMarksView(
        rollNumber: widget.rollNumber,
        studentData: widget.studentData,
        memo: memo,
      ),
    ));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Admin Memo Marks Viewer (same data as student memo screen)
// ─────────────────────────────────────────────────────────────────────────────

class _AdminMemoMarksView extends StatefulWidget {
  final String rollNumber;
  final Map<String, dynamic> studentData;
  final Map<String, dynamic> memo;
  const _AdminMemoMarksView(
      {required this.rollNumber,
      required this.studentData,
      required this.memo});
  @override
  State<_AdminMemoMarksView> createState() => _AdminMemoMarksViewState();
}

class _AdminMemoMarksViewState extends State<_AdminMemoMarksView> {
  final _fs = FirebaseFirestore.instance;
  bool _loading = true;
  String? _error;
  List<_MarkRow> _rows = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  static String _normSem(String s) {
    switch (s.trim().toUpperCase()) {
      case 'I':
      case '1':
        return '1';
      case 'II':
      case '2':
        return '2';
      default:
        return s.trim();
    }
  }

  Future<void> _load() async {
    try {
      final snap = await _fs
          .collection('studentMarks')
          .where('studentId', isEqualTo: widget.rollNumber)
          .get();

      final memoYear = widget.memo['year']?.toString() ?? '';
      final memoSem = _normSem(widget.memo['semester']?.toString() ?? '');
      final memoYearInt = int.tryParse(memoYear);

      final docs = snap.docs.where((doc) {
        final d = doc.data();
        final docYear = d['year'];
        final yearMatch = memoYearInt != null
            ? (docYear == memoYearInt || docYear?.toString() == memoYear)
            : docYear?.toString() == memoYear;
        final semMatch = _normSem(d['semester']?.toString() ?? '') == memoSem;
        return yearMatch && semMatch;
      }).toList();

      bool isEte(String name) {
        final l = name.toLowerCase();
        return l.contains('end term') ||
            l.contains('ete') ||
            l.contains('end-term') ||
            l.contains('external');
      }

      final rows = docs.map((doc) {
        final d = doc.data();
        final rawMarks = d['componentMarks'] as Map<String, dynamic>? ?? {};
        int cieSum = 0, eteSum = 0;
        for (final e in rawMarks.entries) {
          final v = e.value;
          final val = v is int
              ? v
              : (v is num ? v.floor() : int.tryParse(v.toString()) ?? 0);
          if (isEte(e.key)) {
            eteSum += val;
          } else {
            cieSum += val;
          }
        }
        final maxAll = d['maxMarks'] is int
            ? d['maxMarks'] as int
            : (d['maxMarks'] is num
                ? (d['maxMarks'] as num).floor()
                : int.tryParse(d['maxMarks']?.toString() ?? '') ?? 0);
        final rawCr = d['credits'];
        final cr = (rawCr is int)
            ? rawCr
            : (rawCr is num)
                ? rawCr.floor()
                : int.tryParse(rawCr?.toString() ?? '') ?? 3;
        return _MarkRow(
          code: (d['subjectCode'] ?? '').toString(),
          name: (d['subjectName'] ?? '').toString(),
          cieTotal: cieSum,
          eteTotal: eteSum,
          maxMarks: maxAll,
          credits: cr,
        );
      }).toList()
        ..sort((a, b) => a.code.compareTo(b.code));

      setState(() {
        _rows = rows;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  String _grade(double pct) {
    if (pct >= 90) return 'O';
    if (pct >= 80) return 'A';
    if (pct >= 70) return 'B';
    if (pct >= 60) return 'C';
    if (pct >= 50) return 'D';
    if (pct >= 40) return 'E';
    return 'F';
  }

  int _gradePoint(double pct) {
    if (pct >= 90) return 10;
    if (pct >= 80) return 9;
    if (pct >= 70) return 8;
    if (pct >= 60) return 7;
    if (pct >= 50) return 6;
    if (pct >= 40) return 5;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final yr = widget.memo['year'] ?? '';
    final sem = widget.memo['semester'] ?? '';
    final name = widget.studentData['name']?.toString() ?? widget.rollNumber;

    return Scaffold(
      appBar: AppBar(
        title: Text('$name – Y$yr S$sem Marks'),
        backgroundColor: const Color(0xFF1e3a5f),
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _ErrorView(message: _error!)
              : _rows.isEmpty
                  ? const _EmptyView(
                      icon: Icons.grade_outlined,
                      message: 'No marks found for this semester.')
                  : _buildTable(),
    );
  }

  Widget _buildTable() {
    double totalCp = 0;
    int totalCr = 0;
    for (final r in _rows) {
      final pct = r.maxMarks > 0 ? (r.grand / r.maxMarks * 100) : 0.0;
      final gp = _gradePoint(pct);
      totalCp += gp * r.credits;
      totalCr += r.credits;
    }
    final sgpa = totalCr > 0 ? totalCp / totalCr : 0.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(const Color(0xFF1e3a5f)),
              headingTextStyle: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold),
              columns: const [
                DataColumn(label: Text('#')),
                DataColumn(label: Text('Code')),
                DataColumn(label: Text('Subject')),
                DataColumn(label: Text('Grand\nTotal')),
                DataColumn(label: Text('Max')),
                DataColumn(label: Text('Grade')),
                DataColumn(label: Text('Credits')),
                DataColumn(label: Text('Credit\nPoints')),
                DataColumn(label: Text('Status')),
              ],
              rows: _rows.asMap().entries.map((e) {
                final idx = e.key;
                final r = e.value;
                final pct = r.maxMarks > 0 ? (r.grand / r.maxMarks * 100) : 0.0;
                final grade = _grade(pct);
                final gp = _gradePoint(pct);
                final cp = gp * r.credits;
                final minPass = (widget.memo['minPassMarks'] is int)
                    ? widget.memo['minPassMarks'] as int
                    : int.tryParse(
                            widget.memo['minPassMarks']?.toString() ?? '') ??
                        40;
                final passed = r.grand >= minPass;
                return DataRow(
                  color: WidgetStateProperty.resolveWith((states) =>
                      idx % 2 == 0 ? Colors.white : Colors.grey.shade50),
                  cells: [
                    DataCell(Text('${idx + 1}')),
                    DataCell(Text(r.code)),
                    DataCell(
                        SizedBox(width: 180, child: Text(r.name, maxLines: 2))),
                    DataCell(Text('${r.grand}',
                        style: const TextStyle(fontWeight: FontWeight.bold))),
                    DataCell(Text('${r.maxMarks}')),
                    DataCell(Text(grade,
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: gp >= 7
                                ? Colors.blue.shade700
                                : gp >= 5
                                    ? Colors.orange.shade700
                                    : Colors.red.shade700))),
                    DataCell(Text('${r.credits}')),
                    DataCell(Text(cp.toStringAsFixed(1),
                        style: const TextStyle(fontWeight: FontWeight.bold))),
                    DataCell(Text(
                      passed ? 'PASS' : 'FAIL',
                      style: TextStyle(
                          color: passed
                              ? Colors.green.shade700
                              : Colors.red.shade700,
                          fontWeight: FontWeight.bold),
                    )),
                  ],
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF1e3a5f),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'SGPA: ${sgpa.toStringAsFixed(3)}   |   Total Credits: $totalCr   |   Total Credit Points: ${totalCp.toStringAsFixed(2)}',
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

class _MarkRow {
  final String code, name;
  final int cieTotal, eteTotal, maxMarks, credits;
  _MarkRow(
      {required this.code,
      required this.name,
      required this.cieTotal,
      required this.eteTotal,
      required this.maxMarks,
      required this.credits});
  int get grand => cieTotal + eteTotal;
}

// ─────────────────────────────────────────────────────────────────────────────
// Faculty Lookup Tab
// ─────────────────────────────────────────────────────────────────────────────

class _FacultyLookupTab extends StatefulWidget {
  const _FacultyLookupTab();
  @override
  State<_FacultyLookupTab> createState() => _FacultyLookupTabState();
}

class _FacultyLookupTabState extends State<_FacultyLookupTab> {
  final _fs = FirebaseFirestore.instance;
  final _searchCtrl = TextEditingController();

  bool _searching = false;
  String? _error;
  List<Map<String, dynamic>> _searchResults = [];
  bool _showResults = false;
  Map<String, dynamic>? _facultyData;
  String? _selectedId;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final q = _searchCtrl.text.trim().toUpperCase();
    if (q.isEmpty) return;
    setState(() {
      _searching = true;
      _error = null;
      _facultyData = null;
      _selectedId = null;
      _showResults = false;
      _searchResults = [];
    });
    try {
      // Exact doc ID (faculty ID)
      final doc = await _fs.collection('faculty').doc(q).get();
      if (doc.exists) {
        final data = Map<String, dynamic>.from(doc.data()!);
        data['_facultyId'] = doc.id;
        setState(() {
          _facultyData = data;
          _selectedId = doc.id;
          _searching = false;
        });
        return;
      }

      // Try lowercase (faculty IDs are usually lowercase - email prefix)
      final docLower = await _fs
          .collection('faculty')
          .doc(_searchCtrl.text.trim().toLowerCase())
          .get();
      if (docLower.exists) {
        final data = Map<String, dynamic>.from(docLower.data()!);
        data['_facultyId'] = docLower.id;
        setState(() {
          _facultyData = data;
          _selectedId = docLower.id;
          _searching = false;
        });
        return;
      }

      // Name search
      final snap = await _fs
          .collection('faculty')
          .where('name', isGreaterThanOrEqualTo: _searchCtrl.text.trim())
          .where('name',
              isLessThanOrEqualTo: '${_searchCtrl.text.trim()}\uf8ff')
          .limit(20)
          .get();

      if (snap.docs.isEmpty) {
        setState(() {
          _error = 'No faculty found for "${_searchCtrl.text.trim()}"';
          _searching = false;
        });
        return;
      }
      if (snap.docs.length == 1) {
        final data = Map<String, dynamic>.from(snap.docs.first.data());
        data['_facultyId'] = snap.docs.first.id;
        setState(() {
          _facultyData = data;
          _selectedId = snap.docs.first.id;
          _searching = false;
        });
        return;
      }
      setState(() {
        _searchResults = snap.docs.map((d) {
          final m = Map<String, dynamic>.from(d.data());
          m['_facultyId'] = d.id;
          return m;
        }).toList();
        _showResults = true;
        _searching = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _searching = false;
      });
    }
  }

  void _selectFaculty(Map<String, dynamic> data) {
    setState(() {
      _facultyData = data;
      _selectedId = data['_facultyId']?.toString();
      _showResults = false;
      _searchResults = [];
    });
  }

  void _clear() {
    _searchCtrl.clear();
    setState(() {
      _facultyData = null;
      _selectedId = null;
      _error = null;
      _searchResults = [];
      _showResults = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildSearchBar(),
        if (_searching) const LinearProgressIndicator(),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(_error!, style: const TextStyle(color: Colors.red)),
          ),
        if (_showResults) _buildResultsList(),
        if (_facultyData != null && _selectedId != null)
          Expanded(
            child: _FacultyDetailView(
              data: _facultyData!,
              facultyId: _selectedId!,
            ),
          ),
        if (!_searching &&
            _facultyData == null &&
            !_showResults &&
            _error == null)
          const Expanded(child: _SearchPrompt(forStudent: false)),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Enter faculty ID or name…',
                prefixIcon: const Icon(Icons.search),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                isDense: true,
              ),
              onSubmitted: (_) => _search(),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1e3a5f),
                foregroundColor: Colors.white),
            onPressed: _searching ? null : _search,
            child: const Text('Search'),
          ),
          if (_facultyData != null || _showResults) ...[
            const SizedBox(width: 6),
            IconButton(
                onPressed: _clear,
                icon: const Icon(Icons.clear),
                tooltip: 'Clear'),
          ],
        ],
      ),
    );
  }

  Widget _buildResultsList() {
    return Container(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text('${_searchResults.length} results found',
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          ),
          ..._searchResults.map((f) {
            final id = f['_facultyId']?.toString() ?? '';
            final name = f['name']?.toString() ?? id;
            final dept = f['department']?.toString() ?? '';
            return ListTile(
              leading: const CircleAvatar(
                  radius: 20,
                  child: Icon(Icons.person_outline)),
              title: Text(name),
              subtitle: Text('$id  •  $dept'),
              onTap: () => _selectFaculty(f),
            );
          }),
          const Divider(height: 1),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Faculty Detail – Tabbed: Profile | Assignments | Marks Entered
// ─────────────────────────────────────────────────────────────────────────────

class _FacultyDetailView extends StatelessWidget {
  final Map<String, dynamic> data;
  final String facultyId;
  const _FacultyDetailView({required this.data, required this.facultyId});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          Container(
            color: const Color(0xFF1e3a5f).withOpacity(0.07),
            child: const TabBar(
              labelColor: Color(0xFF1e3a5f),
              unselectedLabelColor: Colors.grey,
              indicatorColor: Color(0xFF1e3a5f),
              tabs: [
                Tab(text: 'Profile'),
                Tab(text: 'Assignments'),
                Tab(text: 'Marks Entered'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _FacultyProfileTab(data: data, facultyId: facultyId),
                _FacultyAssignmentsTab(facultyId: facultyId),
                _FacultyMarksEnteredTab(facultyId: facultyId),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Faculty Profile Tab ───────────────────────────────────────────────────────

class _FacultyProfileTab extends StatelessWidget {
  final Map<String, dynamic> data;
  final String facultyId;
  const _FacultyProfileTab({required this.data, required this.facultyId});

  @override
  Widget build(BuildContext context) {
    final name = data['name']?.toString() ?? facultyId;
    final fields = <_FieldEntry>[
      _FieldEntry('Faculty ID', facultyId),
      _FieldEntry('Name', data['name']),
      _FieldEntry('Email', data['email']),
      _FieldEntry('Phone', data['phone'] ?? data['phoneNumber']),
      _FieldEntry('Department', data['department']),
      _FieldEntry('Designation', data['designation']),
      _FieldEntry('Qualification', data['qualification']),
      _FieldEntry('Experience', data['experience']),
      _FieldEntry('Specialization', data['specialization']),
      _FieldEntry('Status', data['status']),
    ];
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1e3a5f),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 32,
                backgroundColor: Colors.white24,
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : 'F',
                  style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(facultyId,
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 13)),
                    Text(
                        data['designation']?.toString() ??
                            data['department']?.toString() ??
                            '',
                        style: const TextStyle(
                            color: Colors.white60, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: fields
                  .where((f) =>
                      f.value != null &&
                      f.value.toString().isNotEmpty &&
                      f.value.toString() != 'null')
                  .map((f) =>
                      _InfoRow(label: f.label, value: f.value!.toString()))
                  .toList(),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Faculty Assignments Tab ───────────────────────────────────────────────────

class _FacultyAssignmentsTab extends StatefulWidget {
  final String facultyId;
  const _FacultyAssignmentsTab({required this.facultyId});
  @override
  State<_FacultyAssignmentsTab> createState() => _FacultyAssignmentsTabState();
}

class _FacultyAssignmentsTabState extends State<_FacultyAssignmentsTab> {
  final _fs = FirebaseFirestore.instance;
  bool _loading = true;
  String? _error;
  List<QueryDocumentSnapshot> _docs = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final snap = await _fs
          .collection('facultyAssignments')
          .where('facultyId', isEqualTo: widget.facultyId)
          .get();
      setState(() {
        _docs = snap.docs;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return _ErrorView(message: _error!);
    if (_docs.isEmpty) {
      return const _EmptyView(
          icon: Icons.assignment_outlined,
          message: 'No faculty assignments found.');
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: _docs.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final d = _docs[i].data() as Map<String, dynamic>;
        return Card(
          child: ListTile(
            leading: const Icon(Icons.book_outlined, color: Color(0xFF1e3a5f)),
            title: Text('${d['subjectCode'] ?? ''} – ${d['subjectName'] ?? ''}',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(
                'Year ${d['year']}  •  Sem ${d['semester']}  •  ${d['department'] ?? d['branch'] ?? ''}'
                '\nBatch: ${d['batch'] ?? d['section'] ?? '–'}  •  ${d['academicYear'] ?? ''}'),
            isThreeLine: true,
          ),
        );
      },
    );
  }
}

// ── Faculty Marks Entered Tab ─────────────────────────────────────────────────

class _FacultyMarksEnteredTab extends StatefulWidget {
  final String facultyId;
  const _FacultyMarksEnteredTab({required this.facultyId});
  @override
  State<_FacultyMarksEnteredTab> createState() =>
      _FacultyMarksEnteredTabState();
}

class _FacultyMarksEnteredTabState extends State<_FacultyMarksEnteredTab> {
  final _fs = FirebaseFirestore.instance;
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _marks = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final snap = await _fs
          .collection('studentMarks')
          .where('facultyId', isEqualTo: widget.facultyId)
          .limit(300)
          .get();
      setState(() {
        _marks = snap.docs.map((d) => d.data()).toList();
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return _ErrorView(message: _error!);
    if (_marks.isEmpty) {
      return const _EmptyView(
          icon: Icons.grade_outlined,
          message: 'No marks entered by this faculty member.');
    }

    // Group by subject+year+sem
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final m in _marks) {
      final k =
          '${m['subjectCode'] ?? m['subjectName'] ?? ''}  Y${m['year']} S${m['semester']}';
      grouped.putIfAbsent(k, () => []).add(m);
    }

    return ListView(
      padding: const EdgeInsets.all(12),
      children: grouped.entries.map((e) {
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: ExpansionTile(
            title: Text(e.key,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            subtitle: Text('${e.value.length} students'),
            children: e.value.map((m) {
              final compMarks =
                  m['componentMarks'] as Map<String, dynamic>? ?? {};
              return ListTile(
                dense: true,
                title:
                    Text('${m['studentId'] ?? '?'}  ${m['studentName'] ?? ''}'),
                subtitle: Text(
                    compMarks.entries
                        .map((c) => '${c.key}: ${c.value}')
                        .join('   '),
                    style: const TextStyle(fontSize: 11)),
                trailing: m['totalMarks'] != null
                    ? Text('${m['totalMarks']} / ${m['maxMarks'] ?? '?'}',
                        style: const TextStyle(fontWeight: FontWeight.bold))
                    : null,
              );
            }).toList(),
          ),
        );
      }).toList(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared helpers
// ─────────────────────────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(label,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.black54)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1e3a5f))),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  const _ErrorView({required this.message});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 12),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red)),
          ],
        ),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  final IconData icon;
  final String message;
  const _EmptyView({required this.icon, required this.message});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(message,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey.shade500)),
          ],
        ),
      ),
    );
  }
}

class _SearchPrompt extends StatelessWidget {
  final bool forStudent;
  const _SearchPrompt({required this.forStudent});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            forStudent ? Icons.manage_search : Icons.person_search,
            size: 80,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            forStudent
                ? 'Search by roll number or student name'
                : 'Search by faculty ID or name',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }
}

class _PctBadge extends StatelessWidget {
  final double pct;
  const _PctBadge({required this.pct});
  @override
  Widget build(BuildContext context) {
    final color = pct >= 75
        ? Colors.green
        : pct >= 65
            ? Colors.orange
            : Colors.red;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.5))),
      child: Text(
        '${pct.toStringAsFixed(1)}%',
        style:
            TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12),
      ),
    );
  }
}
