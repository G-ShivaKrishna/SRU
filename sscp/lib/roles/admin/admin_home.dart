import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'pages/mentor_assignment_page.dart';
import '../../screens/role_selection_screen.dart';
import '../../services/user_service.dart';
import 'pages/unified_permissions_page.dart';
import 'pages/account_creation_page.dart';
import 'pages/student_name_edit_page.dart';
import 'pages/student_admission_edit_page.dart';
import 'pages/academic_calendar_management_page.dart';
import 'pages/faculty_assignment_page.dart';
import 'pages/subject_management_page.dart';
import 'pages/student_promotion_page.dart';
import 'pages/feedback_management_page.dart';
import 'pages/regulations_management_page.dart';
import 'pages/syllabus_management_page.dart';
import 'pages/grievance_management_page.dart';
import 'pages/attendance_management_page.dart';
import 'pages/results_management_page.dart';
import 'pages/makeup_mid_management_page.dart';
import 'screens/admin_course_management_screen.dart';
import 'screens/admin_cie_memo_release_screen.dart';
import 'screens/admin_lookup_screen.dart';
import 'pages/audit_log_viewer_page.dart';

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
    setState(() => _isLoading = true);

    try {
      final authUser = FirebaseAuth.instance.currentUser;
      final userEmail = authUser?.email?.trim() ?? '';
      String? adminId = UserService.getCurrentUserId();

      if (adminId == null || adminId.isEmpty) {
        adminId = await UserService.fetchAndCacheUserId();
      }

      Map<String, dynamic>? backendData;
      String resolvedAdminId = (adminId ?? '').trim().toUpperCase();

      // Preferred lookup: document ID based on adminId.
      if (resolvedAdminId.isNotEmpty) {
        final byIdDoc = await FirebaseFirestore.instance
            .collection('admin')
            .doc(resolvedAdminId)
            .get();
        if (byIdDoc.exists) {
          backendData = byIdDoc.data();
          resolvedAdminId = byIdDoc.id;
        }
      }

      // Fallback lookup: email.
      if (backendData == null && userEmail.isNotEmpty) {
        final byEmail = await FirebaseFirestore.instance
            .collection('admin')
            .where('email', isEqualTo: userEmail.toLowerCase())
            .limit(1)
            .get();

        if (byEmail.docs.isNotEmpty) {
          final doc = byEmail.docs.first;
          backendData = doc.data();
          resolvedAdminId = doc.id;
        }

        // Additional fallback for case-mismatched stored emails.
        if (backendData == null) {
          final allAdmins =
              await FirebaseFirestore.instance.collection('admin').get();
          for (final doc in allAdmins.docs) {
            final storedEmail =
                (doc.data()['email'] ?? '').toString().toLowerCase().trim();
            if (storedEmail == userEmail.toLowerCase()) {
              backendData = doc.data();
              resolvedAdminId = doc.id;
              break;
            }
          }
        }
      }

      final roleValue =
          _readString(backendData, ['role', 'designation']).isNotEmpty
              ? _readString(backendData, ['role', 'designation'])
              : 'admin';

      final mappedData = <String, dynamic>{
        'name': _readString(backendData, ['name', 'adminName']).isNotEmpty
            ? _readString(backendData, ['name', 'adminName'])
            : 'Admin User',
        'adminId': _readString(backendData, ['adminId']).isNotEmpty
            ? _readString(backendData, ['adminId'])
            : (resolvedAdminId.isNotEmpty ? resolvedAdminId : 'ADM001'),
        'email': _readString(backendData, ['email']).isNotEmpty
            ? _readString(backendData, ['email'])
            : userEmail,
        // As requested, designation is treated as backend role.
        'designation': roleValue,
      };

      if (!mounted) return;
      setState(() {
        _adminData = mappedData;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _adminData = {
          'name': 'Admin User',
          'adminId': 'ADM001',
          'email':
              FirebaseAuth.instance.currentUser?.email ?? 'admin@sru.edu.in',
          'designation': 'admin',
        };
        _isLoading = false;
      });
    }
  }

  String _readString(Map<String, dynamic>? data, List<String> keys) {
    if (data == null) return '';
    for (final key in keys) {
      final value = data[key]?.toString().trim() ?? '';
      if (value.isNotEmpty) return value;
    }
    return '';
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
    } else if (pageName == 'Year Management' ||
        pageName == 'Student Promotion') {
      page = const StudentPromotionPage();
    } else if (pageName == 'View Only') {
      page = const AdminLookupScreen();
    } else if (pageName == 'Academic Calendar') {
      page = const AcademicCalendarManagementPage();
    } else if (pageName == 'Course Management') {
      page = const AdminCourseManagementScreen();
    } else if (pageName == 'Sem Memo Release' ||
        pageName == 'CIE Memo Release') {
      page = const AdminCieMemoReleaseScreen();
    } else if (pageName == 'Subject Management') {
      page = const SubjectManagementPage();
    } else if (pageName == 'Faculty Assignment') {
      page = const FacultyAssignmentPage();
    } else if (pageName == 'Mentor Assignment') {
      page = const MentorAssignmentPage();
    } else if (pageName == 'Lookup') {
      page = const AdminLookupScreen();
    } else if (pageName == 'Feedback Management') {
      page = const FeedbackManagementPage();
    } else if (pageName == 'Regulations') {
      page = const RegulationsManagementPage();
    } else if (pageName == 'Syllabus') {
      page = const SyllabusManagementPage();
    } else if (pageName == 'Grievances') {
      page = const GrievanceManagementPage();
    } else if (pageName == 'Attendance Management') {
      page = const AttendanceManagementPage();
    } else if (pageName == 'Results Management') {
      page = const ResultsManagementPage();
    } else if (pageName == 'Supply Exam') {
      page = const ResultsManagementPage(initialTab: 1);
    } else if (pageName == 'Makeup Mid') {
      page = const MakeupMidManagementPage();
    } else if (pageName == 'Audit Trail') {
      page = const AuditLogViewerPage();
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

  // Width estimate: text chars + horizontal padding (20) + chevron icon+gap (20) + buffer (6)
  double _itemWidth(String label) => label.length * 7.5 + 46;

  Widget _buildNavigationMenu(BuildContext context) {
    const menuItems = [
      'Home',
      'Accounts',
      'Manage Access',
      'Edit Names',
      'Management',
      'Academic',
      'Assignments',
      'Grievances',
      'Lookup',
    ];

    const managementSubItems = [
      'Year Management',
      'Sem Memo Release',
      'Subject Management',
      'Course Management',
      'Feedback Management',
      'Attendance Management',
      'Supply Exam',
      'Makeup Mid',
    ];

    const academicSubItems = [
      'Academic Calendar',
      'Regulations',
      'Syllabus',
    ];

    const assignmentsSubItems = [
      'Faculty Assignment',
      'Mentor Assignment',
    ];

    const allSubMenus = <String, List<String>>{
      'Management': managementSubItems,
      'Academic': academicSubItems,
      'Assignments': assignmentsSubItems,
    };

    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxWidth;
        const moreButtonWidth = 90.0;
        final budget = available - 8;

        final totalWidth =
            menuItems.fold(0.0, (s, item) => s + _itemWidth(item));

        List<String> visible;
        List<String> overflow;

        if (totalWidth <= budget) {
          visible = List<String>.from(menuItems);
          overflow = <String>[];
        } else {
          visible = <String>[];
          overflow = <String>[];
          double used = 0;
          for (final item in menuItems) {
            final w = _itemWidth(item);
            if (used + w + moreButtonWidth <= budget) {
              visible.add(item);
              used += w;
            } else {
              overflow.add(item);
            }
          }
        }

        return SizedBox(
          width: available,
          child: Container(
            color: const Color(0xFF1e3a5f),
            height: 42,
            child: ClipRect(
              child: Row(
                mainAxisSize: MainAxisSize.max,
                children: [
                  ...visible.map((item) {
                    final isHome = item == 'Home';
                    final subItems = allSubMenus[item];
                    final showChevron =
                        item != visible.last || overflow.isNotEmpty;
                    final labelWidget = Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 10),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isHome)
                            const Icon(Icons.home,
                                color: Colors.white70, size: 14),
                          if (isHome) const SizedBox(width: 4),
                          Text(
                            item,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (showChevron)
                            const Padding(
                              padding: EdgeInsets.only(left: 6),
                              child: Icon(Icons.chevron_right,
                                  color: Colors.white38, size: 14),
                            ),
                        ],
                      ),
                    );
                    if (subItems != null) {
                      return PopupMenuButton<String>(
                        offset: const Offset(0, 42),
                        color: const Color(0xFF1e3a5f),
                        onSelected: (value) => _navigateToPage(context, value),
                        itemBuilder: (_) => subItems
                            .map((s) => PopupMenuItem<String>(
                                  value: s,
                                  height: 40,
                                  child: Text(s,
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500)),
                                ))
                            .toList(),
                        child: labelWidget,
                      );
                    }
                    return InkWell(
                      onTap: () => _navigateToPage(context, item),
                      hoverColor: Colors.white.withOpacity(0.12),
                      child: labelWidget,
                    );
                  }),
                  if (overflow.isNotEmpty)
                    _OverflowNavButton(
                      items: overflow,
                      subMenus: allSubMenus,
                      onSelected: (item) => _navigateToPage(context, item),
                    ),
                  const Spacer(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusBar(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Container(
      width: double.infinity,
      color: const Color(0xFF1e3a5f),
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 16,
        vertical: 8,
      ),
      child: const Row(
        children: [
          Icon(Icons.check_circle, color: Colors.green, size: 16),
          SizedBox(width: 8),
          Text(
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
      width: double.infinity,
      color: const Color(0xFF1e3a5f),
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      child: Text(
        'Welcome to Admin - $adminId - $designation',
        style: TextStyle(
          color: Colors.yellow,
          fontSize: isMobile ? 12 : 14,
          fontWeight: FontWeight.bold,
        ),
        textAlign: TextAlign.right,
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
                child: const Icon(Icons.admin_panel_settings,
                    color: Color(0xFF1e3a5f), size: 32),
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
        _buildActionCard(
          'CIE Memo\nRelease',
          Icons.assignment_turned_in,
          Colors.indigo,
          context,
          () => _navigateToPage(context, 'Sem Memo Release'),
        ),
        _buildActionCard(
          'Lookup',
          Icons.manage_search,
          const Color(0xFF1e3a5f),
          context,
          () => _navigateToPage(context, 'Lookup'),
        ),
        _buildActionCard(
          'Regulations',
          Icons.menu_book,
          Colors.deepPurple,
          context,
          () => _navigateToPage(context, 'Regulations'),
        ),
        _buildActionCard(
          'Syllabus',
          Icons.import_contacts,
          Colors.teal,
          context,
          () => _navigateToPage(context, 'Syllabus'),
        ),
        _buildActionCard(
          'Grievances',
          Icons.report_problem,
          Colors.deepOrange,
          context,
          () => _navigateToPage(context, 'Grievances'),
        ),
        _buildActionCard(
          'Attendance\nManagement',
          Icons.fact_check,
          Colors.brown,
          context,
          () => _navigateToPage(context, 'Attendance Management'),
        ),
        _buildActionCard(
          'Results &\nBacklogs',
          Icons.school,
          Colors.indigo,
          context,
          () => _navigateToPage(context, 'Results Management'),
        ),
        _buildActionCard(
          'Supply Exam\nEnable',
          Icons.event_available,
          Colors.green.shade700,
          context,
          () => _navigateToPage(context, 'Supply Exam'),
        ),
        _buildActionCard(
          'Makeup Mid\nExam',
          Icons.edit_calendar,
          Colors.teal,
          context,
          () => _navigateToPage(context, 'Makeup Mid'),
        ),
        _buildActionCard(
          'Audit Trail',
          Icons.history,
          Colors.deepPurple.shade700,
          context,
          () => _navigateToPage(context, 'Audit Trail'),
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
              const Icon(Icons.history, color: Color(0xFF1e3a5f), size: 24),
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
      onTap: () => _navigateToPage(context, 'Audit Trail'),
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

// ─────────────────────────────────────────────────────────────────────────────
// Overflow "More ▼" nav button — opens a bottom sheet with expandable groups
// ─────────────────────────────────────────────────────────────────────────────
class _OverflowNavButton extends StatelessWidget {
  final List<String> items;
  final Map<String, List<String>> subMenus;
  final void Function(String) onSelected;

  const _OverflowNavButton({
    required this.items,
    required this.subMenus,
    required this.onSelected,
  });

  void _openSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1e3a5f),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
      ),
      builder: (_) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: items.map((item) {
            final subs = subMenus[item];
            if (subs != null) {
              // Expandable parent — sub-items shown only when tapped
              return Theme(
                data: ThemeData(
                  dividerColor: Colors.transparent,
                  colorScheme: const ColorScheme.dark(),
                ),
                child: ExpansionTile(
                  tilePadding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
                  iconColor: Colors.white70,
                  collapsedIconColor: Colors.white54,
                  title: Text(
                    item,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  children: subs
                      .map((sub) => ListTile(
                            contentPadding:
                                const EdgeInsets.only(left: 40, right: 20),
                            title: Text(
                              sub,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                              ),
                            ),
                            onTap: () {
                              Navigator.pop(context);
                              onSelected(sub);
                            },
                          ))
                      .toList(),
                ),
              );
            }
            // Regular item
            return ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20),
              title: Text(
                item,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                onSelected(item);
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _openSheet(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('More',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500)),
            SizedBox(width: 4),
            Icon(Icons.arrow_drop_down, color: Colors.white70, size: 18),
          ],
        ),
      ),
    );
  }
}
