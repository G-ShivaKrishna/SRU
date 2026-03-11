import 'package:shared_preferences/shared_preferences.dart';

class SessionData {
  final String role;
  final String? uid;
  final String? roleId;
  final String? email;

  const SessionData({
    required this.role,
    this.uid,
    this.roleId,
    this.email,
  });
}

/// Persists the logged-in role across app restarts.
class SessionService {
  static const _roleKey = 'saved_role';
  static const _uidKey = 'saved_uid';
  static const _roleIdKey = 'saved_role_id';
  static const _emailKey = 'saved_email';

  static String _normalizeRole(String role) {
    final value = role.trim().toLowerCase();
    if (value == 'feepayment' || value == 'fee payment') {
      return 'fee_payment';
    }
    if (value == 'feePayment') {
      return 'fee_payment';
    }
    return value;
  }

  static Future<void> saveSession({
    required String role,
    String? uid,
    String? roleId,
    String? email,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_roleKey, _normalizeRole(role));

    if (uid != null && uid.isNotEmpty) {
      await prefs.setString(_uidKey, uid);
    } else {
      await prefs.remove(_uidKey);
    }

    if (roleId != null && roleId.isNotEmpty) {
      await prefs.setString(_roleIdKey, roleId);
    } else {
      await prefs.remove(_roleIdKey);
    }

    if (email != null && email.isNotEmpty) {
      await prefs.setString(_emailKey, email);
    } else {
      await prefs.remove(_emailKey);
    }
  }

  /// Call after successful login. [role] should be one of:
  /// 'admin' | 'student' | 'faculty' | 'fee_payment'
  static Future<void> saveRole(String role) async {
    await saveSession(role: role);
  }

  /// Call on logout.
  static Future<void> clearRole() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_roleKey);
    await prefs.remove(_uidKey);
    await prefs.remove(_roleIdKey);
    await prefs.remove(_emailKey);
  }

  /// Returns the saved role, or null if no session exists.
  static Future<String?> getSavedRole() async {
    final prefs = await SharedPreferences.getInstance();
    final role = prefs.getString(_roleKey);
    return role == null ? null : _normalizeRole(role);
  }

  static Future<SessionData?> getSession() async {
    final prefs = await SharedPreferences.getInstance();
    final role = prefs.getString(_roleKey);
    if (role == null || role.isEmpty) {
      return null;
    }
    return SessionData(
      role: _normalizeRole(role),
      uid: prefs.getString(_uidKey),
      roleId: prefs.getString(_roleIdKey),
      email: prefs.getString(_emailKey),
    );
  }
}
