import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../screens/role_selection_screen.dart';
import '../../config/dev_config.dart';
import 'screens/academics_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/course_registration_screen.dart';
import 'screens/attendance_screen.dart';
import 'screens/results_screen.dart';
import 'screens/feedback_screen.dart';
import 'screens/exams_screen.dart';
import 'screens/university_clubs_screen.dart';
import 'screens/central_library_screen.dart';

class StudentHome extends StatefulWidget {
  const StudentHome({super.key});

  @override
  State<StudentHome> createState() => _StudentHomeState();
}

class _StudentHomeState extends State<StudentHome> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  User? _currentUser;
  Map<String, dynamic>? _studentData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStudentData();
  }

  Future<void> _loadStudentData() async {
    try {
      final user = _auth.currentUser;

      // If bypass is enabled or no user logged in, use default data
      if (DevConfig.bypassLogin || user == null) {
        setState(() {
          _studentData = {
            'name': 'Demo Student',
            'hallTicketNumber': '2203A51318',
            'department': 'cse',
            'batchNumber': '18',
            'email': 'demo@sru.edu.in',
            'program': 'BTECH',
            'mentorName': 'Dr. Demo Mentor',
            'mentorPhone': '9999999999',
            'mentorEmail': 'mentor@sru.edu.in',
          };
          _isLoading = false;
        });
        return;
      }

      _currentUser = user;
      // Extract roll number from email and convert to uppercase for Firestore query
      final email = _currentUser?.email ?? '';
      final rollNumber = email.split('@')[0].toUpperCase();

      final doc = await _firestore.collection('students').doc(rollNumber).get();
      if (doc.exists) {
        setState(() {
          _studentData = doc.data();
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _navigateToPage(BuildContext context, String pageName) {
    Widget page;

    switch (pageName) {
      case 'Home':
        return;
      case 'Academics':
        page = const AcademicsScreen();
        break;
      case 'Profile':
        page = const ProfileScreen();
        break;
      case 'Course Reg.':
        page = const CourseRegistrationScreen();
        break;
      case 'Attendance':
        page = const AttendanceScreen();
        break;
      case 'Results':
        page = const ResultsScreen();
        break;
      case 'Feedback':
        page = const FeedbackScreen();
        break;
      case 'Exams':
        page = const ExamsScreen();
        break;
      case 'Central Library':
        page = const CentralLibraryScreen();
        break;
      case 'University Clubs':
        _launchURL('https://www.sruclub.in/');
        return;
      default:
        return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => page),
    );
  }

  Future<void> _launchURL(String url) async {
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      throw 'Could not launch $url';
    }
  }

  Future<void> _logout() async {
    await _auth.signOut();
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const RoleSelectionScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final isMobile = MediaQuery.of(context).size.width < 600;
    final name = _studentData?['name'] ?? 'Student';
    final rollNumber = _currentUser?.email?.split('@')[0].toUpperCase() ?? 'DEMO';
    final hallTicketNumber = _studentData?['hallTicketNumber'] ?? rollNumber;
    final department =
        _studentData?['department']?.toString().toUpperCase() ?? 'CSE';
    final batchNumber = _studentData?['batchNumber'] ?? 'N/A';
    final email = _studentData?['email'] ?? _currentUser?.email ?? 'N/A';
    final program = _studentData?['program'] ?? 'BTECH';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Academics & Administration Portal'),
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
                  const Text('Password', style: TextStyle(color: Colors.white)),
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
            _buildWelcomeSection(
                context, name, hallTicketNumber, program, department),
            _buildTimetableLink(context),
            Padding(
              padding: EdgeInsets.all(isMobile ? 12 : 16),
              child: Column(
                children: [
                  _buildStudentDetailsCard(context, hallTicketNumber, name,
                      email, department, batchNumber),
                  const SizedBox(height: 24),
                  _buildAcademicsCardsGrid(context),
                  const SizedBox(height: 24),
                  _buildMentorCard(context),
                  const SizedBox(height: 24),
                  _buildChartSection('Last Week Attendance %', context),
                  const SizedBox(height: 24),
                  _buildChartSection('Course Wise Attendance %', context),
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
      'Academics',
      'Profile',
      'Course Reg.',
      'Attendance',
      'Results',
      'Feedback',
      'Exams',
      'University Clubs',
      'Central Library',
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
                    .take(4)
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
                      item != 'Home' &&
                      !['Academics', 'Profile', 'Course Reg.', 'Attendance']
                          .contains(item))
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
          const Text(
            'No Due',
            style: TextStyle(color: Colors.white, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeSection(BuildContext context, String name,
      String hallTicketNumber, String program, String department) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Container(
      color: const Color(0xFF1e3a5f),
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      child: Text(
        'Welcome to $name - $hallTicketNumber - $program - $department',
        style: TextStyle(
          color: Colors.yellow,
          fontSize: isMobile ? 12 : 14,
          fontWeight: FontWeight.bold,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildStudentDetailsCard(BuildContext context, String hallTicketNumber,
      String name, String email, String department, String batchNumber) {
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
                  color: Colors.blue.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child:
                    Icon(Icons.person, color: Colors.blue.shade700, size: 32),
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
                      hallTicketNumber,
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
          _buildDetailRow('Department', department, isMobile),
          const SizedBox(height: 12),
          _buildDetailRow('Batch Number', batchNumber, isMobile),
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

  Widget _buildAcademicsCardsGrid(BuildContext context) {
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
        _buildAcademicsCard(
          'Year-Semester',
          _studentData?['yearSemester'] ?? 'N/A',
          Colors.teal,
          context,
        ),
        _buildAcademicsCard(
          'Attendance %',
          '${_studentData?['attendance'] ?? '0'}%',
          Colors.green,
          context,
        ),
        _buildAcademicsCard(
          'CGPA',
          _studentData?['cgpa'] ?? '0.0',
          Colors.orange,
          context,
        ),
        _buildAcademicsCard(
          'Backlogs',
          '${_studentData?['backlogs'] ?? '0'}',
          Colors.red,
          context,
        ),
      ],
    );
  }

  Widget _buildAcademicsCard(
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

  Widget _buildMentorCard(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final mentorName = _studentData?['mentorName'] ?? 'N/A';
    final mentorPhone = _studentData?['mentorPhone'] ?? 'N/A';
    final mentorEmail = _studentData?['mentorEmail'] ?? 'N/A';

    return Container(
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        border: Border.all(color: Colors.amber.shade200, width: 2),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.person_outline,
                  color: Colors.amber.shade700, size: 24),
              const SizedBox(width: 8),
              Text(
                'Mentoring Staff',
                style: TextStyle(
                  fontSize: isMobile ? 13 : 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.amber.shade900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildDetailRow('Name', mentorName, isMobile),
          const SizedBox(height: 10),
          _buildDetailRow('Phone', mentorPhone, isMobile),
          const SizedBox(height: 10),
          _buildDetailRow('Email', mentorEmail, isMobile),
        ],
      ),
    );
  }

  Widget _buildChartSection(String title, BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final chartHeight = isMobile ? 150.0 : 200.0;

    return Container(
      color: const Color(0xFF2d3e4f),
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: Colors.white,
              fontSize: isMobile ? 14 : 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            height: chartHeight,
            color: Colors.grey[300],
            child: const Center(
              child: Text('Chart Placeholder'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimetableLink(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return GestureDetector(
      onTap: () {
        _launchURL('https://timetable.sruniv.com/batchReport');
      },
      child: Container(
        color: Colors.blue,
        padding: EdgeInsets.all(isMobile ? 10 : 12),
        width: double.infinity,
        child: Text(
          'Click Here to View Your Timetable',
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
