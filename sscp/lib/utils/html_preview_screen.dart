import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class HtmlPreviewScreen extends StatefulWidget {
  final String htmlContent;

  const HtmlPreviewScreen({super.key, required this.htmlContent});

  @override
  State<HtmlPreviewScreen> createState() => _HtmlPreviewScreenState();
}

class _HtmlPreviewScreenState extends State<HtmlPreviewScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Result Preview"),
        backgroundColor: const Color(0xFF1e3a5f),
        foregroundColor: Colors.white,
      ),
      body: kIsWeb
          ? _WebMemoRenderer(htmlContent: widget.htmlContent)
          : _NativeMemoRenderer(htmlContent: widget.htmlContent),
    );
  }
}

/// Web implementation - renders the memo in a styled format
class _WebMemoRenderer extends StatelessWidget {
  final String htmlContent;

  const _WebMemoRenderer({required this.htmlContent});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Container(
        color: Colors.grey.shade100,
        padding: const EdgeInsets.all(16),
        child: Container(
          color: Colors.white,
          padding: const EdgeInsets.all(32),
          child: _MemoContent(htmlContent: htmlContent),
        ),
      ),
    );
  }
}

/// Renders the memo content extracted from HTML
class _MemoContent extends StatelessWidget {
  final String htmlContent;

  const _MemoContent({required this.htmlContent});

