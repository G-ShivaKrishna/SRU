import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Service to manage current user information
class UserService {
  static final UserService _instance = UserService._internal();
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Cache for current user data
  static String? _currentUserId;
  static String? _currentUserRole;
  static Map<String, dynamic>? _currentUserData;

  factory UserService() {
    return _instance;
  }

  UserService._internal();

  /// Get current user ID (hallTicketNumber, facultyId, or feePaymentId)
  static String? getCurrentUserId() => _currentUserId;

  /// Get current user role
  static String? getCurrentUserRole() => _currentUserRole;

  /// Get current user data
  static Map<String, dynamic>? getCurrentUserData() => _currentUserData;

  /// Fetch and cache user ID based on email
  static Future<String?> fetchAndCacheUserId() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        _clearCache();
        return null;
      }

      final email = user.email?.toLowerCase().trim();
      if (email == null) {
        _clearCache();
        return null;
      }

      print('🔍 UserService: Looking up user with email: $email');

      // Try to find in students collection by custom email field
      var studentQuery = await _firestore
          .collection('students')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (studentQuery.docs.isNotEmpty) {
        _currentUserId =
            studentQuery.docs.first['hallTicketNumber']?.toString();
        _currentUserRole = 'student';
        _currentUserData = studentQuery.docs.first.data();
        print('✅ UserService: Found student - ID: $_currentUserId');
        return _currentUserId;
      }

      // Fallback: Search all students with case-insensitive comparison
      final allStudents = await _firestore.collection('students').get();
      for (final doc in allStudents.docs) {
        final storedEmail =
            (doc['email'] ?? '').toString().toLowerCase().trim();
        if (storedEmail == email) {
          _currentUserId = doc['hallTicketNumber']?.toString();
          _currentUserRole = 'student';
          _currentUserData = doc.data();
          print(
              '✅ UserService: Found student (fallback) - ID: $_currentUserId');
          return _currentUserId;
        }
      }

      print('❌ UserService: Student not found with email: $email');

      // Try to find in faculty collection by custom email field
      var facultyQuery = await _firestore
          .collection('faculty')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (facultyQuery.docs.isNotEmpty) {
        _currentUserId = facultyQuery.docs.first['facultyId']?.toString();
        _currentUserRole = 'faculty';
        _currentUserData = facultyQuery.docs.first.data();
        print('✅ UserService: Found faculty - ID: $_currentUserId');
        return _currentUserId;
      }

      // Fallback: Search all faculty
      final allFaculty = await _firestore.collection('faculty').get();
      for (final doc in allFaculty.docs) {
        final storedEmail =
            (doc['email'] ?? '').toString().toLowerCase().trim();
        if (storedEmail == email) {
          _currentUserId = doc['facultyId']?.toString();
          _currentUserRole = 'faculty';
          _currentUserData = doc.data();
          print(
              '✅ UserService: Found faculty (fallback) - ID: $_currentUserId');
          return _currentUserId;
        }
      }

      print('❌ UserService: Faculty not found with email: $email');

      // Try to find in feePayments collection by custom email field
      var feeQuery = await _firestore
          .collection('feePayments')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (feeQuery.docs.isNotEmpty) {
        _currentUserId = feeQuery.docs.first['feePaymentId']?.toString();
        _currentUserRole = 'feePayment';
        _currentUserData = feeQuery.docs.first.data();
        print('✅ UserService: Found feePayment staff - ID: $_currentUserId');
        return _currentUserId;
      }

      // Fallback: Search all feePayments
      final allFeePayment = await _firestore.collection('feePayments').get();
      for (final doc in allFeePayment.docs) {
        final storedEmail =
            (doc['email'] ?? '').toString().toLowerCase().trim();
        if (storedEmail == email) {
          _currentUserId = doc['feePaymentId']?.toString();
          _currentUserRole = 'feePayment';
          _currentUserData = doc.data();
          print(
              '✅ UserService: Found feePayment (fallback) - ID: $_currentUserId');
          return _currentUserId;
        }
      }

      print(
          '❌ UserService: User not found in any collection with email: $email');
      _clearCache();
      return null;
    } catch (e) {
      print('❌ Error fetching user ID: $e');
      _clearCache();
      return null;
    }
  }

  /// Clear cache
  static void _clearCache() {
    _currentUserId = null;
    _currentUserRole = null;
    _currentUserData = null;
  }

  /// Clear cache on logout
  static void clearOnLogout() {
    _clearCache();
  }
}
