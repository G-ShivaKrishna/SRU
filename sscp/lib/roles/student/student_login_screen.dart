import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math';
import 'student_home.dart';
import '../../screens/role_selection_screen.dart';

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

    // Authenticate using Firebase Auth
    setState(() => _isLoading = true);

    try {
      // Use lowercase for Firebase Auth email
      final email = '${rollNumber.toLowerCase()}@sru.edu.in';

      await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

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
      } else if (e.code == 'wrong-password') {
        _showError('Incorrect password');
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
