import 'dart:io';
import 'firebase_service.dart';

class ExcelUploadService {
  static Future<Map<String, dynamic>> uploadAccounts(
    String type,
    File file,
  ) async {
    try {
      // In production, parse the Excel file here
      // For now, return mock data
      await Future.delayed(const Duration(seconds: 2));

      if (!await file.exists()) {
        return {
          'success': false,
          'message': 'File not found',
        };
      }

      final fileName = file.path.split('/').last.toLowerCase();
      final isValidFormat = fileName.endsWith('.xlsx') ||
          fileName.endsWith('.xls') ||
          fileName.endsWith('.csv');

      if (!isValidFormat) {
        return {
          'success': false,
          'message': 'Invalid file format. Please use .xlsx, .xls, or .csv',
        };
      }

      // Mock data - in production, parse from file
      if (type == 'Students') {
        final mockStudents = [
          {
            'hallTicketNumber': '2203A51291',
            'studentName': 'John Doe',
            'department': 'CSE',
            'batchNumber': '22CSBTB09',
            'year': '2',
            'email': 'john@example.com',
          },
          {
            'hallTicketNumber': '2203A51292',
            'studentName': 'Jane Smith',
            'department': 'CSE',
            'batchNumber': '22CSBTB09',
            'year': '2',
            'email': 'jane@example.com',
          },
        ];

        return await FirebaseService.bulkCreateStudents(mockStudents);
      } else {
        final mockFaculty = [
          {
            'facultyId': 'FAC2001',
            'facultyName': 'Dr. John Smith',
            'department': 'CSE',
            'designation': 'Assistant Professor',
            'email': 'john.smith@sru.edu',
            'subjects': 'DBMS, OS, DSA',
          },
        ];

        return await FirebaseService.bulkCreateFaculty(mockFaculty);
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
      final future = type == 'Students'
          ? FirebaseService.createStudentAccount(
              hallTicketNumber: data['hallTicketNumber'] ?? '',
              studentName: data['studentName'] ?? '',
              department: data['department'] ?? '',
              batchNumber: data['batchNumber'] ?? '',
              year: data['year'] ?? '1',
              email: data['email'] ?? '',
            )
          : FirebaseService.createFacultyAccount(
              facultyId: data['facultyId'] ?? '',
              facultyName: data['facultyName'] ?? '',
              department: data['department'] ?? '',
              designation: data['designation'] ?? '',
              email: data['email'] ?? '',
              subjects: data['subjects'] ?? '',
            );

      final result = await future.timeout(
        const Duration(seconds: 30),
        onTimeout: () => {
          'success': false,
          'message': 'Request timeout. Please try again.',
        },
      );

      return result is Map<String, dynamic>
          ? result
          : {
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
}
