import 'package:flutter/material.dart';
import '../config/dev_config.dart';
import '../roles/student/student_login_screen.dart';
import '../roles/student/student_home.dart';
import '../roles/faculty/faculty_login_screen.dart';
import '../roles/faculty/faculty_home.dart';
import '../roles/fee_payment/fee_payment_login_screen.dart';
import '../roles/fee_payment/fee_payment_home.dart';
import '../roles/admin/admin_home.dart';

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1e3a5f), Color(0xFF2a5178)],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Column(
                    children: [
                      const SizedBox(height: 30),
                      // Header
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          children: [
                            SizedBox(
                              width: isMobile ? 72 : 92,
                              height: isMobile ? 72 : 92,
                              child: Image.asset(
                                'assets/images/logo.png',
                                fit: BoxFit.contain,
                              ),
                            ),
                            const SizedBox(height: 20),
                            const Text(
                              'Select Role',
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Choose your role to continue',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 50),
                      // Role Cards
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          children: [
                            _buildRoleCard(
                              context,
                              icon: Icons.school,
                              label: 'Student',
                              subtitle: 'Student type',
                              onPressed: () {
                                Navigator.of(context).pushReplacement(
                                  MaterialPageRoute(
                                    builder: (context) => DevConfig.bypassLogin
                                        ? const StudentHome()
                                        : const StudentLoginScreen(),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 16),
                            _buildRoleCard(
                              context,
                              icon: Icons.person,
                              label: 'Teacher / Faculty',
                              subtitle: 'Teacher/Faculty',
                              onPressed: () {
                                Navigator.of(context).pushReplacement(
                                  MaterialPageRoute(
                                    builder: (context) => DevConfig.bypassLogin
                                        ? const FacultyHome()
                                        : const FacultyLoginScreen(),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 16),
                            _buildRoleCard(
                              context,
                              icon: Icons.security,
                              label: 'Admin',
                              subtitle: 'Admin portal',
                              onPressed: () {
                                Navigator.of(context).pushReplacement(
                                  MaterialPageRoute(
                                    builder: (context) => const AdminHome(),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 16),
                            _buildRoleCard(
                              context,
                              icon: Icons.credit_card,
                              label: 'Fee Payment',
                              subtitle: 'Fee management',
                              onPressed: () {
                                Navigator.of(context).pushReplacement(
                                  MaterialPageRoute(
                                    builder: (context) => DevConfig.bypassLogin
                                        ? const FeePaymentHome()
                                        : const FeePaymentLoginScreen(),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 50),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildRoleCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String subtitle,
    required VoidCallback onPressed,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: const Color(0xFF1e3a5f).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: const Color(0xFF1e3a5f),
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1e3a5f),
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: Colors.grey[400],
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
