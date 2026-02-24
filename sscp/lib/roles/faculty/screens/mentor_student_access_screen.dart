import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MentorStudentAccessScreen extends StatefulWidget {
  const MentorStudentAccessScreen({super.key});

  @override
  State<MentorStudentAccessScreen> createState() =>
      _MentorStudentAccessScreenState();
}

class _MentorStudentAccessScreenState
    extends State<MentorStudentAccessScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isLoading = true;
  String? _errorMessage;
  String? _facultyName;
  String? _assignedBatch;
  List<Map<String, dynamic>> _students = [];
  List<Map<String, dynamic>> _filteredStudents = [];

  final TextEditingController _searchController = TextEditingController();
  int? _expandedIndex;

  @override
  void initState() {
    super.initState();
    _loadData();
    _searchController.addListener(_onSearch);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearch() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredStudents = List.from(_students);
      } else {
        _filteredStudents = _students.where((s) {
          final name = (s['name'] ?? '').toString().toLowerCase();
          final roll = (s['rollNumber'] ?? '').toString().toLowerCase();
          final email = (s['email'] ?? '').toString().toLowerCase();
          return name.contains(query) ||
              roll.contains(query) ||
              email.contains(query);
        }).toList();
      }
      _expandedIndex = null;
    });
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = _auth.currentUser;
      if (user == null) {
        setState(() {
          _errorMessage = 'Not logged in.';
          _isLoading = false;
        });
        return;
      }

      // Step 1: derive faculty doc ID from email
      final facultyId = user.email!.split('@')[0].toUpperCase();

      // Step 2: fetch faculty name from 'faculty' collection
      final facultyDoc =
          await _firestore.collection('faculty').doc(facultyId).get();
      if (!facultyDoc.exists) {
        setState(() {
          _errorMessage = 'Faculty profile not found.';
          _isLoading = false;
        });
        return;
      }
      final facultyName =
          (facultyDoc.data()?['name'] ?? '').toString().trim();
      if (facultyName.isEmpty) {
        setState(() {
          _errorMessage = 'Faculty name not set in profile.';
          _isLoading = false;
        });
        return;
      }

      // Step 3: find mentorAssignments where facultyName matches
      final assignSnap = await _firestore
          .collection('mentorAssignments')
          .where('facultyName', isEqualTo: facultyName)
          .get();

      if (assignSnap.docs.isEmpty) {
        setState(() {
          _facultyName = facultyName;
          _assignedBatch = null;
          _students = [];
          _filteredStudents = [];
          _isLoading = false;
        });
        return;
      }

      final batchNumber =
          (assignSnap.docs.first.data()['batchNumber'] ?? '').toString().trim();

      // Step 4: fetch all students in that batch
      final studentsSnap = await _firestore
          .collection('students')
          .where('batchNumber', isEqualTo: batchNumber)
          .get();

      final studentsList = studentsSnap.docs.map((doc) {
        final data = doc.data();
        data['rollNumber'] = doc.id; // roll number is the doc ID
        return data;
      }).toList();

      // Sort by roll number
      studentsList.sort((a, b) =>
          (a['rollNumber'] ?? '').compareTo(b['rollNumber'] ?? ''));

      setState(() {
        _facultyName = facultyName;
        _assignedBatch = batchNumber;
        _students = studentsList;
        _filteredStudents = List.from(studentsList);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading data: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mentor – Student Details'),
        backgroundColor: const Color(0xFF1e3a5f),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? _buildError()
              : _buildBody(),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 12),
            Text(_errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _loadData, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInfoBanner(),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search by name, roll number or email…',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        _onSearch();
                      },
                    )
                  : null,
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Text(
            'Showing ${_filteredStudents.length} of ${_students.length} student(s)',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ),
        _students.isEmpty
            ? _buildNoStudents()
            : Expanded(child: _buildStudentList()),
      ],
    );
  }

  Widget _buildInfoBanner() {
    if (_assignedBatch == null) {
      return Container(
        width: double.infinity,
        color: Colors.orange.shade100,
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.orange),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'No mentor batch has been assigned to you ($_facultyName) yet. '
                'Please contact the admin.',
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),
      );
    }
    return Container(
      width: double.infinity,
      color: const Color(0xFF1e3a5f),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          const Icon(Icons.group, color: Colors.white70),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _facultyName ?? '',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15),
                ),
                Text(
                  'Assigned Batch: $_assignedBatch  ·  ${_students.length} students',
                  style:
                      const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoStudents() {
    return const Expanded(
      child: Center(
        child: Text(
          'No students found in this batch.',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      ),
    );
  }

  Widget _buildStudentList() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      itemCount: _filteredStudents.length,
      itemBuilder: (context, index) {
        return _StudentCard(
          student: _filteredStudents[index],
          isExpanded: _expandedIndex == index,
          onTap: () {
            setState(() {
              _expandedIndex = _expandedIndex == index ? null : index;
            });
          },
        );
      },
    );
  }
}

