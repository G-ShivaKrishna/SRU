import 'dart:io';
import 'dart:convert' show utf8;
import 'package:excel/excel.dart';
import 'firebase_service.dart';

class ExcelUploadService {
  // Required columns for students
  static const List<String> studentRequiredColumns = [
    'hallTicketNumber',
    'studentName',
    'department',
    'batchNumber',
    'year',
    'semester',
    'email',
    'admissionYear',
    'admissionType',
    'dateOfAdmission',
  ];

  // Required columns for faculty
  static const List<String> facultyRequiredColumns = [
    'facultyId',
    'facultyName',
    'department',
    'designation',
    'email',
  ];

  static const List<String> feePaymentRequiredColumns = [
    'feePaymentId',
    'staffName',
    'department',
    'email',
  ];

  static Future<Map<String, dynamic>> uploadAccounts(
    String type,
    File? file, {
    List<int>? fileBytes,
    String? fileName,
  }) async {
    try {
      // Check if file exists (mobile) or bytes available (web)
      List<int>? bytes;
      String? actualFileName;

      if (file != null) {
        if (!await file.exists()) {
          return {
            'success': false,
            'message': 'File not found',
            'totalRows': 0,
            'created': 0,
            'failed': 0,
            'failedReasons': [],
          };
        }

        actualFileName = file.path.split('/').last;
        bytes = await file.readAsBytes();
      } else if (fileBytes != null && fileName != null) {
        bytes = fileBytes;
        actualFileName = fileName;
      } else {
        return {
          'success': false,
          'message': 'No file provided',
          'totalRows': 0,
          'created': 0,
          'failed': 0,
          'failedReasons': [],
        };
      }

      // Validate file format
      final fileNameLower = actualFileName.toLowerCase();
      final isCsv = fileNameLower.endsWith('.csv');
      final isExcel =
          fileNameLower.endsWith('.xlsx') || fileNameLower.endsWith('.xls');

      if (!isCsv && !isExcel) {
        return {
          'success': false,
          'message': 'Invalid file format. Please use .xlsx, .xls, or .csv',
          'totalRows': 0,
          'created': 0,
          'failed': 0,
          'failedReasons': [],
        };
      }

      // Parse based on file type
      List<List<String>> rows;

      if (isCsv) {
        // Parse CSV file
        final csvContent = utf8.decode(bytes);
        final lines = csvContent
            .split('\n')
            .where((line) => line.trim().isNotEmpty)
            .toList();

        if (lines.isEmpty) {
          return {
            'success': false,
            'message': 'CSV file is empty. No data found.',
            'totalRows': 0,
            'created': 0,
            'failed': 0,
            'failedReasons': [],
          };
        }

        rows = lines
            .map((line) => line.split(',').map((cell) => cell.trim()).toList())
            .toList();
      } else {
        // Parse Excel file
        try {
          final excel = Excel.decodeBytes(bytes);

          if (excel.sheets.isEmpty) {
            return {
              'success': false,
              'message': 'Excel file is empty. No sheets found.',
              'totalRows': 0,
              'created': 0,
              'failed': 0,
              'failedReasons': [],
            };
          }

          final sheet = excel.sheets.values.first;

          if (sheet.rows.isEmpty) {
            return {
              'success': false,
              'message': 'Excel sheet is empty. No data found.',
              'totalRows': 0,
              'created': 0,
              'failed': 0,
              'failedReasons': [],
            };
          }

          // Convert Excel rows to List<List<String>>
          rows = sheet.rows
              .map((row) => row
                  .map((cell) => cell?.value?.toString().trim() ?? '')
                  .toList())
              .toList();
        } catch (e) {
          return {
            'success': false,
            'message': 'Error parsing Excel file: $e',
            'totalRows': 0,
            'created': 0,
            'failed': 0,
            'failedReasons': [],
          };
        }
      }

      if (rows.isEmpty) {
        return {
          'success': false,
          'message': 'File is empty. No data found.',
          'totalRows': 0,
          'created': 0,
          'failed': 0,
          'failedReasons': [],
        };
      }

      // Get required columns based on type
      final requiredColumns = type == 'Students'
          ? studentRequiredColumns
          : type == 'Faculty'
              ? facultyRequiredColumns
              : feePaymentRequiredColumns;

      // Parse header row (first row)
      final headerRow = rows.first;
      final headers = <String>[];
      final headerIndexMap = <String, int>{};

      for (int i = 0; i < headerRow.length; i++) {
        final cellValue = headerRow[i].trim();
        if (cellValue.isNotEmpty) {
          headers.add(cellValue);
          // Store with lowercase key for case-insensitive matching
          headerIndexMap[cellValue.toLowerCase()] = i;
        }
      }

      // Validate required columns (case-insensitive)
      final missingColumns = <String>[];
      for (final col in requiredColumns) {
        if (!headerIndexMap.containsKey(col.toLowerCase())) {
          missingColumns.add(col);
        }
      }

      if (missingColumns.isNotEmpty) {
        return {
          'success': false,
          'message': 'Missing required columns: ${missingColumns.join(", ")}',
          'totalRows': rows.length - 1, // Exclude header
          'created': 0,
          'failed': rows.length - 1,
          'failedReasons': ['Missing columns: ${missingColumns.join(", ")}'],
        };
      }

      // Parse data rows
      final List<Map<String, String>> dataRows = [];
      final List<String> rowErrors = [];
      final Map<String, int> seenPrimaryKeys = {};
      final Map<String, int> seenEmails = {};

      for (int rowIndex = 1; rowIndex < rows.length; rowIndex++) {
        final row = rows[rowIndex];
        final Map<String, String> rowData = {};
        final List<String> rowErrorMessages = [];

        bool isValidRow = true;

        // Extract data for required columns
        for (final column in requiredColumns) {
          final cellIndex = headerIndexMap[column.toLowerCase()] ?? -1;
          var cellValue = cellIndex != -1 && cellIndex < row.length
              ? row[cellIndex].trim()
              : '';

          // For date fields, extract just the date portion if it contains ISO 8601 format
          if (column == 'dateOfAdmission' && cellValue.contains('T')) {
            cellValue = cellValue.substring(0, 10);
          }

          if (cellValue.isEmpty) {
            rowErrorMessages.add('Row ${rowIndex + 1}: "$column" is empty');
            isValidRow = false;
          }

          rowData[column] = cellValue;
        }

        // Validate specific fields
        if (type == 'Students') {
          // Validate Hall Ticket Number
          if (!_isValidHallTicket(rowData['hallTicketNumber'] ?? '')) {
            rowErrorMessages.add(
                'Row ${rowIndex + 1}: Invalid Hall Ticket Number "${rowData['hallTicketNumber']}" (Format: 4 digits + 1 letter + 5 digits, e.g., 2203A51291)');
            isValidRow = false;
          }

          // Validate Email
          if (!_isValidEmail(rowData['email'] ?? '')) {
            rowErrorMessages.add(
                'Row ${rowIndex + 1}: Invalid email "${rowData['email']}"');
            isValidRow = false;
          }

          // Validate Year
          final year = rowData['year'] ?? '';
          if (!['1', '2', '3', '4'].contains(year)) {
            rowErrorMessages.add(
                'Row ${rowIndex + 1}: Invalid year "$year" (must be 1, 2, 3, or 4)');
            isValidRow = false;
          }

          // Validate Admission Date format
          final admissionDate = rowData['dateOfAdmission'] ?? '';
          if (!_isValidDateFormat(admissionDate)) {
            // Extract just the date part for display if it's ISO format
            final displayDate = admissionDate.contains('T')
                ? admissionDate.substring(0, 10)
                : admissionDate;
            rowErrorMessages.add(
                'Row ${rowIndex + 1}: Invalid date format "$displayDate" (use YYYY-MM-DD)');
            isValidRow = false;
          }
        } else if (type == 'Faculty') {
          // Validate Faculty Email
          if (!_isValidEmail(rowData['email'] ?? '')) {
            rowErrorMessages.add(
                'Row ${rowIndex + 1}: Invalid email "${rowData['email']}"');
            isValidRow = false;
          }
        } else {
          if (!_isValidFeePaymentId(rowData['feePaymentId'] ?? '')) {
            rowErrorMessages.add(
                'Row ${rowIndex + 1}: Invalid Fee Payment ID "${rowData['feePaymentId']}" (Format: FEE001)');
            isValidRow = false;
          }

          if (!_isValidEmail(rowData['email'] ?? '')) {
            rowErrorMessages.add(
                'Row ${rowIndex + 1}: Invalid email "${rowData['email']}"');
            isValidRow = false;
          }
        }

        // Detect duplicate IDs and emails within the same uploaded file.
        if (isValidRow) {
          final currentRowNumber = rowIndex + 1;
          final primaryKey = type == 'Students'
              ? (rowData['hallTicketNumber'] ?? '').trim().toUpperCase()
              : type == 'Faculty'
                  ? (rowData['facultyId'] ?? '').trim().toLowerCase()
                  : (rowData['feePaymentId'] ?? '').trim().toUpperCase();
          final normalizedEmail = (rowData['email'] ?? '').trim().toLowerCase();

          if (primaryKey.isNotEmpty && seenPrimaryKeys.containsKey(primaryKey)) {
            final firstRow = seenPrimaryKeys[primaryKey]!;
            rowErrorMessages.add(
                'Row $currentRowNumber: Duplicate ID in file (already used in row $firstRow)');
            isValidRow = false;
          }

          if (normalizedEmail.isNotEmpty && seenEmails.containsKey(normalizedEmail)) {
            final firstRow = seenEmails[normalizedEmail]!;
            rowErrorMessages.add(
                'Row $currentRowNumber: Duplicate email in file (already used in row $firstRow)');
            isValidRow = false;
          }

          if (isValidRow) {
            if (primaryKey.isNotEmpty) {
              seenPrimaryKeys[primaryKey] = currentRowNumber;
            }
            if (normalizedEmail.isNotEmpty) {
              seenEmails[normalizedEmail] = currentRowNumber;
            }
          }
        }

        if (isValidRow) {
          dataRows.add(rowData);
        } else {
          rowErrors.addAll(rowErrorMessages);
        }
      }

      // If there are no valid rows, return error
      if (dataRows.isEmpty) {
        return {
          'success': false,
          'message':
              'No valid data found in file. Please check the errors below.',
          'totalRows': rows.length - 1,
          'created': 0,
          'failed': rows.length - 1,
          'failedReasons': rowErrors,
        };
      }

      // Fee Payment uploads are strict: any invalid row blocks whole upload
      if (type == 'Fee Payment' && rowErrors.isNotEmpty) {
        return {
          'success': false,
          'message':
              'Fee Payment upload blocked. Fix all row errors before creating accounts.',
          'totalRows': rows.length - 1,
          'created': 0,
          'failed': rows.length - 1,
          'failedReasons': rowErrors,
        };
      }

      // Upload valid data
      if (type == 'Students') {
        return await FirebaseService.bulkCreateStudents(dataRows);
      }
      if (type == 'Faculty') {
        return await FirebaseService.bulkCreateFaculty(dataRows);
      }
      return await FirebaseService.bulkCreateFeePayment(dataRows);
    } catch (e) {
      return {
        'success': false,
        'message': 'Error processing file: $e',
        'totalRows': 0,
        'created': 0,
        'failed': 0,
        'failedReasons': ['Exception: $e'],
      };
    }
  }

