import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';
import 'student_home.dart';
import '../../../services/user_service.dart';
import '../../screens/role_selection_screen.dart';
import '../../config/dev_config.dart';
import '../../../widgets/forgot_password_dialog.dart';
import '../../../widgets/reset_link_helper.dart';

class StudentLoginScreen extends StatefulWidget {
  const StudentLoginScreen({super.key});

  @override
  State<StudentLoginScreen> createState() => _StudentLoginScreenState();
}

class _StudentLoginScreenState extends State<StudentLoginScreen> {
  final _rollNumberController = TextEditingController();
  final _passwordController = TextEditingController();
  final _captchaController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  late String _captchaText;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    _generateCaptcha();
  }

  void _generateCaptcha() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    _captchaText =
        List.generate(6, (index) => chars[Random().nextInt(chars.length)])
            .join();
  }

  void _refreshCaptcha() {
    setState(() {
      _captchaController.clear();
      _generateCaptcha();
    });
  }

  bool _validateCaptcha() {
    return _captchaController.text.toUpperCase() == _captchaText;
  }

  bool _validateRollNumber(String rollNumber) {
    if (rollNumber.isEmpty) return false;
    // Accept format: 2203A51291 or 2203a51291
    return RegExp(r'^[0-9]{4}[A-Za-z]{1}[0-9]{5}$').hasMatch(rollNumber);
  }

  bool _validatePassword(String password) {
    return password.length >= 6;
  }

  Future<void> _handleLogin() async {
    final rollNumber = _rollNumberController.text.trim();
    final password = _passwordController.text;

    // Validate roll number format
    if (!_validateRollNumber(rollNumber)) {
      _showError('Roll number must be in format: 2203A51291');
      return;
    }

    // Validate password format
    if (!_validatePassword(password)) {
      _showError('Password must be at least 6 characters');
      return;
    }

    // Validate CAPTCHA
    if (!_validateCaptcha()) {
      _showError('Invalid CAPTCHA. Please try again.');
      _refreshCaptcha();
      return;
    }

    // Check if bypass is enabled
    if (DevConfig.bypassLogin) {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const StudentHome()),
        );
      }
      return;
    }

    // Authenticate using Firebase Auth with custom email from Firestore
    setState(() => _isLoading = true);

    try {
      // First, fetch student data to get custom email from Firestore
      final studentDoc = await FirebaseFirestore.instance
          .collection('students')
          .doc(rollNumber.toUpperCase())
          .get();

      if (!studentDoc.exists) {
        setState(() => _isLoading = false);
        _showError('Student record not found');
        return;
      }

      // Use the custom email stored in Firestore for authentication
      final customEmail = studentDoc['email'] ?? '';
      if (customEmail.isEmpty) {
        setState(() => _isLoading = false);
        _showError('Email not configured for this student');
        return;
      }

      await _auth.signInWithEmailAndPassword(
        email: customEmail,
        password: password,
      );

      // Fetch and cache user ID from Firestore
      await UserService.fetchAndCacheUserId();

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const StudentHome()),
        );
      }
    } on FirebaseAuthException catch (e) {
      setState(() => _isLoading = false);
      _refreshCaptcha();

      if (e.code == 'user-not-found') {
        _showError('Student account not found. Contact admin.');
      } else if (e.code == 'wrong-password' || 
                 e.code == 'invalid-credential' || 
                 e.code == 'invalid-login-credentials' ||
                 e.code == 'INVALID_LOGIN_CREDENTIALS') {
        _showErrorDialog('Incorrect Password',
            'The password you entered is incorrect. Would you like to reset your password?');
      } else if (e.code == 'invalid-email') {
        _showError('Invalid roll number format');
      } else {
        _showError('Login failed: ${e.message}');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _refreshCaptcha();
      _showError('An error occurred: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red.shade700, size: 24),
            const SizedBox(width: 8),
            Expanded(child: Text(title)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Use the "Forgot Password?" link below to reset your password securely via email.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade600,
            ),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Login'),
        backgroundColor: Colors.blue,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                  builder: (context) => const RoleSelectionScreen()),
            );
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _rollNumberController,
              enabled: !_isLoading,
              keyboardType: TextInputType.text,
              decoration: InputDecoration(
                labelText: 'Roll Number',
                hintText: 'e.g., 2203A51291',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                prefixIcon: const Icon(Icons.badge),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              enabled: !_isLoading,
              obscureText: _obscurePassword,
              decoration: InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                prefixIcon: const Icon(Icons.lock),
                suffixIcon: IconButton(
                  icon: Icon(_obscurePassword
                      ? Icons.visibility_off
                      : Icons.visibility),
                  onPressed: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton.icon(
                  onPressed: _isLoading
                      ? null
                      : () {
                          showDialog(
                            context: context,
                            builder: (context) => const ResetLinkHelper(),
                          );
                        },
                  icon: const Icon(Icons.link, size: 16),
                  label: const Text('Have a reset link?'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.green.shade700,
                    padding: const EdgeInsets.symmetric(horizontal: 0),
                  ),
                ),
                TextButton(
                  onPressed: _isLoading
                      ? null
                      : () {
                          showDialog(
                            context: context,
                            builder: (context) => const ForgotPasswordDialog(
                              role: 'student',
                            ),
                          );
                        },
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 0),
                  ),
                  child: const Text(
                    'Forgot Password?',
                    style: TextStyle(color: Colors.blue, fontSize: 14),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Enter Captcha:'),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _captchaText,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      IconButton(
                        onPressed: _isLoading ? null : _refreshCaptcha,
                        icon: const Icon(Icons.refresh),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _captchaController,
                    enabled: !_isLoading,
                    decoration: InputDecoration(
                      hintText: 'Enter captcha text',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handleLogin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade500,
                  disabledBackgroundColor: Colors.grey[400],
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        'Login',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _rollNumberController.dispose();
    _passwordController.dispose();
    _captchaController.dispose();
    super.dispose();
  }
}
