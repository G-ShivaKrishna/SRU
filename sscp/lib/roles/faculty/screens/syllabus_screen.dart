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
    final isMobile = MediaQuery.of(context).size.width < 600;

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
                isMobile
                    ? _buildMobileSyllabusCards(syllabusList)
                    : Container(
                        decoration: BoxDecoration(
                          border:
                              Border.all(color: Colors.grey[300]!, width: 1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Column(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFFE8E8E8),
                                border: Border(
                                  bottom: BorderSide(
                                      color: Colors.grey[300]!, width: 1),
                                ),
                              ),
                              child: Row(
                                children: [
                                  _buildHeaderCell('S.No',
                                      flex: 2, isMobile: false),
                                  _buildHeaderCell('Class Info',
                                      flex: 5, isMobile: false),
                                  _buildHeaderCell('Regulation',
                                      flex: 3, isMobile: false),
                                  _buildHeaderCell('View',
                                      flex: 2,
                                      isMobile: false,
                                      textAlign: TextAlign.center),
                                ],
                              ),
                            ),
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
                                    _buildDataCell(syllabus.sNo.toString(),
                                        flex: 2, isMobile: false),
                                    _buildDataCell(syllabus.classInfo,
                                        flex: 5, isMobile: false),
                                    _buildDataCell(syllabus.regulation,
                                        flex: 3, isMobile: false),
                                    _buildDataCell(
                                      SizedBox(
                                        width: 72,
                                        child: TextButton(
                                          onPressed: syllabus.pdfUrl.isEmpty
                                              ? null
                                              : () {
                                                  setState(() {
                                                    _selectedSyllabus =
                                                        syllabus;
                                                    _showingPdf = true;
                                                  });
                                                },
                                          style: TextButton.styleFrom(
                                            minimumSize: const Size(72, 40),
                                          ),
                                          child: Text(
                                            syllabus.pdfUrl.isEmpty
                                                ? 'No PDF'
                                                : 'View',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: syllabus.pdfUrl.isEmpty
                                                  ? Colors.grey
                                                  : const Color(0xFF1976D2),
                                            ),
                                          ),
                                        ),
                                      ),
                                      isAction: true,
                                      flex: 2,
                                      isMobile: false,
                                      textAlign: TextAlign.center,
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

  Widget _buildMobileSyllabusCards(List<SyllabusItem> syllabusList) {
    return Column(
      children: syllabusList.map((syllabus) {
        final hasPdf = syllabus.pdfUrl.isNotEmpty;
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.grey[300]!, width: 1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'S.No ${syllabus.sNo}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1e3a5f),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8E8E8),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      syllabus.regulation,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1e3a5f),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                syllabus.classInfo,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: hasPdf
                      ? () {
                          setState(() {
                            _selectedSyllabus = syllabus;
                            _showingPdf = true;
                          });
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        hasPdf ? const Color(0xFF1e3a5f) : Colors.grey.shade400,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(hasPdf ? 'View' : 'No PDF'),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildHeaderCell(
    String text, {
    required int flex,
    required bool isMobile,
    TextAlign textAlign = TextAlign.left,
  }) {
    return Expanded(
      flex: flex,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 8 : 16,
          vertical: 14,
        ),
        child: Text(
          text,
          textAlign: textAlign,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1e3a5f),
          ),
        ),
      ),
    );
  }

  Widget _buildDataCell(
    dynamic content, {
    bool isAction = false,
    required int flex,
    required bool isMobile,
    int maxLines = 2,
    TextAlign textAlign = TextAlign.left,
  }) {
    return Expanded(
      flex: flex,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 8 : 16,
          vertical: 12,
        ),
        child: isAction
            ? Align(
                alignment: textAlign == TextAlign.center
                    ? Alignment.center
                    : Alignment.centerLeft,
                child: content,
              )
            : Text(
                content.toString(),
                textAlign: textAlign,
                maxLines: maxLines,
                overflow: TextOverflow.ellipsis,
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
