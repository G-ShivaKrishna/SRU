import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../widgets/app_header.dart';
import '../../../utils/memo_pdf_generator.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Model for a supply exam session with released results
// ─────────────────────────────────────────────────────────────────────────────

class _SupplyExamSession {
  final String examSession;
  final String windowId;
  final DateTime releasedAt;
  final int subjectCount;

  const _SupplyExamSession({
    required this.examSession,
    required this.windowId,
    required this.releasedAt,
    required this.subjectCount,
  });
}

// Model for one subject's supply marks
class _SupplySubjectEntry {
  final String subjectCode;
  final String subjectName;
  final int internalMarks;
  final int externalMarks;
  final int totalMarks;
  final String grade;
  final String result;
  final int credits;

  const _SupplySubjectEntry({
    required this.subjectCode,
    required this.subjectName,
    required this.internalMarks,
    required this.externalMarks,
    required this.totalMarks,
    required this.grade,
    required this.result,
    this.credits = 3,
  });

  int get gradePoint {
    switch (grade.toUpperCase()) {
      case 'O':
        return 10;
      case 'A+':
        return 9;
      case 'A':
        return 8;
      case 'B+':
        return 7;
      case 'B':
        return 6;
      case 'C':
        return 5;
      case 'P':
        return 4;
      default:
        return 0;
    }
  }

  double get creditPoints => gradePoint * credits.toDouble();

  bool get isPassed => result == 'PASS';

