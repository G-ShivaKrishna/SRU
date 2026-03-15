import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

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
  List<Map<String, dynamic>> _availableReleases = [];
  List<Map<String, dynamic>> _schedules = [];
  Uint8List? _pdfBytes;

  String? _selectedYear;
  String _selectedExamType = 'regular';
  bool _isApplyingFilter = false;

  static const List<String> _examTypeValues = [
    'mid',
    'makeupmid',
    'supply',
    'regular',
  ];

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

  String _normalizedSemester(String value) {
    final raw = value.trim();
    if (raw.isEmpty) return '';
    final u = raw.toUpperCase();
    if (u == 'I' || u == 'SEM I' || u == 'SEMESTER I') return '1';
    if (u == 'II' || u == 'SEM II' || u == 'SEMESTER II') return '2';
    final n = int.tryParse(raw);
    if (n == null || n <= 0) return raw;
    return (((n - 1) % 2) + 1).toString();
  }

  String _normalizedYear({String? year, String? semester}) {
    final y = (year ?? '').trim();
    final yNum = int.tryParse(y);
    if (yNum != null && yNum > 0) return yNum.toString();

    final sNum = int.tryParse((semester ?? '').trim());
    if (sNum != null && sNum > 0) {
      return (((sNum - 1) ~/ 2) + 1).toString();
    }
    return '';
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

  Future<List<Map<String, dynamic>>> _fetchReleasedHalltickets(
    String branch,
  ) async {
    if (branch.isEmpty) return const [];

    QuerySnapshot snap;
    try {
      snap = await _firestore
          .collection('hallticketReleases')
          .where('branch', isEqualTo: branch)
          .where('status', isEqualTo: 'released')
          .get();
    } catch (_) {
      return const [];
    }

    if (snap.docs.isEmpty) return const [];

    final docs = snap.docs
        .map((d) => Map<String, dynamic>.from(d.data() as Map<String, dynamic>))
        .toList();

    docs.sort((a, b) {
      final aTs = a['releasedAt'] as Timestamp?;
      final bTs = b['releasedAt'] as Timestamp?;
      if (aTs == null && bTs == null) return 0;
      if (aTs == null) return 1;
      if (bTs == null) return -1;
      return bTs.toDate().compareTo(aTs.toDate());
    });

    return docs;
  }

  Map<String, dynamic>? _pickRelease({
    required List<Map<String, dynamic>> releases,
    required String selectedType,
    String? selectedYear,
    String? semester,
  }) {
    if (releases.isEmpty) return null;

    String normType(String value) {
      final v = value.trim().toLowerCase().replaceAll(' ', '');
      if (v == 'makeup' || v == 'makeupmidexam' || v == 'makeup_mid') {
        return 'makeupmid';
      }
      return v;
    }

    final typeFiltered = releases.where((r) {
      final t = normType((r['examType'] ?? 'regular').toString());
      return t == selectedType;
    }).toList();

    if (typeFiltered.isEmpty) return null;

    var candidates = typeFiltered;

    if (selectedYear != null && selectedYear.isNotEmpty) {
      final yearFiltered = candidates.where((r) {
        final y = _normalizedYear(
          year: (r['year'] ?? '').toString(),
          semester: (r['semester'] ?? '').toString(),
        );
        return y == selectedYear;
      }).toList();
      if (yearFiltered.isNotEmpty) {
        candidates = yearFiltered;
      }
    }

    if (semester != null && semester.isNotEmpty) {
      final semFiltered = candidates.where((r) {
        final s = _normalizedSemester((r['semester'] ?? '').toString());
        return s == semester;
      }).toList();
      if (semFiltered.isNotEmpty) {
        candidates = semFiltered;
      }
    }

    return candidates.first;
  }

  List<String> _extractAvailableYears(List<Map<String, dynamic>> releases) {
    final years = releases
        .map((r) => _normalizedYear(
              year: (r['year'] ?? '').toString(),
              semester: (r['semester'] ?? '').toString(),
            ))
        .where((y) => y.isNotEmpty)
        .toSet()
        .toList()
      ..sort((a, b) => (int.tryParse(b) ?? 0).compareTo(int.tryParse(a) ?? 0));
    return years;
  }

  List<Map<String, dynamic>> _sortedSchedules(Map<String, dynamic> release) {
    final list =
        List<Map<String, dynamic>>.from(release['schedules'] ?? []);
    list.sort((a, b) {
      final aTs = a['examDateTime'] as Timestamp?;
      final bTs = b['examDateTime'] as Timestamp?;
      if (aTs == null && bTs == null) return 0;
      if (aTs == null) return 1;
      if (bTs == null) return -1;
      return aTs.toDate().compareTo(bTs.toDate());
    });
    return list;
  }

  Future<List<Map<String, dynamic>>> _registeredOnlySchedules({
    required Map<String, dynamic> student,
    required List<Map<String, dynamic>> schedules,
    required String selectedYear,
    required String selectedSemester,
  }) async {
    if (schedules.isEmpty) return const [];

    final studentId =
        (student['hallTicketNumber'] ?? student['rollNo'] ?? _rollNo)
            .toString()
            .trim();
    if (studentId.isEmpty) return schedules;

    final selSnap = await _firestore
        .collection('studentSubjectSelections')
        .where('studentId', isEqualTo: studentId)
        .get();

    if (selSnap.docs.isEmpty) return schedules;

    Map<String, dynamic>? matched;
    for (final doc in selSnap.docs) {
      final d = doc.data();
      final y = _normalizedYear(
        year: (d['year'] ?? '').toString(),
        semester: (d['semester'] ?? '').toString(),
      );
      final s = _normalizedSemester((d['semester'] ?? '').toString());
      if (y == selectedYear && s == selectedSemester) {
        matched = d;
        break;
      }
    }
    matched ??= selSnap.docs.last.data();

    final ids = <String>{
      ...List<String>.from(matched['coreSubjectIds'] ?? const []),
      ...List<String>.from(matched['selectedOEIds'] ?? const []),
      ...List<String>.from(matched['selectedPEIds'] ?? const []),
    }..removeWhere((e) => e.trim().isEmpty);

    if (ids.isEmpty) return const [];

    final registeredCodes = <String>{};
    final idList = ids.toList();
    for (int i = 0; i < idList.length; i += 10) {
      final chunk = idList.sublist(i, i + 10 > idList.length ? idList.length : i + 10);
      final subjectsSnap = await _firestore
          .collection('subjects')
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
      for (final doc in subjectsSnap.docs) {
        final code =
            (doc.data()['code'] ?? doc.data()['subjectCode'] ?? '').toString();
        if (code.trim().isNotEmpty) registeredCodes.add(code.trim().toUpperCase());
      }
    }

    final filtered = schedules.where((s) {
      final sid = (s['subjectId'] ?? '').toString().trim();
      final scode = (s['subjectCode'] ?? '').toString().trim().toUpperCase();
      return ids.contains(sid) || (scode.isNotEmpty && registeredCodes.contains(scode));
    }).toList();

    return filtered;
  }

  Future<Uint8List> _buildHallticketPdf({
    required Map<String, dynamic> student,
    required Map<String, dynamic> release,
    required List<Map<String, dynamic>> schedules,
    required String examType,
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

    final releasedTs = release['releasedAt'] as Timestamp?;
    final releasedDate = releasedTs?.toDate();
    final examSession = releasedDate == null
        ? 'EXAMINATION'
        : DateFormat('MMM yyyy').format(releasedDate).toUpperCase();

    // Load app logo from assets
    pw.ImageProvider? logoProvider;
    try {
      final logoData =
          await rootBundle.load('assets/images/logo.png');
      logoProvider = pw.MemoryImage(logoData.buffer.asUint8List());
    } catch (_) {
      // Logo not critical; fall back gracefully.
    }

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
        margin: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        build: (context) => [
          // ── Outer border card ─────────────────────────────────────────────
          pw.Container(
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.blueGrey800, width: 1.2),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                // ── University header ─────────────────────────────────────
                pw.Container(
                  color: const PdfColor.fromInt(0xFF1e3a5f),
                  padding: const pw.EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      // Logo
                      pw.Container(
                        width: 52,
                        height: 52,
                        decoration: pw.BoxDecoration(
                          color: PdfColors.white,
                          borderRadius: const pw.BorderRadius.all(
                              pw.Radius.circular(4)),
                        ),
                        padding: const pw.EdgeInsets.all(3),
                        child: logoProvider != null
                            ? pw.Image(logoProvider, fit: pw.BoxFit.contain)
                            : pw.Center(
                                child: pw.Text('SRU',
                                    style: pw.TextStyle(
                                        fontWeight: pw.FontWeight.bold,
                                        fontSize: 11,
                                        color: const PdfColor.fromInt(
                                            0xFF1e3a5f)))),
                      ),
                      pw.SizedBox(width: 12),
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              'SR UNIVERSITY',
                              style: pw.TextStyle(
                                fontSize: 20,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.white,
                                letterSpacing: 1.5,
                              ),
                            ),
                            pw.Text(
                              'Hanmakonda - 506 371, Telangana State, INDIA',
                              style: const pw.TextStyle(
                                  fontSize: 9, color: PdfColors.white),
                            ),
                          ],
                        ),
                      ),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text(
                            'HALL TICKET',
                            style: pw.TextStyle(
                              fontSize: 13,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.white,
                              letterSpacing: 2,
                            ),
                          ),
                          pw.Text(
                            examSession,
                            style: const pw.TextStyle(
                                fontSize: 9, color: PdfColors.white),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // ── Branch band ───────────────────────────────────────────
                pw.Container(
                  color: PdfColors.blueGrey100,
                  padding: const pw.EdgeInsets.symmetric(
                      horizontal: 12, vertical: 5),
                  child: pw.Text(
                    '$branch  —  THEORY EXAMINATIONS',
                    style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold, fontSize: 9.5),
                  ),
                ),
                // ── Student details + photo ───────────────────────────────
                pw.Padding(
                  padding: const pw.EdgeInsets.all(10),
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            _pdfInfoRow('Hall Ticket No', rollNo),
                            _pdfInfoRow(
                                'Name of Candidate', studentName.toUpperCase()),
                            _pdfInfoRow(
                                'Father\'s Name', fatherName.toUpperCase()),
                            _pdfInfoRow('Branch / Dept', branch),
                            _pdfInfoRow('Type', examType.toUpperCase()),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // ── Divider ───────────────────────────────────────────────
                pw.Divider(color: PdfColors.blueGrey300, thickness: 0.7),
                // ── Exam schedule table ───────────────────────────────────
                pw.Padding(
                  padding: const pw.EdgeInsets.fromLTRB(10, 4, 10, 0),
                  child: pw.Text(
                    'EXAMINATION SCHEDULE',
                    style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 9.5,
                        letterSpacing: 0.5),
                  ),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.fromLTRB(10, 6, 10, 10),
                  child: pw.Table(
                    border: pw.TableBorder.all(
                        color: PdfColors.blueGrey400, width: 0.5),
                    columnWidths: const {
                      0: pw.FlexColumnWidth(2.8),
                      1: pw.FlexColumnWidth(2.4),
                      2: pw.FlexColumnWidth(2.0),
                      3: pw.FlexColumnWidth(4.5),
                    },
                    children: [
                      // Header row
                      pw.TableRow(
                        decoration: const pw.BoxDecoration(
                            color: PdfColor.fromInt(0xFF1e3a5f)),
                        children: [
                          'Date',
                          'Time',
                          'Course Code',
                          'Course Name',
                        ]
                            .map(
                              (h) => pw.Padding(
                                padding: const pw.EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 5),
                                child: pw.Text(h,
                                    style: pw.TextStyle(
                                        fontWeight: pw.FontWeight.bold,
                                        fontSize: 8.5,
                                        color: PdfColors.white)),
                              ),
                            )
                            .toList(),
                      ),
                      // Data rows
                      ...tableRows.asMap().entries.map((entry) {
                        final isEven = entry.key.isEven;
                        return pw.TableRow(
                          decoration: pw.BoxDecoration(
                            color: isEven
                                ? PdfColors.white
                                : PdfColors.blueGrey50,
                          ),
                          children: entry.value
                              .map(
                                (cell) => pw.Padding(
                                  padding: const pw.EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 4),
                                  child: pw.Text(cell,
                                      style:
                                          const pw.TextStyle(fontSize: 8.5)),
                                ),
                              )
                              .toList(),
                        );
                      }),
                      if (tableRows.isEmpty)
                        pw.TableRow(children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text('No schedule available.',
                                style: const pw.TextStyle(
                                    fontSize: 8.5,
                                    color: PdfColors.grey)),
                          ),
                          for (var _ in List.generate(3, (_) => null))
                            pw.SizedBox(),
                        ]),
                    ],
                  ),
                ),
                // ── Signature row ─────────────────────────────────────────
                pw.Container(
                  color: PdfColors.blueGrey50,
                  padding:
                      const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.center,
                        children: [
                          pw.Container(
                              width: 100,
                              height: 0.5,
                              color: PdfColors.black),
                          pw.SizedBox(height: 2),
                          pw.Text('Signature of Candidate',
                              style: pw.TextStyle(
                                  fontWeight: pw.FontWeight.bold,
                                  fontSize: 8.5)),
                        ],
                      ),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.center,
                        children: [
                          pw.Container(
                              width: 120,
                              height: 0.5,
                              color: PdfColors.black),
                          pw.SizedBox(height: 2),
                          pw.Text('Controller of Examinations',
                              style: pw.TextStyle(
                                  fontWeight: pw.FontWeight.bold,
                                  fontSize: 8.5)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 14),
          // ── Instructions ─────────────────────────────────────────────────
          pw.Container(
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.blueGrey300, width: 0.7),
            ),
            padding: const pw.EdgeInsets.all(10),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Center(
                  child: pw.Text(
                    '★  INSTRUCTIONS TO THE CANDIDATES  ★',
                    style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold, fontSize: 9.5),
                  ),
                ),
                pw.SizedBox(height: 6),
                ..._hallticketInstructions.map(
                  (line) => pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 3),
                    child:
                        pw.Text(line, style: const pw.TextStyle(fontSize: 8.5)),
                  ),
                ),
              ],
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

      final studentYear =
          _normalizedYear(
            year: (student['year'] ?? student['currentYear'] ?? '').toString(),
            semester:
              (student['semester'] ?? student['currentSemester'] ?? '')
                .toString());
        final studentSem = _normalizedSemester(
          (student['semester'] ?? student['currentSemester'] ?? '')
            .toString());

      final releases = await _fetchReleasedHalltickets(branch);
      if (releases.isEmpty) {
        throw Exception('Hallticket not released yet for your branch');
      }

      final years = _extractAvailableYears(releases);
      if ((_selectedYear == null || _selectedYear!.isEmpty) &&
          studentYear.isNotEmpty &&
          years.contains(studentYear)) {
        _selectedYear = studentYear;
      } else if ((_selectedYear == null || _selectedYear!.isEmpty) &&
          years.isNotEmpty) {
        _selectedYear = years.first;
      }

      final release = _pickRelease(
        releases: releases,
        selectedType: _selectedExamType,
        selectedYear: _selectedYear,
        semester: studentSem,
      );
      if (release == null) {
        throw Exception(
            'No hallticket available for selected year and exam type');
      }

      final sorted = _sortedSchedules(release);
      final registeredOnly = await _registeredOnlySchedules(
        student: student,
        schedules: sorted,
        selectedYear: _selectedYear ?? studentYear,
        selectedSemester: studentSem,
      );

      if (registeredOnly.isEmpty) {
        throw Exception(
            'No registered subjects found for your selected hallticket term');
      }

      final bytes = await _buildHallticketPdf(
        student: student,
        release: release,
        schedules: registeredOnly,
        examType: _selectedExamType,
      );

      if (!mounted) return;
      setState(() {
        _studentData = student;
        _availableReleases = releases;
        _releaseData = release;
        _schedules = registeredOnly;
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

  Future<void> _applySelectionFilter() async {
    if (_isApplyingFilter || _studentData == null) return;
    final student = _studentData!;
    final branch =
        (student['branch'] ?? student['department'] ?? student['dept'] ?? '')
            .toString()
            .trim()
            .toUpperCase();
    final sem =
      _normalizedSemester(
        (student['semester'] ?? student['currentSemester'] ?? '')
          .toString());

    setState(() {
      _isApplyingFilter = true;
      _errorMessage = null;
    });

    try {
      final releases = _availableReleases.isNotEmpty
          ? _availableReleases
          : await _fetchReleasedHalltickets(branch);

      final release = _pickRelease(
        releases: releases,
        selectedType: _selectedExamType,
        selectedYear: _selectedYear,
        semester: sem,
      );
      if (release == null) {
        throw Exception('No hallticket found for selected filter');
      }

      final sorted = _sortedSchedules(release);
      final registeredOnly = await _registeredOnlySchedules(
        student: student,
        schedules: sorted,
        selectedYear: _selectedYear ??
            _normalizedYear(
              year: (student['year'] ?? student['currentYear'] ?? '').toString(),
              semester:
                  (student['semester'] ?? student['currentSemester'] ?? '')
                      .toString(),
            ),
        selectedSemester: sem,
      );

      if (registeredOnly.isEmpty) {
        throw Exception('No registered subjects found for selected filter');
      }

      final bytes = await _buildHallticketPdf(
        student: student,
        release: release,
        schedules: registeredOnly,
        examType: _selectedExamType,
      );

      if (!mounted) return;
      setState(() {
        _releaseData = release;
        _schedules = registeredOnly;
        _pdfBytes = bytes;
        _isApplyingFilter = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _releaseData = null;
        _schedules = [];
        _pdfBytes = null;
        _isApplyingFilter = false;
      });
    }
  }

  // ── Saved-file management ─────────────────────────────────────────────────

  Future<List<File>> _listSavedHalltickets() async {
    final dir = await getApplicationDocumentsDirectory();
    final prefix = 'Hallticket_${_rollNo}_';
    try {
      return dir
          .listSync()
          .whereType<File>()
          .where((f) =>
              f.path.split('/').last.startsWith(prefix) &&
              f.path.endsWith('.pdf'))
          .toList()
        ..sort((a, b) => b.path.compareTo(a.path));
    } catch (_) {
      return [];
    }
  }

  Future<void> _manageSavedFiles() async {
    final files = await _listSavedHalltickets();
    if (!mounted) return;

    if (files.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No saved hall ticket files found.')),
      );
      return;
    }

    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(12))),
      builder: (_) => _SavedFilesSheet(
        files: files,
        onDeleted: () {
          if (mounted) setState(() {});
        },
      ),
    );
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
        content: Text('Saved: ${file.path}'),
        action: SnackBarAction(
          label: 'Share',
          onPressed: () =>
              Printing.sharePdf(bytes: bytes, filename: fileName),
        ),
      ),
    );
  }

  Future<void> _printHallticket() async {
    final bytes = _pdfBytes;
    if (bytes == null) return;
    await Printing.layoutPdf(onLayout: (_) async => bytes);
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Flutter UI
  // ──────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F0F0),
      appBar: AppBar(
        title: const Text('Hall Ticket'),
        backgroundColor: const Color(0xFF1e3a5f),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.folder_outlined),
            onPressed: _manageSavedFiles,
            tooltip: 'Manage saved files',
          ),
          if (_pdfBytes != null) ...[
            IconButton(
              icon: const Icon(Icons.download_outlined),
              onPressed: _downloadHallticket,
              tooltip: 'Download PDF',
            ),
            IconButton(
              icon: const Icon(Icons.print_outlined),
              onPressed: _printHallticket,
              tooltip: 'Print',
            ),
          ],
        ],
      ),
      body: Column(
        children: [
          const AppHeader(showBack: false),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading || _isApplyingFilter) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_studentData == null || _releaseData == null) {
      return _buildEmptyState();
    }
    return _buildHallticketDocument();
  }

  // ── Empty / error state ──────────────────────────────────────────────────

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_busy_outlined, size: 90, color: Colors.grey[400]),
            const SizedBox(height: 20),
            Text(
              'Hall Ticket Not Available',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[700]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              _errorMessage ??
                  'Hall ticket has not been released yet.\nPlease check back later.',
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1e3a5f),
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
              ),
              onPressed: _loadHallticket,
              icon: const Icon(Icons.refresh, color: Colors.white),
              label: const Text('Refresh',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  // ── Main hallticket document card ────────────────────────────────────────

  Widget _buildHallticketDocument() {
    final student = _studentData!;
    final release = _releaseData!;

    final studentName = (student['name'] ?? 'N/A').toString().toUpperCase();
    final fatherName =
        ((student['fatherName'] ?? student['fathername'] ?? 'N/A'))
            .toString()
            .toUpperCase();
    final branch =
        (student['branch'] ?? student['department'] ?? student['dept'] ?? 'N/A')
            .toString()
            .toUpperCase();
    final rollNo =
        (student['hallTicketNumber'] ?? _rollNo).toString().toUpperCase();

    final releasedTs = release['releasedAt'] as Timestamp?;
    final releasedDate = releasedTs?.toDate();
    final examSession = releasedDate == null
        ? 'EXAMINATION'
        : DateFormat('MMM yyyy').format(releasedDate).toUpperCase();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: Column(
            children: [
              _buildSelectionBar(student),
              const SizedBox(height: 12),
              // ── Document card ──────────────────────────────────────────
              Container(
                color: Colors.white,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // University header
                    _buildUniversityHeader(branch, examSession),
                    // Student details block
                    _buildStudentDetailsBlock(
                        rollNo, studentName, fatherName, branch),
                    // Schedule table
                    _buildScheduleTable(),
                    // Signatures
                    _buildSignatureRow(),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // ── Instructions card ──────────────────────────────────────
              _buildInstructionsCard(),
              const SizedBox(height: 16),
              // ── Action buttons ─────────────────────────────────────────
              _buildActionButtons(),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSelectionBar(Map<String, dynamic> student) {
    final years = _extractAvailableYears(_availableReleases);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.blueGrey.shade100),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 180,
            child: DropdownButtonFormField<String>(
              value: (_selectedYear != null && years.contains(_selectedYear))
                  ? _selectedYear
                  : null,
              isDense: true,
              decoration: const InputDecoration(
                labelText: 'Year',
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              ),
              items: years
                  .map((y) => DropdownMenuItem(value: y, child: Text('Year $y')))
                  .toList(),
              onChanged: (v) {
                if (v == null) return;
                setState(() => _selectedYear = v);
                _applySelectionFilter();
              },
            ),
          ),
          SizedBox(
            width: 220,
            child: DropdownButtonFormField<String>(
              value: _selectedExamType,
              isDense: true,
              decoration: const InputDecoration(
                labelText: 'Exam Type',
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              ),
              items: _examTypeValues
                  .map(
                    (e) => DropdownMenuItem(
                      value: e,
                      child: Text(_displayExamType(e)),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                if (v == null) return;
                setState(() => _selectedExamType = v);
                _applySelectionFilter();
              },
            ),
          ),
        ],
      ),
    );
  }

  String _displayExamType(String value) {
    switch (value) {
      case 'mid':
        return 'Mid';
      case 'makeupmid':
        return 'Makeup Mid';
      case 'supply':
        return 'Supply';
      default:
        return 'Regular';
    }
  }

  Widget _buildUniversityHeader(String branch, String examSession) {
    return Container(
      color: const Color(0xFF1e3a5f),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // App logo
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
            ),
            padding: const EdgeInsets.all(4),
            child: Image.asset(
              'assets/images/logo.png',
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Center(
                child: Text('SRU',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: Color(0xFF1e3a5f))),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'SR UNIVERSITY',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Hanmakonda - 506 371, Telangana State, INDIA',
                  style:
                      TextStyle(fontSize: 11, color: Colors.white70),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text(
                'HALL TICKET',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 2),
              ),
              const SizedBox(height: 2),
              Text(
                examSession,
                style:
                    const TextStyle(fontSize: 11, color: Colors.white70),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStudentDetailsBlock(
      String rollNo, String name, String fatherName, String branch) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Branch band
        Container(
          color: const Color(0xFFECEFF1),
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Text(
            '$branch  —  THEORY EXAMINATIONS',
            style: const TextStyle(
                fontWeight: FontWeight.bold, fontSize: 12),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Details table
              Expanded(
                child: Column(
                  children: [
                    _detailRow('Hall Ticket No', rollNo),
                    _detailRow('Name of Candidate', name),
                    _detailRow('Father\'s Name', fatherName),
                    _detailRow('Branch / Department', branch),
                    _detailRow('Type', 'REGULAR'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 160,
            child: Text(
              label,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87),
            ),
          ),
          const Text(': ',
              style:
                  TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleTable() {
    const headerStyle = TextStyle(
        fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white);
    const cellStyle = TextStyle(fontSize: 12);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          color: const Color(0xFFECEFF1),
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: const Text(
            'EXAMINATION SCHEDULE',
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                letterSpacing: 0.5),
          ),
        ),
        Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Table(
            border: TableBorder.all(
                color: Colors.blueGrey.shade200, width: 0.8),
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            columnWidths: const {
              0: FlexColumnWidth(2.8),
              1: FlexColumnWidth(2.4),
              2: FlexColumnWidth(2.0),
              3: FlexColumnWidth(4.5),
            },
            children: [
              // Header
              TableRow(
                decoration:
                    const BoxDecoration(color: Color(0xFF1e3a5f)),
                children: [
                  'Date',
                  'Time',
                  'Course Code',
                  'Course Name',
                ]
                    .map((h) => Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 8),
                          child: Text(h, style: headerStyle),
                        ))
                    .toList(),
              ),
              // Data
              ..._schedules.asMap().entries.map((entry) {
                final i = entry.key;
                final s = entry.value;
                final ts = s['examDateTime'] as Timestamp?;
                final dt = ts?.toDate();
                final dateText = dt == null
                    ? (s['examDate'] ?? '').toString()
                    : DateFormat('dd/MM/yyyy').format(dt);
                final bg = i.isEven
                    ? Colors.white
                    : const Color(0xFFF5F7FA);
                return TableRow(
                  decoration: BoxDecoration(color: bg),
                  children: [
                    dateText,
                    (s['examTime'] ?? '').toString(),
                    (s['subjectCode'] ?? '').toString(),
                    (s['subjectName'] ?? '').toString(),
                  ]
                      .map((cell) => Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 7),
                            child: Text(cell, style: cellStyle),
                          ))
                      .toList(),
                );
              }),
              if (_schedules.isEmpty)
                TableRow(children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text('No schedule available.',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey[500])),
                  ),
                  const SizedBox(),
                  const SizedBox(),
                  const SizedBox(),
                ]),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSignatureRow() {
    return Container(
      color: const Color(0xFFF5F7FA),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _signatureBlock('Signature of Candidate'),
          _signatureBlock('Controller of Examinations'),
        ],
      ),
    );
  }

  Widget _signatureBlock(String label) {
    return Column(
      children: [
        Container(width: 120, height: 1, color: Colors.black54),
        const SizedBox(height: 4),
        Text(label,
            style: const TextStyle(
                fontWeight: FontWeight.w600, fontSize: 11)),
      ],
    );
  }

  Widget _buildInstructionsCard() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.blueGrey.shade200),
        borderRadius: BorderRadius.circular(4),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Center(
            child: Text(
              '★  INSTRUCTIONS TO THE CANDIDATES  ★',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  letterSpacing: 0.5),
            ),
          ),
          const SizedBox(height: 10),
          ..._hallticketInstructions.map(
            (line) => Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child:
                  Text(line, style: const TextStyle(fontSize: 12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1e3a5f),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6)),
            ),
            onPressed: _pdfBytes == null ? null : _downloadHallticket,
            icon: const Icon(Icons.download_outlined,
                color: Colors.white),
            label: const Text('Download PDF',
                style: TextStyle(color: Colors.white, fontSize: 14)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              side: const BorderSide(color: Color(0xFF1e3a5f), width: 1.5),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6)),
            ),
            onPressed: _pdfBytes == null ? null : _printHallticket,
            icon: const Icon(Icons.print_outlined,
                color: Color(0xFF1e3a5f)),
            label: const Text('Print',
                style: TextStyle(
                    color: Color(0xFF1e3a5f), fontSize: 14)),
          ),
        ),
      ],
    );
  }

  // ── PDF helper ───────────────────────────────────────────────────────────

  pw.Widget _pdfInfoRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2.5),
      child: pw.Row(
        children: [
          pw.SizedBox(
            width: 110,
            child: pw.Text(label,
                style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold, fontSize: 9)),
          ),
          pw.Text(': ', style: const pw.TextStyle(fontSize: 9)),
          pw.Expanded(
              child: pw.Text(value,
                  style: const pw.TextStyle(fontSize: 9))),
        ],
      ),
    );
  }

  List<String> get _hallticketInstructions => const [
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

// ─────────────────────────────────────────────────────────────────────────────
// Bottom sheet — manage saved hall ticket PDF files
// ─────────────────────────────────────────────────────────────────────────────

class _SavedFilesSheet extends StatefulWidget {
  final List<File> files;
  final VoidCallback onDeleted;

  const _SavedFilesSheet({required this.files, required this.onDeleted});

  @override
  State<_SavedFilesSheet> createState() => _SavedFilesSheetState();
}

class _SavedFilesSheetState extends State<_SavedFilesSheet> {
  late List<File> _files;

  @override
  void initState() {
    super.initState();
    _files = List.from(widget.files);
  }

  String _fmtSize(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }

  Future<void> _delete(File file) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete File'),
        content: Text(
            'Delete "${file.path.split('/').last}"?\nThis cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete',
                  style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await file.delete();
      setState(() => _files.remove(file));
      widget.onDeleted();
      if (_files.isEmpty && mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not delete: $e')));
      }
    }
  }

  Future<void> _deleteAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete All Saved Files'),
        content: Text(
            'Delete all ${_files.length} saved hall ticket PDF(s)?\nThis cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete All',
                  style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmed != true) return;
    for (final f in List.from(_files)) {
      try {
        await f.delete();
        setState(() => _files.remove(f));
      } catch (_) {}
    }
    widget.onDeleted();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Expanded(
                  child: Text('Saved Hall Ticket Files',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15)),
                ),
                if (_files.isNotEmpty)
                  TextButton.icon(
                    onPressed: _deleteAll,
                    icon: const Icon(Icons.delete_sweep_outlined,
                        color: Colors.red, size: 18),
                    label: const Text('Delete All',
                        style: TextStyle(color: Colors.red, fontSize: 12)),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          ConstrainedBox(
            constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.45),
            child: _files.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(32),
                    child: Text('No saved files.',
                        style: TextStyle(color: Colors.grey)),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: _files.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final f = _files[i];
                      final name = f.path.split('/').last;
                      final size = _fmtSize(f.lengthSync());
                      return ListTile(
                        leading: const Icon(Icons.picture_as_pdf_outlined,
                            color: Color(0xFF1e3a5f)),
                        title: Text(name,
                            style: const TextStyle(fontSize: 13),
                            overflow: TextOverflow.ellipsis),
                        subtitle: Text(size,
                            style: const TextStyle(fontSize: 11)),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline,
                              color: Colors.red),
                          tooltip: 'Delete',
                          onPressed: () => _delete(f),
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
