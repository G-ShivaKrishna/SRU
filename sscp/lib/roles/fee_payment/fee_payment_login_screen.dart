import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../config/dev_config.dart';
import '../../services/user_service.dart';
import '../../screens/role_selection_screen.dart';
import 'fee_payment_home.dart';

class FeePaymentLoginScreen extends StatefulWidget {
  const FeePaymentLoginScreen({super.key});

  @override
  State<FeePaymentLoginScreen> createState() => _FeePaymentLoginScreenState();
}

class _FeePaymentLoginScreenState extends State<FeePaymentLoginScreen> {
  final _feeIdController = TextEditingController();
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

  bool _validateFeeId(String feeId) {
    if (feeId.isEmpty) return false;
    return RegExp(r'^FEE[0-9]{3,5}$', caseSensitive: false)
        .hasMatch(feeId.trim());
  }

  Future<void> _handleLogin() async {
    final feeId = _feeIdController.text.trim();
    final password = _passwordController.text;

    if (!_validateFeeId(feeId)) {
      _showError('Fee Payment ID must be like FEE001');
      return;
    }

    if (password.length < 6) {
      _showError('Password must be at least 6 characters');
      return;
    }

    if (!_validateCaptcha()) {
      _showError('Invalid CAPTCHA. Please try again.');
      _refreshCaptcha();
      return;
    }

    if (DevConfig.bypassLogin) {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const FeePaymentHome()),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Normalize fee ID to uppercase
      final normalizedFeeId = feeId.toUpperCase();

      // Fetch fee payment staff data to get custom email from Firestore
      final feePaymentDoc = await FirebaseFirestore.instance
          .collection('feePaymentStaff')
          .doc(normalizedFeeId)
          .get();

      if (!feePaymentDoc.exists) {
        setState(() => _isLoading = false);
        _showError('Fee Payment staff record not found');
        _refreshCaptcha();
        return;
      }

      // Use the custom email stored in Firestore for authentication
      final customEmail = feePaymentDoc['email'] ?? '';
      if (customEmail.isEmpty) {
        setState(() => _isLoading = false);
        _showError('Email not configured for this staff');
        _refreshCaptcha();
        return;
      }

      await _auth.signInWithEmailAndPassword(
          email: customEmail, password: password);

      // Fetch and cache user ID from Firestore
      await UserService.fetchAndCacheUserId();

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const FeePaymentHome()),
      );
    } on FirebaseAuthException catch (e) {
      setState(() => _isLoading = false);
      _refreshCaptcha();

      if (e.code == 'user-not-found') {
        _showError('Fee Payment account not found. Contact admin.');
      } else if (e.code == 'wrong-password' ||
          e.code == 'invalid-credential' ||
          e.code == 'invalid-login-credentials' ||
          e.code == 'INVALID_LOGIN_CREDENTIALS') {
        _showErrorDialog('Incorrect Password',
            'The password you entered is incorrect. Would you like to reset your password?');
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
                  Icon(Icons.info_outline,
                      color: Colors.blue.shade700, size: 20),
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
    final size = MediaQuery.of(context).size;
    final panelWidth = size.width > 420 ? 360.0 : size.width - 32;
    final panelHeight = size.height > 820 ? 760.0 : 700.0;

    return Scaffold(
      backgroundColor: const Color(0xFFE9EBF1),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Container(
              width: panelWidth,
              height: panelHeight,
              decoration: BoxDecoration(
                color: const Color(0xFFDDE2EC),
                borderRadius: BorderRadius.circular(34),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x220B2A4A),
                    blurRadius: 28,
                    offset: Offset(0, 16),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  Container(
                    height: 148,
                    decoration: const BoxDecoration(
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(34),
                        topRight: Radius.circular(34),
                      ),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF1E88E5), Color(0xFF54A9EB)],
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: () {
                              Navigator.of(context).pushReplacement(
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const RoleSelectionScreen(),
                                ),
                              );
                            },
                            icon: const Icon(
                              Icons.arrow_back,
                              color: Colors.white,
                            ),
                          ),
                          const Expanded(
                            child: Text(
                              'Fee Payment Login',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 34 / 1.6,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 48),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    top: 114,
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 22),
                      decoration: const BoxDecoration(
                        color: Color(0xFFF0F2F7),
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(34),
                          topRight: Radius.circular(34),
                          bottomLeft: Radius.circular(34),
                          bottomRight: Radius.circular(34),
                        ),
                      ),
                      child: Column(
                        children: [
                          _buildInputField(
                            controller: _feeIdController,
                            hintText: 'Fee Payment ID',
                            icon: Icons.badge,
                            enabled: !_isLoading,
                          ),
                          const SizedBox(height: 14),
                          _buildInputField(
                            controller: _passwordController,
                            hintText: 'Password',
                            icon: Icons.lock,
                            enabled: !_isLoading,
                            obscureText: _obscurePassword,
                            suffixIcon: IconButton(
                              onPressed: () {
                                setState(
                                  () => _obscurePassword = !_obscurePassword,
                                );
                              },
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                                color: const Color(0xFF4D586D),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0F2F7),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFFB8BEC9)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Enter Captcha:',
                                  style: TextStyle(
                                    fontSize: 30 / 1.6,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF37445A),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFE3E5EB),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        _captchaText,
                                        style: const TextStyle(
                                          fontSize: 40 / 1.6,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 1.6,
                                          color: Color(0xFF202735),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      onPressed:
                                          _isLoading ? null : _refreshCaptcha,
                                      icon: const Icon(
                                        Icons.refresh,
                                        color: Color(0xFF4C586D),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                TextField(
                                  controller: _captchaController,
                                  enabled: !_isLoading,
                                  decoration: InputDecoration(
                                    hintText: 'Enter captcha text',
                                    hintStyle: const TextStyle(
                                      color: Color(0xFF7A8394),
                                      fontSize: 16,
                                    ),
                                    filled: true,
                                    fillColor: const Color(0xFFF0F2F7),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: const BorderSide(
                                        color: Color(0xFFB8BEC9),
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: const BorderSide(
                                        color: Color(0xFFB8BEC9),
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: const BorderSide(
                                        color: Color(0xFF1E88E5),
                                        width: 1.2,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            height: 46,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _handleLogin,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1E88E5),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(24),
                                ),
                                elevation: 2,
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                          Colors.white,
                                        ),
                                      ),
                                    )
                                  : const Text(
                                      'LOGIN',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    required bool enabled,
    bool obscureText = false,
    Widget? suffixIcon,
  }) {
    return TextField(
      controller: controller,
      enabled: enabled,
      obscureText: obscureText,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(
          color: Color(0xFF667185),
          fontSize: 30 / 1.6,
        ),
        filled: true,
        fillColor: const Color(0xFFF0F2F7),
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 12, right: 10),
          child: Container(
            width: 30,
            height: 30,
            decoration: const BoxDecoration(
              color: Color(0xFF1E88E5),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: Colors.white),
          ),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        suffixIcon: suffixIcon,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFB8BEC9)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFB8BEC9)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF1E88E5), width: 1.2),
        ),
      ),
    );
  }
}
