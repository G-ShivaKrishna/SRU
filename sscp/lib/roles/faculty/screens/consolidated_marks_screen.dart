import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../services/user_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Consolidated Marks Report – all students' marks for subjects taught by this
// faculty, grouped batch-wise (year × semester × branch × section).
// ─────────────────────────────────────────────────────────────────────────────

class ConsolidatedMarksScreen extends StatefulWidget {
  const ConsolidatedMarksScreen({super.key});

  @override
  State<ConsolidatedMarksScreen> createState() =>
      _ConsolidatedMarksScreenState();
}

class _ConsolidatedMarksScreenState extends State<ConsolidatedMarksScreen>
    with SingleTickerProviderStateMixin {
  final _fs = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  bool _loading = true;
  String? _error;
  String _facultyId = '';

  // List of batches this faculty teaches
  List<_Batch> _batches = [];
  TabController? _tabCtrl;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _tabCtrl?.dispose();
    super.dispose();
  }

  String _resolveFacultyId() {
    final user = _auth.currentUser;
    if (user == null) return '';
    final email = user.email ?? '';
    return UserService.getCurrentUserId() ?? email.split('@')[0].toUpperCase();
  }

  Future<void> _load() async {
    try {
      _facultyId = _resolveFacultyId();
      if (_facultyId.isEmpty) {
        setState(() {
          _error = 'Could not determine faculty identity. Please log in again.';
          _loading = false;
        });
        return;
      }

      // 1. Fetch all active assignments for this faculty
      final assignSnap = await _fs
          .collection('facultyAssignments')
          .where('facultyId', isEqualTo: _facultyId)
          .get();

      // Filter by isActive to exclude courses from previous semesters
      final activeDocs = assignSnap.docs.where((doc) {
        final d = doc.data();
        return (d['isActive'] ?? true) == true;
      }).toList();

      if (activeDocs.isEmpty) {
        setState(() {
          _batches = [];
          _loading = false;
        });
        return;
      }

      // 2. Group assignments into batches keyed by year-sem-branch-section
      final batchMap = <String, _Batch>{};
      for (final doc in activeDocs) {
        final d = doc.data();
        final year = d['year']?.toString() ?? '';
        final sem = d['semester']?.toString() ?? '';
        final branch =
            (d['branch'] ?? d['department'] ?? '').toString().toUpperCase();
        final section = (d['section'] ?? d['batch'] ?? '').toString();
        final key = '$year|$sem|$branch|$section';
        batchMap.putIfAbsent(
          key,
          () => _Batch(
            year: year,
            semester: sem,
            branch: branch,
            section: section,
            subjects: [],
          ),
        );
        batchMap[key]!.subjects.add(_Subject(
              code: (d['subjectCode'] ?? '').toString(),
              name: (d['subjectName'] ?? '').toString(),
              credits: _toInt(d['credits']) ?? 3,
            ));
      }

      final batches = batchMap.values.toList()
        ..sort((a, b) {
          final yr = a.year.compareTo(b.year);
          if (yr != 0) return yr;
          return a.semester.compareTo(b.semester);
        });

      // 3. For each batch, fetch all student marks for each subject
      for (final batch in batches) {
        for (final subject in batch.subjects) {
          if (subject.code.isEmpty) continue;
          final mSnap = await _fs
              .collection('studentMarks')
              .where('subjectCode', isEqualTo: subject.code)
              .where('year', isEqualTo: int.tryParse(batch.year) ?? batch.year)
              .get();

          // Filter by semester
          final normBatchSem = _normSem(batch.semester);
          for (final m in mSnap.docs) {
            final mData = m.data();
            if (_normSem(mData['semester']?.toString() ?? '') != normBatchSem) {
              continue;
            }
            // Optionally filter by branch
            final mBranch = (mData['branch'] ?? mData['department'] ?? '')
                .toString()
                .toUpperCase();
            if (mBranch.isNotEmpty &&
                batch.branch.isNotEmpty &&
                mBranch != batch.branch) {
              continue;
            }
            subject.marks.add(_StudentMark(
              studentId: (mData['studentId'] ?? '').toString(),
              studentName: (mData['studentName'] ?? '').toString(),
              componentMarks: Map<String, dynamic>.from(
                  mData['componentMarks'] as Map? ?? {}),
              totalMarks: _toIntOrNull(mData['totalMarks']),
              maxMarks: _toInt(mData['maxMarks']) ?? 0,
            ));
          }
          subject.marks.sort((a, b) => a.studentId.compareTo(b.studentId));
        }
      }

      setState(() {
        _batches = batches;
        _tabCtrl = TabController(length: batches.length, vsync: this);
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
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

  static int? _toInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.floor();
    return int.tryParse(v?.toString() ?? '');
  }

  static int? _toIntOrNull(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.floor();
    return int.tryParse(v.toString());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Consolidated Marks Report'),
        backgroundColor: const Color(0xFF1e3a5f),
        foregroundColor: Colors.white,
        bottom: _batches.isNotEmpty && _tabCtrl != null
            ? TabBar(
                controller: _tabCtrl,
                isScrollable: true,
                indicatorColor: Colors.yellow,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white60,
                tabs: _batches
                    .map((b) => Tab(
                          text:
                              'Y${b.year} S${b.semester}${b.branch.isNotEmpty ? ' · ${b.branch}' : ''}${b.section.isNotEmpty ? ' · ${b.section}' : ''}',
                        ))
                    .toList(),
              )
            : null,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 12),
              Text(_error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 16),
              ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _loading = true;
                      _error = null;
                    });
                    _load();
                  },
                  child: const Text('Retry')),
            ],
          ),
        ),
      );
    }
    if (_batches.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.assignment_outlined, size: 72, color: Colors.black12),
              SizedBox(height: 16),
              Text('No batch assignments found for you.',
                  style: TextStyle(fontSize: 15, color: Colors.black45),
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }

    return TabBarView(
      controller: _tabCtrl,
      children: _batches.map((b) => _BatchView(batch: b)).toList(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Batch tab content — one tab per year/semester/branch/section combo
// ─────────────────────────────────────────────────────────────────────────────

class _BatchView extends StatelessWidget {
  final _Batch batch;
  const _BatchView({required this.batch});

  @override
  Widget build(BuildContext context) {
    if (batch.subjects.isEmpty) {
      return const Center(
          child: Text('No subjects assigned for this batch.',
              style: TextStyle(color: Colors.black45)));
    }

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        // Batch summary chip row
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            _Chip(label: 'Year ${batch.year}'),
            _Chip(label: 'Semester ${batch.semester}'),
            if (batch.branch.isNotEmpty) _Chip(label: batch.branch),
            if (batch.section.isNotEmpty)
              _Chip(label: 'Section / Batch: ${batch.section}'),
          ],
        ),
        const SizedBox(height: 12),

        // One card per subject
        ...batch.subjects.map((s) => _SubjectCard(subject: s)),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Subject card — shows all students' marks for that subject
// ─────────────────────────────────────────────────────────────────────────────

class _SubjectCard extends StatelessWidget {
  final _Subject subject;
  const _SubjectCard({required this.subject});

  @override
  Widget build(BuildContext context) {
    // Collect all component keys across all student rows
    final compKeys = <String>{};
    for (final m in subject.marks) {
      compKeys.addAll(m.componentMarks.keys);
    }
    final components = compKeys.toList()..sort();

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Subject header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFF1e3a5f),
              borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  subject.code.isNotEmpty ? subject.code : 'Unknown Code',
                  style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 2),
                Text(
                  subject.name.isNotEmpty
                      ? subject.name
                      : '(Subject name not set)',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold),
                ),
                Text(
                  '${subject.marks.length} student${subject.marks.length == 1 ? '' : 's'}  •  Credits: ${subject.credits}',
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                ),
              ],
            ),
          ),

          if (subject.marks.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('No marks uploaded yet.',
                  style: TextStyle(color: Colors.black45, fontSize: 13)),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.all(8),
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(
                    const Color(0xFF1e3a5f).withOpacity(0.07)),
                headingTextStyle: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: Color(0xFF1e3a5f)),
                dataTextStyle:
                    const TextStyle(fontSize: 12, color: Colors.black87),
                columnSpacing: 20,
                columns: [
                  const DataColumn(label: Text('#')),
                  const DataColumn(label: Text('Roll No.')),
                  const DataColumn(label: Text('Name')),
                  ...components.map((c) => DataColumn(label: Text(c))),
                  const DataColumn(label: Text('Total')),
                  const DataColumn(label: Text('Max')),
                  const DataColumn(label: Text('%')),
                ],
                rows: subject.marks.asMap().entries.map((e) {
                  final idx = e.key;
                  final m = e.value;
                  final total = m.totalMarks ??
                      m.componentMarks.values
                          .fold<int>(0, (s, v) => s + (_toInt(v) ?? 0));
                  final pct =
                      m.maxMarks > 0 ? (total / m.maxMarks * 100) : null;
                  final passed = pct != null && pct >= 40;
                  return DataRow(
                    color: WidgetStateProperty.resolveWith((states) =>
                        idx % 2 == 0 ? Colors.white : Colors.grey.shade50),
                    cells: [
                      DataCell(Text('${idx + 1}',
                          style: const TextStyle(color: Colors.black45))),
                      DataCell(Text(m.studentId)),
                      DataCell(SizedBox(
                          width: 130,
                          child: Text(
                              m.studentName.isNotEmpty ? m.studentName : '–',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis))),
                      ...components.map((c) {
                        final v = m.componentMarks[c];
                        return DataCell(Text(v?.toString() ?? '–'));
                      }),
                      DataCell(Text(
                        '$total',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      )),
                      DataCell(Text('${m.maxMarks > 0 ? m.maxMarks : '–'}')),
                      DataCell(pct != null
                          ? Text(
                              '${pct.toStringAsFixed(1)}%',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: passed
                                    ? Colors.green.shade700
                                    : Colors.red.shade700,
                              ),
                            )
                          : const Text('–')),
                    ],
                  );
                }).toList(),
              ),
            ),

          // Summary footer
          if (subject.marks.isNotEmpty) _buildSummary(subject, components),
        ],
      ),
    );
  }

  Widget _buildSummary(_Subject subject, List<String> components) {
    final count = subject.marks.length;
    final passed = subject.marks.where((m) {
      final total = m.totalMarks ??
          m.componentMarks.values.fold<int>(0, (s, v) => s + (_toInt(v) ?? 0));
      return m.maxMarks > 0 && (total / m.maxMarks * 100) >= 40;
    }).length;
    final avgTotal = count > 0
        ? subject.marks
                .map((m) =>
                    m.totalMarks ??
                    m.componentMarks.values
                        .fold<int>(0, (s, v) => s + (_toInt(v) ?? 0)))
                .reduce((a, b) => a + b) /
            count
        : 0.0;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFEEF2FF),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(10)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Wrap(
        spacing: 20,
        runSpacing: 4,
        children: [
          _SummaryItem(label: 'Total', value: '$count'),
          _SummaryItem(label: 'Passed', value: '$passed'),
          _SummaryItem(label: 'Failed', value: '${count - passed}'),
          _SummaryItem(label: 'Avg Marks', value: avgTotal.toStringAsFixed(1)),
          _SummaryItem(
              label: 'Pass %',
              value: count > 0
                  ? '${(passed / count * 100).toStringAsFixed(1)}%'
                  : '–'),
        ],
      ),
    );
  }

  static int? _toInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.floor();
    return int.tryParse(v?.toString() ?? '');
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Data models
// ─────────────────────────────────────────────────────────────────────────────

class _Batch {
  final String year, semester, branch, section;
  final List<_Subject> subjects;
  _Batch({
    required this.year,
    required this.semester,
    required this.branch,
    required this.section,
    required this.subjects,
  });
}

class _Subject {
  final String code, name;
  final int credits;
  final List<_StudentMark> marks = [];
  _Subject({required this.code, required this.name, required this.credits});
}

class _StudentMark {
  final String studentId, studentName;
  final Map<String, dynamic> componentMarks;
  final int? totalMarks;
  final int maxMarks;
  _StudentMark({
    required this.studentId,
    required this.studentName,
    required this.componentMarks,
    this.totalMarks,
    required this.maxMarks,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Small UI helpers
// ─────────────────────────────────────────────────────────────────────────────

class _Chip extends StatelessWidget {
  final String label;
  const _Chip({required this.label});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
          color: const Color(0xFF1e3a5f).withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF1e3a5f).withOpacity(0.25))),
      child: Text(label,
          style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1e3a5f))),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final String label, value;
  const _SummaryItem({required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$label: ',
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: Colors.black54)),
        Text(value,
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1e3a5f))),
      ],
    );
  }
}
