import 'package:flutter/material.dart';
import '../../screens/role_selection_screen.dart';
import 'pages/account_creation_page.dart';
import 'pages/view_only_page.dart';
import 'pages/permission_management_page.dart';

class AdminHome extends StatelessWidget {
  const AdminHome({super.key});

  void _navigateToPage(BuildContext context, String pageName) {
    Widget page;

    switch (pageName) {
      case 'Upload Accounts':
        page = const AccountCreationPage();
        break;
      case 'View Data':
        page = const ViewOnlyPage();
        break;
      case 'Permissions':
        page = const PermissionManagementPage();
        break;
      default:
        return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => page),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        backgroundColor: const Color(0xFF1e3a5f),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => const RoleSelectionScreen(),
              ),
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
              onPressed: () {},
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
              onPressed: () {},
            ),
          ],
          const SizedBox(width: 16),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildNavigationMenu(context),
            _buildStatusBar(context),
            _buildWelcomeSection(context),
            Padding(
              padding: EdgeInsets.all(isMobile ? 12 : 16),
              child: Column(
                children: [
                  _buildAdminProfileCard(context),
                  const SizedBox(height: 20),
                  _buildStatsGrid(context),
                  const SizedBox(height: 24),
                  _buildQuickActionsGrid(context),
                  const SizedBox(height: 24),
                  _buildRecentActivitySection(context),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavigationMenu(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final menuItems = [
      'Home',
      'Upload Accounts',
      'View Data',
      'Permissions',
    ];

    if (isMobile) {
      return _buildMobileMenu(context, menuItems);
    } else {
      return _buildDesktopMenu(context, menuItems);
    }
  }

  Widget _buildMobileMenu(BuildContext context, List<String> menuItems) {
    return Container(
      color: const Color(0xFF1e3a5f),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: menuItems
                    .where((item) => item != 'Home')
                    .take(3)
                    .map((item) {
                  return GestureDetector(
                    onTap: () => _navigateToPage(context, item),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 8),
                      child: Text(
                        item,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopMenu(BuildContext context, List<String> menuItems) {
    return Container(
      color: const Color(0xFF1e3a5f),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: menuItems.map((item) {
            return GestureDetector(
              onTap: () => _navigateToPage(context, item),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                child: Text(
                  item,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildStatusBar(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Container(
      color: const Color(0xFF1e3a5f),
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 16,
        vertical: 8,
      ),
      child: const Row(
        children: [
          Text(
            'System Status: Active',
            style: TextStyle(color: Colors.white, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeSection(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Container(
      color: const Color(0xFF1e3a5f),
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      child: Text(
        'Welcome to Admin Control Center - System Administrator',
        style: TextStyle(
          color: Colors.yellow,
          fontSize: isMobile ? 12 : 14,
          fontWeight: FontWeight.bold,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildAdminProfileCard(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final profileImageSize = isMobile ? 80.0 : 100.0;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: profileImageSize,
          height: profileImageSize,
          decoration: BoxDecoration(
            color: const Color(0xFF1e3a5f),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.admin_panel_settings,
              size: 40, color: Colors.white),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ADMIN - System Administrator',
                style: TextStyle(
                  fontSize: isMobile ? 14 : 16,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Text(
                'Full Access to All Systems',
                style: TextStyle(fontSize: isMobile ? 11 : 12),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                'Admin ID - ADM001',
                style: TextStyle(fontSize: isMobile ? 11 : 12),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatsGrid(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final crossAxisCount =
        isMobile ? 2 : (MediaQuery.of(context).size.width < 1024 ? 2 : 4);
    final childAspectRatio = isMobile ? 1.2 : 1.4;

    return GridView.count(
      crossAxisCount: crossAxisCount,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: childAspectRatio,
      children: [
        _buildStatCard('Total Students', '1,245', Colors.teal, context),
        _buildStatCard('Total Faculty', '89', Colors.green, context),
        _buildStatCard('Pending Requests', '12', Colors.orange, context),
        _buildStatCard('Active Permissions', '34', Colors.blue, context),
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
        borderRadius: BorderRadius.circular(8),
      ),
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: isMobile ? 18 : 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: isMobile ? 10 : 12,
              color: Colors.white,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.bottomRight,
            child: Text(
              'More info >',
              style: TextStyle(
                fontSize: isMobile ? 8 : 10,
                color: Colors.white.withOpacity(0.8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsGrid(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: TextStyle(
            fontSize: isMobile ? 14 : 16,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 12),
        _buildActionCard(
          context,
          'Upload Accounts',
          'Create student & faculty accounts via Excel',
          Icons.cloud_upload,
          Colors.blue,
          () => _navigateToPage(context, 'Upload Accounts'),
        ),
        const SizedBox(height: 12),
        _buildActionCard(
          context,
          'View Data (Read-Only)',
          'Browse student and faculty information',
          Icons.visibility,
          Colors.green,
          () => _navigateToPage(context, 'View Data'),
        ),
        const SizedBox(height: 12),
        _buildActionCard(
          context,
          'Manage Permissions',
          'Grant or revoke edit permissions',
          Icons.security,
          Colors.purple,
          () => _navigateToPage(context, 'Permissions'),
        ),
      ],
    );
  }

  Widget _buildActionCard(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[300]!),
        ),
        padding: EdgeInsets.all(isMobile ? 12 : 16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: isMobile ? 13 : 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: isMobile ? 10 : 11,
                      color: Colors.grey[600],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward, color: Colors.grey[600], size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentActivitySection(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Container(
      color: const Color(0xFF2d3e4f),
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recent Activity',
            style: TextStyle(
              color: Colors.white,
              fontSize: isMobile ? 14 : 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildActivityItem('150 Students uploaded', '2 hours ago', Icons.check_circle, Colors.green),
          const SizedBox(height: 12),
          _buildActivityItem('45 Faculty accounts updated', '5 hours ago', Icons.info, Colors.blue),
          const SizedBox(height: 12),
          _buildActivityItem('12 Permission requests pending', 'Today', Icons.schedule, Colors.orange),
          const SizedBox(height: 12),
          _buildActivityItem('System backup completed', 'Yesterday', Icons.backup, Colors.teal),
        ],
      ),
    );
  }

  Widget _buildActivityItem(String title, String time, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
              const SizedBox(height: 2),
              Text(
                time,
                style: TextStyle(color: Colors.grey[400], fontSize: 10),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
