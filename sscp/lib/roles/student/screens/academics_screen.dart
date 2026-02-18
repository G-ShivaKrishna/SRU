import 'package:flutter/material.dart';
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

class AcademicsScreen extends StatefulWidget {
  const AcademicsScreen({super.key});

  @override
  State<AcademicsScreen> createState() => _AcademicsScreenState();
}

class _AcademicsScreenState extends State<AcademicsScreen> {
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
      appBar: AppBar(
        title: const Text('Academic Calendar'),
        backgroundColor: const Color(0xFF1e3a5f),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const AppHeader(),
            Padding(
              padding: EdgeInsets.all(isMobile ? 12 : 16),
              child: Column(
                children: [
                  _buildFilterCard(context),
                  const SizedBox(height: 24),
                  if (calendarData.isNotEmpty)
                    _buildTableContent(context)
                  else
                    _buildNoDataMessage(context),
                ],
              ),
            ),
          ],
        ),
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
                      backgroundColor: Colors.blue,
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
                      backgroundColor: Colors.blue,
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
        final QuerySnapshot<Map<String, dynamic>> snapshot =
            await _firestore
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
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('S.No')),
            DataColumn(label: Text('Academic Year')),
            DataColumn(label: Text('Degree')),
            DataColumn(label: Text('Year')),
            DataColumn(label: Text('Sem')),
            DataColumn(label: Text('S Date')),
            DataColumn(label: Text('E Date')),
            DataColumn(label: Text('View')),
          ],
          rows: List.generate(
            calendarData.length,
            (index) {
              final item = calendarData[index];
              return DataRow(
                cells: [
                  DataCell(Text('${index + 1}')),
                  DataCell(Text(item.academicYear)),
                  DataCell(Text(item.degree)),
                  DataCell(Text('${item.year}')),
                  DataCell(Text('${item.semester}')),
                  DataCell(Text(
                    DateFormat('yyyy-MM-dd').format(item.startDate),
                  )),
                  DataCell(Text(
                    DateFormat('yyyy-MM-dd').format(item.endDate),
                  )),
                  DataCell(
                    GestureDetector(
                      onTap: () => _openPdfViewer(context, item.pdfUrl),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue[100],
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(
                          Icons.picture_as_pdf,
                          color: Colors.blue[700],
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  void _openPdfViewer(BuildContext context, String pdfUrl) {
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
        pdfUrl = pdfUrl.replaceFirst('github.com/', 'raw.githubusercontent.com/');
        pdfUrl = pdfUrl.replaceFirst('/blob/', '/');
      }
      
      // Handle Google Drive URLs
      if (pdfUrl.contains('drive.google.com')) {
        final RegExp regExp = RegExp(r'/d/([a-zA-Z0-9-_]+)');
        final match = regExp.firstMatch(pdfUrl);
        if (match != null) {
          final fileId = match.group(1);
          pdfUrl = 'https://drive.google.com/uc?id=$fileId&export=download&confirm=t';
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
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline,
                          size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      Text('Error: $_error'),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Go Back'),
                      ),
                    ],
                  ),
                )
              : SfPdfViewer.network(
                  _pdfUrl,
                  onDocumentLoadFailed: (PdfDocumentLoadFailedDetails details) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to load PDF: ${details.error}'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  },
                ),
    );
  }
}
