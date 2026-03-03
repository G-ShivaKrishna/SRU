import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../widgets/app_header.dart';

// ─── Model ────────────────────────────────────────────────────────────────────

class _CieEntry {
  final String docId;
  final String subjectCode;
  final String subjectName;
  final int yearNum;
  final String semester;
  final String academicYear;
  final Map<String, int> componentMarks;
  final int maxMarks;

  const _CieEntry({
    required this.docId,
    required this.subjectCode,
    required this.subjectName,
    required this.yearNum,
    required this.semester,
    required this.academicYear,
    required this.componentMarks,
    required this.maxMarks,
  });

  /// Sum of all marks whose component type is 'internal' (CIE)
  int get cieTotal {
    // We don't have type info here; convention: End Term Exam is ETE, rest is CIE
    int total = 0;
    for (final e in componentMarks.entries) {
      if (!_isEte(e.key)) total += e.value;
    }
    return total;
  }

  /// End Term Exam mark
  int get eteTotal {
    int total = 0;
    for (final e in componentMarks.entries) {
      if (_isEte(e.key)) total += e.value;
    }
    return total;
  }

  static bool _isEte(String name) {
    final lower = name.toLowerCase();
    return lower.contains('end term') ||
        lower.contains('ete') ||
        lower.contains('end-term') ||
        lower.contains('external');
  }

  String get yearSem => '$yearNum-$semester';
}

// ─── Screen ───────────────────────────────────────────────────────────────────

class StudentCieMarksScreen extends StatefulWidget {
  const StudentCieMarksScreen({super.key});

  @override
  State<StudentCieMarksScreen> createState() => _StudentCieMarksScreenState();
}

class _StudentCieMarksScreenState extends State<StudentCieMarksScreen> {
  final _auth = FirebaseAuth.instance;
  final _fs = FirebaseFirestore.instance;

