import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../utils/memo_pdf_generator.dart';

class SupplyExamMemoScreen extends StatefulWidget {
  const SupplyExamMemoScreen({
    super.key,
    required this.rollNo,
    required this.examSession,
    required this.subjects,
  });

  final String rollNo;
  final String examSession;
  final List<Map<String, dynamic>> subjects;

  @override
  State<SupplyExamMemoScreen> createState() => _SupplyExamMemoScreenState();
}

class _SupplyExamMemoScreenState extends State<SupplyExamMemoScreen> {
  bool _loading = true;
  String? _error;
  String _studentName = '';
  String _fatherName = '';
  String _enrolmentNumber = '';
  String _branch = '';
  String _memoNumber = '';
  String _serialNumber = '';
  int _totalCredits = 0;
  double _totalCreditPoints = 0.0;
  double _sgpa = 0.0;
  int _passed = 0;

  @override
  void initState() {
    super.initState();
    _loadStudentData();
  }

  Future<void> _loadStudentData() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('students')
          .doc(widget.rollNo)
          .get();

      if (!doc.exists) {
        setState(() {
          _error = 'Student record not found';
          _loading = false;
        });
        return;
      }

      final data = doc.data()!;
      setState(() {
        _studentName = data['name'] ?? '';
        _fatherName = data['fatherName'] ?? 'N/A';
        _enrolmentNumber = widget.rollNo;
        _branch = data['department']?.toString().toUpperCase() ?? 'CSE';
        _memoNumber = 'SEM-${widget.rollNo}-SUPPLY-${widget.examSession}';
        _serialNumber = widget.rollNo;
        
        // Calculate totals
        _passed = widget.subjects.where((s) => s['result'] == 'PASS').length;
        _totalCredits = widget.subjects.fold(0, (sum, s) => sum + (int.tryParse(s['credits']?.toString() ?? '0') ?? 0));
        
        // For supply, calculate simple average based on grade points
        int gradeSum = 0;
        int gradeCount = 0;
        for (var s in widget.subjects) {
          final grade = s['grade']?.toString() ?? '';
          final gp = _gradeToPoint(grade);
          if (gp > 0) {
            gradeSum += gp;
            gradeCount++;
          }
        }
        _sgpa = gradeCount > 0 ? gradeSum / gradeCount : 0.0;
        _totalCreditPoints = _sgpa * _totalCredits;
        
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  int _gradeToPoint(String grade) {
    switch (grade.toUpperCase()) {
      case 'O': return 10;
      case 'A+': return 9;
      case 'A': return 8;
      case 'B+': return 7;
      case 'B': return 6;
      case 'C': return 5;
      case 'P': return 4;
      default: return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F0F0),
      appBar: AppBar(
        title: const Text('Supply Exam Marks Memo'),
        backgroundColor: const Color(0xFF1e3a5f),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.print),
            onPressed: () async {
              try {
                await printSupplyExamMemo(
                  studentName: _studentName,
                  fatherName: _fatherName,
                  enrolmentNumber: _enrolmentNumber,
                  branch: _branch,
                  examSession: widget.examSession,
                  memoNumber: _memoNumber,
                  subjects: widget.subjects,
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
            },
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
                      Text('Failed to load data:\n$_error',
                          textAlign: TextAlign.center),
                      const SizedBox(height: 20),
                      ElevatedButton(
                          onPressed: _loadStudentData,
                          child: const Text('Retry')),
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
      ['Exam Session', widget.examSession],
    ];

    return LayoutBuilder(builder: (context, constraints) {
      final isNarrow = constraints.maxWidth < 480;
      if (isNarrow) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ...leftDetails.map((d) => _detailRow(d[0], d[1])),
            ...rightDetails.map((d) => _detailRow(d[0], d[1])),
          ],
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: leftDetails.map((d) => _detailRow(d[0], d[1])).toList(),
            ),
          ),
          const SizedBox(width: 20),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 280),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children:
                  rightDetails.map((d) => _detailRow(d[0], d[1])).toList(),
            ),
          ),
        ],
      );
    });
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              '$label:',
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600, height: 1.3),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: const TextStyle(fontSize: 12, height: 1.3),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMarksTable() {
    if (widget.subjects.isEmpty) {
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
                    _cell('SUBJECT', headerText, rowPad),
                    _cell('INT', headerText, rowPad, align: TextAlign.center),
                    _cell('EXT', headerText, rowPad, align: TextAlign.center),
                    _cell('TOT', headerText, rowPad, align: TextAlign.center),
                    _cell('GR', headerText, rowPad, align: TextAlign.center),
                    _cell('STATUS', headerText, rowPad, align: TextAlign.center),
                  ]
                : [
                    _cell('S.NO', headerText, rowPad),
                    _cell('COURSE\nCODE', headerText, rowPad),
                    _cell('COURSE TITLE', headerText, rowPad),
                    _cell('INTERNAL', headerText, rowPad, align: TextAlign.center),
                    _cell('EXTERNAL', headerText, rowPad, align: TextAlign.center),
                    _cell('TOTAL', headerText, rowPad, align: TextAlign.center),
                    _cell('GRADE', headerText, rowPad, align: TextAlign.center),
                    _cell('STATUS', headerText, rowPad, align: TextAlign.center),
                  ],
            ),
            ...widget.subjects.asMap().entries.map((e) {
              final idx = e.key;
              final s = e.value;
              final isEven = idx % 2 == 0;
              final passed = s['result'] == 'PASS';
              
              return TableRow(
                decoration: BoxDecoration(
                  color: isEven ? Colors.white : Colors.grey.shade50,
                ),
                children: [
                  _cell('${idx + 1}', cellText, rowPad, align: TextAlign.center),
                  _cell(s['subjectCode'] ?? '', cellText, rowPad),
                  _cell(s['subjectName'] ?? '', cellText, rowPad),
                  _cell('${s['internalMarks'] ?? '-'}', cellText, rowPad, align: TextAlign.center),
                  _cell('${s['externalMarks'] ?? '-'}', cellText, rowPad, align: TextAlign.center),
                  _cell(
                    '${s['totalMarks'] ?? '-'}',
                    cellText.copyWith(fontWeight: FontWeight.bold),
                    rowPad,
                    align: TextAlign.center,
                  ),
                  _cell(
                    s['grade'] ?? '-',
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
    final total = widget.subjects.length;

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
                    _summaryCell('PASS\n$_passed', Colors.green.shade700, isMobile),
                    _summaryCell('TOT CR\n$_totalCredits', Colors.black, isMobile),
                    _summaryCell('CR PTS\n${_totalCreditPoints.toStringAsFixed(1)}', Colors.black, isMobile),
                  ]
                : [
                    _summaryCell('SUBJECTS\nREGISTERED\n$total', Colors.black, isMobile),
                    _summaryCell('APPEARED\n$total', Colors.black, isMobile),
                    _summaryCell('PASSED\n$_passed', Colors.green.shade700, isMobile),
                    _summaryCell('TOTAL\nCREDITS\n$_totalCredits', Colors.black, isMobile),
                    _summaryCell('TOTAL CREDIT\nPOINTS\n${_totalCreditPoints.toStringAsFixed(3)}', Colors.black, isMobile),
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
