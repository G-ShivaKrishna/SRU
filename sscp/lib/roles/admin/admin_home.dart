import 'package:flutter/material.dart';
import '../../screens/role_selection_screen.dart';
import 'pages/view_only_page.dart';
import 'pages/unified_permissions_page.dart';
import 'pages/account_creation_page.dart';
import 'pages/student_name_edit_page.dart';
import 'pages/student_admission_edit_page.dart';
import 'pages/academic_calendar_management_page.dart';
import 'pages/faculty_assignment_page.dart';
import 'pages/subject_management_page.dart';
import 'pages/student_promotion_page.dart';
import 'screens/admin_course_management_screen.dart';

class AdminHome extends StatefulWidget {
  const AdminHome({super.key});

  static const String routeName = '/adminHome';

  @override
  State<AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends State<AdminHome> {
  Map<String, dynamic>? _adminData;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadAdminData();
  }

  Future<void> _loadAdminData() async {
    // Load admin data - for now using demo data
    setState(() {
      _adminData = {
        'name': 'Admin User',
        'adminId': 'ADM001',
        'department': 'Administration',
        'email': 'admin@sru.edu.in',
        'phone': '9876543210',
        'designation': 'System Administrator',
      };
      _isLoading = false;
    });
  }

  void _navigateToPage(BuildContext context, String pageName) {
    Widget page;

    if (pageName == 'Home') {
      return;
    } else if (pageName == 'Accounts') {
      page = const AccountCreationPage();
    } else if (pageName == 'Manage Access' || pageName == 'Permissions') {
      page = const UnifiedPermissionsPage();
    } else if (pageName == 'Edit Names' || pageName == 'Names') {
      page = const StudentNameEditPage();
    } else if (pageName == 'Edit Admission' || pageName == 'Admission') {
      page = const StudentAdmissionEditPage();
    } else if (pageName == 'Student Promotion') {
      page = const StudentPromotionPage();
    } else if (pageName == 'View Only') {
      page = const ViewOnlyPage();
    } else if (pageName == 'Academic Calendar') {
      page = const AcademicCalendarManagementPage();
    } else if (pageName == 'Course Management') {
      page = const AdminCourseManagementScreen();
    } else if (pageName == 'Subject Management') {
      page = const SubjectManagementPage();
    } else if (pageName == 'Faculty Assignment') {
      page = const FacultyAssignmentPage();
    } else {
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => page),
    );
  }

  Future<void> _logout() async {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const RoleSelectionScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final isMobile = MediaQuery.of(context).size.width < 600;
    final adminName = _adminData?['name'] ?? 'Admin';
    final adminId = _adminData?['adminId'] ?? 'ADM001';
    final email = _adminData?['email'] ?? 'admin@sru.edu.in';
    final designation = _adminData?['designation'] ?? 'Administrator';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin & Administration Portal'),
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
        actions: [
          if (!isMobile) ...[
            TextButton(
              onPressed: () {},
              child:
                  const Text('Settings', style: TextStyle(color: Colors.white)),
            ),
            TextButton(
              onPressed: _logout,
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
              onPressed: _logout,
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
            _buildWelcomeSection(context, adminName, adminId, designation),
            _buildSystemOverviewLink(context),
            Padding(
              padding: EdgeInsets.all(isMobile ? 12 : 16),
              child: Column(
                children: [
                  _buildAdminDetailsCard(
                      context, adminId, adminName, email, designation),
                  const SizedBox(height: 24),
                  _buildAdminStatsGrid(context),
                  const SizedBox(height: 24),
                  _buildSystemOverviewCard(context),
                  const SizedBox(height: 24),
                  _buildQuickActionsGrid(context),
                  const SizedBox(height: 24),
                  _buildRecentActivityCard(context),
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
      'Accounts',
      'Manage Access',
      'Edit Names',
      'Edit Admission',
      'Student Promotion',
      'Academic Calendar',
      'Subject Management',
      'Faculty Assignment',
      'Course Management',
      'View Only',
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
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_horiz, color: Colors.white),
            color: const Color(0xFF1e3a5f),
            onSelected: (value) => _navigateToPage(context, value),
            itemBuilder: (BuildContext context) {
              return menuItems
                  .where((item) =>
                      item != 'Home')
                  .map((String choice) {
                return PopupMenuItem<String>(
                  value: choice,
                  child: Text(
                    choice,
                    style: const TextStyle(color: Colors.white),
                  ),
                );
              }).toList();
            },
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
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 16),
          const SizedBox(width: 8),
          const Text(
            'System Status: All Systems Operational',
            style: TextStyle(color: Colors.white, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeSection(
      BuildContext context, String name, String adminId, String designation) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Container(
      color: const Color(0xFF1e3a5f),
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      child: Text(
        'Welcome to Admin - $adminId - $designation',
        style: TextStyle(
          color: Colors.yellow,
          fontSize: isMobile ? 12 : 14,
          fontWeight: FontWeight.bold,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildAdminDetailsCard(BuildContext context, String adminId,
      String name, String email, String designation) {
    final isMobile = MediaQuery.of(context).size.width < 600;

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
          Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: const Color(0xFF1e3a5f).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.admin_panel_settings,
                    color: const Color(0xFF1e3a5f), size: 32),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        fontSize: isMobile ? 14 : 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      adminId,
                      style: TextStyle(
                        fontSize: isMobile ? 11 : 12,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),
          _buildDetailRow('Email', email, isMobile),
          const SizedBox(height: 12),
          _buildDetailRow('Designation', designation, isMobile),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, bool isMobile) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: TextStyle(
              fontSize: isMobile ? 10 : 11,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: isMobile ? 10 : 11,
              color: Colors.grey.shade900,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildAdminStatsGrid(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final crossAxisCount =
        isMobile ? 2 : (MediaQuery.of(context).size.width < 1024 ? 2 : 4);
    final childAspectRatio = isMobile ? 1.1 : 1.3;

    return GridView.count(
      crossAxisCount: crossAxisCount,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: childAspectRatio,
      children: [
        _buildStatsCard(
          'Total Students',
          '1,250',
          Colors.blue,
          context,
        ),
        _buildStatsCard(
          'Active Admins',
          '15',
          Colors.green,
          context,
        ),
        _buildStatsCard(
          'Departments',
          '8',
          Colors.orange,
          context,
        ),
        _buildStatsCard(
          'Pending Tasks',
          '12',
          Colors.red,
          context,
        ),
      ],
    );
  }

  Widget _buildStatsCard(
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
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: isMobile ? 10 : 11,
              color: Colors.white.withOpacity(0.9),
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildSystemOverviewCard(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Container(
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        border: Border.all(color: Colors.blue.shade200, width: 2),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.dashboard, color: Colors.blue.shade700, size: 24),
              const SizedBox(width: 8),
              Text(
                'System Overview',
                style: TextStyle(
                  fontSize: isMobile ? 13 : 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildSystemMetric(
              'Database Status', 'Healthy', Colors.green, isMobile),
          const SizedBox(height: 10),
          _buildSystemMetric('Server Load', '35%', Colors.orange, isMobile),
          const SizedBox(height: 10),
          _buildSystemMetric(
              'Last Backup', '2 hours ago', Colors.blue, isMobile),
        ],
      ),
    );
  }

  Widget _buildSystemMetric(
      String label, String value, Color statusColor, bool isMobile) {
    return Row(
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: TextStyle(
              fontSize: isMobile ? 10 : 11,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.2),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: statusColor.withOpacity(0.5)),
          ),
          child: Text(
            value,
            style: TextStyle(
              fontSize: isMobile ? 10 : 11,
              color: statusColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActionsGrid(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final crossAxisCount =
        isMobile ? 2 : (MediaQuery.of(context).size.width < 1024 ? 2 : 4);
    final childAspectRatio = isMobile ? 1.1 : 1.2;

    return GridView.count(
      crossAxisCount: crossAxisCount,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: childAspectRatio,
      children: [
        _buildActionCard(
          'Upload\nAccounts',
          Icons.cloud_upload,
          Colors.blue,
          context,
          () => _navigateToPage(context, 'Accounts'),
        ),
        _buildActionCard(
          'Manage\nAccess',
          Icons.security,
          Colors.purple,
          context,
          () => _navigateToPage(context, 'Permissions'),
        ),
        _buildActionCard(
          'Edit Names',
          Icons.person_outline,
          Colors.cyan,
          context,
          () => _navigateToPage(context, 'Names'),
        ),
        _buildActionCard(
          'Edit Admission',
          Icons.school,
          Colors.teal,
          context,
          () => _navigateToPage(context, 'Admission'),
        ),
        _buildActionCard(
          'Course\nManagement',
          Icons.library_books,
          Colors.orange,
          context,
          () => _navigateToPage(context, 'Course Management'),
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
            Icon(
              icon,
              size: isMobile ? 28 : 40,
              color: Colors.white,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: isMobile ? 10 : 11,
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentActivityCard(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

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
          Row(
            children: [
              Icon(Icons.history, color: const Color(0xFF1e3a5f), size: 24),
              const SizedBox(width: 8),
              Text(
                'Recent Activity',
                style: TextStyle(
                  fontSize: isMobile ? 13 : 14,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1e3a5f),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildActivityItem(
              'Student accounts uploaded', '30 min ago', isMobile),
          const SizedBox(height: 10),
          _buildActivityItem(
              'Permissions granted to 5 users', '2 hours ago', isMobile),
          const SizedBox(height: 10),
          _buildActivityItem(
              'System backup completed', '5 hours ago', isMobile),
        ],
      ),
    );
  }

  Widget _buildActivityItem(String activity, String time, bool isMobile) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: Colors.blue,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                activity,
                style: TextStyle(
                  fontSize: isMobile ? 10 : 11,
                  color: Colors.grey.shade900,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                time,
                style: TextStyle(
                  fontSize: isMobile ? 9 : 10,
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSystemOverviewLink(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return GestureDetector(
      onTap: () {
        // Navigate to system overview or external resource
      },
      child: Container(
        color: Colors.blue,
        padding: EdgeInsets.all(isMobile ? 10 : 12),
        width: double.infinity,
        child: Text(
          'Click Here to View System Logs',
          style: TextStyle(
            color: Colors.white,
            fontSize: isMobile ? 12 : 14,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
