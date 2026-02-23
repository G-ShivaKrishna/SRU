import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../widgets/app_header.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Small model for a released memo
// ─────────────────────────────────────────────────────────────────────────────

class _ReleasedMemo {
  final String id;
  final String year;
  final String semester;
  final String branch;
  final String academicYear;
  final String examSession;
  final DateTime releasedAt;
  final int minPassMarks;

  const _ReleasedMemo({
    required this.id,
    required this.year,
    required this.semester,
    required this.branch,
    required this.academicYear,
    required this.examSession,
    required this.releasedAt,
    this.minPassMarks = 40,
  });

  factory _ReleasedMemo.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return _ReleasedMemo(
      id: doc.id,
      year: (d['year'] ?? '').toString(),
      semester: (d['semester'] ?? '').toString(),
      branch: (d['branch'] ?? 'ALL').toString(),
      academicYear: (d['academicYear'] ?? '').toString(),
      examSession: (d['examSession'] ?? '').toString(),
      releasedAt: (d['releasedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      minPassMarks: (d['minPassMarks'] is int)
          ? d['minPassMarks'] as int
          : int.tryParse(d['minPassMarks']?.toString() ?? '') ?? 40,
    );
  }
}

// Model for one subject's semester marks
class _SubjectEntry {
  final String subjectCode;
  final String subjectName;
  final int cieTotal;
  final int eteTotal;
  final int maxMarks;
  // Credit hours — default 3 (stored in marksDefinition as 'credits' if available)
  // Stored as nullable so old/hot-reloaded instances with null survive gracefully.
  final int? _credits;
  int get credits => _credits ?? 3;

  const _SubjectEntry({
    required this.subjectCode,
    required this.subjectName,
    required this.cieTotal,
    required this.eteTotal,
    required this.maxMarks,
    int? credits,
  }) : _credits = credits;

  int get grandTotal => cieTotal + eteTotal;

  /// Percentage based on grandTotal / maxMarks
  double get percentage => maxMarks > 0 ? (grandTotal / maxMarks) * 100 : 0;

  String get letterGrade {
    final p = percentage;
    if (p >= 90) return 'O';
    if (p >= 80) return 'A';
    if (p >= 70) return 'B';
    if (p >= 60) return 'C';
    if (p >= 50) return 'D';
    if (p >= 40) return 'E';
    return 'F';
  }

  int get gradePoint {
    final p = percentage;
    if (p >= 90) return 10;
    if (p >= 80) return 9;
    if (p >= 70) return 8;
    if (p >= 60) return 7;
    if (p >= 50) return 6;
    if (p >= 40) return 5;
    return 0;
  }

  /// Credit Points = grade point × credit hours
  double get creditPoints => gradePoint * credits.toDouble();

  bool isPassedFor(int minMarks) => grandTotal >= minMarks;

  static bool _isEte(String name) {
    final l = name.toLowerCase();
    return l.contains('end term') ||
        l.contains('ete') ||
        l.contains('end-term') ||
        l.contains('external');
  }

