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

  /// Get current user ID (hallTicketNumber, facultyId, adminId, or feePaymentId)
  static String? getCurrentUserId() => _currentUserId;

  /// Get current user role
  static String? getCurrentUserRole() => _currentUserRole;

  /// Get current user data
  static Map<String, dynamic>? getCurrentUserData() => _currentUserData;

  static void cacheCurrentUser({
    required String userId,
    required String role,
    Map<String, dynamic>? userData,
  }) {
    _currentUserId = userId;
    _currentUserRole = _normalizeRole(role);
    _currentUserData = userData;
  }

  static String _normalizeRole(String role) {
    final value = role.trim().toLowerCase();
    if (value == 'feepayment' || value == 'fee payment') {
      return 'fee_payment';
    }
    return value;
  }

  static String? _roleIdFromUsersDoc(String role, Map<String, dynamic> data) {
    switch (role) {
      case 'student':
        return data['studentId']?.toString();
      case 'faculty':
        return data['facultyId']?.toString();
      case 'admin':
        return data['adminId']?.toString();
      case 'fee_payment':
        return data['feePaymentId']?.toString();
      default:
        return null;
    }
  }

  /// Fetch and cache user ID from users/{uid}.
  static Future<String?> fetchAndCacheUserId() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        _clearCache();
        return null;
      }

      final usersDoc = await _firestore.collection('users').doc(user.uid).get();
      if (!usersDoc.exists) {
        _clearCache();
        return null;
      }

      final usersData = Map<String, dynamic>.from(usersDoc.data()!);
      final role = _normalizeRole((usersData['role'] ?? '').toString());
      if (role.isEmpty) {
        _clearCache();
        return null;
      }

      final roleId = _roleIdFromUsersDoc(role, usersData);
      if (roleId == null || roleId.isEmpty) {
        _clearCache();
        return null;
      }

      _currentUserId = roleId;
      _currentUserRole = role;
      _currentUserData = usersData;
      return _currentUserId;
    } catch (e) {
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
