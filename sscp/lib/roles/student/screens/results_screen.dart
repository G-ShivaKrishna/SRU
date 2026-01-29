import 'package:flutter/material.dart';

class ResultsScreen extends StatelessWidget {
  const ResultsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Results'),
        backgroundColor: const Color(0xFF1e3a5f),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildHeaderSection(context),
            Padding(
              padding: EdgeInsets.all(isMobile ? 12 : 16),
              child: _buildResultsTable(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderSection(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Container(
      color: const Color(0xFF1e3a5f),
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      child: Text(
        'Exam Results & Memos',
        style: TextStyle(
          color: Colors.yellow,
          fontSize: isMobile ? 14 : 16,
          fontWeight: FontWeight.bold,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildResultsTable(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final results = [
      {'sNo': '1', 'year': '4', 'sem': '1', 'examType': 'Regular', 'examSession': 'NOV-2025'},
      {'sNo': '2', 'year': '3', 'sem': '2', 'examType': 'Regular', 'examSession': 'APR-2025'},
      {'sNo': '3', 'year': '3', 'sem': '1', 'examType': 'Regular', 'examSession': 'NOV-2024'},
      {'sNo': '4', 'year': '2', 'sem': '2', 'examType': 'Regular', 'examSession': 'MAY-2024'},
      {'sNo': '5', 'year': '2', 'sem': '1', 'examType': 'Regular', 'examSession': 'DEC-2023'},
      {'sNo': '6', 'year': '1', 'sem': '2', 'examType': 'Regular', 'examSession': 'JUN-2023'},
      {'sNo': '7', 'year': '1', 'sem': '1', 'examType': 'Regular', 'examSession': 'FEB-2023'},
    ];

    if (isMobile) {
      return _buildMobileResultsView(results);
    } else {
      return _buildDesktopResultsTable(results);
    }
  }

  Widget _buildDesktopResultsTable(List<Map<String, String>> results) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('S.No.', style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text('Year', style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text('Sem', style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text('Exam Type', style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text('Exam Session', style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text('Print Memo', style: TextStyle(fontWeight: FontWeight.bold))),
        ],
        rows: results.map((result) {
          return DataRow(
            cells: [
              DataCell(Text(result['sNo']!)),
              DataCell(Text(result['year']!)),
              DataCell(Text(result['sem']!)),
              DataCell(Text(result['examType']!)),
              DataCell(Text(result['examSession']!)),
              DataCell(
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  onPressed: () {},
                  child: const Text(
                    'Print Memo',
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMobileResultsView(List<Map<String, String>> results) {
    return Column(
      children: results.map((result) {
        return _buildResultCard(result);
      }).toList(),
    );
  }

  Widget _buildResultCard(Map<String, String> result) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!, width: 1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF1e3a5f),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(7),
                topRight: Radius.circular(7),
              ),
            ),
            child: Text(
              'Exam Session: ${result['examSession']}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildMobileResultRow('S.No.', result['sNo']!),
                _buildMobileResultRow('Year', result['year']!),
                _buildMobileResultRow('Semester', result['sem']!),
                _buildMobileResultRow('Exam Type', result['examType']!),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    onPressed: () {},
                    child: const Text(
                      'Print Memo',
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileResultRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1e3a5f),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}
