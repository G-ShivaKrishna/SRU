import 'package:flutter/material.dart';
import '../../../widgets/app_header.dart';
import 'admin_course_management_screen.dart';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        backgroundColor: const Color(0xFF1e3a5f),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const AppHeader(),
            Padding(
              padding: EdgeInsets.all(isMobile ? 12 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Administration Panel',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1e3a5f),
                        ),
                  ),
                  const SizedBox(height: 24),
                  _buildAdminMenuGrid(context, isMobile),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdminMenuGrid(BuildContext context, bool isMobile) {
    return GridView.count(
      crossAxisCount: isMobile ? 1 : 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: isMobile ? 1.6 : 1.8,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      children: [
        _buildAdminMenuItem(
          context,
          title: 'Course Management',
          description: 'Manage courses and registration settings',
          icon: Icons.school,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const AdminCourseManagementScreen(),
              ),
            );
          },
        ),
        _buildAdminMenuItem(
          context,
          title: 'Faculty Management',
          description: 'Manage faculty and assignments',
          icon: Icons.person_outline,
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Faculty management coming soon'),
              ),
            );
          },
        ),
        _buildAdminMenuItem(
          context,
          title: 'Student Management',
          description: 'Manage student accounts and access',
          icon: Icons.group_outlined,
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Student management coming soon'),
              ),
            );
          },
        ),
        _buildAdminMenuItem(
          context,
          title: 'Reports',
          description: 'View academic reports and statistics',
          icon: Icons.bar_chart_outlined,
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Reports coming soon'),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildAdminMenuItem(
    BuildContext context, {
    required String title,
    required String description,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1e3a5f).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 32,
                  color: const Color(0xFF1e3a5f),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1e3a5f),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                description,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
