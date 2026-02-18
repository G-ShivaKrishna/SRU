import 'package:flutter/material.dart';
import '../../../widgets/app_header.dart';

class FacultyExamsScreen extends StatefulWidget {
  const FacultyExamsScreen({super.key});

  @override
  State<FacultyExamsScreen> createState() => _FacultyExamsScreenState();
}

class _FacultyExamsScreenState extends State<FacultyExamsScreen> {
  bool hasPdfUploaded = false; // Toggle based on admin upload

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Exam Schedule & Invigilation'),
        backgroundColor: const Color(0xFF1e3a5f),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const AppHeader(),
            if (hasPdfUploaded)
              Padding(
                padding: EdgeInsets.all(isMobile ? 12 : 16),
                child: _buildPdfViewer(context),
              )
            else
              _buildNoDataMessage(context),
          ],
        ),
      ),
    );
  }

  Widget _buildNoDataMessage(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Center(
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 16 : 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 40),
            Icon(
              Icons.event_busy,
              size: isMobile ? 80 : 120,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 20),
            Text(
              'No Data Yet Uploaded',
              style: TextStyle(
                fontSize: isMobile ? 16 : 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Exam schedule PDF will be available soon.\nPlease check back later or contact the Examination Cell.',
              style: TextStyle(
                fontSize: isMobile ? 12 : 14,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1e3a5f),
                padding: EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: isMobile ? 10 : 12,
                ),
              ),
              onPressed: () {
                setState(() {
                  hasPdfUploaded = !hasPdfUploaded;
                });
              },
              child: const Text(
                'Refresh',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPdfViewer(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!, width: 1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(isMobile ? 12 : 14),
            decoration: BoxDecoration(
              color: const Color(0xFF1e3a5f),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(7),
                topRight: Radius.circular(7),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Exam Schedule & Invigilation Duty',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isMobile ? 13 : 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.download, color: Colors.white),
                      onPressed: () {},
                      tooltip: 'Download PDF',
                    ),
                    IconButton(
                      icon: const Icon(Icons.print, color: Colors.white),
                      onPressed: () {},
                      tooltip: 'Print PDF',
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.all(isMobile ? 12 : 16),
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  height: isMobile ? 500 : 600,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[400]!),
                    borderRadius: BorderRadius.circular(4),
                    color: Colors.grey[100],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.picture_as_pdf,
                        size: isMobile ? 64 : 80,
                        color: Colors.red[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Faculty_Exam_Duty_2025-26.pdf',
                        style: TextStyle(
                          fontSize: isMobile ? 12 : 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[700],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Page 1 of 2',
                        style: TextStyle(
                          fontSize: isMobile ? 11 : 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Click to view PDF',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: isMobile ? 12 : 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios),
                      onPressed: () {},
                      tooltip: 'Previous Page',
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[400]!),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Page 1 of 2',
                        style: TextStyle(
                          fontSize: isMobile ? 11 : 12,
                          color: Colors.grey[700],
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.arrow_forward_ios),
                      onPressed: () {},
                      tooltip: 'Next Page',
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(isMobile ? 12 : 14),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    border: Border.all(color: Colors.blue[200]!),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'PDF Information',
                        style: TextStyle(
                          fontSize: isMobile ? 12 : 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[900],
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildPdfInfoRow('File Name',
                          'Faculty_Exam_Duty_2025-26.pdf', isMobile),
                      _buildPdfInfoRow(
                          'Uploaded Date', '15-Jan-2025', isMobile),
                      _buildPdfInfoRow('File Size', '1.8 MB', isMobile),
                      _buildPdfInfoRow('Pages', '2', isMobile),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPdfInfoRow(String label, String value, bool isMobile) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: isMobile ? 100 : 120,
            child: Text(
              label,
              style: TextStyle(
                fontSize: isMobile ? 11 : 12,
                fontWeight: FontWeight.w600,
                color: Colors.blue[900],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: isMobile ? 11 : 12,
                color: Colors.blue[800],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
