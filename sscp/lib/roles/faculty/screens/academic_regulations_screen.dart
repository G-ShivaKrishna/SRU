import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../widgets/app_header.dart';

class RegulationItem {
  final String id;
  final int sNo;
  final String degree;
  final String regulation;
  final String pdfUrl;

  RegulationItem({
    required this.id,
    required this.sNo,
    required this.degree,
    required this.regulation,
    required this.pdfUrl,
  });

  factory RegulationItem.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return RegulationItem(
      id: doc.id,
      sNo: (d['sNo'] as num?)?.toInt() ?? 0,
      degree: d['degree'] ?? '',
      regulation: d['regulation'] ?? '',
      pdfUrl: d['pdfUrl'] ?? '',
    );
  }
}

class AcademicRegulationsScreen extends StatefulWidget {
  const AcademicRegulationsScreen({super.key});

  @override
  State<AcademicRegulationsScreen> createState() =>
      _AcademicRegulationsScreenState();
}

class _AcademicRegulationsScreenState extends State<AcademicRegulationsScreen> {
  bool _showingPdf = false;
  RegulationItem? _selectedRegulation;
  late final Stream<QuerySnapshot> _regulationsStream;

  @override
  void initState() {
    super.initState();
    _regulationsStream = FirebaseFirestore.instance
        .collection('academicRegulations')
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
            child: _showingPdf && _selectedRegulation != null
                ? _buildPdfViewer()
                : _buildRegulationsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildRegulationsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _regulationsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final regulations = (snapshot.data?.docs ?? [])
            .map((doc) => RegulationItem.fromDoc(doc))
            .toList();

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
              if (regulations.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Text(
                      'No regulations found.\nAdmin needs to add them.',
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
                              _buildDataCell(reg.sNo.toString()),
                              _buildDataCell(reg.degree),
                              _buildDataCell(reg.regulation),
                              _buildDataCell(
                                TextButton(
                                  onPressed: reg.pdfUrl.isEmpty
                                      ? null
                                      : () {
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
                                  child: Text(
                                    reg.pdfUrl.isEmpty ? 'No PDF' : 'View',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: reg.pdfUrl.isEmpty
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
    final reg = _selectedRegulation!;
    return Stack(
      children: [
        SfPdfViewer.network(
          reg.pdfUrl,
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
            label: Text('${reg.degree} – ${reg.regulation}'),
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
