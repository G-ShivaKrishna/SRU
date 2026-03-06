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
                    alignment: const Alignment(0, 0.15),
                    child: const Text(
                      'Select Role',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 42 / 1.6,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 114,
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
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
                          const SizedBox(height: 14),
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
                          const SizedBox(height: 14),
                          _buildRoleCard(
                            context,
                            icon: Icons.verified_user,
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
                          const SizedBox(height: 14),
                          _buildRoleCard(
                            context,
                            icon: Icons.credit_card,
                            label: 'Fee Payment',
                            subtitle: 'Credit card',
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
                  ),
                ],
              ),
            ),
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F8FA),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE3E6ED)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x120A2E4E),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
                     decoration: const BoxDecoration(
                       color: Color(0xFFD8EBFA),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: const Color(0xFF1E88E5),
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF2D3C57),
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF8A93A4),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: Color(0xFFB0B6C4),
              size: 30,
            ),
          ],
        ),
      ),
    );
  }
}
