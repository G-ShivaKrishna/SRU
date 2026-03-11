import 'package:shared_preferences/shared_preferences.dart';

/// Persists the logged-in role across app restarts.
class SessionService {
  static const _roleKey = 'saved_role';

  /// Call after successful login. [role] should be one of:
  /// 'admin' | 'student' | 'faculty' | 'fee_payment'
  static Future<void> saveRole(String role) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_roleKey, role);
  }

  /// Call on logout.
  static Future<void> clearRole() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_roleKey);
  }

  /// Returns the saved role, or null if no session exists.
  static Future<String?> getSavedRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_roleKey);
  }
}
