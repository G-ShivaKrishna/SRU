import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

/// Generates and prints a Supply Exam Memo PDF
Future<void> printSupplyExamMemo({
  required String studentName,
  required String fatherName,
  required String enrolmentNumber,
  required String branch,
  required String examSession,
  required String memoNumber,
  required List<Map<String, dynamic>> subjects,
  required double sgpa,
  required int totalCredits,
  required double totalCreditPoints,
  required int passed,
}) async {
  final pdf = pw.Document();

  pdf.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(20),
      build: (context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            // University Header
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Container(
                  width: 50,
                  height: 50,
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey500),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                  ),
                  alignment: pw.Alignment.center,
                  child: pw.Text(
                    'SRU',
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blue900,
                    ),
                  ),
                ),
                pw.SizedBox(width: 16),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'SR UNIVERSITY',
                        style: pw.TextStyle(
                          fontSize: 24,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blue900,
                          letterSpacing: 1.5,
                        ),
                      ),
                      pw.Text(
                        'Hanmakonda - 506 371, Telangana State, INDIA',
                        style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 6),
            pw.Divider(color: PdfColors.grey400, thickness: 1),
            pw.SizedBox(height: 12),

            // Title Box
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.black, width: 1),
              ),
              child: pw.Text(
                'MEMORANDUM OF SUPPLEMENTARY EXAMINATION MARKS',
                style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                  fontStyle: pw.FontStyle.italic,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            pw.SizedBox(height: 14),

            // Details Grid
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  flex: 2,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      _detailRowPdf('Memo No.', memoNumber),
                      _detailRowPdf('Serial No.', enrolmentNumber),
                      _detailRowPdf('Examination', 'SUPPLEMENTARY EXAMINATION'),
                      _detailRowPdf('Branch', branch),
                      _detailRowPdf('Name', studentName),
                      _detailRowPdf('Father\'s Name', fatherName),
                    ],
                  ),
                ),
                pw.SizedBox(width: 16),
                pw.Expanded(
                  flex: 1,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      _detailRowPdf('Enrolment Number', enrolmentNumber),
                      _detailRowPdf('Exam Session', examSession),
                    ],
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 14),

            // Marks Table
            _buildMarksTablePdf(subjects),
            pw.SizedBox(height: 8),

            // Summary Row
            _buildSummaryRowPdf(subjects.length, passed, totalCredits, totalCreditPoints),
            pw.SizedBox(height: 8),

            // SGPA Bar
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: pw.BoxDecoration(
                color: PdfColors.blue900,
                border: pw.Border.all(color: PdfColors.grey500, width: 0.5),
              ),
              child: pw.Text(
                'SEMESTER GRADE POINT AVERAGE (SGPA): ${sgpa.toStringAsFixed(3)}',
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                  letterSpacing: 0.4,
                ),
              ),
            ),
            pw.SizedBox(height: 12),

            // Watermark Note
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                border: pw.Border.all(color: PdfColors.grey400),
              ),
              child: pw.Text(
                'This is a computer-generated supplementary examination marks memorandum. '
                'It is valid as a record of supplementary examination marks for the stated exam session.',
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                textAlign: pw.TextAlign.center,
              ),
            ),
          ],
        );
      },
    ),
  );

  await Printing.layoutPdf(
    onLayout: (_) => pdf.save(),
    name: 'Supply_Exam_Memo_$enrolmentNumber',
  );
}