  static Future<Map<String, dynamic>> createAccountManually(
    String type,
    Map<String, String> data,
  ) async {
    try {
      final future = type == 'Students'
          ? FirebaseService.createStudentAccount(
              hallTicketNumber: data['hallTicketNumber'] ?? '',
              studentName: data['studentName'] ?? '',
              department: data['department'] ?? '',
              batchNumber: data['batchNumber'] ?? '',
              year: data['year'] ?? '1',
              semester: data['semester'] ?? '1',
              email: data['email'] ?? '',
              admissionYear: data['admissionYear'],
              admissionType: data['admissionType'],
              dateOfAdmission: data['dateOfAdmission'],
            )
          : type == 'Faculty'
              ? FirebaseService.createFacultyAccount(
                  facultyId: data['facultyId'] ?? '',
                  facultyName: data['facultyName'] ?? '',
                  department: data['department'] ?? '',
                  designation: data['designation'] ?? '',
                  email: data['email'] ?? '',
                )
              : FirebaseService.createFeePaymentAccount(
                  feePaymentId: data['feePaymentId'] ?? '',
                  staffName: data['staffName'] ?? '',
                  department: data['department'] ?? '',
                  email: data['email'] ?? '',
                );

      final result = await future.timeout(
        const Duration(seconds: 30),
        onTimeout: () => {
          'success': false,
          'message': 'Request timeout. Please try again.',
        },
      );

      return result as Map<String, dynamic>? ??
          {
            'success': false,
            'message': 'Invalid response from server',
          };
    } catch (e) {
      return {
        'success': false,
        'message': 'Error creating account: $e',
      };
    }
  }

  static bool _isValidHallTicket(String value) {
    final pattern = RegExp(r'^[0-9]{4}[A-Z][0-9]{5}$');
    return pattern.hasMatch(value);
  }

  static bool _isValidEmail(String value) {
    final pattern = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    return pattern.hasMatch(value);
  }

  static bool _isValidFeePaymentId(String value) {
    final pattern = RegExp(r'^FEE[0-9]{3,5}$', caseSensitive: false);
    return pattern.hasMatch(value.trim());
  }

  static bool _isValidDateFormat(String value) {
    if (value.isEmpty) return false;

    // Handle ISO 8601 datetime format (e.g., "2022-09-10T00:00:00.000Z")
    // Extract just the date part (first 10 characters)
    String dateOnly = value;
    if (value.contains('T')) {
      dateOnly = value.substring(0, 10);
    }

    // Check if date format is YYYY-MM-DD
    final pattern = RegExp(r'^\d{4}-\d{2}-\d{2}$');
    if (!pattern.hasMatch(dateOnly)) {
      return false;
    }

    // Try to parse the date
    try {
      DateTime.parse(dateOnly);
      return true;
    } catch (e) {
      return false;
    }
  }
}
