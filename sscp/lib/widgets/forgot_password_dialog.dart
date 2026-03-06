import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Forgot Password Dialog - works for all roles
/// User enters their ID, system looks up email and sends reset link
class ForgotPasswordDialog extends StatefulWidget {
  final String role; // 'student', 'faculty', or 'feePayment'

  const ForgotPasswordDialog({
    super.key,
    required this.role,
  });

  @override
  State<ForgotPasswordDialog> createState() => _ForgotPasswordDialogState();
}

class _ForgotPasswordDialogState extends State<ForgotPasswordDialog> {
  final _idController = TextEditingController();
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _idController.dispose();
    super.dispose();
  }

  String _getCollectionName() {
    switch (widget.role) {
      case 'faculty':
        return 'faculty';
      case 'feePayment':
        return 'feePayments';
      default:
        return 'students';
    }
  }

  String _getIdFieldName() {
    switch (widget.role) {
      case 'faculty':
        return 'facultyId';
      case 'feePayment':
        return 'feePaymentId';
      default:
        return 'hallTicketNumber';
    }
  }

  Future<void> _handleForgotPassword() async {
    final idInput = _idController.text.trim().toUpperCase();
    
    if (idInput.isEmpty) {
      setState(() => _errorMessage = 'Please enter your ${widget.role == 'student' ? 'roll number' : 'ID'}');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final collection = _getCollectionName();
      final idField = _getIdFieldName();

      // Query Firestore to find the user and get their email
      final Query query = _firestore.collection(collection).where(idField, isEqualTo: idInput);
      final QuerySnapshot snapshot = await query.limit(1).get();

      if (snapshot.docs.isEmpty) {
        setState(() {
          _isLoading = false;
          _errorMessage = '${widget.role == 'student' ? 'Roll number' : 'ID'} not found';
        });
        return;
      }

      // Get the custom email from the document
      final userDoc = snapshot.docs.first;
      final customEmail = userDoc['email']?.toString() ?? '';

      if (customEmail.isEmpty) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Email not configured for this ${widget.role}';
        });
        return;
      }

      // Send password reset email via Firebase
      await _auth.sendPasswordResetEmail(email: customEmail);

      if (!mounted) return;

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Password reset link sent to $customEmail'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 4),
        ),
      );

      // Close dialog
      Navigator.of(context).pop();
    } on FirebaseAuthException catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error: ${e.message}';
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
    return AlertDialog(
      title: const Text('Forgot Password'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Enter your ${widget.role == 'student' ? 'roll number' : 'ID'} to receive a password reset link',
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _idController,
              enabled: !_isLoading,
              decoration: InputDecoration(
                hintText: widget.role == 'student'
                    ? 'e.g., 22CSB001'
                    : widget.role == 'faculty'
                        ? 'e.g., FAC001'
                        : 'e.g., FEE001',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                prefixIcon: const Icon(Icons.person),
              ),
              textInputAction: TextInputAction.done,
              onSubmitted: _isLoading ? null : (_) => _handleForgotPassword(),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red.shade700, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(
                          color: Colors.red.shade700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _handleForgotPassword,
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Send Reset Link'),
        ),
      ],
    );
  }
}
