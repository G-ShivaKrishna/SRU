import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import '../../../services/user_service.dart';
import '../../../widgets/app_header.dart';

class ExamsScreen extends StatefulWidget {
  const ExamsScreen({super.key});

  @override
  State<ExamsScreen> createState() => _ExamsScreenState();
}

class _ExamsScreenState extends State<ExamsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isLoading = true;
  String? _errorMessage;
  String _rollNo = '';

  Map<String, dynamic>? _studentData;
  Map<String, dynamic>? _releaseData;
  Uint8List? _pdfBytes;

  @override
  void initState() {
    super.initState();
    _rollNo = _resolveRollNo();
    _loadHallticket();
  }

  String _resolveRollNo() {
    final email = FirebaseAuth.instance.currentUser?.email ?? '';
    return UserService.getCurrentUserId() ??
        (email.contains('@') ? email.split('@')[0].toUpperCase() : '');
  }

  Future<Map<String, dynamic>?> _fetchStudentData() async {
    if (_rollNo.isEmpty) return null;

    final byId = await _firestore.collection('students').doc(_rollNo).get();
    if (byId.exists) return byId.data();

    final byField = await _firestore
        .collection('students')
        .where('hallTicketNumber', isEqualTo: _rollNo)
        .limit(1)
        .get();
    if (byField.docs.isNotEmpty) return byField.docs.first.data();

    return null;
  }

  Future<Map<String, dynamic>?> _fetchLatestReleasedHallticket(
      String branch) async {
    if (branch.isEmpty) return null;

    try {
      final snap = await _firestore
          .collection('hallticketReleases')
          .where('branch', isEqualTo: branch)
          .where('status', isEqualTo: 'released')
          .orderBy('releasedAt', descending: true)
          .limit(1)
          .get();

      if (snap.docs.isNotEmpty) return snap.docs.first.data();
    } catch (_) {
      // Fallback without orderBy if indexes are missing.
    }

    final fallback = await _firestore
        .collection('hallticketReleases')
        .where('branch', isEqualTo: branch)
        .where('status', isEqualTo: 'released')
        .get();

    if (fallback.docs.isEmpty) return null;

    fallback.docs.sort((a, b) {
      final aTs = a.data()['releasedAt'] as Timestamp?;
      final bTs = b.data()['releasedAt'] as Timestamp?;
      if (aTs == null && bTs == null) return 0;
      if (aTs == null) return 1;
      if (bTs == null) return -1;
      return bTs.toDate().compareTo(aTs.toDate());
    });

    return fallback.docs.first.data();
  }

  Future<Uint8List?> _tryLoadStudentPhotoBytes(
      Map<String, dynamic> student) async {
    final photoUrl = (student['photoUrl'] ??
            student['profileImageUrl'] ??
            student['imageUrl'] ??
            '')
        .toString()
        .trim();

    if (photoUrl.isEmpty || !photoUrl.startsWith('http')) return null;

    try {
      final res = await http.get(Uri.parse(photoUrl));
      if (res.statusCode == 200) return res.bodyBytes;
    } catch (_) {
      // Optional photo; ignore failures.
    }
    return null;
  }

  Future<Uint8List> _buildHallticketPdf({
    required Map<String, dynamic> student,
    required Map<String, dynamic> release,
  }) async {
    final doc = pw.Document();

    final studentName = (student['name'] ?? 'N/A').toString();
    final fatherName =
        (student['fatherName'] ?? student['fathername'] ?? 'N/A').toString();
    final branch =
        (student['branch'] ?? student['department'] ?? student['dept'] ?? 'N/A')
            .toString()
            .toUpperCase();
    final rollNo = (student['hallTicketNumber'] ?? _rollNo).toString();

    final schedules =
        List<Map<String, dynamic>>.from(release['schedules'] ?? []);
    schedules.sort((a, b) {
      final aTs = a['examDateTime'] as Timestamp?;
      final bTs = b['examDateTime'] as Timestamp?;
      if (aTs == null && bTs == null) return 0;
      if (aTs == null) return 1;
      if (bTs == null) return -1;
      return aTs.toDate().compareTo(bTs.toDate());
    });

    final releasedTs = release['releasedAt'] as Timestamp?;
    final releasedDate = releasedTs?.toDate();
    final examLabel = releasedDate == null
        ? 'HALLTICKET'
        : 'HALLTICKET - ${DateFormat('MMM yyyy').format(releasedDate).toUpperCase()}';

    final photoBytes = await _tryLoadStudentPhotoBytes(student);
    final photoProvider =
        photoBytes == null ? null : pw.MemoryImage(photoBytes);

    final tableRows = schedules.map((s) {
      final ts = s['examDateTime'] as Timestamp?;
      final dt = ts?.toDate();
      final dateText = dt == null
          ? (s['examDate'] ?? '').toString()
          : DateFormat('dd/MM/yyyy').format(dt);
      return [
        dateText,
        (s['examTime'] ?? '').toString(),
        (s['subjectCode'] ?? '').toString(),
        (s['subjectName'] ?? '').toString(),
      ];
    }).toList();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        build: (context) => [
          pw.Container(
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey700, width: 1),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                pw.Padding(
                  padding: const pw.EdgeInsets.all(8),
                  child: pw.Column(
                    children: [
                      pw.Text(
                        'SRU SMART CAMPUS APP',
                        style: pw.TextStyle(
                          fontSize: 18,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        examLabel,
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                pw.Container(
                  color: PdfColors.grey300,
                  padding: const pw.EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  child: pw.Row(
                    children: [
                      pw.Expanded(
                        child: pw.Text(
                          branch,
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                      ),
                      pw.Text(
                        'HALLTICKET',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(8),
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            _pdfInfoRow('Hall Ticket No', rollNo),
                            _pdfInfoRow('Name', studentName.toUpperCase()),
                            _pdfInfoRow(
                                'Father\'s Name', fatherName.toUpperCase()),
                            _pdfInfoRow('Regular/Supplementary', 'REGULAR'),
                          ],
                        ),
                      ),
                      pw.Container(
                        width: 80,
                        height: 95,
                        alignment: pw.Alignment.center,
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(color: PdfColors.grey700),
                        ),
                        child: photoProvider == null
                            ? pw.Text('PHOTO',
                                style: const pw.TextStyle(fontSize: 10))
                            : pw.Image(photoProvider, fit: pw.BoxFit.cover),
                      ),
                    ],
                  ),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 8),
                  child: pw.Table.fromTextArray(
                    headers: const [
                      'Date',
                      'Time',
                      'Course Code',
                      'Courses Registered'
                    ],
                    data: tableRows,
                    headerStyle: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 9,
                    ),
                    cellStyle: const pw.TextStyle(fontSize: 9),
                    cellAlignment: pw.Alignment.centerLeft,
                    border: pw.TableBorder.all(
                        color: PdfColors.grey700, width: 0.6),
                    columnWidths: {
                      0: const pw.FlexColumnWidth(1.1),
                      1: const pw.FlexColumnWidth(1.9),
                      2: const pw.FlexColumnWidth(1.4),
                      3: const pw.FlexColumnWidth(3.8),
                    },
                  ),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.fromLTRB(8, 12, 8, 8),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Signature of Candidate',
                          style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold, fontSize: 10)),
                      pw.Text('Controller of Examinations',
                          style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold, fontSize: 10)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 10),
          pw.Text('***INSTRUCTIONS TO THE CANDIDATES***',
              textAlign: pw.TextAlign.center,
              style:
                  pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
          pw.SizedBox(height: 6),
          ..._hallticketInstructions.map(
            (line) => pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 3),
              child: pw.Text(line, style: const pw.TextStyle(fontSize: 8.5)),
            ),
          ),
        ],
      ),
    );

    return doc.save();
  }

  Future<void> _loadHallticket() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final student = await _fetchStudentData();
      if (student == null) {
        throw Exception('Student details not found');
      }

      final branch =
          (student['branch'] ?? student['department'] ?? student['dept'] ?? '')
              .toString()
              .trim()
              .toUpperCase();
      if (branch.isEmpty) {
        throw Exception('Student branch not available');
      }

      final release = await _fetchLatestReleasedHallticket(branch);
      if (release == null) {
        throw Exception('Hallticket not released yet for your branch');
      }

      final bytes =
          await _buildHallticketPdf(student: student, release: release);

      if (!mounted) return;
      setState(() {
        _studentData = student;
        _releaseData = release;
        _pdfBytes = bytes;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _downloadHallticket() async {
    final bytes = _pdfBytes;
    if (bytes == null) return;

    final dir = await getApplicationDocumentsDirectory();
    final fileName =
        'Hallticket_${_rollNo}_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf';
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(bytes, flush: true);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Hallticket saved: ${file.path}'),
        action: SnackBarAction(
          label: 'Share',
          onPressed: () {
            Printing.sharePdf(bytes: bytes, filename: fileName);
          },
        ),
      ),
    );
  }

  Future<void> _printHallticket() async {
    final bytes = _pdfBytes;
    if (bytes == null) return;
    await Printing.layoutPdf(onLayout: (_) async => bytes);
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hallticket'),
        backgroundColor: const Color(0xFF1e3a5f),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: _pdfBytes == null ? null : _downloadHallticket,
            tooltip: 'Download Hallticket',
          ),
          IconButton(
            icon: const Icon(Icons.print),
            onPressed: _pdfBytes == null ? null : _printHallticket,
            tooltip: 'Print Hallticket',
          ),
        ],
      ),
      body: Column(
        children: [
          const AppHeader(showBack: false),
          Expanded(
            child: Padding(
              padding: EdgeInsets.all(isMobile ? 12 : 16),
              child: _buildBody(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_pdfBytes == null) {
      return _buildNoDataMessage(context);
    }

    return _buildPdfViewer(context);
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
              'Hallticket Not Available',
              style: TextStyle(
                fontSize: isMobile ? 16 : 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              _errorMessage ??
                  'Hallticket is not released yet for your branch.\nPlease check back later.',
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
                _loadHallticket();
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
    final studentName = (_studentData?['name'] ?? '').toString();
    final branch = (_studentData?['branch'] ??
            _studentData?['department'] ??
            _studentData?['dept'] ??
            '')
        .toString()
        .toUpperCase();

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
            decoration: const BoxDecoration(
              color: Color(0xFF1e3a5f),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(7),
                topRight: Radius.circular(7),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Hallticket - $branch',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isMobile ? 13 : 15,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.download, color: Colors.white),
                      onPressed: _downloadHallticket,
                      tooltip: 'Download PDF',
                    ),
                    IconButton(
                      icon: const Icon(Icons.print, color: Colors.white),
                      onPressed: _printHallticket,
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
                  height: isMobile ? 520 : 640,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[400]!),
                    borderRadius: BorderRadius.circular(4),
                    color: Colors.white,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: SfPdfViewer.memory(_pdfBytes!),
                  ),
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
                        'Hallticket Information',
                        style: TextStyle(
                          fontSize: isMobile ? 12 : 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[900],
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildPdfInfoRow('Hall Ticket No',
                          _rollNo.isEmpty ? 'N/A' : _rollNo, isMobile),
                      _buildPdfInfoRow('Student',
                          studentName.isEmpty ? 'N/A' : studentName, isMobile),
                      _buildPdfInfoRow(
                          'Branch', branch.isEmpty ? 'N/A' : branch, isMobile),
                      _buildPdfInfoRow(
                          'Subjects',
                          ((_releaseData?['subjectCount'] ?? 0).toString()),
                          isMobile),
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

  pw.Widget _pdfInfoRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        children: [
          pw.SizedBox(
            width: 100,
            child: pw.Text(label,
                style:
                    pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
          ),
          pw.Text(': ', style: const pw.TextStyle(fontSize: 9)),
          pw.Expanded(
              child: pw.Text(value, style: const pw.TextStyle(fontSize: 9))),
        ],
      ),
    );
  }

  static const List<String> _hallticketInstructions = [
    '1. Candidate must carry Hall Ticket and ID Card to the exam hall.',
    '2. Reach the exam hall at least 30 minutes before exam commencement.',
    '3. Mobile phones, smart watches and electronic gadgets are not allowed.',
    '4. Follow invigilator instructions and maintain discipline.',
    '5. Candidates are responsible for verifying subject code and timing.',
    '6. University reserves the right to change schedule in exceptional cases.',
    '7. Any malpractice leads to cancellation of examination.',
    '8. Preserve this hallticket until completion of all examinations.',
  ];
}
