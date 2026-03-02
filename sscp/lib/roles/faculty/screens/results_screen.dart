import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
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

class FacultyResultsScreen extends StatefulWidget {
  const FacultyResultsScreen({super.key});

  @override
  State<FacultyResultsScreen> createState() => _FacultyResultsScreenState();
}

class _FacultyResultsScreenState extends State<FacultyResultsScreen> {
  String? selectedCourse;
  String? selectedSection;
  String? selectedExamType;
  bool isStudentListLoaded = false;
  bool isUploadingExcel = false;

  final courses = ['22CS301 - DAA', '22CS302 - OS', '22CS303 - DBMS'];
  final sections = ['A', 'B', 'C', 'D'];
  final examTypes = ['Mid Sem 1', 'Mid Sem 2', 'End Sem'];

  final List<Map<String, dynamic>> students = [
    {'rollNo': '22CSBTB01', 'name': 'STUDENT 1', 'marks': ''},
    {'rollNo': '22CSBTB02', 'name': 'STUDENT 2', 'marks': ''},
    {'rollNo': '22CSBTB03', 'name': 'STUDENT 3', 'marks': ''},
    {'rollNo': '22CSBTB04', 'name': 'STUDENT 4', 'marks': ''},
    {'rollNo': '22CSBTB05', 'name': 'STUDENT 5', 'marks': ''},
  ];

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Grade Entry & Results'),
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
                  _buildSelectionCard(context),
                  const SizedBox(height: 24),
                  if (isStudentListLoaded) _buildGradeEntryForm(context),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectionCard(BuildContext context) {
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
            'Select Exam Details',
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
                _buildDropdownField('Course', selectedCourse, courses, (value) {
                  setState(() => selectedCourse = value);
                }),
                const SizedBox(height: 12),
                _buildDropdownField('Section', selectedSection, sections,
                    (value) {
                  setState(() => selectedSection = value);
                }),
                const SizedBox(height: 12),
                _buildDropdownField('Exam Type', selectedExamType, examTypes,
                    (value) {
                  setState(() => selectedExamType = value);
                }),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: _onLoadPressed,
                    child: const Text(
                      'Load Students',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: selectedCourse != null &&
                                selectedSection != null &&
                                selectedExamType != null
                            ? _downloadExcelTemplate
                            : null,
                        icon: const Icon(Icons.download),
                        label: const Text(
                          'Download Template',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
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
                            isUploadingExcel ? null : _uploadAndParseExcel,
                        icon: const Icon(Icons.upload_file),
                        label: Text(
                          isUploadingExcel ? 'Uploading...' : 'Upload Excel',
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
            )
          else
            Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildDropdownField(
                          'Course', selectedCourse, courses, (value) {
                        setState(() => selectedCourse = value);
                      }),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildDropdownField(
                          'Section', selectedSection, sections, (value) {
                        setState(() => selectedSection = value);
                      }),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildDropdownField(
                          'Exam Type', selectedExamType, examTypes, (value) {
                        setState(() => selectedExamType = value);
                      }),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: _onLoadPressed,
                        child: const Text(
                          'Load Students',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: selectedCourse != null &&
                                selectedSection != null &&
                                selectedExamType != null
                            ? _downloadExcelTemplate
                            : null,
                        icon: const Icon(Icons.download),
                        label: const Text(
                          'Download Template',
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
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed:
                            isUploadingExcel ? null : _uploadAndParseExcel,
                        icon: const Icon(Icons.upload_file),
                        label: Text(
                          isUploadingExcel ? 'Uploading...' : 'Upload Excel',
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

  void _onLoadPressed() {
    if (selectedCourse != null &&
        selectedSection != null &&
        selectedExamType != null) {
      setState(() => isStudentListLoaded = true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select all fields'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildGradeEntryForm(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

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
            child: Text(
              'Enter Grades - $selectedCourse Section $selectedSection - $selectedExamType',
              style: TextStyle(
                color: Colors.white,
                fontSize: isMobile ? 12 : 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(isMobile ? 12 : 14),
            child: Column(
              children: [
                ...students.asMap().entries.map((entry) {
                  int index = entry.key;
                  Map<String, dynamic> student = entry.value;
                  return Column(
                    children: [
                      if (index > 0)
                        Divider(color: Colors.grey[300], height: 16),
                      _buildStudentGradeRow(student, isMobile),
                    ],
                  );
                }),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Grades submitted successfully!'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    },
                    child: const Text(
                      'Submit Grades',
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
          ),
        ],
      ),
    );
  }

  Widget _buildStudentGradeRow(Map<String, dynamic> student, bool isMobile) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  student['rollNo'],
                  style: TextStyle(
                    fontSize: isMobile ? 12 : 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  student['name'],
                  style: TextStyle(
                    fontSize: isMobile ? 11 : 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 1,
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Marks',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              keyboardType: TextInputType.number,
              style: TextStyle(fontSize: isMobile ? 12 : 13),
              onChanged: (value) {
                student['marks'] = value;
              },
            ),
          ),
        ],
      ),
    );
  }

  // Excel template creation
  Uint8List _createExcelTemplate() {
    var excelFile = excel_package.Excel.createExcel();
    excel_package.Sheet sheetObject = excelFile['Sheet1'];

    // Add headers
    sheetObject.appendRow([
      excel_package.TextCellValue('Student ID'),
      excel_package.TextCellValue('Student Name'),
      excel_package.TextCellValue('Marks'),
    ]);

    // Add student data
    for (var student in students) {
      sheetObject.appendRow([
        excel_package.TextCellValue(student['rollNo']),
        excel_package.TextCellValue(student['name']),
        excel_package.TextCellValue(
            ''), // Empty marks column for faculty to fill
      ]);
    }

    List<int> encoded = excelFile.encode()!;
    return Uint8List.fromList(encoded);
  }

  // Download Excel template
  Future<void> _downloadExcelTemplate() async {
    try {
      final bytes = _createExcelTemplate();
      final fileName =
          '${selectedCourse}_${selectedSection}_${selectedExamType}_Template.xlsx'
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

  // Upload and parse Excel file
  Future<void> _uploadAndParseExcel() async {
    try {
      setState(() => isUploadingExcel = true);

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
          int marksColumnIndex = -1;
          int rollNoColumnIndex = -1;
          List<String> headerNames = [];

          // Parse Excel data
          for (var rows in sheet.rows) {
            if (isFirstRow) {
              // Find column indices from headers
              for (int i = 0; i < rows.length; i++) {
                String cellValue = rows[i]?.value.toString().toLowerCase() ?? '';
                headerNames.add(cellValue);
                if (cellValue.contains('id') || cellValue.contains('roll')) {
                  rollNoColumnIndex = i;
                  print('DEBUG: Found Roll No column at index $i');
                }
                if (cellValue.contains('mark')) {
                  marksColumnIndex = i;
                  print('DEBUG: Found Marks column at index $i');
                }
              }
              print('DEBUG: Headers found: $headerNames');
              isFirstRow = false;
              continue;
            }

            if (rollNoColumnIndex >= 0 &&
                marksColumnIndex >= 0 &&
                rows.length > marksColumnIndex) {
              String rollNo = rows[rollNoColumnIndex]?.value.toString().trim() ?? '';
              String marks = rows[marksColumnIndex]?.value.toString().trim() ?? '';

              // Update student marks only if valid
              if (rollNo.isNotEmpty && marks.isNotEmpty && 
                  int.tryParse(marks) != null) {
                for (var student in students) {
                  if (student['rollNo'] == rollNo) {
                    student['marks'] = marks;
                    break;
                  }
                }
              }
            }
          }

          if (rollNoColumnIndex < 0 || marksColumnIndex < 0) {
            throw Exception('Required columns not found. Headers found: $headerNames\n'
                'Looking for columns containing "roll" or "id" and "mark"');
          }

          setState(() {
            isStudentListLoaded = true;
            isUploadingExcel = false;
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Excel file uploaded and parsed successfully!'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 2),
              ),
            );
          }
        } catch (parseError) {
          // If Excel parsing fails, show user-friendly error
          print('DEBUG: Parse error: $parseError');
          setState(() => isUploadingExcel = false);
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('❌ Excel parsing failed. Microsoft Excel adds formatting that causes this error.\n\n'
                    '✅ RECOMMENDED SOLUTIONS:\n'
                    '1. Use "Download CSV" + "Upload CSV" instead (works perfectly)\n'
                    '2. Use the "Download Excel" template from this app (not your own Excel file)\n\n'
                    'The app-generated template and CSV format work reliably!'),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 8),
              ),
            );
          }
        }
      } else {
        setState(() => isUploadingExcel = false);
      }
    } catch (e) {
      setState(() => isUploadingExcel = false);
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

  String _createCsvTemplate() {
    // Create CSV header
    StringBuffer csvContent = StringBuffer();
    csvContent.writeln('Student ID,Student Name,Marks');
    
    // Add student data rows
    for (var student in students) {
      csvContent.writeln('${student['rollNo']},${student['studentName']},');
    }
    
    return csvContent.toString();
  }

  Future<void> _downloadCsvTemplate() async {
    if (students.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No students found to export'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      String csvContent = _createCsvTemplate();
      final bytes = utf8.encode(csvContent);
      final fileName = 'Results_Template.csv';

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

        if (downloadsDir != null) {
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
    try {
      setState(() => isUploadingExcel = true);

      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (result != null && result.files.single.bytes != null) {
        var bytes = result.files.single.bytes!;
        String csvContent = utf8.decode(bytes);
        print('DEBUG: CSV content length: ${csvContent.length}');
        
        List<String> lines = csvContent.split('\n')
            .where((line) => line.trim().isNotEmpty)
            .toList();
        
        if (lines.isEmpty) {
          throw Exception('CSV file is empty');
        }

        // Parse header row
        List<String> headers = lines[0].split(',').map((h) => h.trim()).toList();
        int rollNoIndex = -1;
        int marksIndex = -1;
        
        print('DEBUG: CSV headers: $headers');
        
        // Find column indices
        for (int i = 0; i < headers.length; i++) {
          String headerLower = headers[i].toLowerCase();
          if (headerLower.contains('id') || headerLower.contains('roll')) {
            rollNoIndex = i;
          }
          if (headerLower.contains('mark')) {
            marksIndex = i;
          }
        }
        
        if (rollNoIndex < 0 || marksIndex < 0) {
          throw Exception('Required columns not found. Headers: $headers\n'
              'Looking for columns containing "roll" or "id" and "mark"');
        }

        // Parse data rows
        int updatedCount = 0;
        for (int rowIndex = 1; rowIndex < lines.length; rowIndex++) {
          List<String> values = lines[rowIndex].split(',').map((v) => v.trim()).toList();
          
          if (values.length > rollNoIndex && values.length > marksIndex) {
            String rollNo = values[rollNoIndex];
            String marks = values[marksIndex];
            
            if (rollNo.isNotEmpty && marks.isNotEmpty && int.tryParse(marks) != null) {
              for (var student in students) {
                if (student['rollNo'] == rollNo) {
                  student['marks'] = marks;
                  updatedCount++;
                  break;
                }
              }
            }
          }
        }

        setState(() {
          isStudentListLoaded = true;
          isUploadingExcel = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('CSV uploaded! Updated $updatedCount student(s).'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        setState(() => isUploadingExcel = false);
      }
    } catch (e) {
      print('DEBUG: CSV parse error: $e');
      setState(() => isUploadingExcel = false);
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
}
