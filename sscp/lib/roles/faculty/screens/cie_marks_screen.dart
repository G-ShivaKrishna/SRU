import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' as excel_package;
import 'dart:io' show Directory, File, Platform;
import 'dart:typed_data';
import 'dart:convert' show utf8;
import '../../../widgets/app_header.dart';

// Web-only import for file download
import 'dart:html' as html show Blob, Url, AnchorElement;

// For web: conditional import
export 'dart:html' if (dart.library.io) 'dart:convert';

// ─── Models ────────────────────────────────────────────────────────────────────

class _CieAssignment {
  final String docId;
  final String subjectCode;
  final String subjectName;
  final String department;
  final List<String> batches;
  final String academicYear;
  final String semester;
  final int year;

  const _CieAssignment({
    required this.docId,
    required this.subjectCode,
    required this.subjectName,
    required this.department,
    required this.batches,
    required this.academicYear,
    required this.semester,
    required this.year,
  });
}

class _Component {
  final String name;
  final int maxMarks;
  final String type;
  const _Component(
      {required this.name, required this.maxMarks, required this.type});
}

class _StudentRow {
  final String studentId;
  final String studentName;
  // componentName → TextEditingController
  final Map<String, TextEditingController> controllers;
  bool isSaved;
  bool isSaving = false;

  _StudentRow({
    required this.studentId,
    required this.studentName,
    required this.controllers,
    this.isSaved = false,
  });

  int totalEntered(List<_Component> comps) {
    int t = 0;
    for (final c in comps) {
      t += int.tryParse(controllers[c.name]?.text ?? '') ?? 0;
    }
    return t;
  }

  bool hasAnyValue(List<_Component> comps) =>
      comps.any((c) => (controllers[c.name]?.text ?? '').isNotEmpty);

  void dispose() {
    for (final ctrl in controllers.values) {
      ctrl.dispose();
    }
  }
}

// ─── Screen ────────────────────────────────────────────────────────────────────

class CieMarksScreen extends StatefulWidget {
  const CieMarksScreen({super.key});

  @override
  State<CieMarksScreen> createState() => _CieMarksScreenState();
}

class _CieMarksScreenState extends State<CieMarksScreen> {
  final _auth = FirebaseAuth.instance;
  final _fs = FirebaseFirestore.instance;

  // ── Phase 1: selection ──────────────────
  bool _loadingAssignments = true;
  String? _assignmentError;
  List<_CieAssignment> _assignments = [];
  _CieAssignment? _selectedAssignment;
  String? _selectedBatch;

  // ── Phase 2: marks entry ────────────────
  bool _loadingMarks = false;
  String? _marksError;
  List<_Component> _components = [];
  List<_StudentRow> _studentRows = [];
  int _maxTotalMarks = 0;
  bool _marksLoaded = false;

  // save-all state
  bool _savingAll = false;
  bool _isUploadingExcel = false;

  @override
  void initState() {
    super.initState();
    _loadAssignments();
  }

  @override
  void dispose() {
    for (final row in _studentRows) {
      row.dispose();
    }
    super.dispose();
  }

  // ── Load assignments ──────────────────────────────────────────────────────