  @override
  Widget build(BuildContext context) {
    try {
      final data = _parseHtmlMemo(htmlContent);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // University Header
          _buildUniversityHeader(),
          const SizedBox(height: 20),
          // Memo Title
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black, width: 2),
              ),
              child: const Text(
                'MEMORANDUM OF SUPPLEMENTARY EXAMINATION MARKS',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  fontStyle: FontStyle.italic,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          // Details Section (Left and Right columns)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _DetailLine('Memo No.', data['memoNo'] ?? '—'),
                    _DetailLine('Serial No.', data['serialNo'] ?? '—'),
                    _DetailLine('Examination', data['examination'] ?? '—'),
                    _DetailLine('Branch', data['branch'] ?? '—'),
                    _DetailLine('Name', data['studentName'] ?? '—'),
                    _DetailLine('Father\'s Name', data['fatherName'] ?? '—'),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _DetailLine('Enrolment Number', data['rollNo'] ?? '—'),
                    _DetailLine('Academic Year', data['academicYear'] ?? '—'),
                    _DetailLine('Exam Session', data['examSession'] ?? '—'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Results Table
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              border: TableBorder.all(color: Colors.grey.shade400),
              headingRowColor:
                  WidgetStateProperty.all(const Color(0xFF1e3a5f)),
              columns: const [
                DataColumn(
                  label: Text('S.NO',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                ),
                DataColumn(
                  label: Text('COURSE CODE',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                ),
                DataColumn(
                  label: Text('COURSE TITLE',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                ),
                DataColumn(
                  label: Text('INT',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                ),
                DataColumn(
                  label: Text('EXT',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                ),
                DataColumn(
                  label: Text('TOTAL',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                ),
                DataColumn(
                  label: Text('GRADE',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                ),
                DataColumn(
                  label: Text('STATUS',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
              rows: _buildDataRows(
                  data['subjects'] as List<Map<String, String>>? ?? []),
            ),
          ),
          const SizedBox(height: 20),
          // Summary Section
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade400),
            ),
            child: Table(
              border: TableBorder.all(color: Colors.grey.shade400),
              children: [
                TableRow(
                  children: [
                    _SummaryCell(
                        'SUBJECTS REGISTERED', data['subjectsCount'] ?? '—'),
                    _SummaryCell('APPEARED', data['appearedCount'] ?? '—'),
                    _SummaryCell('PASSED', data['passedCount'] ?? '—'),
                  ],
                ),
                TableRow(
                  children: [
                    _SummaryCell('TOTAL CREDITS', data['totalCredits'] ?? '—'),
                    _SummaryCell('CREDIT POINTS', data['creditPoints'] ?? '—'),
                    const _SummaryCell('', ''),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // SGPA Section
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF1e3a5f),
              border: Border.all(color: const Color(0xFF1e3a5f)),
            ),
            child: Text(
              'OVERALL RESULT: ${data['overallResult'] ?? '—'}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(height: 32),
          // Footer
          Center(
            child: Text(
              'This is a computer-generated document. For official use only.',
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      );
    } catch (e) {
      return _FallbackMemoRenderer(htmlContent: htmlContent);
    }
  }

  Widget _buildUniversityHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade400),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'SRU',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'SR UNIVERSITY',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  'Hanmakonda - 506 371, Telangana State, INDIA',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        Divider(color: Colors.grey.shade400, thickness: 1),
      ],
    );
  }

  List<DataRow> _buildDataRows(List<Map<String, String>> subjects) {
    return subjects.asMap().entries.map((entry) {
      int index = entry.key + 1;
      Map<String, String> s = entry.value;
      final isPassed = s['result']?.toUpperCase() == 'PASS';

      return DataRow(
        cells: [
          DataCell(
              Text(index.toString(), style: const TextStyle(fontSize: 11))),
          DataCell(Text(s['code'] ?? '', style: const TextStyle(fontSize: 11))),
          DataCell(Text(s['name'] ?? '', style: const TextStyle(fontSize: 11))),
          DataCell(Text(s['int'] ?? '—', style: const TextStyle(fontSize: 11))),
          DataCell(Text(s['ext'] ?? '—', style: const TextStyle(fontSize: 11))),
          DataCell(Text(s['tot'] ?? '—',
              style:
                  const TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
          DataCell(
              Text(s['grade'] ?? '—', style: const TextStyle(fontSize: 11))),
          DataCell(
            Text(
              s['result'] ?? '—',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isPassed ? Colors.green : Colors.red,
              ),
            ),
          ),
        ],
      );
    }).toList();
  }

  Map<String, dynamic> _parseHtmlMemo(String html) {
    final result = <String, dynamic>{
      'memoNo': _extractValue(html, r'Memo No\.*?:\s*(.*?)(?:<|$)'),
      'serialNo': _extractValue(html, r'Serial No\.*?:\s*(.*?)(?:<|$)'),
      'examination': _extractValue(html, r'Examination.*?>(.*?)<'),
      'branch': _extractValue(html, r'Branch.*?>(.*?)<'),
      'studentName': _extractValue(html, r'Student Name.*?>(.*?)<'),
      'fatherName': _extractValue(html, r'Father.*?Name.*?>(.*?)<'),
      'rollNo': _extractValue(html, r'Roll No.*?>(.*?)<'),
      'academicYear': _extractValue(html, r'Academic Year.*?>(.*?)<'),
      'examSession': _extractValue(html, r'Exam Session.*?>(.*?)<'),
      'overallResult': _extractValue(html, r'Overall Result:.*?>(.*?)<'),
      'subjects': <Map<String, String>>[],
      'subjectsCount': '—',
      'appearedCount': '—',
      'passedCount': '—',
      'totalCredits': '—',
      'creditPoints': '—',
    };

    // Extract table rows
    final rowPattern =
        RegExp(r'<tr>(.*?)</tr>', caseSensitive: false, dotAll: true);
    for (final match in rowPattern.allMatches(html)) {
      final rowHtml = match.group(1) ?? '';
      final cells = RegExp(r'<td[^>]*>(.*?)</td>', caseSensitive: false)
          .allMatches(rowHtml)
          .map((m) => _stripHtml(m.group(1) ?? ''))
          .toList();

      if (cells.length >= 7) {
        (result['subjects'] as List).add({
          'code': cells[0].trim(),
          'name': cells[1].trim(),
          'int': cells[2].trim(),
          'ext': cells[3].trim(),
          'tot': cells[4].trim(),
          'grade': cells[5].trim(),
          'result': cells[6].trim(),
        });
      }
    }

    // Count results
    final subjects = result['subjects'] as List<Map<String, String>>;
    result['subjectsCount'] = subjects.length.toString();
    result['appearedCount'] = subjects.length.toString();
    final passedCount =
        subjects.where((s) => s['result']?.toUpperCase() == 'PASS').length;
    result['passedCount'] = passedCount.toString();

    return result;
  }

  String _extractValue(String html, String pattern) {
    final match = RegExp(pattern, caseSensitive: false).firstMatch(html);
    return match != null ? _stripHtml(match.group(1) ?? '').trim() : '';
  }

  String _stripHtml(String html) {
    return html
        .replaceAll(RegExp(r'<[^>]+>', caseSensitive: false), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&amp;', '&');
  }
}

/// Fallback renderer if parsing fails
class _FallbackMemoRenderer extends StatelessWidget {
  final String htmlContent;

  const _FallbackMemoRenderer({required this.htmlContent});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.all(16),
        child: SelectableText(
          htmlContent,
          style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
        ),
      ),
    );
  }
}

/// Native implementation
class _NativeMemoRenderer extends StatelessWidget {
  final String htmlContent;

  const _NativeMemoRenderer({required this.htmlContent});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.all(16),
        child: SelectableText(
          htmlContent,
          style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
        ),
      ),
    );
  }
}

/// Detail line widget for memo
class _DetailLine extends StatelessWidget {
  final String label;
  final String value;

  const _DetailLine(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 11,
            ),
          ),
          Expanded(
            child: Text(
              ': $value',
              style: const TextStyle(fontSize: 11),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// Summary cell widget for table
class _SummaryCell extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryCell(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 10,
              letterSpacing: 0.3,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
