import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math';
import 'faculty_home.dart';
import '../../screens/role_selection_screen.dart';
import '../../config/dev_config.dart';

class FacultyLoginScreen extends StatefulWidget {
  const FacultyLoginScreen({super.key});

  @override
  State<FacultyLoginScreen> createState() => _FacultyLoginScreenState();
}

class _FacultyLoginScreenState extends State<FacultyLoginScreen> {
  final _facultyIdController = TextEditingController();
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

  bool _validateFacultyId(String facultyId) {
    if (facultyId.isEmpty) return false;
    return RegExp(r'^[A-Za-z]{3}[0-9]{3,5}$').hasMatch(facultyId);
  }

  bool _validatePassword(String password) {
    return password.length >= 6;
  }

  Future<void> _handleLogin() async {
    final facultyId = _facultyIdController.text.trim();
    final password = _passwordController.text;

    if (!_validateFacultyId(facultyId)) {
      _showError('Faculty ID must be in format: FAC001');
      return;
    }

    if (!_validatePassword(password)) {
      _showError('Password must be at least 6 characters');
      return;
    }

    if (!_validateCaptcha()) {
      _showError('Invalid CAPTCHA. Please try again.');
      _refreshCaptcha();
      return;
    }

    if (DevConfig.bypassLogin) {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const FacultyHome()),
        );
      }
      return;
    }

    setState(() => _isLoading = true);

    try {
      final email = '${facultyId.toLowerCase()}@sru.edu.in';

      await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const FacultyHome()),
        );
      }
    } on FirebaseAuthException catch (e) {
      setState(() => _isLoading = false);
      _refreshCaptcha();

      if (e.code == 'user-not-found') {
        _showError('Faculty account not found. Contact admin.');
      } else if (e.code == 'wrong-password') {
        _showError('Incorrect password');
      } else if (e.code == 'invalid-email') {
        _showError('Invalid faculty ID format');
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
        title: const Text('Faculty Login'),
        backgroundColor: const Color(0xFF1e3a5f),
        foregroundColor: Colors.white,
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
              controller: _facultyIdController,
              enabled: !_isLoading,
              keyboardType: TextInputType.text,
              decoration: InputDecoration(
                labelText: 'Faculty ID',
                hintText: 'e.g., FAC001',
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
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1e3a5f),
                ),
                onPressed: _isLoading ? null : _handleLogin,
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'Login',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