  Future<void> _loadAssignments() async {
    setState(() {
      _loadingAssignments = true;
      _assignmentError = null;
    });
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('Not logged in');
      final facultyId = user.email!.split('@')[0].toUpperCase();

      final snap = await _fs
          .collection('facultyAssignments')
          .where('facultyId', isEqualTo: facultyId)
          .get();

      final list = <_CieAssignment>[];
      for (final doc in snap.docs) {
        final d = doc.data();
        if ((d['isActive'] ?? true) == true) {
          list.add(_CieAssignment(
            docId: doc.id,
            subjectCode: d['subjectCode'] ?? '',
            subjectName: d['subjectName'] ?? '',
            department: d['department'] ?? '',
            batches: List<String>.from(d['assignedBatches'] ?? []),
            academicYear: d['academicYear'] ?? '',
            semester: d['semester'] ?? '',
            year: (d['year'] ?? 0) is int
                ? d['year']
                : int.tryParse(d['year'].toString()) ?? 0,
          ));
        }
      }

      if (!mounted) return;
      setState(() {
        _assignments = list;
        _loadingAssignments = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _assignmentError = e.toString();
        _loadingAssignments = false;
      });
    }
  }

  // ── Load students + marks ─────────────────────────────────────────────────

  Future<void> _loadMarksEntry() async {
    final assignment = _selectedAssignment;
    final batch = _selectedBatch;
    if (assignment == null || batch == null) return;

    // Dispose old rows
    for (final row in _studentRows) {
      row.dispose();
    }

    setState(() {
      _loadingMarks = true;
      _marksError = null;
      _marksLoaded = false;
      _studentRows = [];
    });

    try {
      // 1. Load marksDefinition for this assignment
      final defDoc =
          await _fs.collection('marksDefinition').doc(assignment.docId).get();
      if (!defDoc.exists) {
        setState(() {
          _marksError =
              'No marks format defined for this subject yet.\nGo to Marks Entry → Regular Exams → "Check & Define CIE Format" first.';
          _loadingMarks = false;
        });
        return;
      }
      final defData = defDoc.data()!;
      final compList = (defData['components'] as List<dynamic>? ?? [])
          .map((c) => _Component(
                name: c['name'] ?? '',
                maxMarks: (c['marks'] ?? 0) is int
                    ? c['marks']
                    : int.tryParse(c['marks'].toString()) ?? 0,
                type: c['type'] ?? 'internal',
              ))
          .toList();

      // 2. Get department from assignment and parse batchNumber from batch
      // Batch can be "B1", "CSE-A", "A", etc.
      // For "CSE-A" format: extract the section part after last hyphen
      // For "B1" or "A" format: use directly as batchNumber
      final dept = assignment.department;
      String batchNumber;
      if (batch.contains('-')) {
        // Format like "CSE-A" or "CSE-B1" - take the last part
        batchNumber = batch.split('-').last;
      } else {
        // Format like "B1" or "A" - use directly
        batchNumber = batch;
      }

      // 3. Load students: query by department, filter by batchNumber/section in Dart
      final studentSnap = await _fs
          .collection('students')
          .where('department', isEqualTo: dept)
          .get();

      final students = studentSnap.docs.where((doc) {
        final d = doc.data();
        // Check both batchNumber and section fields
        final bn = (d['batchNumber'] ?? '').toString();
        final section = (d['section'] ?? '').toString();
        final yr = (d['year'] ?? 0) is int
            ? d['year'] as int
            : int.tryParse(d['year'].toString()) ?? 0;
        final status = (d['status'] ?? 'active').toString();

        // Match if batchNumber OR section equals the batch identifier
        final batchMatch = bn == batchNumber ||
            section == batchNumber ||
            bn == batch ||
            section == batch;

        return batchMatch &&
            yr == assignment.year &&
            status != 'graduated' &&
            status != 'inactive';
      }).toList();

      // Sort by hallTicketNumber / doc ID
      students.sort((a, b) => a.id.compareTo(b.id));

      // 4. Load existing marks for this assignment (all batches, filter in Dart)
      final marksSnap = await _fs
          .collection('studentMarks')
          .where('assignmentId', isEqualTo: assignment.docId)
          .get();

      final existingMarks = <String, Map<String, dynamic>>{};
      for (final doc in marksSnap.docs) {
        final d = doc.data();
        if ((d['batch'] ?? '') == batch) {
          final sid = (d['studentId'] ?? '').toString();
          existingMarks[sid] =
              Map<String, dynamic>.from(d['componentMarks'] ?? {});
        }
      }

      // 5. Build rows
      final rows = students.map((doc) {
        final d = doc.data();
        final sid = doc.id;
        final name = (d['studentName'] ?? d['name'] ?? '').toString();
        final saved = existingMarks[sid];
        final controllers = <String, TextEditingController>{};
        for (final comp in compList) {
          final existing =
              saved != null ? (saved[comp.name] ?? '').toString() : '';
          controllers[comp.name] = TextEditingController(
              text: existing == '0' && saved == null
                  ? ''
                  : (existing == '0' ? '' : existing));
        }
        return _StudentRow(
          studentId: sid,
          studentName: name.isNotEmpty ? name : sid,
          controllers: controllers,
          isSaved: saved != null,
        );
      }).toList();

      if (!mounted) return;
      setState(() {
        _components = compList;
        _studentRows = rows;
        _maxTotalMarks = defData['totalMarks'] is int
            ? defData['totalMarks']
            : int.tryParse(defData['totalMarks'].toString()) ?? 0;
        _loadingMarks = false;
        _marksLoaded = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _marksError = e.toString();
        _loadingMarks = false;
      });
    }
  }

  // ── Save single student ───────────────────────────────────────────────────

  Future<void> _saveRow(_StudentRow row) async {
    final assignment = _selectedAssignment!;
    final batch = _selectedBatch!;
    setState(() => row.isSaving = true);
    try {
      final facultyId = _auth.currentUser!.email!.split('@')[0].toUpperCase();

      // Validate that assignment is still active before saving
      final assignDoc = await _fs
          .collection('facultyAssignments')
          .doc(assignment.docId)
          .get();
      if (!assignDoc.exists ||
          (assignDoc.data()?['isActive'] ?? true) != true) {
        throw Exception(
            'This course is no longer active. Students may have been promoted. Please refresh the page.');
      }

      final compMarks = <String, int>{};
      for (final c in _components) {
        compMarks[c.name] =
            int.tryParse(row.controllers[c.name]?.text ?? '') ?? 0;
      }
      final total = compMarks.values.fold(0, (s, v) => s + v);

      final docId =
          '${assignment.docId}_${batch.replaceAll('-', '_')}_${row.studentId}';
      await _fs.collection('studentMarks').doc(docId).set({
        'facultyId': facultyId,
        'assignmentId': assignment.docId,
        'subjectCode': assignment.subjectCode,
        'subjectName': assignment.subjectName,
        'academicYear': assignment.academicYear,
        'semester': assignment.semester,
        'year': assignment.year,
        'batch': batch,
        'studentId': row.studentId,
        'studentName': row.studentName,
        'componentMarks': compMarks,
        'totalMarks': total,
        'maxMarks': _maxTotalMarks,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;
      setState(() {
        row.isSaved = true;
        row.isSaving = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => row.isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Failed to save ${row.studentId}: $e'),
            backgroundColor: Colors.red),
      );
    }
  }

  // ── Save all ──────────────────────────────────────────────────────────────

  Future<void> _saveAll() async {
    if (_studentRows.isEmpty) return;

    // Validate all rows
    for (final row in _studentRows) {
      for (final comp in _components) {
        final val = int.tryParse(row.controllers[comp.name]?.text ?? '');
        if (val == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content:
                    Text('${row.studentId}: "${comp.name}" must be a number'),
                backgroundColor: Colors.red),
          );
          return;
        }
        if (val < 0 || val > comp.maxMarks) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    '${row.studentId}: "${comp.name}" must be 0–${comp.maxMarks}'),
                backgroundColor: Colors.red),
          );
          return;
        }
      }
    }

    setState(() => _savingAll = true);
    final assignment = _selectedAssignment!;
    final batch = _selectedBatch!;
    final facultyId = _auth.currentUser!.email!.split('@')[0].toUpperCase();
    final now = FieldValue.serverTimestamp();

    try {
      // Validate that assignment is still active before saving
      final assignDoc = await _fs
          .collection('facultyAssignments')
          .doc(assignment.docId)
          .get();
      if (!assignDoc.exists ||
          (assignDoc.data()?['isActive'] ?? true) != true) {
        throw Exception(
            'This course is no longer active. Students may have been promoted. Please refresh the page.');
      }

      final wb = _fs.batch();
      for (final row in _studentRows) {
        final compMarks = <String, int>{};
        for (final c in _components) {
          compMarks[c.name] =
              int.tryParse(row.controllers[c.name]?.text ?? '') ?? 0;
        }
        final total = compMarks.values.fold(0, (s, v) => s + v);
        final docId =
            '${assignment.docId}_${batch.replaceAll('-', '_')}_${row.studentId}';
        wb.set(
          _fs.collection('studentMarks').doc(docId),
          {
            'facultyId': facultyId,
            'assignmentId': assignment.docId,
            'subjectCode': assignment.subjectCode,
            'subjectName': assignment.subjectName,
            'academicYear': assignment.academicYear,
            'semester': assignment.semester,
            'year': assignment.year,
            'batch': batch,
            'studentId': row.studentId,
            'studentName': row.studentName,
            'componentMarks': compMarks,
            'totalMarks': total,
            'maxMarks': _maxTotalMarks,
            'updatedAt': now,
          },
          SetOptions(merge: true),
        );
      }
      await wb.commit();
      if (!mounted) return;
      setState(() {
        for (final row in _studentRows) {
          row.isSaved = true;
        }
        _savingAll = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Marks saved for ${_studentRows.length} students'),
            backgroundColor: Colors.green),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _savingAll = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: $e'), backgroundColor: Colors.red),
      );
    }
  }

  // ── Excel Download/Upload ─────────────────────────────────────────────────

  Uint8List _createExcelTemplate(String assignmentName, String batchName) {
    var excelFile = excel_package.Excel.createExcel();
    excel_package.Sheet sheetObject = excelFile['Sheet1'];

    // Add headers
    sheetObject.appendRow([
      excel_package.TextCellValue('Student ID'),
      excel_package.TextCellValue('Student Name'),
      ..._components
          .map((c) => excel_package.TextCellValue('${c.name} /${c.maxMarks}')),
    ]);

    // Add student data
    for (var student in _studentRows) {
      sheetObject.appendRow([
        excel_package.TextCellValue(student.studentId),
        excel_package.TextCellValue(student.studentName),
        ..._components.map((c) => excel_package.TextCellValue('')),
      ]);
    }

    List<int> encoded = excelFile.encode()!;
    return Uint8List.fromList(encoded);
  }

  Future<void> _downloadExcelTemplate() async {
    if (_selectedAssignment == null || _selectedBatch == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select subject and batch first'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      final assignment = _selectedAssignment!;
      final bytes =
          _createExcelTemplate(assignment.subjectName, _selectedBatch!);
      final fileName =
          '${assignment.subjectCode}_${_selectedBatch}_Marks_Template.xlsx'
              .replaceAll(' ', '_')
              .replaceAll('-', '')
              .replaceAll('/', '');

      // For web - trigger browser download
      if (kIsWeb) {
        try {
          final blob = html.Blob([bytes]);
          final url = html.Url.createObjectUrlFromBlob(blob);
          (html.AnchorElement(href: url)..setAttribute('download', fileName))
              .click();
          html.Url.revokeObjectUrl(url);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Template downloading:\n$fileName'),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Download error: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
      // For mobile (Android/iOS) - save to Downloads folder
      else if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
        try {
          // Android: /storage/emulated/0/Download or /sdcard/Download
          Directory downloadsDir = Directory('/storage/emulated/0/Download');

          // Check if the primary downloads directory exists
          if (!await downloadsDir.exists()) {
            // Try alternative path
            downloadsDir = Directory('/sdcard/Download');
          }

          if (!await downloadsDir.exists()) {
            // Create Downloads directory if it doesn't exist
            await downloadsDir.create(recursive: true);
          }

          final filePath = '${downloadsDir.path}/$fileName';
          final file = File(filePath);
          await file.writeAsBytes(bytes);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Template downloaded to Downloads:\n$fileName',
                ),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        } catch (e) {
          // If Downloads folder access fails, try internal app directory
          try {
            final tempDir = Directory.systemTemp;
            final filePath = '${tempDir.path}/$fileName';
            final file = File(filePath);
            await file.writeAsBytes(bytes);

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Template prepared:\n$fileName\nCheck Files app',
                  ),
                  backgroundColor: Colors.amber,
                  duration: const Duration(seconds: 4),
                ),
              );
            }
          } catch (innerError) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Save error: $e'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        }
      }
      // For desktop (Windows/macOS/Linux) - show save dialog
      else {
        try {
          String? outputPath = await FilePicker.platform.saveFile(
            fileName: fileName,
            type: FileType.custom,
            allowedExtensions: ['xlsx'],
          );

          if (outputPath != null) {
            final file = File(outputPath);
            await file.writeAsBytes(bytes);

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Template downloaded:\n$fileName'),
                  backgroundColor: Colors.green,
                  duration: const Duration(seconds: 3),
                ),
              );
            }
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating template: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _uploadAndParseExcel() async {
    if (_studentRows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please load students first'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      setState(() => _isUploadingExcel = true);

      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
      );

      if (result != null && result.files.single.bytes != null) {
        var bytes = result.files.single.bytes!;
        print('DEBUG: File picked, bytes length: ${bytes.length}');

        try {
          // Try to decode the Excel file
          excel_package.Excel excelFile;
          try {
            excelFile = excel_package.Excel.decodeBytes(bytes);
            print('DEBUG: Excel file decoded successfully');
          } catch (e) {
            print('DEBUG: Decode failed, retrying: $e');
            // Retry once more
            try {
              excelFile = excel_package.Excel.decodeBytes(bytes);
              print('DEBUG: Excel file decoded on retry');
            } catch (e2) {
              print('DEBUG: Final decode failure: $e2');
              rethrow;
            }
          }

          print('DEBUG: Tables count: ${excelFile.tables.length}');

          if (excelFile.tables.isEmpty) {
            throw Exception('Excel file has no sheets');
          }

          excel_package.Sheet? sheet = excelFile.tables.values.first;
          print('DEBUG: Sheet rows count: ${sheet.rows.length}');

          if (sheet.rows.isEmpty) {
            throw Exception('Excel sheet is empty');
          }

          bool isFirstRow = true;
          Map<int, String> componentColumns = {};
          List<String> headerNames = [];

          // Parse Excel data
          for (var rows in sheet.rows) {
            if (isFirstRow) {
              // Find column indices for components
              for (int i = 0; i < rows.length; i++) {
                String cellValue =
                    rows[i]?.value.toString().toLowerCase() ?? '';
                headerNames.add(cellValue);
                for (final comp in _components) {
                  if (cellValue.contains(comp.name.toLowerCase())) {
                    componentColumns[i] = comp.name;
                    print('DEBUG: Found column $i for ${comp.name}');
                    break;
                  }
                }
              }
              print('DEBUG: Headers found: $headerNames');
              print('DEBUG: Component columns mapped: $componentColumns');
              isFirstRow = false;
              continue;
            }

            if (rows.isNotEmpty && componentColumns.isNotEmpty) {
              String studentId = rows[0]?.value.toString().trim() ?? '';

              if (studentId.isNotEmpty) {
                // Find and update matching student row
                for (var studentRow in _studentRows) {
                  if (studentRow.studentId == studentId) {
                    // Update marks from Excel
                    componentColumns.forEach((colIndex, componentName) {
                      if (colIndex < rows.length) {
                        String value =
                            rows[colIndex]?.value.toString().trim() ?? '';
                        // Only update if value is not empty and is numeric
                        if (value.isNotEmpty && int.tryParse(value) != null) {
                          studentRow.controllers[componentName]?.text = value;
                        }
                      }
                    });
                    break;
                  }
                }
              }
            }
          }

          if (componentColumns.isEmpty) {
            throw Exception(
                'No component columns found. Headers found: $headerNames\n'
                'Expected headers containing: ${_components.map((c) => c.name).join(", ")}');
          }

          setState(() {
            _isUploadingExcel = false;
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Excel file uploaded successfully!'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 2),
              ),
            );
          }
        } catch (parseError) {
          // If Excel parsing fails, show user-friendly error
          print('DEBUG: Parse error: $parseError');
          setState(() => _isUploadingExcel = false);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                    '❌ Excel parsing failed. Microsoft Excel adds formatting that causes this error.\n\n'
                    '✅ RECOMMENDED SOLUTIONS:\n'
                    '1. Use "Download CSV" + "Upload CSV" instead (works perfectly)\n'
                    '2. Use the "Download Excel" template from this app (not your own Excel file)\n\n'
                    'The app-generated template and CSV format work reliably!'),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 8),
              ),
            );
          }
        }
      } else {
        setState(() => _isUploadingExcel = false);
      }
    } catch (e) {
      setState(() => _isUploadingExcel = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ─── CSV Methods ────────────────────────────────────────────────────────────

  String _createCsvTemplate(String assignmentName, String batchName) {
    // Create CSV header
    List<String> headers = ['Student ID', 'Student Name'];
    headers.addAll(_components.map((c) => '${c.name} /${c.maxMarks}'));

    StringBuffer csvContent = StringBuffer();
    csvContent.writeln(headers.join(','));

    // Add student data rows
    for (var student in _studentRows) {
      List<String> row = [student.studentId, student.studentName];
      row.addAll(List.filled(_components.length, ''));
      csvContent.writeln(row.join(','));
    }

    return csvContent.toString();
  }

  Future<void> _downloadCsvTemplate() async {
    if (_selectedAssignment == null || _selectedBatch == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select assignment and batch first'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_studentRows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No students found to export'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      String csvContent = _createCsvTemplate(
        _selectedAssignment!.subjectName,
        _selectedBatch!,
      );

      final bytes = utf8.encode(csvContent);
      final fileName =
          'CIE_${_selectedAssignment!.subjectName}_${_selectedBatch}_Template.csv';

      if (kIsWeb) {
        // Web: Use browser download
        final blob = html.Blob([bytes]);
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.AnchorElement(href: url)
          ..setAttribute('download', fileName)
          ..click();
        html.Url.revokeObjectUrl(url);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('CSV template downloaded successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else if (Platform.isAndroid || Platform.isIOS) {
        // Mobile: Save to Downloads folder
        Directory? downloadsDir;
        try {
          downloadsDir = Directory('/storage/emulated/0/Download');
          if (!await downloadsDir.exists()) {
            downloadsDir = Directory('/sdcard/Download');
          }
        } catch (e) {
          downloadsDir = Directory.systemTemp;
        }

        final filePath = '${downloadsDir.path}/$fileName';
        final file = File(filePath);
        await file.writeAsBytes(bytes);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('CSV saved to: $filePath'),
              backgroundColor: Colors.green,
            ),
          );
        }
            } else {
        // Desktop: Show save dialog
        String? outputPath = await FilePicker.platform.saveFile(
          dialogTitle: 'Save CSV Template',
          fileName: fileName,
          type: FileType.custom,
          allowedExtensions: ['csv'],
        );

        if (outputPath != null) {
          final file = File(outputPath);
          await file.writeAsBytes(bytes);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('CSV saved to: $outputPath'),
                backgroundColor: Colors.green,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating CSV: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _uploadAndParseCsv() async {
    if (_studentRows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please load students first'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      setState(() => _isUploadingExcel = true);

      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (result != null && result.files.single.bytes != null) {
        var bytes = result.files.single.bytes!;
        String csvContent = utf8.decode(bytes);
        print('DEBUG: CSV content length: ${csvContent.length}');

        List<String> lines = csvContent
            .split('\n')
            .where((line) => line.trim().isNotEmpty)
            .toList();

        if (lines.isEmpty) {
          throw Exception('CSV file is empty');
        }

        // Parse header row
        List<String> headers =
            lines[0].split(',').map((h) => h.trim()).toList();
        Map<int, String> componentColumns = {};

        print('DEBUG: CSV headers: $headers');

        // Map component columns
        for (int i = 0; i < headers.length; i++) {
          String headerLower = headers[i].toLowerCase();
          for (final comp in _components) {
            if (headerLower.contains(comp.name.toLowerCase())) {
              componentColumns[i] = comp.name;
              print('DEBUG: Found CSV column $i for ${comp.name}');
              break;
            }
          }
        }

        if (componentColumns.isEmpty) {
          throw Exception(
              'No component columns found. Headers found: $headers\n'
              'Expected headers containing: ${_components.map((c) => c.name).join(", ")}');
        }

        // Parse data rows
        int updatedCount = 0;
        for (int rowIndex = 1; rowIndex < lines.length; rowIndex++) {
          List<String> values =
              lines[rowIndex].split(',').map((v) => v.trim()).toList();

          if (values.isEmpty) continue;

          String studentId = values[0];

          if (studentId.isNotEmpty) {
            // Find matching student
            for (var studentRow in _studentRows) {
              if (studentRow.studentId == studentId) {
                // Update marks from CSV
                componentColumns.forEach((colIndex, componentName) {
                  if (colIndex < values.length) {
                    String value = values[colIndex].trim();
                    if (value.isNotEmpty && int.tryParse(value) != null) {
                      studentRow.controllers[componentName]?.text = value;
                      updatedCount++;
                    }
                  }
                });
                break;
              }
            }
          }
        }

        setState(() => _isUploadingExcel = false);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('CSV uploaded! Updated $updatedCount mark(s).'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        setState(() => _isUploadingExcel = false);
      }
    } catch (e) {
      print('DEBUG: CSV parse error: $e');
      setState(() => _isUploadingExcel = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error parsing CSV: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Column(
        children: [
          const AppHeader(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loadingAssignments) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_assignmentError != null) {
      return Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.error_outline, size: 64, color: Colors.red),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(_assignmentError!, textAlign: TextAlign.center),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
            onPressed: _loadAssignments,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry')),
      ]));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Center(
                child: Text('CIE Marks Entry',
                    style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87)),
              ),
              const SizedBox(height: 4),
              const Center(
                child: Text(
                    'Enter internal/external marks for your assigned courses',
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                    textAlign: TextAlign.center),
              ),
              const SizedBox(height: 20),
              _buildSelectionCard(),
              if (_loadingMarks) ...[
                const SizedBox(height: 32),
                const Center(child: CircularProgressIndicator()),
              ] else if (_marksError != null) ...[
                const SizedBox(height: 20),
                _buildErrorBox(_marksError!),
              ] else if (_marksLoaded) ...[
                const SizedBox(height: 20),
                _buildMarksTable(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ── Selection card ─────────────────────────────────────────────────────────

  Widget _buildSelectionCard() {
    final isMobile = MediaQuery.of(context).size.width < 700;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [
            Icon(Icons.tune, color: Color(0xFF1e3a5f), size: 18),
            SizedBox(width: 8),
            Text('Select Subject & Batch',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Color(0xFF1e3a5f))),
          ]),
          const SizedBox(height: 16),
          if (_assignments.isEmpty)
            const Text(
                'No active assignments found. Contact admin to assign courses.',
                style: TextStyle(color: Colors.grey))
          else ...[
            isMobile ? _buildSelectionMobile() : _buildSelectionDesktop(),
            const SizedBox(height: 16),
            if (isMobile)
              Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: (_selectedAssignment != null &&
                              _selectedBatch != null)
                          ? _loadMarksEntry
                          : null,
                      icon: const Icon(Icons.search),
                      label: const Text('Load Students'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1e3a5f),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      'Excel Format:',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: (_selectedAssignment != null &&
                                  _selectedBatch != null &&
                                  _marksLoaded)
                              ? _downloadExcelTemplate
                              : null,
                          icon: const Icon(Icons.download, size: 18),
                          label: const Text(
                            'Download Excel',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed:
                              _isUploadingExcel ? null : _uploadAndParseExcel,
                          icon: const Icon(Icons.upload_file, size: 18),
                          label: Text(
                            _isUploadingExcel ? 'Uploading...' : 'Upload Excel',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      'CSV Format (Recommended if Excel has errors):',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: (_selectedAssignment != null &&
                                  _selectedBatch != null &&
                                  _marksLoaded)
                              ? _downloadCsvTemplate
                              : null,
                          icon: const Icon(Icons.download, size: 18),
                          label: const Text(
                            'Download CSV',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepOrange,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed:
                              _isUploadingExcel ? null : _uploadAndParseCsv,
                          icon: const Icon(Icons.upload_file, size: 18),
                          label: Text(
                            _isUploadingExcel ? 'Uploading...' : 'Upload CSV',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: (_selectedAssignment != null &&
                                  _selectedBatch != null)
                              ? _loadMarksEntry
                              : null,
                          icon: const Icon(Icons.search),
                          label: const Text('Load Students'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1e3a5f),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                          ),
                          onPressed: (_selectedAssignment != null &&
                                  _selectedBatch != null &&
                                  _marksLoaded)
                              ? _downloadExcelTemplate
                              : null,
                          icon: const Icon(Icons.download),
                          label: const Text(
                            'Download Excel',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                          ),
                          onPressed:
                              _isUploadingExcel ? null : _uploadAndParseExcel,
                          icon: const Icon(Icons.upload_file),
                          label: Text(
                            _isUploadingExcel ? 'Uploading...' : 'Upload Excel',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Padding(
                    padding: EdgeInsets.only(left: 4),
                    child: Text(
                      'Or use CSV (Recommended if Excel has parsing errors):',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Expanded(child: SizedBox()),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                          ),
                          onPressed: (_selectedAssignment != null &&
                                  _selectedBatch != null &&
                                  _marksLoaded)
                              ? _downloadCsvTemplate
                              : null,
                          icon: const Icon(Icons.download),
                          label: const Text(
                            'Download CSV',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepOrange,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                          ),
                          onPressed:
                              _isUploadingExcel ? null : _uploadAndParseCsv,
                          icon: const Icon(Icons.upload_file),
                          label: Text(
                            _isUploadingExcel ? 'Uploading...' : 'Upload CSV',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildSelectionDesktop() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(flex: 3, child: _buildSubjectDropdown()),
        const SizedBox(width: 16),
        Expanded(flex: 2, child: _buildBatchDropdown()),
      ],
    );
  }

  Widget _buildSelectionMobile() {
    return Column(children: [
      _buildSubjectDropdown(),
      const SizedBox(height: 12),
      _buildBatchDropdown(),
    ]);
  }

  Widget _buildSubjectDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Subject *',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1e3a5f))),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          initialValue: _selectedAssignment?.docId,
          isExpanded: true,
          decoration: const InputDecoration(
              border: OutlineInputBorder(),
              isDense: true,
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
          hint: const Text('Select subject'),
          items: _assignments.map((a) {
            return DropdownMenuItem(
              value: a.docId,
              child: Text(
                  '${a.subjectCode} – ${a.subjectName}  (Y${a.year} Sem${a.semester})',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13)),
            );
          }).toList(),
          onChanged: (id) {
            final a = _assignments.firstWhere((x) => x.docId == id);
            setState(() {
              _selectedAssignment = a;
              _selectedBatch = a.batches.length == 1 ? a.batches.first : null;
              _marksLoaded = false;
              _marksError = null;
              for (final row in _studentRows) {
                row.dispose();
              }
              _studentRows = [];
            });
          },
        ),
      ],
    );
  }

  Widget _buildBatchDropdown() {
    final batches = _selectedAssignment?.batches ?? [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Batch *',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1e3a5f))),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          initialValue:
              batches.contains(_selectedBatch) ? _selectedBatch : null,
          isExpanded: true,
          decoration: const InputDecoration(
              border: OutlineInputBorder(),
              isDense: true,
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
          hint: const Text('Select batch'),
          items: batches
              .map((b) => DropdownMenuItem(value: b, child: Text(b)))
              .toList(),
          onChanged: batches.isEmpty
              ? null
              : (b) {
                  setState(() {
                    _selectedBatch = b;
                    _marksLoaded = false;
                    _marksError = null;
                    for (final row in _studentRows) {
                      row.dispose();
                    }
                    _studentRows = [];
                  });
                },
        ),
      ],
    );
  }

  // ── Error box ──────────────────────────────────────────────────────────────

  Widget _buildErrorBox(String msg) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        border: Border.all(color: Colors.orange[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: Colors.orange[700], size: 20),
          const SizedBox(width: 10),
          Expanded(
              child: Text(msg, style: TextStyle(color: Colors.orange[800]))),
        ],
      ),
    );
  }

  // ── Marks table ────────────────────────────────────────────────────────────

  Widget _buildMarksTable() {
    final isMobile = MediaQuery.of(context).size.width < 800;
    final a = _selectedAssignment!;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFF1e3a5f),
              borderRadius: BorderRadius.vertical(top: Radius.circular(7)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${a.subjectCode} – ${a.subjectName}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14)),
                const SizedBox(height: 4),
                Wrap(spacing: 12, children: [
                  _headerInfo('Batch: $_selectedBatch'),
                  _headerInfo('Year ${a.year}  |  Sem ${a.semester}'),
                  _headerInfo('AY: ${a.academicYear}'),
                  _headerInfo('Max Marks: $_maxTotalMarks'),
                  _headerInfo('${_studentRows.length} students'),
                  _headerInfo(
                      'Components: ${_components.map((c) => "${c.name} (${c.maxMarks})").join("  •  ")}'),
                ]),
              ],
            ),
          ),
          // Students
          if (_studentRows.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Column(children: [
                  Icon(Icons.people_outline, size: 48, color: Colors.grey[400]),
                  const SizedBox(height: 12),
                  const Text('No students found in this batch.',
                      style: TextStyle(color: Colors.grey, fontSize: 14)),
                  const SizedBox(height: 4),
                  Text(
                      'Looking for: department="${a.department}", Year ${a.year}, batch/section="$_selectedBatch"',
                      style: TextStyle(color: Colors.grey[500], fontSize: 12),
                      textAlign: TextAlign.center),
                  const SizedBox(height: 4),
                  Text(
                      'Check that students have matching department, year, and batchNumber/section.',
                      style: TextStyle(color: Colors.grey[500], fontSize: 11),
                      textAlign: TextAlign.center),
                ]),
              ),
            )
          else
            isMobile ? _buildMobileList() : _buildDesktopTable(),
          // Save all footer
          if (_studentRows.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.grey[200]!)),
                color: Colors.grey[50],
                borderRadius:
                    const BorderRadius.vertical(bottom: Radius.circular(7)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${_studentRows.where((r) => r.isSaved).length}/${_studentRows.length} saved',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  ElevatedButton.icon(
                    onPressed: _savingAll ? null : _saveAll,
                    icon: _savingAll
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.save, size: 16),
                    label: Text(_savingAll ? 'Saving...' : 'Save All Marks'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[700],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 10),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _headerInfo(String text) {
    return Text(text,
        style: const TextStyle(color: Colors.white70, fontSize: 11));
  }

  // ── Desktop table ──────────────────────────────────────────────────────────

  Widget _buildDesktopTable() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        constraints:
            BoxConstraints(minWidth: MediaQuery.of(context).size.width - 64),
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(Colors.grey[100]),
          columnSpacing: 16,
          columns: [
            const DataColumn(
                label: Text('S.No',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
            const DataColumn(
                label: Text('Roll No',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
            const DataColumn(
                label: SizedBox(
                    width: 180,
                    child: Text('Student Name',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 12)))),
            ..._components.map((c) => DataColumn(
                    label: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(c.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 11)),
                    Text('/ ${c.maxMarks}',
                        style:
                            TextStyle(fontSize: 10, color: Colors.grey[600])),
                  ],
                ))),
            const DataColumn(
                label: Text('Total',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
            const DataColumn(label: Text('', style: TextStyle(fontSize: 12))),
          ],
          rows: _studentRows.asMap().entries.map((entry) {
            final i = entry.key;
            final row = entry.value;
            final total = row.totalEntered(_components);
            final isOver = total > _maxTotalMarks;
            return DataRow(
              color: WidgetStateProperty.resolveWith((states) {
                if (row.isSaved) return Colors.green.withOpacity(0.04);
                return null;
              }),
              cells: [
                DataCell(
                    Text('${i + 1}', style: const TextStyle(fontSize: 12))),
                DataCell(Text(row.studentId,
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w500))),
                DataCell(SizedBox(
                    width: 180,
                    child: Text(row.studentName,
                        style: const TextStyle(fontSize: 12),
                        overflow: TextOverflow.ellipsis))),
                ..._components.map((c) => DataCell(_marksField(row, c))),
                DataCell(Text(
                  '$total / $_maxTotalMarks',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: isOver
                        ? Colors.red
                        : total == _maxTotalMarks
                            ? Colors.green
                            : Colors.black87,
                  ),
                )),
                DataCell(
                  row.isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : IconButton(
                          icon: Icon(
                            row.isSaved
                                ? Icons.check_circle
                                : Icons.save_outlined,
                            size: 18,
                            color: row.isSaved
                                ? Colors.green
                                : const Color(0xFF1e3a5f),
                          ),
                          tooltip: row.isSaved
                              ? 'Saved – click to re-save'
                              : 'Save this row',
                          onPressed: () => _saveRow(row),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _marksField(_StudentRow row, _Component comp) {
    return SizedBox(
      width: 70,
      child: StatefulBuilder(builder: (ctx, setMarksState) {
        return TextField(
          controller: row.controllers[comp.name],
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13),
          decoration: InputDecoration(
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            border: const OutlineInputBorder(),
            errorText: (() {
              final val = int.tryParse(row.controllers[comp.name]?.text ?? '');
              if (val != null && val > comp.maxMarks) return '>max';
              return null;
            })(),
          ),
          onChanged: (_) {
            setMarksState(() {});
            setState(() {
              row.isSaved = false;
            });
          },
        );
      }),
    );
  }

  // ── Mobile list ────────────────────────────────────────────────────────────

  Widget _buildMobileList() {
    return Column(
      children: _studentRows.asMap().entries.map((entry) {
        final i = entry.key;
        final row = entry.value;
        return Column(children: [
          if (i > 0) Divider(height: 1, color: Colors.grey[200]),
          _buildMobileStudentCard(i + 1, row),
        ]);
      }).toList(),
    );
  }

  Widget _buildMobileStudentCard(int serial, _StudentRow row) {
    final total = row.totalEntered(_components);
    final isOver = total > _maxTotalMarks;

    return Container(
      color: row.isSaved ? Colors.green.withOpacity(0.04) : null,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: const Color(0xFF1e3a5f).withOpacity(0.1),
                child: Text('$serial',
                    style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF1e3a5f),
                        fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(row.studentId,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13)),
                    Text(row.studentName,
                        style:
                            TextStyle(fontSize: 11, color: Colors.grey[600])),
                  ],
                ),
              ),
              Text(
                '$total / $_maxTotalMarks',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: isOver
                        ? Colors.red
                        : total == _maxTotalMarks
                            ? Colors.green
                            : Colors.black87),
              ),
              const SizedBox(width: 8),
              row.isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : IconButton(
                      icon: Icon(
                          row.isSaved
                              ? Icons.check_circle
                              : Icons.save_outlined,
                          size: 20,
                          color: row.isSaved
                              ? Colors.green
                              : const Color(0xFF1e3a5f)),
                      onPressed: () => _saveRow(row),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _components
                .map((c) => SizedBox(
                      width: 120,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${c.name} (/${c.maxMarks})',
                              style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF1e3a5f))),
                          const SizedBox(height: 4),
                          TextField(
                            controller: row.controllers[c.name],
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly
                            ],
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 13),
                            decoration: const InputDecoration(
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 8),
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (_) =>
                                setState(() => row.isSaved = false),
                          ),
                        ],
                      ),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }
}
