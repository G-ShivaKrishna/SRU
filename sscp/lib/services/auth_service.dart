import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'session_service.dart';
import 'user_service.dart';

class AuthResult {
  final bool success;
  final String message;
  final String? role;
  final String? roleId;
  final String? uid;

  const AuthResult({
    required this.success,
    required this.message,
    this.role,
    this.roleId,
    this.uid,
  });
}

class AuthService {
  AuthService._();

  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _fs = FirebaseFirestore.instance;

  static String normalizeRole(String role) {
    final value = role.trim().toLowerCase();
    if (value == 'feepayment' || value == 'fee payment') {
      return 'fee_payment';
    }
    return value;
  }

  static Future<AuthResult> loginWithRoleId({
    required String role,
    required String roleId,
    required String password,
  }) async {
    final normalizedRole = normalizeRole(role);
    final normalizedRoleId = roleId.trim().toUpperCase();

    try {
      final roleDoc = await _readRoleDoc(normalizedRole, normalizedRoleId);
      if (roleDoc == null) {
        return const AuthResult(
          success: false,
          message: 'Account record not found for the entered ID.',
        );
      }

      final authEmail = _readAuthEmail(roleDoc);
      if (authEmail.isEmpty) {
        return const AuthResult(
          success: false,
          message: 'Email is not configured for this account.',
        );
      }

      await _auth.signInWithEmailAndPassword(
        email: authEmail,
        password: password,
      );

      final authUser = _auth.currentUser;
      if (authUser == null) {
        return const AuthResult(
          success: false,
          message: 'Login failed. Please try again.',
        );
      }

      final usersRef = _fs.collection('users').doc(authUser.uid);
      final usersSnap = await usersRef.get();

      Map<String, dynamic> usersData;
      if (usersSnap.exists) {
        usersData = Map<String, dynamic>.from(usersSnap.data()!);
      } else {
        usersData = _buildUsersDoc(
          uid: authUser.uid,
          role: normalizedRole,
          roleId: normalizedRoleId,
          authEmail: authEmail,
          roleDoc: roleDoc,
        );
        await usersRef.set(usersData, SetOptions(merge: true));
      }

      String storedRole = normalizeRole((usersData['role'] ?? '').toString());
      if (storedRole.isEmpty) {
        storedRole = normalizedRole;
        await usersRef.set({'role': storedRole}, SetOptions(merge: true));
      }

      String? storedRoleId = _extractRoleId(storedRole, usersData);
      if (storedRoleId == null || storedRoleId.isEmpty) {
        storedRoleId = normalizedRoleId;
        await usersRef.set(
          {_roleIdField(storedRole): storedRoleId},
          SetOptions(merge: true),
        );
      }

      if (storedRole != normalizedRole) {
        await _auth.signOut();
        return const AuthResult(
          success: false,
          message:
              'This account belongs to a different role. Please choose the correct role.',
        );
      }

      if (storedRoleId.toUpperCase() != normalizedRoleId) {
        await _auth.signOut();
        return const AuthResult(
          success: false,
          message: 'Entered ID does not match this account.',
        );
      }

      await SessionService.saveSession(
        role: storedRole,
        uid: authUser.uid,
        roleId: storedRoleId,
        email: authEmail,
      );

      UserService.cacheCurrentUser(
        userId: storedRoleId,
        role: storedRole,
        userData: usersData,
      );

      return AuthResult(
        success: true,
        message: 'Login successful',
        role: storedRole,
        roleId: storedRoleId,
        uid: authUser.uid,
      );
    } on FirebaseAuthException catch (e) {
      return AuthResult(
        success: false,
        message: _mapAuthError(e.code, e.message),
      );
    } catch (_) {
      return const AuthResult(
        success: false,
        message: 'An unexpected error occurred during login.',
      );
    }
  }

  static Future<Map<String, dynamic>?> _readRoleDoc(
    String role,
    String roleId,
  ) async {
    final collection = _collectionForRole(role);
    final doc = await _fs.collection(collection).doc(roleId).get();
    if (!doc.exists) {
      return null;
    }
    return Map<String, dynamic>.from(doc.data()!);
  }

  static String _collectionForRole(String role) {
    switch (role) {
      case 'student':
        return 'students';
      case 'faculty':
        return 'faculty';
      case 'admin':
        return 'admin';
      case 'fee_payment':
        return 'feePayments';
      default:
        return 'users';
    }
  }

  static String _roleIdField(String role) {
    switch (role) {
      case 'student':
        return 'studentId';
      case 'faculty':
        return 'facultyId';
      case 'admin':
        return 'adminId';
      case 'fee_payment':
        return 'feePaymentId';
      default:
        return 'userId';
    }
  }

  static String? _extractRoleId(String role, Map<String, dynamic> data) {
    final field = _roleIdField(role);
    final value = data[field]?.toString().trim() ?? '';
    if (value.isNotEmpty) {
      return value;
    }
    return null;
  }

  static String _readAuthEmail(Map<String, dynamic> roleDoc) {
    final firebaseEmail = roleDoc['firebaseEmail']?.toString().trim() ?? '';
    if (firebaseEmail.isNotEmpty) {
      return firebaseEmail.toLowerCase();
    }
    final email = roleDoc['email']?.toString().trim() ?? '';
    return email.toLowerCase();
  }

  static Map<String, dynamic> _buildUsersDoc({
    required String uid,
    required String role,
    required String roleId,
    required String authEmail,
    required Map<String, dynamic> roleDoc,
  }) {
    final data = <String, dynamic>{
      'uid': uid,
      'role': role,
      _roleIdField(role): roleId,
      'email': authEmail,
      'customEmail': roleDoc['email']?.toString().trim(),
      'idBasedEmail': roleDoc['idBasedEmail']?.toString().trim(),
      'migratedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    return data;
  }

  static String _mapAuthError(String code, String? fallbackMessage) {
    switch (code) {
      case 'user-not-found':
        return 'Account not found. Contact admin.';
      case 'wrong-password':
      case 'invalid-credential':
      case 'invalid-login-credentials':
      case 'INVALID_LOGIN_CREDENTIALS':
        return 'Incorrect password.';
      case 'invalid-email':
        return 'Invalid account email configuration.';
      case 'network-request-failed':
        return 'Network error. Please check your connection and try again.';
      default:
        return fallbackMessage ?? 'Login failed. Please try again.';
    }
  }
}
