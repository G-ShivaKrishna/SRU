import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../../widgets/app_header.dart';

class AcademicRegulationsScreen extends StatefulWidget {
  const AcademicRegulationsScreen({super.key});

  @override
  State<AcademicRegulationsScreen> createState() =>
      _AcademicRegulationsScreenState();
}

class RegulationItem {
  final String sNo;
  final String degree;
  final String regulation;
  final String pdfUrl;

  RegulationItem({
    required this.sNo,
    required this.degree,
    required this.regulation,
    required this.pdfUrl,
  });
}

class _AcademicRegulationsScreenState extends State<AcademicRegulationsScreen> {
  bool _showingPdf = false;
  late RegulationItem _selectedRegulation;

  final List<RegulationItem> regulations = [
    RegulationItem(
      sNo: '1',
      degree: 'BTECH',
      regulation: 'R25',
      pdfUrl: 'https://www.w3.org/WAI/WCAG21/Documents/WCAG21-20180605.pdf',
    ),
    RegulationItem(
      sNo: '2',
      degree: 'BSC_HONS',
      regulation: 'RSUM',
      pdfUrl: 'https://www.w3.org/WAI/WCAG21/Documents/WCAG21-20180605.pdf',
    ),
    RegulationItem(
      sNo: '3',
      degree: 'PhD',
      regulation: 'RA20',
      pdfUrl: 'https://www.w3.org/WAI/WCAG21/Documents/WCAG21-20180605.pdf',
    ),
    RegulationItem(
      sNo: '4',
      degree: 'BTECH',
      regulation: 'RA20',
      pdfUrl: 'https://www.w3.org/WAI/WCAG21/Documents/WCAG21-20180605.pdf',
    ),
    RegulationItem(
      sNo: '5',
      degree: 'BBA',
      regulation: 'RA20',
      pdfUrl: 'https://www.w3.org/WAI/WCAG21/Documents/WCAG21-20180605.pdf',
    ),
    RegulationItem(
      sNo: '6',
      degree: 'IMBA',
      regulation: 'RA20',
      pdfUrl: 'https://www.w3.org/WAI/WCAG21/Documents/WCAG21-20180605.pdf',
    ),
    RegulationItem(
      sNo: '7',
      degree: 'BSC_HONS',
      regulation: 'RA20',
      pdfUrl: 'https://www.w3.org/WAI/WCAG21/Documents/WCAG21-20180605.pdf',
    ),
    RegulationItem(
      sNo: '8',
      degree: 'MTECH',
      regulation: 'RA20',
      pdfUrl: 'https://www.w3.org/WAI/WCAG21/Documents/WCAG21-20180605.pdf',
    ),
    RegulationItem(
      sNo: '9',
      degree: 'BTECH',
      regulation: 'RA18',
      pdfUrl: 'https://www.w3.org/WAI/WCAG21/Documents/WCAG21-20180605.pdf',
    ),
    RegulationItem(
      sNo: '10',
      degree: 'MBA',
      regulation: 'RA18',
      pdfUrl: 'https://www.w3.org/WAI/WCAG21/Documents/WCAG21-20180605.pdf',
    ),
    RegulationItem(
      sNo: '11',
      degree: 'BTECH',
      regulation: 'R25',
      pdfUrl: 'https://www.w3.org/WAI/WCAG21/Documents/WCAG21-20180605.pdf',
    ),
    RegulationItem(
      sNo: '12',
      degree: 'PhD',
      regulation: 'R24',
      pdfUrl: 'https://www.w3.org/WAI/WCAG21/Documents/WCAG21-20180605.pdf',
    ),
  ];

  // Future use: Fetch PDF from Firebase Storage
  // Uncomment when you upload PDFs to Firebase Storage
  // Future<String> _getPdfUrl(String url) async {
  //   try {
  //     final ref = FirebaseStorage.instance
  //         .ref()
  //         .child('documents/academic_regulations.pdf');
  //     final firebaseUrl = await ref.getDownloadURL();
  //     return firebaseUrl;
  //   } catch (e) {
  //     return url; // Fallback to provided URL
  //   }
  // }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Column(
        children: [
          const AppHeader(),
          Expanded(
            child: _showingPdf ? _buildPdfViewer() : _buildRegulationsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildRegulationsList() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Academic Regulations',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1e3a5f),
            ),
          ),
          const SizedBox(height: 24),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!, width: 1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Column(
              children: [
                // Header Row
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8E8E8),
                    border: Border(
                      bottom: BorderSide(color: Colors.grey[300]!, width: 1),
                    ),
                  ),
                  child: Row(
                    children: [
                      _buildHeaderCell('S.No'),
                      _buildHeaderCell('Degree'),
                      _buildHeaderCell('Regulation'),
                      _buildHeaderCell('View'),
                    ],
                  ),
                ),
                // Data Rows
                ...regulations.asMap().entries.map((entry) {
                  final index = entry.key;
                  final reg = entry.value;
                  final isLast = index == regulations.length - 1;
                  final isEvenRow = index % 2 == 0;

                  return Container(
                    decoration: BoxDecoration(
                      color: isEvenRow ? Colors.white : const Color(0xFFF5F5F5),
                      border: Border(
                        bottom: BorderSide(
                          color:
                              isLast ? Colors.transparent : Colors.grey[200]!,
                          width: 1,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        _buildDataCell(reg.sNo),
                        _buildDataCell(reg.degree),
                        _buildDataCell(reg.regulation),
                        _buildDataCell(
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _selectedRegulation = reg;
                                _showingPdf = true;
                              });
                            },
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                            ),
                            child: const Text(
                              'View',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1976D2),
                              ),
                            ),
                          ),
                          isAction: true,
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderCell(String text) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1e3a5f),
          ),
        ),
      ),
    );
  }

  Widget _buildDataCell(dynamic content, {bool isAction = false}) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: isAction
            ? content
            : Text(
                content.toString(),
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.black87,
                ),
              ),
      ),
    );
  }

  Widget _buildPdfViewer() {
    return Stack(
      children: [
        SfPdfViewer.network(
          _selectedRegulation.pdfUrl,
          onDocumentLoadFailed: (PdfDocumentLoadFailedDetails details) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error: ${details.error}'),
                backgroundColor: Colors.red,
              ),
            );
          },
        ),
        Positioned(
          top: 16,
          left: 16,
          child: ElevatedButton.icon(
            onPressed: () {
              setState(() {
                _showingPdf = false;
              });
            },
            icon: const Icon(Icons.arrow_back),
            label: const Text('Back'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1e3a5f),
              foregroundColor: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}
