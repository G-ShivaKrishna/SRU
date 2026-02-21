import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import '../../../widgets/app_header.dart';

// Model for Academic Calendar
class AcademicCalendarModel {
  final String id;
  final String academicYear;
  final String degree;
  final int year;
  final int semester;
  final DateTime startDate;
  final DateTime endDate;
  final String pdfUrl;

  AcademicCalendarModel({
    required this.id,
    required this.academicYear,
    required this.degree,
    required this.year,
    required this.semester,
    required this.startDate,
    required this.endDate,
    required this.pdfUrl,
  });

  factory AcademicCalendarModel.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return AcademicCalendarModel(
      id: doc.id,
      academicYear: data['academicYear'] ?? '',
      degree: data['degree'] ?? '',
      year: data['year'] ?? 0,
      semester: data['semester'] ?? 0,
      startDate: (data['startDate'] as Timestamp).toDate(),
      endDate: (data['endDate'] as Timestamp).toDate(),
      pdfUrl: data['pdfUrl'] ?? '',
    );
  }
}

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  String? selectedYear;
  String? selectedDegree;
  String? selectedSem;
  List<AcademicCalendarModel> calendarData = [];
  bool isLoading = false;

  final academicYears = ['2025-26'];
  final degrees = ['BTECH', 'MTECH', 'MBA', 'MCA'];
  final semesters = ['1', '2'];

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Column(
        children: [
          const AppHeader(),
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.all(isMobile ? 12 : 16),
                child: Column(
                  children: [
                    _buildFilterCard(context),
                    const SizedBox(height: 24),
                    if (isLoading)
                      const Center(child: CircularProgressIndicator())
                    else if (calendarData.isNotEmpty)
                      _buildTableContent(context)
                    else
                      _buildNoDataMessage(context),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterCard(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!, width: 1),
        borderRadius: BorderRadius.circular(8),
        color: Colors.white,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Select Filters',
            style: TextStyle(
              fontSize: isMobile ? 13 : 14,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1e3a5f),
            ),
          ),
          const SizedBox(height: 16),
          if (isMobile)
            Column(
              children: [
                _buildDropdownField(
                    'Academic Year', selectedYear, academicYears, (value) {
                  setState(() => selectedYear = value);
                }),
                const SizedBox(height: 12),
                _buildDropdownField('Degree', selectedDegree, degrees, (value) {
                  setState(() => selectedDegree = value);
                }),
                const SizedBox(height: 12),
                _buildDropdownField('Semester', selectedSem, semesters,
                    (value) {
                  setState(() => selectedSem = value);
                }),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1e3a5f),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: _onSearchPressed,
                    child: const Text(
                      'Search',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            )
          else
            Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildDropdownField(
                          'Academic Year', selectedYear, academicYears,
                          (value) {
                        setState(() => selectedYear = value);
                      }),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildDropdownField(
                          'Degree', selectedDegree, degrees, (value) {
                        setState(() => selectedDegree = value);
                      }),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildDropdownField(
                          'Semester', selectedSem, semesters, (value) {
                        setState(() => selectedSem = value);
                      }),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1e3a5f),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: _onSearchPressed,
                    child: const Text(
                      'Search',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildDropdownField(String label, String? value, List<String> items,
      Function(String?) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1e3a5f),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[400]!),
            borderRadius: BorderRadius.circular(4),
            color: Colors.white,
          ),
          child: DropdownButton<String>(
            value: value,
            isExpanded: true,
            underline: const SizedBox(),
            hint: Text('Select $label'),
            items: items.map((String item) {
              return DropdownMenuItem<String>(
                value: item,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(item),
                ),
              );
            }).toList(),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  void _onSearchPressed() async {
    if (selectedYear != null && selectedDegree != null && selectedSem != null) {
      setState(() => isLoading = true);

      try {
        // Query Firestore for matching academic calendars
        final QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
            .collection('academic_calendars')
            .where('academicYear', isEqualTo: selectedYear)
            .where('degree', isEqualTo: selectedDegree)
            .where('semester', isEqualTo: int.parse(selectedSem!))
            .get();

        if (!mounted) return;

        setState(() {
          calendarData = snapshot.docs
              .map((doc) => AcademicCalendarModel.fromFirestore(doc))
              .toList();
          isLoading = false;
        });

        if (calendarData.isEmpty && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No academic calendars found'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } catch (e) {
        if (!mounted) return;
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select all filters'),
          backgroundColor: Colors.red,
        ),
      );
    }
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
              Icons.calendar_today,
              size: isMobile ? 80 : 120,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 20),
            Text(
              'Select filters and click Search',
              style: TextStyle(
                fontSize: isMobile ? 16 : 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'to view the academic calendar',
              style: TextStyle(
                fontSize: isMobile ? 12 : 14,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTableContent(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!, width: 1),
        borderRadius: BorderRadius.circular(8),
        color: Colors.white,
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
                _buildHeaderCell('S.No', flex: 1),
                _buildHeaderCell('Academic Year', flex: 2),
                _buildHeaderCell('Degree', flex: 2),
                _buildHeaderCell('Year', flex: 1),
                _buildHeaderCell('Sem', flex: 1),
                _buildHeaderCell('S Date', flex: 2),
                _buildHeaderCell('E Date', flex: 2),
                _buildHeaderCell('View', flex: 1),
              ],
            ),
          ),
          // Data Rows
          ...calendarData.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            final isLast = index == calendarData.length - 1;
            final isEvenRow = index % 2 == 0;

            return Container(
              decoration: BoxDecoration(
                color: isEvenRow ? Colors.white : const Color(0xFFF5F5F5),
                border: Border(
                  bottom: BorderSide(
                    color: isLast ? Colors.transparent : Colors.grey[200]!,
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  _buildDataCell('${index + 1}', flex: 1),
                  _buildDataCell(item.academicYear, flex: 2),
                  _buildDataCell(item.degree, flex: 2),
                  _buildDataCell('${item.year}', flex: 1),
                  _buildDataCell('${item.semester}', flex: 1),
                  _buildDataCell(
                    DateFormat('yyyy-MM-dd').format(item.startDate),
                    flex: 2,
                  ),
                  _buildDataCell(
                    DateFormat('yyyy-MM-dd').format(item.endDate),
                    flex: 2,
                  ),
                  _buildDataCell(
                    _buildViewButton(item.pdfUrl),
                    flex: 1,
                    isAction: true,
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildHeaderCell(String text, {int flex = 1}) {
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1e3a5f),
          ),
        ),
      ),
    );
  }

  Widget _buildDataCell(dynamic content,
      {int flex = 1, bool isAction = false}) {
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: isAction
            ? content
            : Text(
                content.toString(),
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.black87,
                ),
              ),
      ),
    );
  }

  Widget _buildViewButton(String pdfUrl) {
    return GestureDetector(
      onTap: () => _openPdfViewer(pdfUrl),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: const Color(0xFF1976D2).withOpacity(0.1),
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Icon(
          Icons.picture_as_pdf,
          color: Color(0xFF1976D2),
          size: 18,
        ),
      ),
    );
  }

  void _openPdfViewer(String pdfUrl) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PdfViewerScreen(pdfUrl: pdfUrl),
      ),
    );
  }
}

