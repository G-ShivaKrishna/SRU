import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

class FirebaseService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ============ STUDENT ACCOUNT CREATION ============
  static Future<Map<String, dynamic>> createStudentAccount({
    required String hallTicketNumber,
    required String studentName,
    required String department,
    required String batchNumber,
    required String year,
    required String email,
    String? admissionYear,
    String? admissionType,
    String? dateOfAdmission,
  }) async {
    try {
      // Generate Firebase email from Hall Ticket Number
      final firebaseEmail = '${hallTicketNumber.toLowerCase()}@sru.edu.in';
      final firebasePassword = _generateStrongPassword(hallTicketNumber);

      // Create Firebase Auth user with timeout
      UserCredential userCredential;
      try {
        userCredential = await _auth
            .createUserWithEmailAndPassword(
              email: firebaseEmail,
              password: firebasePassword,
            )
            .timeout(const Duration(seconds: 15));
      } on FirebaseAuthException catch (e) {
        if (e.code == 'email-already-in-use') {
          return {
            'success': false,
            'message': 'Student ID already has an account',
            'error': e.code,
          };
        }
        rethrow;
      }

      final uid = userCredential.user!.uid;

      // Create Firestore student document
      await _firestore.collection('students').doc(hallTicketNumber).set({
        'uid': uid,
        'hallTicketNumber': hallTicketNumber,
        'name': studentName,
        'department': department,
        'batchNumber': batchNumber,
        'year': int.tryParse(year) ?? 1,
        'email': email,
        'firebaseEmail': firebaseEmail,
        'admissionYear': admissionYear,
        'admissionType': admissionType,
        'dateOfAdmission': dateOfAdmission,
        'role': 'student',
        'status': 'active',
        'passwordHash': _hashPassword(firebasePassword),
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': 'admin',
      });

      // Create user metadata document
      await _firestore.collection('users').doc(uid).set({
        'uid': uid,
        'role': 'student',
        'studentId': hallTicketNumber,
        'email': email,
        'firebaseEmail': firebaseEmail,
        'createdAt': FieldValue.serverTimestamp(),
      });

      return {
        'success': true,
        'message': 'Student account created successfully',
        'uid': uid,
        'username': hallTicketNumber,
        'password': firebasePassword,
        'email': email,
        'firebaseEmail': firebaseEmail,
      };
    } on FirebaseAuthException catch (e) {
      return {
        'success': false,
        'message': _getAuthErrorMessage(e.code),
        'error': e.code,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Error creating student account: $e',
      };
    }
  }

  // ============ FACULTY ACCOUNT CREATION ============
  static Future<Map<String, dynamic>> createFacultyAccount({
    required String facultyId,
    required String facultyName,
    required String department,
    required String designation,
    required String email,
  }) async {
    try {
      // Generate Firebase email from Faculty ID
      final firebaseEmail = '${facultyId.toLowerCase()}@sru.edu.in';
      final firebasePassword = _generateStrongPassword(facultyId);

      // Create Firebase Auth user with timeout
      UserCredential userCredential;
      try {
        userCredential = await _auth
            .createUserWithEmailAndPassword(
              email: firebaseEmail,
              password: firebasePassword,
            )
            .timeout(const Duration(seconds: 15));
      } on FirebaseAuthException catch (e) {
        if (e.code == 'email-already-in-use') {
          return {
            'success': false,
            'message': 'Faculty ID already has an account',
            'error': e.code,
          };
        }
        rethrow;
      }

      final uid = userCredential.user!.uid;

      // Create Firestore faculty document
      await _firestore.collection('faculty').doc(facultyId).set({
        'uid': uid,
        'facultyId': facultyId,
        'name': facultyName,
        'department': department,
        'designation': designation,
        'email': email,
        'firebaseEmail': firebaseEmail,
        'role': 'faculty',
        'status': 'active',
        'passwordHash': _hashPassword(firebasePassword),
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': 'admin',
      });

      // Create user metadata document
      await _firestore.collection('users').doc(uid).set({
        'uid': uid,
        'role': 'faculty',
        'facultyId': facultyId,
        'email': email,
        'firebaseEmail': firebaseEmail,
        'createdAt': FieldValue.serverTimestamp(),
      });

      return {
        'success': true,
        'message': 'Faculty account created successfully',
        'uid': uid,
        'username': facultyId,
        'password': firebasePassword,
        'email': email,
        'firebaseEmail': firebaseEmail,
      };
    } on FirebaseAuthException catch (e) {
      return {
        'success': false,
        'message': _getAuthErrorMessage(e.code),
        'error': e.code,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Error creating faculty account: $e',
      };
    }
  }

  // ============ VERIFY USERNAME & PASSWORD ============
  static Future<Map<String, dynamic>> verifyUserCredentials({
    required String username,
    required String password,
  }) async {
    try {
      // Determine if student or faculty based on format
      final isStudent = RegExp(r'^[0-9]{4}[A-Z][0-9]{5}$').hasMatch(username);

      if (isStudent) {
        // Verify student credentials
        final studentDoc =
            await _firestore.collection('students').doc(username).get();

        if (!studentDoc.exists) {
          return {
            'success': false,
            'message': 'Student not found',
          };
        }

        final data = studentDoc.data() as Map<String, dynamic>;

        if (data['passwordHash'] != _hashPassword(password)) {
          return {
            'success': false,
            'message': 'Invalid password',
          };
        }

        if (data['status'] != 'active') {
          return {
            'success': false,
            'message': 'Account is inactive',
          };
        }

        // Sign in with Firebase
        await _auth.signInWithEmailAndPassword(
          email: data['firebaseEmail'],
          password: password,
        );

        return {
          'success': true,
          'uid': data['uid'],
          'role': 'student',
          'name': data['name'],
          'username': username,
        };
      } else {
        // Verify faculty credentials
        final facultyDoc =
            await _firestore.collection('faculty').doc(username).get();

        if (!facultyDoc.exists) {
          return {
            'success': false,
            'message': 'Faculty not found',
          };
        }

        final data = facultyDoc.data() as Map<String, dynamic>;

        if (data['passwordHash'] != _hashPassword(password)) {
          return {
            'success': false,
            'message': 'Invalid password',
          };
        }

        if (data['status'] != 'active') {
          return {
            'success': false,
            'message': 'Account is inactive',
          };
        }

        // Sign in with Firebase
        await _auth.signInWithEmailAndPassword(
          email: data['firebaseEmail'],
          password: password,
        );

        return {
          'success': true,
          'uid': data['uid'],
          'role': 'faculty',
          'name': data['name'],
          'username': username,
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Authentication failed: $e',
      };
    }
  }

  // ============ BULK UPLOAD (EXCEL) ============
  static Future<Map<String, dynamic>> bulkCreateStudents(
    List<Map<String, String>> studentsData,
  ) async {
    int created = 0;
    int failed = 0;
    List<String> failedReasons = [];

    for (int i = 0; i < studentsData.length; i++) {
      try {
        final student = studentsData[i];
        final result = await createStudentAccount(
          hallTicketNumber: student['hallTicketNumber'] ?? '',
          studentName: student['studentName'] ?? '',
          department: student['department'] ?? '',
          batchNumber: student['batchNumber'] ?? '',
          year: student['year'] ?? '1',
          email: student['email'] ?? '',
          admissionYear: student['admissionYear'],
          admissionType: student['admissionType'],
          dateOfAdmission: student['dateOfAdmission'],
        );

        if (result['success'] == true) {
          created++;
        } else {
          failed++;
          failedReasons.add(
            'Row ${i + 2}: ${result['message'] ?? 'Unknown error'}',
          );
        }
      } catch (e) {
        failed++;
        failedReasons.add('Row ${i + 2}: Error - $e');
      }
    }

    return {
      'success': failed == 0,
      'message': 'Bulk student upload completed',
      'totalRows': studentsData.length,
      'created': created,
      'failed': failed,
      'failedReasons': failedReasons,
    };
  }

  static Future<Map<String, dynamic>> bulkCreateFaculty(
    List<Map<String, String>> facultyData,
  ) async {
    int created = 0;
    int failed = 0;
    List<String> failedReasons = [];

    for (int i = 0; i < facultyData.length; i++) {
      try {
        final faculty = facultyData[i];
        final result = await createFacultyAccount(
          facultyId: faculty['facultyId'] ?? '',
          facultyName: faculty['facultyName'] ?? '',
          department: faculty['department'] ?? '',
          designation: faculty['designation'] ?? '',
          email: faculty['email'] ?? '',
        );

        if (result['success'] == true) {
          created++;
        } else {
          failed++;
          failedReasons.add(
            'Row ${i + 2}: ${result['message'] ?? 'Unknown error'}',
          );
        }
      } catch (e) {
        failed++;
        failedReasons.add('Row ${i + 2}: Error - $e');
      }
    }

    return {
      'success': failed == 0,
      'message': 'Bulk faculty upload completed',
      'totalRows': facultyData.length,
      'created': created,
      'failed': failed,
      'failedReasons': failedReasons,
    };
  }

  // ============ HELPER METHODS ============
  static String _generateStrongPassword(String id) {
    // Password is same as the ID
    return id;
  }

  static String _hashPassword(String password) {
    return sha256.convert(utf8.encode(password)).toString();
  }

  static String _getAuthErrorMessage(String code) {
    switch (code) {
      case 'email-already-in-use':
        return 'This ID already has an account';
      case 'weak-password':
        return 'Password is too weak';
      case 'invalid-email':
        return 'Invalid email format';
      case 'user-disabled':
        return 'User account is disabled';
      case 'user-not-found':
        return 'User not found';
      case 'wrong-password':
        return 'Wrong password';
      default:
        return 'Authentication error: $code';
    }
  }

  static Future<void> logout() async {
    await _auth.signOut();
  }

  static User? getCurrentUser() {
    return _auth.currentUser;
  }
}