  static _SubjectEntry fromMarksDoc(Map<String, dynamic> d) {
    final rawMarks = d['componentMarks'] as Map<String, dynamic>? ?? {};
    int cieSum = 0;
    int eteSum = 0;
    for (final e in rawMarks.entries) {
      final v = e.value;
      final intVal = (v is int) ? v : int.tryParse(v.toString()) ?? 0;
      if (_isEte(e.key)) {
        eteSum += intVal;
      } else {
        cieSum += intVal;
      }
    }
    final maxAll = (d['maxMarks'] is int)
        ? d['maxMarks'] as int
        : int.tryParse(d['maxMarks']?.toString() ?? '') ?? 0;
    // credits may be missing (null) or stored as double — safe parse with fallback
    final rawCr = d['credits'];
    final int? cr = (rawCr is int)
        ? rawCr
        : (rawCr is num)
            ? rawCr.floor()
            : int.tryParse(rawCr?.toString() ?? '');

    return _SubjectEntry(
      subjectCode: (d['subjectCode'] ?? '').toString(),
      subjectName: (d['subjectName'] ?? '').toString(),
      cieTotal: cieSum,
      eteTotal: eteSum,
      maxMarks: maxAll,
      credits: cr, // null → defaults to 3 via getter
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Main list screen
// ─────────────────────────────────────────────────────────────────────────────

class StudentCieMemoScreen extends StatefulWidget {
  const StudentCieMemoScreen({super.key});

  @override
  State<StudentCieMemoScreen> createState() => _StudentCieMemoScreenState();
}

class _StudentCieMemoScreenState extends State<StudentCieMemoScreen> {
  final _auth = FirebaseAuth.instance;
  final _fs = FirebaseFirestore.instance;

  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _studentData;
  List<_ReleasedMemo> _releasedMemos = [];

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

      // Load active releases
      final releasesSnap = await _fs
          .collection('cieMemoReleases')
          .where('isActive', isEqualTo: true)
          .get();

      final studentBranch =
          (sData['department'] ?? '').toString().toUpperCase();

      final memos =
          releasesSnap.docs.map((d) => _ReleasedMemo.fromDoc(d)).where((m) {
        final branchMatch =
            m.branch == 'ALL' || m.branch.toUpperCase() == studentBranch;
        return branchMatch;
      }).toList()
            ..sort((a, b) {
              final yCmp = int.tryParse(b.year) ?? 0;
              final yA = int.tryParse(a.year) ?? 0;
              if (yCmp != yA) return yCmp.compareTo(yA);
              return (int.tryParse(b.semester) ?? 0)
                  .compareTo(int.tryParse(a.semester) ?? 0);
            });

      if (!mounted) return;
      setState(() {
        _studentData = sData;
        _releasedMemos = memos;
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
                  'Semester Memos',
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
                  'Memos are released by the Admin once per semester. You will see them here as soon as they are released.',
                  style: TextStyle(fontSize: 12, color: Colors.blue.shade800),
                ),
              ),
              if (_releasedMemos.isEmpty)
                _buildEmptyState()
              else
                ..._releasedMemos.map((memo) => _buildMemoCard(memo, isMobile)),
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
            'No semester memos released yet.\nMemos will appear here once the Admin releases them.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildMemoCard(_ReleasedMemo memo, bool isMobile) {
    final yearLabel = _yearToRoman(memo.year);
    final semLabel = _semToRoman(memo.semester);
    final studentBranch =
        (_studentData?['department'] ?? '').toString().toUpperCase();
    final program =
        (_studentData?['program'] ?? 'BTECH').toString().toUpperCase();

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
            // Left: icon + badge
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
                    '$yearLabel $program $studentBranch $semLabel SEMESTER',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${memo.academicYear}  •  ${memo.examSession}',
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
                      'Released on ${_fmtDate(memo.releasedAt)}',
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
              onPressed: () => _openMemo(memo),
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

  void _openMemo(_ReleasedMemo memo) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => _MemoViewScreen(
        memo: memo,
        studentData: _studentData ?? {},
        rollNumber: _studentData?['rollNumber'] ?? '',
      ),
    ));
  }

  String _yearToRoman(String y) {
    const m = {'1': 'I', '2': 'II', '3': 'III', '4': 'IV'};
    return m[y] ?? y;
  }

