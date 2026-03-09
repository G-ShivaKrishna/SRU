import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';
import 'student_home.dart';
import '../../../services/user_service.dart';
import '../../../services/session_service.dart';
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

      // Use the firebase email stored in Firestore for authentication
      final customEmail =
          (studentDoc['firebaseEmail'] ?? studentDoc['email'] ?? '') as String;
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
      await SessionService.saveRole('student');

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
      } else if (e.code == 'network-request-failed') {
        _showError(
            'Network error. Please check your internet connection and try again.');
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
                color: const Color(0xFFEAF0F6),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFF9EB0C7)),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Color(0xFF1e3a5f),
                    size: 20,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Use the "Forgot Password?" link below to reset your password securely via email.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF1e3a5f),
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
              backgroundColor: const Color(0xFF1e3a5f),
              foregroundColor: Colors.white,
            ),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Login'),
        backgroundColor: const Color(0xFF1e3a5f),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => const RoleSelectionScreen(),
              ),
            );
          },
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(isMobile ? 16 : 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 40),
              Icon(
                Icons.school,
                size: isMobile ? 60 : 80,
                color: const Color(0xFF1e3a5f),
              ),
              const SizedBox(height: 24),
              Text(
                'Student Login',
                style: TextStyle(
                  fontSize: isMobile ? 20 : 28,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1e3a5f),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Enter your credentials',
                style: TextStyle(
                  fontSize: isMobile ? 12 : 14,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 48),
              TextField(
                controller: _rollNumberController,
                enabled: !_isLoading,
                keyboardType: TextInputType.text,
                decoration: InputDecoration(
                  labelText: 'Roll Number',
                  hintText: 'e.g., 2203A51291',
                  prefixIcon: const Icon(Icons.badge),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                enabled: !_isLoading,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Password',
                  hintText: 'Enter your password',
                  prefixIcon: const Icon(Icons.lock),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off
                          : Icons.visibility,
                    ),
                    onPressed: () {
                      setState(
                        () => _obscurePassword = !_obscurePassword,
                      );
                    },
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
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
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF1e3a5f),
                    ),
                    icon: const Icon(Icons.link, size: 16),
                    label: const Text('Have a reset link?'),
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
                      foregroundColor: const Color(0xFF1e3a5f),
                    ),
                    child: const Text('Forgot Password?'),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF0F6),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF1e3a5f)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      'Enter CAPTCHA: $_captchaText',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                        color: Color(0xFF1e3a5f),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _captchaController,
                            enabled: !_isLoading,
                            decoration: InputDecoration(
                              hintText: 'Enter captcha text',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: _isLoading ? null : _refreshCaptcha,
                          icon: const Icon(Icons.refresh),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleLogin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1e3a5f),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : const Text(
                          'LOGIN',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
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
