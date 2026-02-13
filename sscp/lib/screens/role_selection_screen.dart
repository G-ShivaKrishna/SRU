import 'package:flutter/material.dart';
import '../config/dev_config.dart';
import '../roles/student/student_login_screen.dart';
import '../roles/student/student_home.dart';
import '../roles/faculty/faculty_login_screen.dart';
import '../roles/faculty/faculty_home.dart';
import '../roles/admin/admin_home.dart';

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 40),
            // Logo removed for clean startup
            const SizedBox(height: 0),
            const SizedBox(height: 30),
            // Title
            const Text(
              'Select Role',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            // Subtitle
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                'Select an Attendant if you do service & select manager if it is managerial work',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white70,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 50),
            // Role Buttons
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 30),
                  child: Column(
                    children: [
                      _buildRoleButton(
                        context,
                        label: 'Student',
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
                      const SizedBox(height: 20),
                      _buildRoleButton(
                        context,
                        label: 'Teacher/Faculty',
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
                      const SizedBox(height: 20),
                      _buildRoleButton(
                        context,
                        label: 'Admin',
                        onPressed: () {
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(
                                builder: (context) => const AdminHome()),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleButton(
    BuildContext context, {
    required String label,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue.shade700,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
