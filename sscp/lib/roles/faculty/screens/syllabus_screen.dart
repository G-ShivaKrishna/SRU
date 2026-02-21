import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import '../../../widgets/app_header.dart';

class SyllabusScreen extends StatefulWidget {
  const SyllabusScreen({super.key});

  @override
  State<SyllabusScreen> createState() => _SyllabusScreenState();
}

class SyllabusItem {
  final String sNo;
  final String classInfo;
  final String regulation;
  final String pdfUrl;

  SyllabusItem({
    required this.sNo,
    required this.classInfo,
    required this.regulation,
    required this.pdfUrl,
  });
}

class _SyllabusScreenState extends State<SyllabusScreen> {
  bool _showingPdf = false;
  late SyllabusItem _selectedSyllabus;

  Future<Uint8List> _loadPdfBytes(String pdfUrl) async {
    final uri = Uri.parse(pdfUrl);
    final data = await NetworkAssetBundle(uri).load(uri.toString());
    final bytes = data.buffer.asUint8List();

    // Quick PDF header check to avoid parsing HTML or invalid content.
    if (bytes.length < 4 ||
        bytes[0] != 0x25 ||
        bytes[1] != 0x50 ||
        bytes[2] != 0x44 ||
        bytes[3] != 0x46) {
      throw Exception('Invalid PDF file or URL');
    }

    return bytes;
  }

  final List<SyllabusItem> syllabusList = [
    SyllabusItem(
      sNo: '1',
      classInfo: '1-1-BTECH-HSC(HSC)',
      regulation: 'RA20',
      pdfUrl: 'https://www.w3.org/WAI/WCAG21/Documents/WCAG21-20180605.pdf',
    ),
    SyllabusItem(
      sNo: '2',
      classInfo: '2-2-BTECH-EEE(EEE)',
      regulation: 'RA20',
      pdfUrl: 'https://www.w3.org/WAI/WCAG21/Documents/WCAG21-20180605.pdf',
    ),
    SyllabusItem(
      sNo: '3',
      classInfo: '4-2-BTECH-EEE(EEE)',
      regulation: 'RA18',
      pdfUrl: 'https://www.w3.org/WAI/WCAG21/Documents/WCAG21-20180605.pdf',
    ),
    SyllabusItem(
      sNo: '4',
      classInfo: '3-2-BTECH-EEE(EEE)',
      regulation: 'RA20',
      pdfUrl: 'https://www.w3.org/WAI/WCAG21/Documents/WCAG21-20180605.pdf',
    ),
    SyllabusItem(
      sNo: '5',
      classInfo: '4-2-BTECH-CSE(CSE)',
      regulation: 'RA18',
      pdfUrl: 'https://www.w3.org/WAI/WCAG21/Documents/WCAG21-20180605.pdf',
    ),
    SyllabusItem(
      sNo: '6',
      classInfo: '3-2-BTECH-CSE(CSE)',
      regulation: 'RA20',
      pdfUrl: 'https://www.w3.org/WAI/WCAG21/Documents/WCAG21-20180605.pdf',
    ),
    SyllabusItem(
      sNo: '7',
      classInfo: '2-2-BTECH-CSE(CSE)',
      regulation: 'RA20',
      pdfUrl: 'https://www.w3.org/WAI/WCAG21/Documents/WCAG21-20180605.pdf',
    ),
    SyllabusItem(
      sNo: '8',
      classInfo: '4-2-BTECH-MECH(MECH)',
      regulation: 'RA18',
      pdfUrl: 'https://www.w3.org/WAI/WCAG21/Documents/WCAG21-20180605.pdf',
    ),
    SyllabusItem(
      sNo: '9',
      classInfo: '1-2-BTECH-HSC(HSC)',
      regulation: 'RA20',
      pdfUrl: 'https://www.w3.org/WAI/WCAG21/Documents/WCAG21-20180605.pdf',
    ),
    SyllabusItem(
      sNo: '10',
      classInfo: '4-2-BTECH-ECE(ECE)',
      regulation: 'RA18',
      pdfUrl: 'https://www.w3.org/WAI/WCAG21/Documents/WCAG21-20180605.pdf',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Column(
        children: [
          const AppHeader(),
          Expanded(
            child: _showingPdf ? _buildPdfViewer() : _buildSyllabusList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSyllabusList() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Syllabus Copies',
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
                      _buildHeaderCell('Class Info'),
                      _buildHeaderCell('Regulation'),
                      _buildHeaderCell('View'),
                    ],
                  ),
                ),
                // Data Rows
                ...syllabusList.asMap().entries.map((entry) {
                  final index = entry.key;
                  final syllabus = entry.value;
                  final isLast = index == syllabusList.length - 1;
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
                        _buildDataCell(syllabus.sNo),
                        _buildDataCell(syllabus.classInfo),
                        _buildDataCell(syllabus.regulation),
                        _buildDataCell(
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _selectedSyllabus = syllabus;
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
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1e3a5f),
        title: const Text('Syllabus PDF'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            setState(() {
              _showingPdf = false;
            });
          },
        ),
      ),
      body: FutureBuilder<Uint8List>(
        future: _loadPdfBytes(_selectedSyllabus.pdfUrl),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || snapshot.data == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error: ${snapshot.error ?? 'Failed to load PDF'}'),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _showingPdf = false;
                      });
                    },
                    child: const Text('Go Back'),
                  ),
                ],
              ),
            );
          }

          return SfPdfViewer.memory(
            snapshot.data!,
            onDocumentLoadFailed: (PdfDocumentLoadFailedDetails details) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Error: ${details.error}'),
                  backgroundColor: Colors.red,
                ),
              );
            },
          );
        },
      ),
    );
  }
}