  static _SupplySubjectEntry fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return _SupplySubjectEntry(
      subjectCode: (d['subjectCode'] ?? '').toString(),
      subjectName: (d['subjectName'] ?? '').toString(),
      internalMarks: _parseInt(d['internalMarks']),
      externalMarks: _parseInt(d['externalMarks']),
      totalMarks: _parseInt(d['totalMarks']),
      grade: (d['grade'] ?? '').toString(),
      result: (d['result'] ?? '').toString(),
      credits: _parseInt(d['credits'], defaultValue: 3),
    );
  }

  static int _parseInt(dynamic value, {int defaultValue = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? defaultValue;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Main list screen - shows all released supply exam results
// ─────────────────────────────────────────────────────────────────────────────

class SupplyExamMemoScreen extends StatefulWidget {
  const SupplyExamMemoScreen({super.key});

  @override
  State<SupplyExamMemoScreen> createState() => _SupplyExamMemoScreenState();
}

class _SupplyExamMemoScreenState extends State<SupplyExamMemoScreen> {
  final _auth = FirebaseAuth.instance;
  final _fs = FirebaseFirestore.instance;

  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _studentData;
  List<_SupplyExamSession> _sessions = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('Not logged in');
      final rollNumber = user.email!.split('@')[0].toUpperCase();

      // Load student profile
      final doc = await _fs.collection('students').doc(rollNumber).get();
      final sData = doc.exists
          ? (doc.data() as Map<String, dynamic>)
          : <String, dynamic>{};
      sData['rollNumber'] = rollNumber;

      // Load all released supply marks for this student
      final marksSnap = await _fs
          .collection('supplyMarks')
          .where('rollNo', isEqualTo: rollNumber)
          .where('resultsReleased', isEqualTo: true)
          .get();

      // Group by exam session
      final sessionMap = <String, _SupplyExamSession>{};
      for (final doc in marksSnap.docs) {
        final data = doc.data();
        final examSession = (data['examSession'] ?? '').toString();
        final windowId = (data['supplyWindowId'] ?? '').toString();
        final releasedAt =
            (data['releasedAt'] as Timestamp?)?.toDate() ?? DateTime.now();

        if (examSession.isNotEmpty) {
          if (!sessionMap.containsKey(examSession)) {
            sessionMap[examSession] = _SupplyExamSession(
              examSession: examSession,
              windowId: windowId,
              releasedAt: releasedAt,
              subjectCount: 1,
            );
          } else {
            final existing = sessionMap[examSession]!;
            sessionMap[examSession] = _SupplyExamSession(
              examSession: existing.examSession,
              windowId: existing.windowId,
              releasedAt: existing.releasedAt,
              subjectCount: existing.subjectCount + 1,
            );
          }
        }
      }

      final sessions = sessionMap.values.toList()
        ..sort((a, b) => b.releasedAt.compareTo(a.releasedAt));

      if (!mounted) return;
      setState(() {
        _studentData = sData;
        _sessions = sessions;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────────

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
            Text('Failed to load memos:\n$_error', textAlign: TextAlign.center),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }

    final isMobile = MediaQuery.of(context).size.width < 700;

    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 12 : 20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Page header
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                decoration: const BoxDecoration(
                  color: Color(0xFF1e3a5f),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
                ),
                child: const Text(
                  'Supply Exam Memos',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Text(
                  'Supply exam results are released by the Admin once marks are uploaded. '
                  'You will see them here as soon as they are released.',
                  style: TextStyle(fontSize: 12, color: Colors.blue.shade800),
                ),
              ),
              if (_sessions.isEmpty)
                _buildEmptyState()
              else
                ..._sessions
                    .map((session) => _buildSessionCard(session, isMobile)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(48),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8)),
      ),
      child: Column(
        children: [
          Icon(Icons.description_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No supply exam results released yet.\nResults will appear here once the Admin releases them.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionCard(_SupplyExamSession session, bool isMobile) {
    return Container(
      margin: const EdgeInsets.only(top: 0),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 14 : 18),
        child: Row(
          children: [
            // Left: icon
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFF1e3a5f).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.article_outlined,
                  color: Color(0xFF1e3a5f), size: 28),
            ),
            const SizedBox(width: 14),
            // Middle: details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    session.examSession,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${session.subjectCount} subject${session.subjectCount != 1 ? 's' : ''}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.green.shade300),
                    ),
                    child: Text(
                      'Released on ${_fmtDate(session.releasedAt)}',
                      style: TextStyle(
                          fontSize: 11,
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            // Right: button
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1e3a5f),
                padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 10 : 16, vertical: 10),
              ),
              onPressed: () => _openMemo(session),
              icon: const Icon(Icons.visibility, color: Colors.white, size: 16),
              label: Text(
                isMobile ? 'View' : 'View Memo',
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openMemo(_SupplyExamSession session) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => _SupplyMemoViewScreen(
        session: session,
        studentData: _studentData ?? {},
        rollNumber: _studentData?['rollNumber'] ?? '',
      ),
    ));
  }

  String _fmtDate(DateTime dt) {
    const months = [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${dt.day} ${months[dt.month]} ${dt.year}';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Supply Memo View Screen — styled like the university memorandum
// ─────────────────────────────────────────────────────────────────────────────

class _SupplyMemoViewScreen extends StatefulWidget {
  final _SupplyExamSession session;
  final Map<String, dynamic> studentData;
  final String rollNumber;

  const _SupplyMemoViewScreen({
    required this.session,
    required this.studentData,
    required this.rollNumber,
  });

  @override
  State<_SupplyMemoViewScreen> createState() => _SupplyMemoViewScreenState();
}

class _SupplyMemoViewScreenState extends State<_SupplyMemoViewScreen> {
  final _fs = FirebaseFirestore.instance;

  bool _loading = true;
  List<_SupplySubjectEntry> _subjects = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadMarks();
  }

  Future<void> _loadMarks() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final snap = await _fs
          .collection('supplyMarks')
          .where('rollNo', isEqualTo: widget.rollNumber)
          .where('examSession', isEqualTo: widget.session.examSession)
          .where('resultsReleased', isEqualTo: true)
          .get();

      final entries = snap.docs
          .map((doc) => _SupplySubjectEntry.fromDoc(doc))
          .toList()
        ..sort((a, b) => a.subjectCode.compareTo(b.subjectCode));

      if (!mounted) return;
      setState(() {
        _subjects = entries;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  String get _studentName =>
      (widget.studentData['name'] ?? 'N/A').toString().toUpperCase();
  String get _fatherName =>
      (widget.studentData['fatherName'] ?? 'N/A').toString().toUpperCase();
  String get _enrolmentNumber =>
      (widget.studentData['hallTicketNumber'] ?? widget.rollNumber)
          .toString()
          .toUpperCase();
  String get _branch =>
      (widget.studentData['department'] ?? 'CSE').toString().toUpperCase();

  String get _memoNumber =>
      'SUPP-${widget.rollNumber}-${widget.session.examSession}';

  String get _serialNumber => 'SRU-${widget.rollNumber}';

  int get _totalCredits => _subjects.fold<int>(0, (s, e) => s + e.credits);
  double get _totalCreditPoints =>
      _subjects.fold<double>(0, (s, e) => s + e.creditPoints);
  int get _passed => _subjects.where((e) => e.isPassed).length;

  /// SGPA = total credit points / total credits
  double get _sgpa {
    if (_subjects.isEmpty || _totalCredits == 0) return 0.0;
    return _totalCreditPoints / _totalCredits;
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F0F0),
      appBar: AppBar(
        title: const Text('Supply Exam Marks Memo'),
        backgroundColor: const Color(0xFF1e3a5f),
        foregroundColor: Colors.white,
        actions: [
          if (!_loading && _subjects.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.print),
              onPressed: _printMemo,
              tooltip: 'Print Memo',
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline,
                          size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      Text('Failed to load marks:\n$_error',
                          textAlign: TextAlign.center),
                      const SizedBox(height: 20),
                      ElevatedButton(
                          onPressed: _loadMarks, child: const Text('Retry')),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 860),
                      child: _buildMemoDocument(),
                    ),
                  ),
                ),
    );
  }

  Future<void> _printMemo() async {
    try {
      final subjects = _subjects.map((s) {
        return {
          'subjectCode': s.subjectCode,
          'subjectName': s.subjectName,
          'internalMarks': s.internalMarks,
          'externalMarks': s.externalMarks,
          'totalMarks': s.totalMarks,
          'grade': s.grade,
          'result': s.result,
          'credits': s.credits,
        };
      }).toList();

      await printSupplyExamMemo(
        studentName: _studentName,
        fatherName: _fatherName,
        enrolmentNumber: _enrolmentNumber,
        branch: _branch,
        examSession: widget.session.examSession,
        memoNumber: _memoNumber,
        subjects: subjects,
        sgpa: _sgpa,
        totalCredits: _totalCredits,
        totalCreditPoints: _totalCreditPoints,
        passed: _passed,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Print error: $e')),
        );
      }
    }
  }

  Widget _buildMemoDocument() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _buildUniversityHeader(),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 7),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.black, width: 1.2),
            ),
            child: const Text(
              'MEMORANDUM OF SUPPLEMENTARY EXAMINATION MARKS',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                fontStyle: FontStyle.italic,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildDetailsGrid(),
          const SizedBox(height: 16),
          _buildMarksTable(),
          const SizedBox(height: 8),
          _buildSummaryRow(),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF1e3a5f),
              border: Border.all(color: Colors.grey.shade500, width: 0.8),
            ),
            child: Text(
              'SEMESTER GRADE POINT AVERAGE (SGPA): ${_sgpa.toStringAsFixed(3)}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              border: Border.all(color: Colors.grey.shade400),
            ),
            child: const Text(
              'This is a computer-generated supplementary examination marks memorandum. '
              'It is valid as a record of supplementary examination marks for the stated exam session.',
              style: TextStyle(fontSize: 10, color: Colors.black54),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUniversityHeader() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade400),
                borderRadius: BorderRadius.circular(6),
              ),
              alignment: Alignment.center,
              child: const Text(
                'SRU',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1e3a5f),
                ),
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'SR UNIVERSITY',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1e3a5f),
                      letterSpacing: 2,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Hanmakonda - 506 371, Telangana State, INDIA',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Divider(color: Colors.grey.shade400, thickness: 1),
      ],
    );
  }

  Widget _buildDetailsGrid() {
    final leftDetails = [
      ['Memo No.', _memoNumber],
      ['Serial No.', _serialNumber],
      ['Examination', 'SUPPLEMENTARY EXAMINATION'],
      ['Branch', _branch],
      ['Name', _studentName],
      ['Father\'s Name', _fatherName],
    ];
    final rightDetails = [
      ['Enrolment Number', _enrolmentNumber],
      ['Academic Year', '2025-26'],
      ['Exam Session', widget.session.examSession],
    ];

    return LayoutBuilder(builder: (context, constraints) {
      final isNarrow = constraints.maxWidth < 480;
      if (isNarrow) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: leftDetails
                  .map((item) => _detailRow(item[0], item[1]))
                  .toList(),
            ),
            const SizedBox(height: 8),
            Column(
              children: rightDetails.map((item) {
                return _detailRow(item[0], item[1],
                    valueStyle: item[0] == 'Enrolment Number'
                        ? const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Colors.red)
                        : null);
              }).toList(),
            ),
          ],
        );
      }

      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              children: leftDetails.map((item) {
                return _detailRow(item[0], item[1]);
              }).toList(),
            ),
          ),
          const SizedBox(width: 16),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 260),
            child: Column(
              children: rightDetails.map((item) {
                return _detailRow(item[0], item[1],
                    valueStyle: item[0] == 'Enrolment Number'
                        ? const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Colors.red)
                        : null);
              }).toList(),
            ),
          ),
        ],
      );
    });
  }

  Widget _detailRow(String label, String value, {TextStyle? valueStyle}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const Text(': ',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: valueStyle ??
                  const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1e3a5f)),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMarksTable() {
    if (_subjects.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.black),
        ),
        child: const Text(
          'No marks available.',
          textAlign: TextAlign.center,
          style: TextStyle(fontStyle: FontStyle.italic, color: Colors.black54),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;

        const headerDecoration = BoxDecoration(
          color: Color(0xFF1e3a5f),
        );
        final headerText = TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: isMobile ? 9 : 12,
        );
        final cellText = TextStyle(fontSize: isMobile ? 10 : 12);
        final rowPad = EdgeInsets.symmetric(
          horizontal: isMobile ? 3 : 8,
          vertical: isMobile ? 4 : 6,
        );

        return Table(
          border: TableBorder.all(color: Colors.grey.shade500, width: 0.8),
          columnWidths: isMobile
              ? const {
                  0: FlexColumnWidth(1.2),
                  1: FlexColumnWidth(2.5),
                  2: FlexColumnWidth(5),
                  3: FlexColumnWidth(1.5),
                  4: FlexColumnWidth(1.5),
                  5: FlexColumnWidth(2),
                  6: FlexColumnWidth(1.5),
                  7: FlexColumnWidth(1.8),
                }
              : const {
                  0: FixedColumnWidth(36),
                  1: FixedColumnWidth(90),
                  2: FlexColumnWidth(3),
                  3: FixedColumnWidth(60),
                  4: FixedColumnWidth(60),
                  5: FixedColumnWidth(60),
                  6: FixedColumnWidth(60),
                  7: FixedColumnWidth(60),
                },
          children: [
            TableRow(
              decoration: headerDecoration,
              children: isMobile
                  ? [
                      _cell('S.NO', headerText, rowPad),
                      _cell('CODE', headerText, rowPad),
                      _cell('COURSE', headerText, rowPad),
                      _cell('INT', headerText, rowPad, align: TextAlign.center),
                      _cell('EXT', headerText, rowPad, align: TextAlign.center),
                      _cell('TOT', headerText, rowPad, align: TextAlign.center),
                      _cell('GR', headerText, rowPad, align: TextAlign.center),
                      _cell('STATUS', headerText, rowPad,
                          align: TextAlign.center),
                    ]
                  : [
                      _cell('S.NO', headerText, rowPad),
                      _cell('COURSE\nCODE', headerText, rowPad),
                      _cell('COURSE TITLE', headerText, rowPad),
                      _cell('INTERNAL', headerText, rowPad,
                          align: TextAlign.center),
                      _cell('EXTERNAL', headerText, rowPad,
                          align: TextAlign.center),
                      _cell('TOTAL', headerText, rowPad,
                          align: TextAlign.center),
                      _cell('GRADE', headerText, rowPad,
                          align: TextAlign.center),
                      _cell('STATUS', headerText, rowPad,
                          align: TextAlign.center),
                    ],
            ),
            ..._subjects.asMap().entries.map((e) {
              final idx = e.key;
              final s = e.value;
              final isEven = idx % 2 == 0;

              return TableRow(
                decoration: BoxDecoration(
                  color: isEven ? Colors.white : Colors.grey.shade50,
                ),
                children: [
                  _cell('${idx + 1}', cellText, rowPad,
                      align: TextAlign.center),
                  _cell(s.subjectCode, cellText, rowPad),
                  _cell(s.subjectName, cellText, rowPad),
                  _cell('${s.internalMarks}', cellText, rowPad,
                      align: TextAlign.center),
                  _cell('${s.externalMarks}', cellText, rowPad,
                      align: TextAlign.center),
                  _cell(
                    '${s.totalMarks}',
                    cellText.copyWith(fontWeight: FontWeight.bold),
                    rowPad,
                    align: TextAlign.center,
                  ),
                  _cell(
                    s.grade,
                    cellText.copyWith(fontWeight: FontWeight.bold),
                    rowPad,
                    align: TextAlign.center,
                  ),
                  _cell(
                    s.result,
                    cellText.copyWith(
                      color: s.isPassed
                          ? Colors.green.shade700
                          : Colors.red.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                    rowPad,
                    align: TextAlign.center,
                  ),
                ],
              );
            }),
          ],
        );
      },
    );
  }

  Widget _cell(String text, TextStyle style, EdgeInsets padding,
      {TextAlign align = TextAlign.left}) {
    return Padding(
      padding: padding,
      child: Text(
        text,
        style: style,
        textAlign: align,
        overflow: TextOverflow.ellipsis,
        maxLines: 3,
      ),
    );
  }

  Widget _buildSummaryRow() {
    final total = _subjects.length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;

        return Table(
          border: TableBorder.all(color: Colors.grey.shade500, width: 0.8),
          columnWidths: const {
            0: FlexColumnWidth(2),
            1: FlexColumnWidth(2),
            2: FlexColumnWidth(2),
            3: FlexColumnWidth(2),
            4: FlexColumnWidth(2),
          },
          children: [
            TableRow(
              decoration: const BoxDecoration(color: Color(0xFFF5F5F5)),
              children: isMobile
                  ? [
                      _summaryCell('REG\n$total', Colors.black, isMobile),
                      _summaryCell('APP\n$total', Colors.black, isMobile),
                      _summaryCell(
                          'PASS\n$_passed', Colors.green.shade700, isMobile),
                      _summaryCell(
                          'TOT CR\n$_totalCredits', Colors.black, isMobile),
                      _summaryCell(
                          'CR PTS\n${_totalCreditPoints.toStringAsFixed(1)}',
                          Colors.black,
                          isMobile),
                    ]
                  : [
                      _summaryCell('SUBJECTS\nREGISTERED\n$total', Colors.black,
                          isMobile),
                      _summaryCell('APPEARED\n$total', Colors.black, isMobile),
                      _summaryCell(
                          'PASSED\n$_passed', Colors.green.shade700, isMobile),
                      _summaryCell('TOTAL\nCREDITS\n$_totalCredits',
                          Colors.black, isMobile),
                      _summaryCell(
                          'TOTAL CREDIT\nPOINTS\n${_totalCreditPoints.toStringAsFixed(3)}',
                          Colors.black,
                          isMobile),
                    ],
            ),
          ],
        );
      },
    );
  }

  Widget _summaryCell(String text, Color color, bool isMobile) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 4 : 8,
        vertical: isMobile ? 6 : 8,
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: isMobile ? 9 : 11,
          fontWeight: FontWeight.bold,
          color: color,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