  bool _loading = true;
  String? _error;
  List<_CieEntry> _entries = [];
  StreamSubscription<QuerySnapshot>? _sub;

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _subscribe() {
    final user = _auth.currentUser;
    if (user == null) {
      setState(() {
        _error = 'Not logged in';
        _loading = false;
      });
      return;
    }
    final studentId = user.email!.split('@')[0].toUpperCase();

    _sub?.cancel();
    _sub = _fs
        .collection('studentMarks')
        .where('studentId', isEqualTo: studentId)
        .snapshots()
        .listen(
      (snap) {
        final entries = snap.docs.map((doc) {
          final d = doc.data();
          final rawMarks = d['componentMarks'] as Map<String, dynamic>? ?? {};
          final marks = rawMarks.map((k, v) =>
              MapEntry(k, (v is int) ? v : int.tryParse(v.toString()) ?? 0));
          return _CieEntry(
            docId: doc.id,
            subjectCode: (d['subjectCode'] ?? '').toString(),
            subjectName: (d['subjectName'] ?? '').toString(),
            yearNum: (d['year'] is int)
                ? d['year'] as int
                : int.tryParse(d['year'].toString()) ?? 0,
            semester: (d['semester'] ?? '').toString(),
            academicYear: (d['academicYear'] ?? '').toString(),
            componentMarks: marks,
            maxMarks: (d['maxMarks'] is int)
                ? d['maxMarks'] as int
                : int.tryParse(d['maxMarks'].toString()) ?? 0,
          );
        }).toList();

        // Sort: latest year+semester first, then by subjectCode
        entries.sort((a, b) {
          final yCmp = b.yearNum.compareTo(a.yearNum);
          if (yCmp != 0) return yCmp;
          final sCmp = b.semester.compareTo(a.semester);
          if (sCmp != 0) return sCmp;
          return a.subjectCode.compareTo(b.subjectCode);
        });

        if (!mounted) return;
        setState(() {
          _entries = entries;
          _loading = false;
          _error = null;
        });
      },
      onError: (e) {
        if (!mounted) return;
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      },
    );
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Column(
        children: [
          const AppHeader(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'Failed to load CIE marks:\n$_error',
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: _subscribe, child: const Text('Retry')),
          ],
        ),
      );
    }

    final isMobile = MediaQuery.of(context).size.width < 700;

    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Page title ──────────────────────────────────────────
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                decoration: const BoxDecoration(
                  color: Color(0xFF1e3a5f),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
                ),
                child: const Text(
                  'Student Mid Examination Marks',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              if (_entries.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(40),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius:
                        const BorderRadius.vertical(bottom: Radius.circular(8)),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.assignment_outlined,
                          size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'No CIE marks available yet.\nFaculty has not entered marks for your subjects.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                )
              else
                isMobile ? _buildMobileList() : _buildDesktopTable(),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Desktop table ─────────────────────────────────────────────────────────

  Widget _buildDesktopTable() {
    const headerStyle = TextStyle(
      color: Colors.white,
      fontWeight: FontWeight.bold,
      fontSize: 13,
    );

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(const Color(0xFF4169E1)),
          headingRowHeight: 48,
          dataRowMinHeight: 52,
          dataRowMaxHeight: 52,
          columnSpacing: 24,
          columns: const [
            DataColumn(label: Text('S.No', style: headerStyle)),
            DataColumn(label: Text('Year-Sem', style: headerStyle)),
            DataColumn(label: Text('Course', style: headerStyle)),
            DataColumn(label: Text('CIE', style: headerStyle)),
            DataColumn(label: Text('ETE', style: headerStyle)),
            DataColumn(label: Text('View', style: headerStyle)),
          ],
          rows: _entries.asMap().entries.map((e) {
            final idx = e.key;
            final entry = e.value;
            return DataRow(
              cells: [
                DataCell(Text('${idx + 1}')),
                DataCell(
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1e3a5f).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(entry.yearSem,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 12)),
                  ),
                ),
                DataCell(
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(entry.subjectCode,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 12)),
                      Text(entry.subjectName,
                          style:
                              TextStyle(fontSize: 11, color: Colors.grey[600]),
                          overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                DataCell(_marksBadge(entry.cieTotal, null, Colors.green)),
                DataCell(_marksBadge(entry.eteTotal, null, Colors.orange)),
                DataCell(
                  TextButton.icon(
                    onPressed: () => _showDetail(entry),
                    icon: const Icon(Icons.visibility, size: 16),
                    label: const Text('View'),
                    style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF1e3a5f)),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  // ─── Mobile list ───────────────────────────────────────────────────────────

  Widget _buildMobileList() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8)),
      ),
      child: Column(
        children: _entries.asMap().entries.map((e) {
          final idx = e.key;
          final entry = e.value;
          return Column(
            children: [
              if (idx > 0) const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1e3a5f),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text('${idx + 1}',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(entry.subjectCode,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13)),
                              Text(entry.subjectName,
                                  style: TextStyle(
                                      fontSize: 11, color: Colors.grey[600]),
                                  overflow: TextOverflow.ellipsis),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1e3a5f).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(entry.yearSem,
                              style: const TextStyle(
                                  fontSize: 11, fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _mobileStatBox(
                              'CIE (Internal)', entry.cieTotal, Colors.green),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _mobileStatBox(
                              'ETE (End Term)', entry.eteTotal, Colors.orange),
                        ),
                        const SizedBox(width: 10),
                        OutlinedButton.icon(
                          onPressed: () => _showDetail(entry),
                          icon: const Icon(Icons.visibility, size: 15),
                          label: const Text('View',
                              style: TextStyle(fontSize: 12)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF1e3a5f),
                            side: const BorderSide(color: Color(0xFF1e3a5f)),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  // ─── Detail dialog ─────────────────────────────────────────────────────────

  void _showDetail(_CieEntry entry) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFF1e3a5f),
                borderRadius: BorderRadius.vertical(top: Radius.circular(11)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(entry.subjectCode,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15)),
                  const SizedBox(height: 2),
                  Text(entry.subjectName,
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 12)),
                  const SizedBox(height: 6),
                  Text(
                      'Year ${entry.yearNum}  •  Semester ${entry.semester}  •  ${entry.academicYear}',
                      style:
                          const TextStyle(color: Colors.white60, fontSize: 11)),
                ],
              ),
            ),
            // Component rows
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    ...entry.componentMarks.entries.map((e) {
                      final isEte = _CieEntry._isEte(e.key);
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    margin: const EdgeInsets.only(right: 8),
                                    decoration: BoxDecoration(
                                      color:
                                          isEte ? Colors.orange : Colors.green,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(e.key,
                                        style: const TextStyle(fontSize: 13)),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: isEte
                                    ? Colors.orange.withOpacity(0.1)
                                    : Colors.green.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isEte ? Colors.orange : Colors.green,
                                  width: 1,
                                ),
                              ),
                              child: Text('${e.value}',
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: isEte
                                          ? Colors.orange[800]
                                          : Colors.green[800])),
                            ),
                          ],
                        ),
                      );
                    }),
                    const Divider(height: 24),
                    // Summary row
                    Row(
                      children: [
                        Expanded(
                          child: _summaryBox(
                              'CIE Total', entry.cieTotal, Colors.green),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _summaryBox(
                              'ETE Total', entry.eteTotal, Colors.orange),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _summaryBox(
                              'Grand Total',
                              entry.cieTotal + entry.eteTotal,
                              const Color(0xFF1e3a5f)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            // Close
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1e3a5f),
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Close',
                      style: TextStyle(color: Colors.white)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Helpers ───────────────────────────────────────────────────────────────

  Widget _marksBadge(int value, int? max, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        max != null ? '$value/$max' : '$value',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: color.shade700,
        ),
      ),
    );
  }

  Widget _mobileStatBox(String label, int value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Column(
        children: [
          Text('$value',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: color.shade700)),
          Text(label,
              style: TextStyle(fontSize: 9, color: color.shade700),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _summaryBox(String label, int value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Column(
        children: [
          Text('$value',
              style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(fontSize: 10, color: color),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

extension _ColorShade on Color {
  Color get shade700 {
    return Color.fromARGB(
      alpha,
      (red * 0.7).round(),
      (green * 0.7).round(),
      (blue * 0.7).round(),
    );
  }
}
