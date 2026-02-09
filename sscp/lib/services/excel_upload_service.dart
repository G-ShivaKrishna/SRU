import 'dart:io';

class ExcelUploadService {
  static Future<Map<String, dynamic>> uploadAccounts(
    String type,
    File file,
  ) async {
    try {
      // Simulate file processing delay
      await Future.delayed(const Duration(seconds: 2));

      // Validate file exists
      if (!await file.exists()) {
        return {
          'success': false,
          'message': 'File not found',
        };
      }

      // Mock parsing based on file extension
      final fileName = file.path.split('/').last.toLowerCase();
      final isValidFormat =
          fileName.endsWith('.xlsx') ||
          fileName.endsWith('.xls') ||
          fileName.endsWith('.csv');

      if (!isValidFormat) {
        return {
          'success': false,
          'message': 'Invalid file format. Please use .xlsx, .xls, or .csv',
        };
      }

      // Mock data processing
      if (type == 'Students') {
        return {
          'success': true,
          'message': 'Students uploaded successfully',
          'totalRows': 150,
          'created': 148,
          'failed': 2,
          'failedReasons': [
            'Row 45: Invalid Hall Ticket Number (duplicate HT2022001)',
            'Row 89: Missing required field: Email',
          ],
        };
      } else {
        return {
          'success': true,
          'message': 'Faculty uploaded successfully',
          'totalRows': 45,
          'created': 45,
          'failed': 0,
          'failedReasons': [],
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error processing file: $e',
      };
    }
  }

  static Future<Map<String, dynamic>> createAccountManually(
    String type,
    Map<String, String> data,
  ) async {
    try {
      await Future.delayed(const Duration(seconds: 1));

      // Validate data
      if (data.values.any((value) => value.isEmpty)) {
        return {
          'success': false,
          'message': 'All fields are required',
          'totalRows': 1,
          'created': 0,
          'failed': 1,
          'failedReasons': ['Missing required fields'],
        };
      }

      // Mock validation for specific fields
      if (type == 'Students') {
        if (!_isValidHallTicket(data['hallTicketNumber'] ?? '')) {
          return {
            'success': false,
            'message': 'Invalid Hall Ticket Number format',
            'totalRows': 1,
            'created': 0,
            'failed': 1,
            'failedReasons': ['Invalid Hall Ticket Number format (e.g., 2203A51291)'],
          };
        }
        if (!_isValidEmail(data['email'] ?? '')) {
          return {
            'success': false,
            'message': 'Invalid email format',
            'totalRows': 1,
            'created': 0,
            'failed': 1,
            'failedReasons': ['Invalid email format'],
          };
        }
      } else {
        if (!_isValidEmail(data['email'] ?? '')) {
          return {
            'success': false,
            'message': 'Invalid email format',
            'totalRows': 1,
            'created': 0,
            'failed': 1,
            'failedReasons': ['Invalid email format'],
          };
        }
      }

      return {
        'success': true,
        'message': '${type == 'Students' ? 'Student' : 'Faculty'} account created successfully',
        'totalRows': 1,
        'created': 1,
        'failed': 0,
        'failedReasons': [],
        'accountDetails': {
          'id': type == 'Students' ? data['hallTicketNumber'] : data['facultyId'],
          'name': type == 'Students' ? data['studentName'] : data['facultyName'],
          'password': _generateRandomPassword(),
        },
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

  static String _generateRandomPassword() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789@#\$%';
    final random = List.generate(8, (index) => chars[(index * 7) % chars.length]);
    return random.join();
  }
}
