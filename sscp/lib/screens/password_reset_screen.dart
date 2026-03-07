import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Password Reset Screen - handles Firebase reset links with custom UI
/// Verifies the reset code from email and allows user to set new password
class PasswordResetScreen extends StatefulWidget {
  final String? oobCode; // The reset code from Firebase email link

  const PasswordResetScreen({
    super.key,
    this.oobCode,
  });

  @override
  State<PasswordResetScreen> createState() => _PasswordResetScreenState();
}

class _PasswordResetScreenState extends State<PasswordResetScreen> {
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _auth = FirebaseAuth.instance;

  bool _isLoading = false;
  bool _showNewPassword = false;
  bool _showConfirmPassword = false;
  bool _isVerifying = true;
  String? _errorMessage;
  String? _userEmail;

  @override
  void initState() {
    super.initState();
    _verifyResetCode();
  }

  @override
  void dispose() {
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _verifyResetCode() async {
    if (widget.oobCode == null || widget.oobCode!.isEmpty) {
      setState(() {
        _isVerifying = false;
        _errorMessage = 'Invalid or missing reset code';
      });
      return;
    }

    try {
      // Verify the password reset code is valid
      final email = await _auth.verifyPasswordResetCode(widget.oobCode!);
      setState(() {
        _userEmail = email;
        _isVerifying = false;
      });
    } on FirebaseAuthException catch (e) {
      setState(() {
        _isVerifying = false;
        if (e.code == 'expired-action-code') {
          _errorMessage =
              'This reset link has expired. Please request a new one.';
        } else if (e.code == 'invalid-action-code') {
          _errorMessage =
              'This reset link is invalid or has already been used.';
        } else {
          _errorMessage = 'Error: ${e.message}';
        }
      });
    } catch (e) {
      setState(() {
        _isVerifying = false;
        _errorMessage = 'An error occurred: $e';
      });
    }
  }

  Future<void> _handlePasswordReset() async {
    final newPassword = _newPasswordController.text;
    final confirmPassword = _confirmPasswordController.text;

    // Validation
    if (newPassword.isEmpty) {
      setState(() => _errorMessage = 'Please enter a new password');
      return;
    }

    if (newPassword.length < 6) {
      setState(
          () => _errorMessage = 'Password must be at least 6 characters long');
      return;
    }

    if (newPassword != confirmPassword) {
      setState(() => _errorMessage = 'Passwords do not match');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Confirm the password reset with Firebase
      await _auth.confirmPasswordReset(
        code: widget.oobCode!,
        newPassword: newPassword,
      );

      if (!mounted) return;

      // Show success dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green.shade700, size: 28),
              const SizedBox(width: 12),
              const Text('Success!'),
            ],
          ),
          content: const Text(
            'Your password has been reset successfully.\n\nYou can now log in with your new password.',
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                Navigator.of(context)
                    .popUntil((route) => route.isFirst); // Go to login
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade600,
              ),
              child: const Text('Go to Login'),
            ),
          ],
        ),
      );
    } on FirebaseAuthException catch (e) {
      setState(() {
        _isLoading = false;
        if (e.code == 'weak-password') {
          _errorMessage =
              'Password is too weak. Please choose a stronger password.';
        } else {
          _errorMessage = 'Error: ${e.message}';
        }
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'An error occurred: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reset Password'),
        backgroundColor: const Color(0xFF1e3a5f),
        foregroundColor: Colors.white,
      ),
      body: _isVerifying
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Verifying reset link...'),
                ],
              ),
            )
          : _errorMessage != null && _userEmail == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          color: Colors.red.shade700,
                          size: 64,
                        ),
                        const SizedBox(height: 24),
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.red.shade700,
                          ),
                        ),
                        const SizedBox(height: 32),
                        ElevatedButton.icon(
                          onPressed: () => Navigator.of(context)
                              .popUntil((route) => route.isFirst),
                          icon: const Icon(Icons.arrow_back),
                          label: const Text('Back to Login'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : SingleChildScrollView(
                  child: Padding(
                    padding: EdgeInsets.all(isMobile ? 16 : 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header
                        Container(
                          padding: EdgeInsets.all(isMobile ? 12 : 16),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.blue.shade200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.lock_reset,
                                    color: Colors.blue.shade700,
                                    size: 24,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Reset Your Password',
                                      style: TextStyle(
                                        fontSize: isMobile ? 16 : 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue.shade700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'for $_userEmail',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.blue.shade600,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Enter your new password below',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.blue.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // New Password Field
                        const Text(
                          'New Password',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _newPasswordController,
                          enabled: !_isLoading,
                          obscureText: !_showNewPassword,
                          decoration: InputDecoration(
                            hintText: 'Enter new password (min 6 characters)',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            prefixIcon: const Icon(Icons.lock),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _showNewPassword
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                              ),
                              onPressed: () {
                                setState(
                                    () => _showNewPassword = !_showNewPassword);
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Confirm Password Field
                        const Text(
                          'Confirm Password',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _confirmPasswordController,
                          enabled: !_isLoading,
                          obscureText: !_showConfirmPassword,
                          decoration: InputDecoration(
                            hintText: 'Re-enter your password',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            prefixIcon: const Icon(Icons.lock),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _showConfirmPassword
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                              ),
                              onPressed: () {
                                setState(() => _showConfirmPassword =
                                    !_showConfirmPassword);
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Error Message
                        if (_errorMessage != null) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.red.shade100,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.red.shade300),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.error_outline,
                                    color: Colors.red.shade700, size: 20),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: TextStyle(
                                      color: Colors.red.shade700,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],

                        // Reset Button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _isLoading ? null : _handlePasswordReset,
                            icon: _isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                          Colors.white),
                                    ),
                                  )
                                : const Icon(Icons.check_circle),
                            label: Text(
                              _isLoading ? 'Resetting...' : 'Reset Password',
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              backgroundColor: const Color(0xFF1e3a5f),
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: Colors.grey[400],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Cancel Button
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: _isLoading
                                ? null
                                : () => Navigator.of(context)
                                    .popUntil((route) => route.isFirst),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: const Text('Cancel'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }
}
