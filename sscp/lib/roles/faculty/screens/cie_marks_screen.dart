import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' as excel_package;
import 'dart:typed_data';
import 'dart:convert' show utf8;
import '../../../widgets/app_header.dart';
import '../../../utils/web_download_stub.dart'
    if (dart.library.html) '../../../utils/web_download_web.dart';
import '../../../utils/file_save_stub.dart'
    if (dart.library.io) '../../../utils/file_save_io.dart';
import '../../../services/audit_log_service.dart';
import '../services/faculty_scope_service.dart';

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
  final _fs = FirebaseFirestore.instance;
  final _scopeService = FacultyScopeService();

  // ── Phase 1: selection ──────────────────
  bool _loadingAssignments = true;
  String? _assignmentError;
  List<_CieAssignment> _assignments = [];
  _CieAssignment? _selectedAssignment;
  String? _selectedBatch;
  String? _facultyId;

  // ── Phase 2: marks entry ────────────────
  bool _loadingMarks = false;
  String? _marksError;
  List<_Component> _components = [];
  List<_StudentRow> _studentRows = [];
  int _maxTotalMarks = 0;
  bool _marksLoaded = false;
  bool _hasStaleData =
      false; // true when existing marks have outdated component keys

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
      final facultyId = await _scopeService.resolveCurrentFacultyId();

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
        _facultyId = facultyId;
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

      // 2. Load only students from the assignment's department, year and batch
      final students = await _scopeService.loadStudentsForAssignment(
        department: assignment.department,
        year: assignment.year,
        assignedBatches: [batch],
      );

      // 4. Load existing marks for this assignment (all batches, filter in Dart)
      final marksSnap = await _fs
          .collection('studentMarks')
          .where('assignmentId', isEqualTo: assignment.docId)
          .get();

      final existingMarks = <String, Map<String, dynamic>>{};
      bool staleDetected = false;
      final currentKeys = compList.map((c) => c.name).toSet();
      for (final doc in marksSnap.docs) {
        final d = doc.data();
        if ((d['batch'] ?? '') == batch) {
          final sid = (d['studentId'] ?? '').toString();
          final rawComp = Map<String, dynamic>.from(d['componentMarks'] ?? {});
          existingMarks[sid] = rawComp;
          // Detect stale: saved has keys not in current format
          if (!staleDetected &&
              rawComp.keys.any((k) => !currentKeys.contains(k))) {
            staleDetected = true;
          }
        }
      }

      // 5. Build rows
      final rows = students.map((student) {
        final sid =
            student['studentId']?.toString() ?? student['rollNo'].toString();
        final name =
            (student['studentName'] ?? student['name'] ?? '').toString();
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
        _hasStaleData = staleDetected;
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
      final facultyId =
          _facultyId ?? await _scopeService.resolveCurrentFacultyId();

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
      });

      // Log audit trail
      print(
          '📝 About to log marks posting for facultyId: $facultyId, student: ${row.studentId}');
      await AuditLogService().logMarksPosting(
        facultyId: facultyId,
        marksType: 'cie',
        courseCode: assignment.subjectCode,
        section: batch,
        studentRollNos: [row.studentId],
        additionalDetails: {
          'studentName': row.studentName,
          'subjectName': assignment.subjectName,
          'academicYear': assignment.academicYear,
          'semester': assignment.semester,
          'year': assignment.year,
          'department': assignment.department,
          'batch': batch,
          'totalMarks': total,
          'maxMarks': _maxTotalMarks,
          'components': compMarks,
          'savedVia': 'Individual Save',
        },
      );
      print('📝 Audit log call completed');

      if (!mounted) return;
      setState(() {
        row.isSaved = true;
        row.isSaving = false;
      });

      // Show success message with audit confirmation
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✓ Marks saved for ${row.studentId} (Logged)'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
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
    final facultyId =
        _facultyId ?? await _scopeService.resolveCurrentFacultyId();
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
        );
      }
      await wb.commit();

      // Log audit trail for all students
      print(
          '📝 About to log marks posting for ${_studentRows.length} students (Save All)');
      final allStudentIds = _studentRows.map((row) => row.studentId).toList();
      await AuditLogService().logMarksPosting(
        facultyId: facultyId,
        marksType: 'cie',
        courseCode: assignment.subjectCode,
        section: batch,
        studentRollNos: allStudentIds,
        additionalDetails: {
          'subjectName': assignment.subjectName,
          'academicYear': assignment.academicYear,
          'semester': assignment.semester,
          'year': assignment.year,
          'department': assignment.department,
          'batch': batch,
          'studentCount': allStudentIds.length,
          'maxMarks': _maxTotalMarks,
          'components':
              _components.map((c) => '${c.name} (${c.maxMarks})').join(', '),
          'savedVia': 'Save All',
        },
      );
      print('📝 Audit log call completed for Save All');

      if (!mounted) return;
      setState(() {
        for (final row in _studentRows) {
          row.isSaved = true;
        }
        _savingAll = false;
        _hasStaleData = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                '✓ Marks saved for ${_studentRows.length} students (Logged)'),
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

  Uint8List _createExcelTemplate() {
    final excelFile = excel_package.Excel.createExcel();
    final sheet = excelFile['Sheet1'];

    sheet.appendRow([
      excel_package.TextCellValue('Student ID'),
      excel_package.TextCellValue('Student Name'),
      ..._components
          .map((c) => excel_package.TextCellValue('${c.name} /${c.maxMarks}')),
    ]);

    for (final student in _studentRows) {
      sheet.appendRow([
        excel_package.TextCellValue(student.studentId),
        excel_package.TextCellValue(student.studentName),
        ..._components.map((_) => excel_package.TextCellValue('')),
      ]);
    }

    final encoded = excelFile.encode() ?? <int>[];
    return Uint8List.fromList(encoded);
  }

  Future<void> _downloadExcelTemplate() async {
    if (_selectedAssignment == null ||
        _selectedBatch == null ||
        !_marksLoaded) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select subject/batch and load students first'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      final assignment = _selectedAssignment!;
      final bytes = _createExcelTemplate();
      final fileName =
          '${assignment.subjectCode}_${_selectedBatch}_Marks_Template.xlsx'
              .replaceAll(' ', '_')
              .replaceAll('-', '')
              .replaceAll('/', '');

      if (kIsWeb) {
        downloadBytesOnWeb(bytes, fileName);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Template downloading: $fileName'),
            backgroundColor: Colors.green,
          ),
        );
        return;
      }

      final savedPath = await saveBytesToLocalFile(bytes, fileName);
      if (!mounted) return;
      if (savedPath == null) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Template saved: $savedPath'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error creating Excel template: $e'),
          backgroundColor: Colors.red,
        ),
      );
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

      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        if (mounted) setState(() => _isUploadingExcel = false);
        return;
      }

      final selectedFile = result.files.single;
      final bytes = selectedFile.bytes;
      if (bytes == null || bytes.isEmpty) {
        throw Exception(
          'Could not read "${selectedFile.name}". Please reselect the file or export it again.',
        );
      }

      final excelFile = excel_package.Excel.decodeBytes(bytes);
      if (excelFile.tables.isEmpty) {
        throw Exception('Excel file has no sheets');
      }

      final sheet = excelFile.tables.values.first;
      if (sheet.rows.isEmpty) {
        throw Exception('Excel sheet is empty');
      }

      final headers = sheet.rows.first
          .map((cell) => _stripBom((cell?.value ?? '').toString()).trim())
          .toList();
      final componentColumns = _matchComponentColumns(headers);

      if (componentColumns.isEmpty) {
        throw Exception(
            'No matching component headers were found.\nExpected: ${_components.map((c) => c.name).join(', ')}\nFound: ${headers.join(', ')}');
      }

      final studentById = <String, _StudentRow>{
        for (final row in _studentRows) _normalizeStudentId(row.studentId): row
      };
      final pendingUpdates = <String, Map<String, String>>{};
      final issues = <String>[];
      final unknownStudentIds = <String>{};

      for (int rowIndex = 1; rowIndex < sheet.rows.length; rowIndex++) {
        final row = sheet.rows[rowIndex];
        if (row.every((cell) => ((cell?.value ?? '').toString().trim().isEmpty))) {
          continue;
        }

        final rawStudentId =
            row.isNotEmpty ? (row[0]?.value ?? '').toString().trim() : '';
        if (rawStudentId.isEmpty) {
          issues.add('Row ${rowIndex + 1}: Student ID is empty.');
          continue;
        }

        final normalizedStudentId = _normalizeStudentId(rawStudentId);
        final studentRow = studentById[normalizedStudentId];
        if (studentRow == null) {
          unknownStudentIds.add(rawStudentId);
          continue;
        }

        for (final entry in componentColumns.entries) {
          final colIndex = entry.key;
          final component = entry.value;
          if (colIndex >= row.length) continue;

          final raw = (row[colIndex]?.value ?? '').toString().trim();
          if (raw.isEmpty) continue;

          final parsed = _tryParseWholeNumber(raw);
          if (parsed == null) {
            issues.add(
              'Row ${rowIndex + 1} (${studentRow.studentId}) ${component.name}: "$raw" is not a whole number.',
            );
            continue;
          }

          if (parsed < 0 || parsed > component.maxMarks) {
            issues.add(
              'Row ${rowIndex + 1} (${studentRow.studentId}) ${component.name}: $parsed is out of range (0-${component.maxMarks}).',
            );
            continue;
          }

          pendingUpdates
              .putIfAbsent(studentRow.studentId, () => <String, String>{})
              [component.name] = parsed.toString();
        }
      }

      if (issues.isNotEmpty || unknownStudentIds.isNotEmpty) {
        throw Exception(
          _buildImportFailureMessage(
            format: 'Excel',
            issues: issues,
            unknownStudentIds: unknownStudentIds,
            expectedComponents: _components.map((c) => c.name).toList(),
          ),
        );
      }

      int updatedCount = 0;
      for (final studentEntry in pendingUpdates.entries) {
        final studentId = studentEntry.key;
        final marksByComponent = studentEntry.value;
        final row = _studentRows.firstWhere((s) => s.studentId == studentId);
        for (final markEntry in marksByComponent.entries) {
          row.controllers[markEntry.key]?.text = markEntry.value;
          updatedCount++;
        }
      }

      if (updatedCount == 0) {
        throw Exception(
          'No marks were imported. Ensure the file has student IDs in the first column and mark values under matching component columns.',
        );
      }

      if (!mounted) return;
      setState(() => _isUploadingExcel = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Excel uploaded. Updated $updatedCount mark(s).'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isUploadingExcel = false);
      final message = _cleanExceptionMessage(e);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Excel upload failed. $message'),
          backgroundColor: Colors.red,
        ),
      );
      await _showUploadErrorDialog('Excel Upload Failed', message);
    }
  }

  // ─── CSV Methods ───────────────────────────────────────────────────────────

  String _createCsvTemplate() {
    final headers = <String>['Student ID', 'Student Name'];
    headers.addAll(_components.map((c) => '${c.name} /${c.maxMarks}'));

    final csv = StringBuffer()..writeln(headers.join(','));
    for (final student in _studentRows) {
      final row = <String>[student.studentId, student.studentName]
        ..addAll(List.filled(_components.length, ''));
      csv.writeln(row.join(','));
    }
    return csv.toString();
  }

  Future<void> _downloadCsvTemplate() async {
    if (_selectedAssignment == null ||
        _selectedBatch == null ||
        !_marksLoaded) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select subject/batch and load students first'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      final content = _createCsvTemplate();
      final bytes = Uint8List.fromList(utf8.encode(content));
      final assignment = _selectedAssignment!;
      final fileName =
          'CIE_${assignment.subjectCode}_${_selectedBatch}_Template.csv';

      if (kIsWeb) {
        downloadBytesOnWeb(bytes, fileName);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('CSV template downloaded successfully'),
            backgroundColor: Colors.green,
          ),
        );
        return;
      }

      final savedPath = await saveBytesToLocalFile(bytes, fileName);
      if (!mounted) return;
      if (savedPath == null) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('CSV saved: $savedPath'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error creating CSV: $e'),
          backgroundColor: Colors.red,
        ),
      );
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

      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        if (mounted) setState(() => _isUploadingExcel = false);
        return;
      }

      final selectedFile = result.files.single;
      final bytes = selectedFile.bytes;
      if (bytes == null || bytes.isEmpty) {
        throw Exception(
          'Could not read "${selectedFile.name}". Please reselect the file or export it again.',
        );
      }

      final csvContent = utf8.decode(bytes, allowMalformed: true);
      final lines = csvContent
          .split(RegExp(r'\r?\n'))
          .where((line) => line.trim().isNotEmpty)
          .toList();

      if (lines.isEmpty) throw Exception('CSV file is empty');

      final headers = _parseCsvLine(lines.first)
          .map((h) => _stripBom(h).trim())
          .toList();
      final componentColumns = _matchComponentColumns(headers);

      if (componentColumns.isEmpty) {
        throw Exception(
            'No matching component headers were found.\nExpected: ${_components.map((c) => c.name).join(', ')}\nFound: ${headers.join(', ')}');
      }

      final studentById = <String, _StudentRow>{
        for (final row in _studentRows) _normalizeStudentId(row.studentId): row
      };
      final pendingUpdates = <String, Map<String, String>>{};
      final issues = <String>[];
      final unknownStudentIds = <String>{};

      for (int rowIndex = 1; rowIndex < lines.length; rowIndex++) {
        final values = _parseCsvLine(lines[rowIndex]).map((v) => v.trim()).toList();
        if (values.isEmpty) continue;

        final rawStudentId = values[0];
        if (rawStudentId.isEmpty) {
          issues.add('Row ${rowIndex + 1}: Student ID is empty.');
          continue;
        }

        final normalizedStudentId = _normalizeStudentId(rawStudentId);
        final studentRow = studentById[normalizedStudentId];
        if (studentRow == null) {
          unknownStudentIds.add(rawStudentId);
          continue;
        }

        for (final entry in componentColumns.entries) {
          final colIndex = entry.key;
          final component = entry.value;
          if (colIndex >= values.length) continue;

          final raw = values[colIndex];
          if (raw.isEmpty) continue;

          final parsed = _tryParseWholeNumber(raw);
          if (parsed == null) {
            issues.add(
              'Row ${rowIndex + 1} (${studentRow.studentId}) ${component.name}: "$raw" is not a whole number.',
            );
            continue;
          }

          if (parsed < 0 || parsed > component.maxMarks) {
            issues.add(
              'Row ${rowIndex + 1} (${studentRow.studentId}) ${component.name}: $parsed is out of range (0-${component.maxMarks}).',
            );
            continue;
          }

          pendingUpdates
              .putIfAbsent(studentRow.studentId, () => <String, String>{})
              [component.name] = parsed.toString();
        }
      }

      if (issues.isNotEmpty || unknownStudentIds.isNotEmpty) {
        throw Exception(
          _buildImportFailureMessage(
            format: 'CSV',
            issues: issues,
            unknownStudentIds: unknownStudentIds,
            expectedComponents: _components.map((c) => c.name).toList(),
          ),
        );
      }

      int updatedCount = 0;
      for (final studentEntry in pendingUpdates.entries) {
        final studentId = studentEntry.key;
        final marksByComponent = studentEntry.value;
        final row = _studentRows.firstWhere((s) => s.studentId == studentId);
        for (final markEntry in marksByComponent.entries) {
          row.controllers[markEntry.key]?.text = markEntry.value;
          updatedCount++;
        }
      }

      if (updatedCount == 0) {
        throw Exception(
          'No marks were imported. Ensure the file has student IDs in the first column and mark values under matching component columns.',
        );
      }

      if (!mounted) return;
      setState(() => _isUploadingExcel = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('CSV uploaded. Updated $updatedCount mark(s).'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isUploadingExcel = false);
      final message = _cleanExceptionMessage(e);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('CSV upload failed. $message'),
          backgroundColor: Colors.red,
        ),
      );
      await _showUploadErrorDialog('CSV Upload Failed', message);
    }
  }

  String _normalizeHeader(String value) {
    return value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  String _normalizeStudentId(String value) {
    return value.trim().toUpperCase();
  }

  String _stripBom(String value) {
    return value.replaceFirst('\uFEFF', '');
  }

  int? _tryParseWholeNumber(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;

    final asInt = int.tryParse(trimmed);
    if (asInt != null) return asInt;

    final asDouble = double.tryParse(trimmed);
    if (asDouble != null && asDouble == asDouble.roundToDouble()) {
      return asDouble.toInt();
    }

    return null;
  }

  Map<int, _Component> _matchComponentColumns(List<String> headers) {
    final matched = <int, _Component>{};
    final usedComponents = <String>{};

    for (int i = 0; i < headers.length; i++) {
      final normalizedHeader = _normalizeHeader(headers[i]);
      if (normalizedHeader.isEmpty) continue;

      for (final component in _components) {
        final normalizedComponent = _normalizeHeader(component.name);
        if (normalizedComponent.isEmpty ||
            usedComponents.contains(normalizedComponent)) {
          continue;
        }

        if (normalizedHeader.contains(normalizedComponent) ||
            normalizedComponent.contains(normalizedHeader)) {
          matched[i] = component;
          usedComponents.add(normalizedComponent);
          break;
        }
      }
    }

    return matched;
  }

  List<String> _parseCsvLine(String line) {
    final out = <String>[];
    final sb = StringBuffer();
    bool inQuotes = false;

    for (int i = 0; i < line.length; i++) {
      final ch = line[i];

      if (ch == '"') {
        if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
          sb.write('"');
          i++;
        } else {
          inQuotes = !inQuotes;
        }
        continue;
      }

      if (ch == ',' && !inQuotes) {
        out.add(sb.toString());
        sb.clear();
      } else {
        sb.write(ch);
      }
    }

    out.add(sb.toString());
    return out;
  }

  String _buildImportFailureMessage({
    required String format,
    required List<String> issues,
    required Set<String> unknownStudentIds,
    required List<String> expectedComponents,
  }) {
    final buffer = StringBuffer('$format upload failed due to invalid data.');

    if (issues.isNotEmpty) {
      final limited = issues.take(8).toList();
      buffer.writeln('\n\nIssues found:');
      for (final issue in limited) {
        buffer.writeln('- $issue');
      }
      if (issues.length > limited.length) {
        buffer.writeln('- ...and ${issues.length - limited.length} more issue(s).');
      }
    }

    if (unknownStudentIds.isNotEmpty) {
      final limitedUnknown = unknownStudentIds.take(8).toList();
      buffer.writeln('\nUnknown Student IDs: ${limitedUnknown.join(', ')}');
      if (unknownStudentIds.length > limitedUnknown.length) {
        buffer.writeln(
            '...and ${unknownStudentIds.length - limitedUnknown.length} more unknown ID(s).');
      }
    }

    buffer.writeln('\nExpected component columns: ${expectedComponents.join(', ')}');
    buffer.writeln(
        'Tip: Download the latest template from this screen and paste only marks values.');

    return buffer.toString();
  }

  String _cleanExceptionMessage(Object error) {
    final msg = error.toString();
    return msg.startsWith('Exception: ') ? msg.substring(11) : msg;
  }

  Future<void> _showUploadErrorDialog(String title, String message) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Text(message, style: const TextStyle(fontSize: 13)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

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
                if (_hasStaleData)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.shade300),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning_amber_rounded,
                            color: Colors.orange.shade700, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Some marks were saved with an old format and have stale data. '
                            'Click "Save All Marks" below to update all students to the current format.',
                            style: TextStyle(
                                color: Colors.orange.shade800, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
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