/// Generates and prints a Semester CIE Memo PDF
Future<void> printSemesterMemo({
  required String studentName,
  required String fatherName,
  required String enrolmentNumber,
  required String branch,
  required String semester,
  required String academicYear,
  required List<Map<String, dynamic>> subjects,
  required double sgpa,
  required int totalCredits,
  required double totalCreditPoints,
  required int appeared,
  required int passed,
}) async {
  final pdf = pw.Document();

  pdf.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(20),
      build: (context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            // University Header
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Container(
                  width: 50,
                  height: 50,
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey500),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                  ),
                  alignment: pw.Alignment.center,
                  child: pw.Text(
                    'SRU',
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blue900,
                    ),
                  ),
                ),
                pw.SizedBox(width: 16),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'SR UNIVERSITY',
                        style: pw.TextStyle(
                          fontSize: 24,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blue900,
                          letterSpacing: 1.5,
                        ),
                      ),
                      pw.Text(
                        'Hanmakonda - 506 371, Telangana State, INDIA',
                        style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 6),
            pw.Divider(color: PdfColors.grey400, thickness: 1),
            pw.SizedBox(height: 12),

            // Title Box
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.black, width: 1),
              ),
              child: pw.Text(
                'SEMESTER EXAMINATION MARKS MEMORANDUM',
                style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                  fontStyle: pw.FontStyle.italic,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            pw.SizedBox(height: 14),

            // Details Grid
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  flex: 2,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      _detailRowPdf('Exam Session', 'Odd/Even'),
                      _detailRowPdf('Year', 'Year'),
                      _detailRowPdf('Semester', semester),
                      _detailRowPdf('Branch', branch),
                      _detailRowPdf('Name', studentName),
                      _detailRowPdf('Father\'s Name', fatherName),
                    ],
                  ),
                ),
                pw.SizedBox(width: 16),
                pw.Expanded(
                  flex: 1,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      _detailRowPdf('Roll No.', enrolmentNumber),
                      _detailRowPdf('Academic Year', academicYear),
                    ],
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 14),

            // Marks Table
            _buildMarksTablePdf(subjects),
            pw.SizedBox(height: 8),

            // Summary Row
            _buildSummaryRowPdf(subjects.length, passed, totalCredits, totalCreditPoints),
            pw.SizedBox(height: 8),

            // SGPA Bar
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: pw.BoxDecoration(
                color: PdfColors.blue900,
                border: pw.Border.all(color: PdfColors.grey500, width: 0.5),
              ),
              child: pw.Text(
                'SEMESTER GRADE POINT AVERAGE (SGPA): ${sgpa.toStringAsFixed(3)}',
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                  letterSpacing: 0.4,
                ),
              ),
            ),
            pw.SizedBox(height: 12),

            // Watermark Note
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                border: pw.Border.all(color: PdfColors.grey400),
              ),
              child: pw.Text(
                'This is a computer-generated semester examination marks memorandum. '
                'It is valid as a record of semester examination marks for the stated academic year.',
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                textAlign: pw.TextAlign.center,
              ),
            ),
          ],
        );
      },
    ),
  );

  await Printing.layoutPdf(
    onLayout: (_) => pdf.save(),
    name: 'Semester_Memo_$enrolmentNumber',
  );
}

pw.Widget _detailRowPdf(String label, String value) {
  return pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 4),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          flex: 1,
          child: pw.Text(
            '$label:',
            style: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ),
        pw.Expanded(
          flex: 2,
          child: pw.Text(
            value,
            style: const pw.TextStyle(fontSize: 9),
          ),
        ),
      ],
    ),
  );
}

pw.Widget _buildMarksTablePdf(List<Map<String, dynamic>> subjects) {
  if (subjects.isEmpty) {
    return pw.Text('No marks available.');
  }

  return pw.Table(
    border: pw.TableBorder.all(color: PdfColors.grey500, width: 0.5),
    children: [
      // Header Row
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: PdfColors.blue900),
        children: [
          _tableCellPdf('S.NO', pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 8)),
          _tableCellPdf('CODE', pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 8)),
          _tableCellPdf('SUBJECT', pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 8)),
          _tableCellPdf('INT', pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 8)),
          _tableCellPdf('EXT', pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 8)),
          _tableCellPdf('TOT', pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 8)),
          _tableCellPdf('GR', pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 8)),
          _tableCellPdf('STATUS', pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 8)),
        ],
      ),
      // Data Rows
      ...subjects.asMap().entries.map((e) {
        final idx = e.key;
        final s = e.value;
        final passed = s['result'] == 'PASS';
        return pw.TableRow(
          children: [
            _tableCellPdf('${idx + 1}', const pw.TextStyle(fontSize: 8)),
            _tableCellPdf(s['subjectCode'] ?? '—', const pw.TextStyle(fontSize: 8)),
            _tableCellPdf(s['subjectName'] ?? '—', const pw.TextStyle(fontSize: 8)),
            _tableCellPdf('${s['internalMarks'] ?? '—'}', const pw.TextStyle(fontSize: 8)),
            _tableCellPdf('${s['externalMarks'] ?? '—'}', const pw.TextStyle(fontSize: 8)),
            _tableCellPdf('${s['totalMarks'] ?? '—'}', pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
            _tableCellPdf(s['grade'] ?? '—', pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
            _tableCellPdf(
              passed ? 'PASS' : 'FAIL',
              pw.TextStyle(
                fontSize: 8,
                fontWeight: pw.FontWeight.bold,
                color: passed ? PdfColors.green700 : PdfColors.red700,
              ),
            ),
          ],
        );
      }),
    ],
  );
}

pw.Widget _buildSummaryRowPdf(int total, int passed, int totalCredits, double totalCreditPoints) {
  return pw.Table(
    border: pw.TableBorder.all(color: PdfColors.grey500, width: 0.5),
    children: [
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: PdfColors.grey100),
        children: [
          _tableCellPdf('REG\n$total', pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
          _tableCellPdf('APP\n$total', pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
          _tableCellPdf('PASS\n$passed', pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.green700)),
          _tableCellPdf('TOT CR\n$totalCredits', pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
          _tableCellPdf('CR PTS\n${totalCreditPoints.toStringAsFixed(1)}', pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
        ],
      ),
    ],
  );
}

pw.Widget _tableCellPdf(String text, pw.TextStyle style) {
  return pw.Padding(
    padding: const pw.EdgeInsets.all(4),
    child: pw.Text(
      text,
      style: style,
      textAlign: pw.TextAlign.center,
    ),
  );
}