  String _semToRoman(String s) {
    const m = {'1': 'I', '2': 'II'};
    return m[s] ?? s;
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
// Memo view screen — styled like the university memorandum
// ─────────────────────────────────────────────────────────────────────────────

class _MemoViewScreen extends StatefulWidget {
  final _ReleasedMemo memo;
  final Map<String, dynamic> studentData;
  final String rollNumber;

  const _MemoViewScreen({
    required this.memo,
    required this.studentData,
    required this.rollNumber,
  });

  @override
  State<_MemoViewScreen> createState() => _MemoViewScreenState();
}

class _MemoViewScreenState extends State<_MemoViewScreen> {
  final _fs = FirebaseFirestore.instance;

  bool _loading = true;
  List<_SubjectEntry> _subjects = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadMarks();
  }

  /// Normalise semester to a numeric string: 'I'→'1', 'II'→'2', etc.
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
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // Single .where() only — multiple clauses require a composite Firestore
      // index which may not exist. Filter year + semester in Dart instead.
      final snap = await _fs
          .collection('studentMarks')
          .where('studentId', isEqualTo: widget.rollNumber)
          .get();

      final memoYearInt = int.tryParse(widget.memo.year);
      // memo semester normalised ('1' or '2')
      final memoSemNorm = _normSem(widget.memo.semester);

      final entries = snap.docs
          .where((doc) {
            final d = doc.data();
            // match year (stored as int or string)
            final docYear = d['year'];
            final yearMatch = memoYearInt != null
                ? (docYear == memoYearInt ||
                    docYear?.toString() == widget.memo.year)
                : docYear?.toString() == widget.memo.year;
            // match semester — faculty stores 'I'/'II', admin stores '1'/'2'
            final semMatch =
                _normSem(d['semester']?.toString() ?? '') == memoSemNorm;
            return yearMatch && semMatch;
          })
          .map((doc) => _SubjectEntry.fromMarksDoc(doc.data()))
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

  String get _yearRoman {
    const m = {'1': 'I', '2': 'II', '3': 'III', '4': 'IV'};
    return m[widget.memo.year] ?? widget.memo.year;
  }

  String get _semRoman {
    const m = {'1': 'I', '2': 'II'};
    return m[widget.memo.semester] ?? widget.memo.semester;
  }

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
  String get _program =>
      (widget.studentData['program'] ?? 'BTECH').toString().toUpperCase();

  String get _examTitle => '$_yearRoman $_program $_branch $_semRoman SEMESTER';

  String get _memoNumber =>
      'SEM-${widget.memo.year}-${widget.memo.semester}-${widget.rollNumber}';

  String get _serialNumber => 'SRU-${widget.rollNumber}';

  int get _totalCredits => _subjects.fold<int>(0, (s, e) => s + e.credits);
  double get _totalCreditPoints =>
      _subjects.fold<double>(0, (s, e) => s + e.creditPoints);
  int get _passed =>
      _subjects.where((e) => e.isPassedFor(widget.memo.minPassMarks)).length;

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
        title: const Text('Semester Marks Memo'),
        backgroundColor: const Color(0xFF1e3a5f),
        foregroundColor: Colors.white,
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

  Widget _buildMemoDocument() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ── University header ─────────────────────────────────────────────
          _buildUniversityHeader(),
          const SizedBox(height: 12),

          // ── Title box ─────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 7),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.black, width: 1.2),
            ),
            child: const Text(
              'MEMORANDUM OF SEMESTER MARKS',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                fontStyle: FontStyle.italic,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ── Details grid ──────────────────────────────────────────────────
          _buildDetailsGrid(),
          const SizedBox(height: 16),

          // ── Marks table ───────────────────────────────────────────────────
          _buildMarksTable(),
          const SizedBox(height: 8),

          // ── Bottom summary row ────────────────────────────────────────────
          _buildSummaryRow(),

          // ── SGPA bar ──────────────────────────────────────────────────────
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

          // ── Watermark note ────────────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              border: Border.all(color: Colors.grey.shade400),
            ),
            child: const Text(
              'This is a computer-generated semester marks memorandum. '
              'It is valid as a record of semester marks for the stated exam session.',
              style: TextStyle(fontSize: 10, color: Colors.black54),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  // ── University header ──────────────────────────────────────────────────────

  Widget _buildUniversityHeader() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Logo placeholder
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
            Column(
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
                ),
                Text(
                  'Hanmakonda - 506 371, Telangana State, INDIA',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 6),
        Divider(color: Colors.grey.shade400, thickness: 1),
      ],
    );
  }

  // ── Details grid ──────────────────────────────────────────────────────────

  Widget _buildDetailsGrid() {
    final leftDetails = [
      ['Memo No.', _memoNumber],
      ['Serial No.', _serialNumber],
      ['Examination', _examTitle],
      ['Branch', _branch],
      ['Name', _studentName],
      ['Father\'s Name', _fatherName],
    ];
    final rightDetails = [
      ['Enrolment Number', _enrolmentNumber],
      ['Academic Year', widget.memo.academicYear],
      ['Exam Session', widget.memo.examSession],
    ];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left column
        Expanded(
          child: Column(
            children: leftDetails.map((item) {
              return _detailRow(item[0], item[1]);
            }).toList(),
          ),
        ),
        const SizedBox(width: 16),
        // Right column
        SizedBox(
          width: 220,
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
  }

  Widget _detailRow(String label, String value, {TextStyle? valueStyle}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ),
          const Text(': ',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
          Expanded(
            child: Text(
              value,
              style: valueStyle ??
                  const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1e3a5f)),
            ),
          ),
        ],
      ),
    );
  }

  // ── Marks table ────────────────────────────────────────────────────────────

  Widget _buildMarksTable() {
    if (_subjects.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.black),
        ),
        child: const Text(
          'No marks available for this semester.',
          textAlign: TextAlign.center,
          style: TextStyle(fontStyle: FontStyle.italic, color: Colors.black54),
        ),
      );
    }

    // Table header style
    const headerDecoration = BoxDecoration(
      color: Color(0xFF1e3a5f),
    );
    const headerText = TextStyle(
      color: Colors.white,
      fontWeight: FontWeight.bold,
      fontSize: 12,
    );
    const cellText = TextStyle(fontSize: 12);
    const rowPad = EdgeInsets.symmetric(horizontal: 8, vertical: 6);

    return Table(
      border: TableBorder.all(color: Colors.grey.shade500, width: 0.8),
      columnWidths: const {
        0: FixedColumnWidth(36),
        1: FixedColumnWidth(90),
        2: FlexColumnWidth(3),
        3: FixedColumnWidth(60),
        4: FixedColumnWidth(70),
        5: FixedColumnWidth(75),
        6: FixedColumnWidth(60),
      },
      children: [
        // ── Header ──────────────────────────────────────────────────────────
        TableRow(
          decoration: headerDecoration,
          children: [
            _cell('S.NO', headerText, rowPad),
            _cell('COURSE\nCODE', headerText, rowPad),
            _cell('COURSE TITLE', headerText, rowPad),
            _cell('LETTER\nGRADE', headerText, rowPad, align: TextAlign.center),
            _cell('COURSE\nCREDITS', headerText, rowPad,
                align: TextAlign.center),
            _cell('CREDIT\nPOINTS', headerText, rowPad,
                align: TextAlign.center),
            _cell('STATUS', headerText, rowPad, align: TextAlign.center),
          ],
        ),
        // ── Data rows ───────────────────────────────────────────────────────
        ..._subjects.asMap().entries.map((e) {
          final idx = e.key;
          final s = e.value;
          final isEven = idx % 2 == 0;
          final passed = s.isPassedFor(widget.memo.minPassMarks);
          return TableRow(
            decoration: BoxDecoration(
              color: isEven ? Colors.white : Colors.grey.shade50,
            ),
            children: [
              _cell('${idx + 1}', cellText, rowPad, align: TextAlign.center),
              _cell(s.subjectCode, cellText, rowPad),
              _cell(s.subjectName, cellText, rowPad),
              _cell(
                s.letterGrade,
                cellText.copyWith(
                  fontWeight: FontWeight.bold,
                  color: s.gradePoint >= 7
                      ? Colors.blue.shade700
                      : s.gradePoint >= 5
                          ? Colors.orange.shade700
                          : Colors.red.shade700,
                ),
                rowPad,
                align: TextAlign.center,
              ),
              _cell(
                '${s.credits}',
                cellText,
                rowPad,
                align: TextAlign.center,
              ),
              _cell(
                s.creditPoints.toStringAsFixed(3),
                cellText.copyWith(fontWeight: FontWeight.bold),
                rowPad,
                align: TextAlign.center,
              ),
              _cell(
                passed ? 'PASS' : 'FAIL',
                cellText.copyWith(
                  color: passed ? Colors.green.shade700 : Colors.red.shade700,
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
  }

  Widget _cell(String text, TextStyle style, EdgeInsets padding,
      {TextAlign align = TextAlign.left}) {
    return Padding(
      padding: padding,
      child: Text(text, style: style, textAlign: align),
    );
  }

  // ── Summary row ────────────────────────────────────────────────────────────

  Widget _buildSummaryRow() {
    final total = _subjects.length;
    final passed = _passed;

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
          children: [
            _summaryCell('SUBJECTS\nREGISTERED\n$total', Colors.black),
            _summaryCell('APPEARED\n$total', Colors.black),
            _summaryCell('PASSED\n$passed', Colors.green.shade700),
            _summaryCell('TOTAL\nCREDITS\n$_totalCredits', Colors.black),
            _summaryCell(
                'TOTAL CREDIT\nPOINTS\n${_totalCreditPoints.toStringAsFixed(3)}',
                Colors.black),
          ],
        ),
      ],
    );
  }

  Widget _summaryCell(String text, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Text(
        text,
        style:
            TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
        textAlign: TextAlign.center,
      ),
    );
  }
}
