import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../widgets/app_header.dart';

// ── Per-subject aggregated stats ──────────────────────────────────────────────

class _SubjectStats {
  final String subjectCode;
  final String subjectName;
  int held = 0;
  int present = 0;

  _SubjectStats({required this.subjectCode, required this.subjectName});

  int get absent => held - present;
  double get percentage => held == 0 ? 0 : (present / held) * 100;
}

// ─────────────────────────────────────────────────────────────────────────────

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  DateTime? _fromDate;
  DateTime? _toDate;

  bool _loading = false;
  String? _error;
  bool _searched = false;

  List<_SubjectStats> _results = [];
  int _totalHeld = 0;
  int _totalPresent = 0;

  // ── Date picker helper ────────────────────────────────────────────────────

  Future<DateTime?> _pickDate(DateTime? initial) {
    return showDatePicker(
      context: context,
      initialDate: initial ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
  }

  // ── Fetch from Firestore ──────────────────────────────────────────────────

  Future<void> _fetchAttendance() async {
    if (_fromDate == null || _toDate == null) {
      setState(() => _error = 'Please select both From and To dates.');
      return;
    }
    if (_toDate!.isBefore(_fromDate!)) {
      setState(() => _error = 'To Date must be on or after From Date.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _results = [];
      _searched = false;
    });

    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('Not logged in');
      final rollNo = user.email!.split('@')[0].toUpperCase();

      // Include the full To Date day by querying < toDate + 1 day
      final from = Timestamp.fromDate(
          DateTime(_fromDate!.year, _fromDate!.month, _fromDate!.day));
      final to = Timestamp.fromDate(
          DateTime(_toDate!.year, _toDate!.month, _toDate!.day + 1));

      final snap = await _firestore
          .collection('attendance')
          .where('date', isGreaterThanOrEqualTo: from)
          .where('date', isLessThan: to)
          .get();

      // Group by subjectCode
      final Map<String, _SubjectStats> map = {};

      for (final doc in snap.docs) {
        final d = doc.data();
        final subjectCode = (d['subjectCode'] as String? ?? '').trim();
        final subjectName = (d['subjectName'] as String? ?? subjectCode).trim();
        final periods = List<int>.from(d['periods'] ?? []);
        if (periods.isEmpty) continue;

        // Find this student in the doc's students list
        final students = List<Map<String, dynamic>>.from(
          (d['students'] as List? ?? [])
              .map((e) => Map<String, dynamic>.from(e as Map)),
        );
        final studentRecord = students.cast<Map<String, dynamic>?>().firstWhere(
              (s) => (s!['rollNo'] as String? ?? '').toUpperCase() == rollNo,
              orElse: () => null,
            );
        if (studentRecord == null) continue; // student not in this doc

        final isPresent = studentRecord['present'] == true;
        final classCount = periods.length; // each period = 1 class

        map.putIfAbsent(
          subjectCode,
          () =>
              _SubjectStats(subjectCode: subjectCode, subjectName: subjectName),
        );
        map[subjectCode]!.held += classCount;
        if (isPresent) map[subjectCode]!.present += classCount;
      }

      final results = map.values.toList()
        ..sort((a, b) => a.subjectCode.compareTo(b.subjectCode));

      setState(() {
        _results = results;
        _totalHeld = results.fold(0, (s, e) => s + e.held);
        _totalPresent = results.fold(0, (s, e) => s + e.present);
        _loading = false;
        _searched = true;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
        _searched = true;
      });
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance Report'),
        backgroundColor: const Color(0xFF1e3a5f),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          const AppHeader(showBack: false),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(isMobile ? 12 : 20),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 900),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildDateRangeCard(isMobile),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.red[50],
                            border: Border.all(color: Colors.red[200]!),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(_error!,
                              style: TextStyle(color: Colors.red[700])),
                        ),
                      ],
                      if (_loading) ...[
                        const SizedBox(height: 40),
                        const Center(child: CircularProgressIndicator()),
                      ] else if (_searched) ...[
                        const SizedBox(height: 20),
                        _buildResults(isMobile),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Date range card ───────────────────────────────────────────────────────

  Widget _buildDateRangeCard(bool isMobile) {
    final fmt = DateFormat('dd/MM/yyyy');

    Widget dateField(String label, DateTime? date, VoidCallback onTap) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1e3a5f))),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[400]!),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    date != null ? fmt.format(date) : 'dd/mm/yyyy',
                    style: TextStyle(
                        fontSize: 13,
                        color: date != null ? Colors.black87 : Colors.grey),
                  ),
                  Icon(Icons.calendar_today, size: 18, color: Colors.grey[600]),
                ],
              ),
            ),
          ),
        ],
      );
    }

    final fromField = dateField('Select From Date', _fromDate, () async {
      final d = await _pickDate(_fromDate);
      if (d != null) setState(() => _fromDate = d);
    });

    final toField = dateField('Select To Date', _toDate, () async {
      final d = await _pickDate(_toDate ?? _fromDate);
      if (d != null) setState(() => _toDate = d);
    });

    final submitBtn = SizedBox(
      height: 46,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 28),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        ),
        onPressed: _loading ? null : _fetchAttendance,
        child: const Text('Submit',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
      ),
    );

    return Container(
      padding: EdgeInsets.all(isMobile ? 14 : 20),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                fromField,
                const SizedBox(height: 12),
                toField,
                const SizedBox(height: 16),
                submitBtn,
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(child: fromField),
                const SizedBox(width: 16),
                Expanded(child: toField),
                const SizedBox(width: 16),
                submitBtn,
              ],
            ),
    );
  }

  // ── Results ───────────────────────────────────────────────────────────────

  Widget _buildResults(bool isMobile) {
    if (_results.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Column(
            children: [
              Icon(Icons.info_outline, size: 48, color: Colors.grey[400]),
              const SizedBox(height: 10),
              Text(
                'No attendance records found for the selected date range.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600], fontSize: 15),
              ),
            ],
          ),
        ),
      );
    }

    final totalAbsent = _totalHeld - _totalPresent;
    final overallPct =
        _totalHeld == 0 ? 0.0 : (_totalPresent / _totalHeld) * 100;
    final fmt = DateFormat('dd MMM yyyy');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Date range header ──────────────────────────────────────────────
        Center(
          child: Text(
            '${fmt.format(_fromDate!)}  –  ${fmt.format(_toDate!)}',
            style: const TextStyle(
                fontSize: 13,
                color: Colors.black54,
                fontWeight: FontWeight.w500),
          ),
        ),
        const SizedBox(height: 14),

        // ── Overall summary row ────────────────────────────────────────────
        _buildSummaryRow(
            _totalHeld, _totalPresent, totalAbsent, overallPct, isMobile),
        const SizedBox(height: 20),

        // ── Subject-wise table ─────────────────────────────────────────────
        const Text(
          'Subject Wise Attendance',
          style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1e3a5f)),
        ),
        const SizedBox(height: 10),
        isMobile ? _buildMobileSubjectList() : _buildDesktopSubjectTable(),
      ],
    );
  }

  Widget _buildSummaryRow(
      int held, int present, int absent, double pct, bool isMobile) {
    Color pctColor;
    if (pct >= 75) {
      pctColor = Colors.green;
    } else if (pct >= 60) {
      pctColor = Colors.orange;
    } else {
      pctColor = Colors.red;
    }

    Widget tile(String label, String value, Color color, IconData icon) =>
        Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: color.withOpacity(0.08),
              border: Border.all(color: color.withOpacity(0.3)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Icon(icon, color: color, size: 26),
                const SizedBox(height: 6),
                Text(value,
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: color)),
                const SizedBox(height: 2),
                Text(label,
                    style: TextStyle(fontSize: 11, color: Colors.grey[700])),
              ],
            ),
          ),
        );

    return Row(children: [
      tile('Classes Held', '$held', const Color(0xFF1565C0), Icons.class_),
      tile('Present', '$present', Colors.green, Icons.check_circle_outline),
      tile('Absent', '$absent', Colors.red, Icons.cancel_outlined),
      tile('Overall', '${pct.toStringAsFixed(1)}%', pctColor,
          Icons.pie_chart_outline),
    ]);
  }

  // ── Desktop table ─────────────────────────────────────────────────────────

  Widget _buildDesktopSubjectTable() {
    const hStyle = TextStyle(
        fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white);

    Widget hc(String t, {double? w, bool exp = false}) {
      final c = Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Text(t, style: hStyle));
      return exp ? Expanded(child: c) : SizedBox(width: w ?? 80, child: c);
    }

    Widget dc(String t,
        {double? w, bool exp = false, Color? color, FontWeight? fw}) {
      final c = Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Text(t,
              style: TextStyle(
                  fontSize: 13,
                  color: color ?? Colors.black87,
                  fontWeight: fw)));
      return exp ? Expanded(child: c) : SizedBox(width: w ?? 80, child: c);
    }

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        children: [
          // Header
          Container(
            color: const Color(0xFF1e3a5f),
            child: Row(children: [
              hc('S.No', w: 52),
              hc('Course Code', w: 120),
              hc('Course Name', exp: true),
              hc('Held', w: 72),
              hc('Present', w: 80),
              hc('Absent', w: 72),
              hc('Percentage', w: 100),
            ]),
          ),
          // Rows
          ...List.generate(_results.length, (i) {
            final s = _results[i];
            final pct = s.percentage;
            final pctColor = pct >= 75
                ? Colors.green[700]!
                : pct >= 60
                    ? Colors.orange[800]!
                    : Colors.red[700]!;
            return Container(
              color: i % 2 == 0 ? Colors.white : const Color(0xFFF5F8FF),
              child: Row(children: [
                dc('${i + 1}', w: 52),
                dc(s.subjectCode, w: 120),
                dc(s.subjectName, exp: true),
                dc('${s.held}', w: 72),
                dc('${s.present}', w: 80, color: Colors.green[700]),
                dc('${s.absent}', w: 72, color: Colors.red[700]),
                SizedBox(
                  width: 100,
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: pctColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: pctColor.withOpacity(0.4)),
                      ),
                      child: Text(
                        '${pct.toStringAsFixed(1)}%',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: pctColor),
                      ),
                    ),
                  ),
                ),
              ]),
            );
          }),
        ],
      ),
    );
  }

  // ── Mobile list ────────────────────────────────────────────────────────────

  Widget _buildMobileSubjectList() {
    return Column(
      children: List.generate(_results.length, (i) {
        final s = _results[i];
        final pct = s.percentage;
        final pctColor = pct >= 75
            ? Colors.green[700]!
            : pct >= 60
                ? Colors.orange[800]!
                : Colors.red[700]!;

        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          elevation: 1,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(s.subjectName,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 14)),
                          const SizedBox(height: 2),
                          Text(s.subjectCode,
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey[600])),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: pctColor.withOpacity(0.12),
                        border: Border.all(color: pctColor.withOpacity(0.4)),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${pct.toStringAsFixed(1)}%',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: pctColor),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Progress bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: s.held == 0 ? 0 : s.present / s.held,
                    minHeight: 6,
                    backgroundColor: Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation<Color>(pctColor),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _mobileStat('Held', '${s.held}', const Color(0xFF1565C0)),
                    _mobileStat('Present', '${s.present}', Colors.green[700]!),
                    _mobileStat('Absent', '${s.absent}', Colors.red[700]!),
                  ],
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _mobileStat(String label, String value, Color color) => Column(
        children: [
          Text(value,
              style: TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 16, color: color)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
        ],
      );
}
