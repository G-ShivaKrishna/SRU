import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

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
  final document = _buildMemoPdf(
    title: 'MEMORANDUM OF SUPPLEMENTARY EXAMINATION MARKS',
    leftDetails: [
      ['Memo No.', memoNumber],
      ['Serial No.', enrolmentNumber],
      ['Examination', 'SUPPLEMENTARY EXAMINATION'],
      ['Branch', branch],
      ['Name', studentName],
      ['Father\'s Name', fatherName],
    ],
    rightDetails: [
      ['Enrolment Number', enrolmentNumber],
      ['Exam Session', examSession],
    ],
    subjects: subjects,
    sgpa: sgpa,
    totalCredits: totalCredits,
    totalCreditPoints: totalCreditPoints,
    passed: passed,
    note:
        'This is a computer-generated supplementary examination marks memorandum. '
        'It is valid as a record of supplementary examination marks for the stated exam session.',
  );

  final bytes = await document.save();
  try {
    await Printing.layoutPdf(
      onLayout: (_) async => bytes,
      name: 'Supply_Exam_Memo_$enrolmentNumber',
    );
  } catch (_) {
    await Printing.sharePdf(
      bytes: bytes,
      filename: 'Supply_Exam_Memo_$enrolmentNumber.pdf',
    );
  }
}

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
  final document = _buildMemoPdf(
    title: 'SEMESTER EXAMINATION MARKS MEMORANDUM',
    leftDetails: [
      ['Exam Session', 'Odd/Even'],
      ['Year', 'Year'],
      ['Semester', semester],
      ['Branch', branch],
      ['Name', studentName],
      ['Father\'s Name', fatherName],
    ],
    rightDetails: [
      ['Roll No.', enrolmentNumber],
      ['Academic Year', academicYear],
    ],
    subjects: subjects,
    sgpa: sgpa,
    totalCredits: totalCredits,
    totalCreditPoints: totalCreditPoints,
    passed: passed,
    note:
        'This is a computer-generated semester examination marks memorandum. '
        'It is valid as a record of semester examination marks for the stated academic year.',
  );

  final bytes = await document.save();
  try {
    await Printing.layoutPdf(
      onLayout: (_) async => bytes,
      name: 'Semester_Memo_$enrolmentNumber',
    );
  } catch (_) {
    await Printing.sharePdf(
      bytes: bytes,
      filename: 'Semester_Memo_$enrolmentNumber.pdf',
    );
  }
}

pw.Document _buildMemoPdf({
  required String title,
  required List<List<String>> leftDetails,
  required List<List<String>> rightDetails,
  required List<Map<String, dynamic>> subjects,
  required double sgpa,
  required int totalCredits,
  required double totalCreditPoints,
  required int passed,
  required String note,
}) {
  final pdf = pw.Document();

  pdf.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(20),
      build: (_) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            _universityHeader(),
            pw.SizedBox(height: 12),
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.black, width: 1),
              ),
              child: pw.Text(
                title,
                style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                  fontStyle: pw.FontStyle.italic,
                  letterSpacing: 0.4,
                ),
              ),
            ),
            pw.SizedBox(height: 14),
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  flex: 2,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: leftDetails
                        .map((pair) => _detailRow(pair[0], pair[1]))
                        .toList(),
                  ),
                ),
                pw.SizedBox(width: 16),
                pw.Expanded(
                  flex: 1,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: rightDetails
                        .map((pair) => _detailRow(pair[0], pair[1]))
                        .toList(),
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 14),
            _marksTable(subjects),
            pw.SizedBox(height: 8),
            _summaryRow(subjects.length, passed, totalCredits, totalCreditPoints),
            pw.SizedBox(height: 8),
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
                ),
              ),
            ),
            pw.SizedBox(height: 12),
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                border: pw.Border.all(color: PdfColors.grey400),
              ),
              child: pw.Text(
                note,
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
                textAlign: pw.TextAlign.center,
              ),
            ),
          ],
        );
      },
    ),
  );

  return pdf;
}

pw.Widget _universityHeader() {
  return pw.Column(
    children: [
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
                    letterSpacing: 1.2,
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
    ],
  );
}

pw.Widget _detailRow(String label, String value) {
  return pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 4),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          flex: 1,
          child: pw.Text(
            '$label:',
            style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
          ),
        ),
        pw.Expanded(
          flex: 2,
          child: pw.Text(value, style: const pw.TextStyle(fontSize: 9)),
        ),
      ],
    ),
  );
}

pw.Widget _marksTable(List<Map<String, dynamic>> subjects) {
  if (subjects.isEmpty) {
    return pw.Text('No marks available.');
  }

  return pw.Table(
    border: pw.TableBorder.all(color: PdfColors.grey500, width: 0.5),
    children: [
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: PdfColors.blue900),
        children: [
          _tableCell('S.NO', bold: true, white: true),
          _tableCell('CODE', bold: true, white: true),
          _tableCell('SUBJECT', bold: true, white: true),
          _tableCell('INT', bold: true, white: true),
          _tableCell('EXT', bold: true, white: true),
          _tableCell('TOT', bold: true, white: true),
          _tableCell('GR', bold: true, white: true),
          _tableCell('STATUS', bold: true, white: true),
        ],
      ),
      ...subjects.asMap().entries.map((entry) {
        final index = entry.key;
        final subject = entry.value;
        final isPassed = (subject['result'] ?? '').toString().toUpperCase() == 'PASS';
        return pw.TableRow(
          children: [
            _tableCell('${index + 1}'),
            _tableCell('${subject['subjectCode'] ?? '—'}'),
            _tableCell('${subject['subjectName'] ?? '—'}'),
            _tableCell('${subject['internalMarks'] ?? '—'}'),
            _tableCell('${subject['externalMarks'] ?? '—'}'),
            _tableCell('${subject['totalMarks'] ?? '—'}', bold: true),
            _tableCell('${subject['grade'] ?? '—'}', bold: true),
            _tableCell(
              isPassed ? 'PASS' : 'FAIL',
              bold: true,
              color: isPassed ? PdfColors.green700 : PdfColors.red700,
            ),
          ],
        );
      }),
    ],
  );
}

pw.Widget _summaryRow(
  int total,
  int passed,
  int totalCredits,
  double totalCreditPoints,
) {
  return pw.Table(
    border: pw.TableBorder.all(color: PdfColors.grey500, width: 0.5),
    children: [
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: PdfColors.grey100),
        children: [
          _tableCell('REG\n$total', bold: true),
          _tableCell('APP\n$total', bold: true),
          _tableCell('PASS\n$passed', bold: true, color: PdfColors.green700),
          _tableCell('TOT CR\n$totalCredits', bold: true),
          _tableCell('CR PTS\n${totalCreditPoints.toStringAsFixed(1)}', bold: true),
        ],
      ),
    ],
  );
}

pw.Widget _tableCell(
  String text, {
  bool bold = false,
  bool white = false,
  PdfColor? color,
}) {
  return pw.Padding(
    padding: const pw.EdgeInsets.all(4),
    child: pw.Text(
      text,
      textAlign: pw.TextAlign.center,
      style: pw.TextStyle(
        fontSize: 8,
        fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        color: color ?? (white ? PdfColors.white : PdfColors.black),
      ),
    ),
  );
}