// ─── Individual student card ────────────────────────────────────────────────

class _StudentCard extends StatefulWidget {
  final Map<String, dynamic> student;
  final bool isExpanded;
  final VoidCallback onTap;

  const _StudentCard({
    required this.student,
    required this.isExpanded,
    required this.onTap,
  });

  @override
  State<_StudentCard> createState() => _StudentCardState();
}

class _StudentCardState extends State<_StudentCard> {
  final _fs = FirebaseFirestore.instance;

  bool _marksLoading = false;
  bool _marksLoaded = false;
  List<Map<String, dynamic>> _marks = [];
  String? _computedCgpa;

  String _str(String key) {
    final v = widget.student[key]?.toString().trim() ?? '';
    return v.isEmpty ? '—' : v;
  }

  @override
  void didUpdateWidget(_StudentCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isExpanded && !_marksLoaded && !_marksLoading) {
      _loadMarks();
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.isExpanded) _loadMarks();
  }

  // ── helpers (mirrors student_home.dart _computeCgpa) ──────────────────────

  static bool _isEte(String name) {
    final l = name.toLowerCase();
    return l.contains('end term') ||
        l.contains('ete') ||
        l.contains('end-term') ||
        l.contains('external');
  }

  static int _gradePoint(double pct) {
    if (pct >= 90) return 10;
    if (pct >= 80) return 9;
    if (pct >= 70) return 8;
    if (pct >= 60) return 7;
    if (pct >= 50) return 6;
    if (pct >= 40) return 5;
    return 0;
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

  Future<void> _loadMarks() async {
    final roll = _str('rollNumber');
    if (roll == '—') return;
    setState(() => _marksLoading = true);
    try {
      final snap = await _fs
          .collection('studentMarks')
          .where('studentId', isEqualTo: roll)
          .get();

      final rows = snap.docs.map((d) {
        final data = Map<String, dynamic>.from(d.data());
        return data;
      }).toList()
        ..sort((a, b) {
          final y = (a['year']?.toString() ?? '')
              .compareTo(b['year']?.toString() ?? '');
          if (y != 0) return y;
          return (_normSem(a['semester']?.toString() ?? ''))
              .compareTo(_normSem(b['semester']?.toString() ?? ''));
        });

      // Compute CGPA
      final Map<String, double> semCP = {};
      final Map<String, int> semTC = {};
      for (final d in rows) {
        final semKey =
            '${d['year']?.toString() ?? ''}-${_normSem(d['semester']?.toString() ?? '')}';
        final rawMarks = d['componentMarks'] as Map<String, dynamic>? ?? {};
        int cieSum = 0, eteSum = 0;
        for (final e in rawMarks.entries) {
          final val = e.value is int
              ? e.value as int
              : e.value is num
                  ? (e.value as num).floor()
                  : int.tryParse(e.value.toString()) ?? 0;
          if (_isEte(e.key)) {
            eteSum += val;
          } else {
            cieSum += val;
          }
        }
        final maxAll = d['maxMarks'] is int
            ? d['maxMarks'] as int
            : d['maxMarks'] is num
                ? (d['maxMarks'] as num).floor()
                : int.tryParse(d['maxMarks']?.toString() ?? '') ?? 0;
        final rawCr = d['credits'];
        final cr = rawCr is int
            ? rawCr
            : rawCr is num
                ? rawCr.floor()
                : int.tryParse(rawCr?.toString() ?? '') ?? 3;
        if (maxAll <= 0) continue;
        final pct = ((cieSum + eteSum) / maxAll) * 100;
        final gp = _gradePoint(pct);
        semCP[semKey] = (semCP[semKey] ?? 0.0) + gp * cr.toDouble();
        semTC[semKey] = (semTC[semKey] ?? 0) + cr;
      }

      double sgpaSum = 0;
      int semCount = 0;
      for (final k in semCP.keys) {
        final tc = semTC[k] ?? 0;
        if (tc > 0) {
          sgpaSum += semCP[k]! / tc;
          semCount++;
        }
      }

      final cgpaStr = semCount > 0
          ? (sgpaSum / semCount).toStringAsFixed(2)
          : null;

      if (!mounted) return;
      setState(() {
        _marks = rows;
        _computedCgpa = cgpaStr;
        _marksLoaded = true;
        _marksLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _marksLoading = false;
        _marksLoaded = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final roll = _str('rollNumber');
    final name = _str('name');
    final program = _str('program');
    final year = _str('year');
    final section = _str('section');
    final cgpaDisplay = _computedCgpa ?? '—';

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Column(
        children: [
          // Header row – always visible
          InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: widget.onTap,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: const Color(0xFF1e3a5f),
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 15)),
                        const SizedBox(height: 2),
                        Text(
                          'Roll: $roll  ·  $program  ·  Year $year  ·  Sec $section',
                          style: const TextStyle(
                              fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    widget.isExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: Colors.grey,
                  ),
                ],
              ),
            ),
          ),
          // Expanded detail panel
          if (widget.isExpanded)
            Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(10)),
              ),
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(height: 1),
                  const SizedBox(height: 10),
                  // ── Profile details grid ──────────────────────────────
                  Wrap(
                    spacing: 12,
                    runSpacing: 10,
                    children: [
                      _tile(Icons.badge_outlined, 'Hall Ticket No.',
                          _str('hallTicketNumber')),
                      _tile(Icons.school_outlined, 'Department',
                          _str('department')),
                      _tile(Icons.email_outlined, 'Email', _str('email')),
                      _tile(Icons.phone_outlined, 'Phone', _str('phone')),
                      _tile(Icons.calendar_today_outlined, 'Date of Birth',
                          _str('dob')),
                      _tile(Icons.class_outlined, 'Batch / Section',
                          '${_str('batchNumber')} / ${_str('section')}'),
                      _tile(Icons.layers_outlined, 'Year / Semester',
                          'Year ${_str('year')}  ·  Sem ${_str('semester')}'),
                      _tile(Icons.grade_outlined, 'CGPA',
                          _marksLoading ? '…' : cgpaDisplay),
                      _tile(Icons.home_outlined, 'Address', _str('address')),
                    ],
                  ),
                  const SizedBox(height: 14),
                  // ── Marks section ─────────────────────────────────────
                  const Text('Subject Marks',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Color(0xFF1e3a5f))),
                  const SizedBox(height: 8),
                  if (_marksLoading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_marks.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text('No marks records found.',
                          style:
                              TextStyle(color: Colors.grey, fontSize: 13)),
                    )
                  else
                    _buildMarksSection(),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMarksSection() {
    // Group by year-semester
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final m in _marks) {
      final key =
          'Year ${m['year'] ?? '?'} – Sem ${_normSem(m['semester']?.toString() ?? '?')}';
      grouped.putIfAbsent(key, () => []).add(m);
    }

    return Column(
      children: grouped.entries.map((entry) {
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                decoration: const BoxDecoration(
                  color: Color(0xFF1e3a5f),
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(7)),
                ),
                child: Text(entry.key,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12)),
              ),
              ...entry.value.map((m) {
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
                            fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      subtitle: compMarks.isNotEmpty
                          ? Text(
                              compMarks.entries
                                  .map((e) => '${e.key}: ${e.value}')
                                  .join('   '),
                              style: const TextStyle(
                                  fontSize: 11, color: Colors.grey),
                            )
                          : null,
                      trailing: total != null
                          ? Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1e3a5f)
                                    .withOpacity(0.1),
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
      }).toList(),
    );
  }

  Widget _tile(IconData icon, String label, String value) {
    return SizedBox(
      width: 260,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF1e3a5f)),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 11,
                        color: Colors.grey,
                        fontWeight: FontWeight.w600)),
                Text(value, style: const TextStyle(fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
