import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import '../../../widgets/app_header.dart';

class SyllabusItem {
  final String id;
  final int sNo;
  final String classInfo;
  final String regulation;
  final String pdfUrl;

  SyllabusItem({
    required this.id,
    required this.sNo,
    required this.classInfo,
    required this.regulation,
    required this.pdfUrl,
  });

  factory SyllabusItem.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return SyllabusItem(
      id: doc.id,
      sNo: (d['sNo'] as num?)?.toInt() ?? 0,
      classInfo: d['classInfo'] ?? '',
      regulation: d['regulation'] ?? '',
      pdfUrl: d['pdfUrl'] ?? '',
    );
  }
}

class SyllabusScreen extends StatefulWidget {
  const SyllabusScreen({super.key});

  @override
  State<SyllabusScreen> createState() => _SyllabusScreenState();
}

class _SyllabusScreenState extends State<SyllabusScreen> {
  bool _showingPdf = false;
  SyllabusItem? _selectedSyllabus;
  late final Stream<QuerySnapshot> _syllabusStream;

  @override
  void initState() {
    super.initState();
    _syllabusStream = FirebaseFirestore.instance
        .collection('syllabusItems')
        .orderBy('sNo')
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Column(
        children: [
          const AppHeader(),
          Expanded(
            child: _showingPdf && _selectedSyllabus != null
                ? _buildPdfViewer()
                : _buildSyllabusList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSyllabusList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _syllabusStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final syllabusList = (snapshot.data?.docs ?? [])
            .map((doc) => SyllabusItem.fromDoc(doc))
            .toList();

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
              if (syllabusList.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Text(
                      'No syllabus entries found.\nAdmin needs to add them.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                  ),
                )
              else
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
                            bottom:
                                BorderSide(color: Colors.grey[300]!, width: 1),
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
                            color: isEvenRow
                                ? Colors.white
                                : const Color(0xFFF5F5F5),
                            border: Border(
                              bottom: BorderSide(
                                color: isLast
                                    ? Colors.transparent
                                    : Colors.grey[200]!,
                                width: 1,
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              _buildDataCell(syllabus.sNo.toString()),
                              _buildDataCell(syllabus.classInfo),
                              _buildDataCell(syllabus.regulation),
                              _buildDataCell(
                                TextButton(
                                  onPressed: syllabus.pdfUrl.isEmpty
                                      ? null
                                      : () {
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
                                  child: Text(
                                    syllabus.pdfUrl.isEmpty ? 'No PDF' : 'View',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: syllabus.pdfUrl.isEmpty
                                          ? Colors.grey
                                          : const Color(0xFF1976D2),
                                    ),
                                  ),
                                ),
                                isAction: true,
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
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
    final s = _selectedSyllabus!;
    return Stack(
      children: [
        SfPdfViewer.network(
          s.pdfUrl,
          onDocumentLoadFailed: (PdfDocumentLoadFailedDetails details) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error loading PDF: ${details.error}'),
                backgroundColor: Colors.red,
              ),
            );
          },
        ),
        Positioned(
          top: 16,
          left: 16,
          child: ElevatedButton.icon(
            onPressed: () => setState(() => _showingPdf = false),
            icon: const Icon(Icons.arrow_back),
            label: Text('${s.classInfo} – ${s.regulation}'),
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