// PDF Viewer Screen with Syncfusion
class PdfViewerScreen extends StatefulWidget {
  final String pdfUrl;

  const PdfViewerScreen({super.key, required this.pdfUrl});

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  late String _pdfUrl;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _preparePdfUrl();
  }

  Future<void> _preparePdfUrl() async {
    try {
      String pdfUrl = widget.pdfUrl;

      // Handle GitHub URLs - convert to raw content URL
      if (pdfUrl.contains('github.com')) {
        pdfUrl =
            pdfUrl.replaceFirst('github.com/', 'raw.githubusercontent.com/');
        pdfUrl = pdfUrl.replaceFirst('/blob/', '/');
      }

      // Handle Google Drive URLs
      if (pdfUrl.contains('drive.google.com')) {
        final RegExp regExp = RegExp(r'/d/([a-zA-Z0-9-_]+)');
        final match = regExp.firstMatch(pdfUrl);
        if (match != null) {
          final fileId = match.group(1);
          pdfUrl =
              'https://drive.google.com/uc?id=$fileId&export=download&confirm=t';
        }
      }

      setState(() {
        _pdfUrl = pdfUrl;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Error preparing PDF: $e';
        _isLoading = false;
      });
    }
  }

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

  Widget _buildError(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text('Error: $message'),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Go Back'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Academic Calendar PDF'),
        backgroundColor: const Color(0xFF1e3a5f),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError(_error!)
              : kIsWeb
                  ? SfPdfViewer.network(
                      _pdfUrl,
                      onDocumentLoadFailed:
                          (PdfDocumentLoadFailedDetails details) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content:
                                Text('Failed to load PDF: ${details.error}'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      },
                    )
                  : FutureBuilder<Uint8List>(
                      future: _loadPdfBytes(_pdfUrl),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState != ConnectionState.done) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }
                        if (snapshot.hasError || snapshot.data == null) {
                          return _buildError(snapshot.error?.toString() ??
                              'Failed to load PDF');
                        }

                        return SfPdfViewer.memory(
                          snapshot.data!,
                          onDocumentLoadFailed:
                              (PdfDocumentLoadFailedDetails details) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                    'Failed to load PDF: ${details.error}'),
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
