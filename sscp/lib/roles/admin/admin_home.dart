import 'package:flutter/material.dart';
import '../../screens/role_selection_screen.dart';
import 'pages/view_only_page.dart';
import 'pages/permission_management_page.dart';
import 'pages/account_creation_page.dart';
import 'pages/student_profile_edit_access_page.dart';

class AdminHome extends StatelessWidget {
  const AdminHome({super.key});

  static const String routeName = '/adminHome';

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        backgroundColor: Colors.red,
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
        actions: [
          if (!isMobile) ...[
            TextButton(
              onPressed: () {},
              child:
                  const Text('Settings', style: TextStyle(color: Colors.white)),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                      builder: (context) => const RoleSelectionScreen()),
                );
              },
              child:
                  const Text('Logout', style: TextStyle(color: Colors.white)),
            ),
          ] else ...[
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () {},
            ),
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                      builder: (context) => const RoleSelectionScreen()),
                );
              },
            ),
          ],
          const SizedBox(width: 16),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildAdminHeader(context, isMobile),
            _buildStatusBar(context, isMobile),
            Padding(
              padding: EdgeInsets.all(isMobile ? 12 : 16),
              child: Column(
                children: [
                  _buildStatsGrid(context, isMobile),
                  const SizedBox(height: 24),
                  _buildActionsGrid(context, isMobile),
                  const SizedBox(height: 24),
                  _buildRecentActivityCard(context, isMobile),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdminHeader(BuildContext context, bool isMobile) {
    return Container(
      color: Colors.red,
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Welcome Admin',
            style: TextStyle(
              color: Colors.yellow,
              fontSize: isMobile ? 12 : 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'System Administration Portal',
            style: TextStyle(
              color: Colors.white70,
              fontSize: isMobile ? 11 : 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBar(BuildContext context, bool isMobile) {
    return Container(
      color: Colors.red,
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 16,
        vertical: 8,
      ),
      child: Row(
        children: [
          const Icon(Icons.info, color: Colors.white, size: 16),
          const SizedBox(width: 8),
          const Text(
            'System Status: All Systems Operational',
            style: TextStyle(color: Colors.white, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid(BuildContext context, bool isMobile) {
    return GridView.count(
      crossAxisCount: isMobile ? 2 : 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: isMobile ? 1.2 : 1.3,
      children: [
        _buildStatCard('Total Students', '1,250', Colors.blue, context),
        _buildStatCard('Total Faculty', '85', Colors.green, context),
        _buildStatCard('Total Courses', '42', Colors.orange, context),
        _buildStatCard('Pending Issues', '12', Colors.red, context),
      ],
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    Color backgroundColor,
    BuildContext context,
  ) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: backgroundColor.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: EdgeInsets.all(isMobile ? 12 : 14),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: isMobile ? 20 : 26,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: isMobile ? 10 : 12,
              color: Colors.white.withOpacity(0.9),
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildActionsGrid(BuildContext context, bool isMobile) {
    return GridView.count(
      crossAxisCount: isMobile ? 2 : 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: isMobile ? 1.1 : 1.2,
      children: [
        _buildActionCard(
          'Upload\nAccounts',
          Icons.cloud_upload,
          Colors.blue,
          context,
          () => Navigator.of(context).push(
            MaterialPageRoute(
                builder: (context) => const AccountCreationPage()),
          ),
        ),
        _buildActionCard(
          'Grant Edit\nAccess',
          Icons.edit_note,
          Colors.cyan,
          context,
          () => Navigator.of(context).push(
            MaterialPageRoute(
                builder: (context) => const StudentProfileEditAccessPage()),
          ),
        ),
        _buildActionCard(
          'View\nData',
          Icons.visibility,
          Colors.green,
          context,
          () => Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => const ViewOnlyPage()),
          ),
        ),
        _buildActionCard(
          'Manage\nPermissions',
          Icons.security,
          Colors.orange,
          context,
          () => Navigator.of(context).push(
            MaterialPageRoute(
                builder: (context) => const PermissionManagementPage()),
          ),
        ),
      ],
    );
  }

  Widget _buildActionCard(
    String label,
    IconData icon,
    Color backgroundColor,
    BuildContext context,
    VoidCallback onTap,
  ) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: backgroundColor.withOpacity(0.1),
          border: Border.all(color: backgroundColor, width: 2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: isMobile ? 32 : 40,
              color: backgroundColor,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: isMobile ? 10 : 12,
                fontWeight: FontWeight.w600,
                color: backgroundColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentActivityCard(BuildContext context, bool isMobile) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recent Activity',
            style: TextStyle(
              fontSize: isMobile ? 14 : 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          _buildActivityItem(
              'New student registered', 'Today 10:30 AM', Icons.person_add),
          const Divider(height: 16),
          _buildActivityItem(
              'Faculty password updated', 'Today 09:15 AM', Icons.security),
          const Divider(height: 16),
          _buildActivityItem(
              'Course schedule modified', 'Yesterday 3:45 PM', Icons.edit),
          const Divider(height: 16),
          _buildActivityItem(
              'System backup completed', 'Yesterday 2:20 PM', Icons.backup),
        ],
      ),
    );
  }

  Widget _buildActivityItem(String title, String time, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: Colors.red, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                time,
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showComingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature feature coming soon!'),
        backgroundColor: Colors.blue,
      ),
    );
  }
}
