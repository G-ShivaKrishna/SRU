import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../screens/role_selection_screen.dart';
import '../../config/dev_config.dart';
import 'screens/profile_screen.dart';
import 'screens/attendance_screen.dart';
import 'screens/academics_screen.dart';
import 'screens/results_screen.dart';
import 'screens/feedback_screen.dart';

class FacultyHome extends StatefulWidget {
  const FacultyHome({super.key});

  static const String routeName = '/facultyHome';

  @override
  State<FacultyHome> createState() => _FacultyHomeState();
}

class _FacultyHomeState extends State<FacultyHome> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  User? _currentUser;
  Map<String, dynamic>? _facultyData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFacultyData();
  }

  Future<void> _loadFacultyData() async {
    try {
      final user = _auth.currentUser;

      if (DevConfig.bypassLogin && DevConfig.useDemoData) {
        setState(() {
          _facultyData = {
            'name': 'Demo Faculty',
            'employeeId': 'FAC001',
            'department': 'Computer Science & Engineering',
            'designation': 'Assistant Professor',
            'email': 'faculty.demo@sru.edu.in',
            'experience': '10 Years',
            'courses': '3',
            'hodName': 'Dr. HOD Name',
            'hodPhone': '9999999999',
            'hodEmail': 'hod@sru.edu.in',
            'totalStudents': '180',
            'avgFeedback': '4.6',
            'classesPerWeek': '12',
          };
          _isLoading = false;
        });
        return;
      }

      if (user == null) {
        setState(() => _isLoading = false);
        return;
      }

      _currentUser = user;
      final email = _currentUser?.email ?? '';
      final facultyId = email.split('@')[0].toUpperCase();

      final doc = await _firestore.collection('faculty').doc(facultyId).get();
      if (doc.exists) {
        setState(() {
          _facultyData = doc.data();
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
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
    final name = _facultyData?['name'] ?? 'Faculty';
    final employeeId =
        _currentUser?.email?.split('@')[0].toUpperCase() ?? 'DEMO';
    final department = _facultyData?['department'] ?? 'Department';
    final designation = _facultyData?['designation'] ?? 'Faculty';
    final email = _facultyData?['email'] ?? _currentUser?.email ?? 'N/A';
    final experience = _facultyData?['experience'] ?? 'N/A';

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
                context, name, employeeId, designation, department),
            Padding(
              padding: EdgeInsets.all(isMobile ? 12 : 16),
              child: Column(
                children: [
                  _buildFacultyDetailsCard(context, employeeId, name, email,
                      department, designation, experience),
                  const SizedBox(height: 24),
                  _buildFacultyStatsGrid(context),
                  const SizedBox(height: 24),
                  _buildHODCard(context),
                  const SizedBox(height: 24),
                  _buildChartSection('Weekly Teaching Hours', context),
                  const SizedBox(height: 24),
                  _buildChartSection('Student Feedback Ratings', context),
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

    if (isMobile) {
      return _buildMobileMenu(context);
    }

    return _buildDesktopMenu(context);
  }

  Widget _buildMobileMenu(BuildContext context) {
    return Container(
      color: const Color(0xFF1e3a5f),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildMenuButton(context, 'Home', null),
            _buildDropdownMenu(context, 'Attendance', [
              'Attendance Entry',
              'Attendance Entry-Multi Batch Selection',
              'Lab/Tutorial Attendance Entry',
              'View | Update | Delete Day Attendance',
              'Register View',
              'SSM',
            ]),
            _buildMarksEntryMenu(context),
            _buildDropdownMenu(context, 'Academics', [
              'Regulations',
              'Calendar',
              'Syllabus',
              'Exam Time Table/ Date Sheet',
              'Invigilation Duties',
              'Exams Notice Board',
              'Time Table',
              'Library',
              'Staff Handbook',
              'Student Handbook',
            ]),
            _buildDropdownMenu(context, 'Professional Outline', [
              'View Profile',
              'Update Basic Data',
              'Course Preference',
              'Preference Report',
              'Feedback',
              'Bio-metric Log Records',
              'Employee Directory',
              'Download',
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopMenu(BuildContext context) {
    return Container(
      color: const Color(0xFF1e3a5f),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildMenuButton(context, 'Home', null),
            _buildDropdownMenu(context, 'Attendance', [
              'Attendance Entry',
              'Attendance Entry-Multi Batch Selection',
              'Lab/Tutorial Attendance Entry',
              'View | Update | Delete Day Attendance',
              'Register View',
              'SSM',
            ]),
            _buildMarksEntryMenu(context),
            _buildDropdownMenu(context, 'Academics', [
              'Regulations',
              'Calendar',
              'Syllabus',
              'Exam Time Table/ Date Sheet',
              'Invigilation Duties',
              'Exams Notice Board',
              'Time Table',
              'Library',
              'Staff Handbook',
              'Student Handbook',
            ]),
            _buildDropdownMenu(context, 'Professional Outline', [
              'View Profile',
              'Update Basic Data',
              'Course Preference',
              'Preference Report',
              'Feedback',
              'Bio-metric Log Records',
              'Employee Directory',
              'Download',
            ]),
          ],
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
            'Active Faculty',
            style: TextStyle(color: Colors.white, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeSection(
    BuildContext context,
    String name,
    String employeeId,
    String designation,
    String department,
  ) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Container(
      color: const Color(0xFF1e3a5f),
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      child: Text(
        'Welcome to $name - $employeeId - $designation - $department',
        style: TextStyle(
          color: Colors.yellow,
          fontSize: isMobile ? 12 : 14,
          fontWeight: FontWeight.bold,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildFacultyDetailsCard(
    BuildContext context,
    String employeeId,
    String name,
    String email,
    String department,
    String designation,
    String experience,
  ) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!, width: 1),
        borderRadius: BorderRadius.circular(8),
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
                      employeeId,
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
          _buildDetailRow('Designation', designation, isMobile),
          const SizedBox(height: 12),
          _buildDetailRow('Experience', experience, isMobile),
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

  Widget _buildFacultyStatsGrid(BuildContext context) {
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
          'Courses',
          _facultyData?['courses'] ?? '0',
          Colors.teal,
          context,
        ),
        _buildStatsCard(
          'Total Students',
          _facultyData?['totalStudents'] ?? '0',
          Colors.green,
          context,
        ),
        _buildStatsCard(
          'Avg Feedback',
          _facultyData?['avgFeedback'] ?? '0.0',
          Colors.orange,
          context,
        ),
        _buildStatsCard(
          'Classes/Week',
          _facultyData?['classesPerWeek'] ?? '0',
          Colors.blue,
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

  Widget _buildHODCard(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final hodName = _facultyData?['hodName'] ?? 'N/A';
    final hodPhone = _facultyData?['hodPhone'] ?? 'N/A';
    final hodEmail = _facultyData?['hodEmail'] ?? 'N/A';

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
                'Head of Department',
                style: TextStyle(
                  fontSize: isMobile ? 13 : 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.amber.shade900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildDetailRow('Name', hodName, isMobile),
          const SizedBox(height: 10),
          _buildDetailRow('Phone', hodPhone, isMobile),
          const SizedBox(height: 10),
          _buildDetailRow('Email', hodEmail, isMobile),
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

  Widget _buildMenuButton(BuildContext context, String title, String? route) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: TextButton(
        onPressed:
            route == null ? null : () => _navigateToRoute(context, route),
        style: TextButton.styleFrom(
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        ),
        child: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildDropdownMenu(
      BuildContext context, String title, List<String> items) {
    return PopupMenuButton<String>(
      offset: const Offset(0, 48),
      color: const Color(0xFF2d3e4f),
      constraints: const BoxConstraints(
        minWidth: 250,
        maxWidth: 350,
      ),
      onSelected: (value) => _handleMenuSelection(context, title, value),
      itemBuilder: (BuildContext context) {
        return items.map((String choice) {
          return PopupMenuItem<String>(
            value: choice,
            child: Text(
              choice,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
              ),
            ),
          );
        }).toList();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.arrow_drop_down,
              color: Colors.white,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMarksEntryMenu(BuildContext context) {
    return PopupMenuButton<String>(
      offset: const Offset(0, 48),
      color: const Color(0xFF2d3e4f),
      constraints: const BoxConstraints(
        minWidth: 200,
        maxWidth: 300,
      ),
      onSelected: (value) {
        if (value == 'Regular Exams') {
          // Don't navigate, let the submenu handle it
        } else if (value == 'Supply Exams') {
          _handleMenuSelection(context, 'Marks Entry', value);
        } else {
          // Handle submenu items from Regular Exams
          _handleMenuSelection(context, 'Regular Exams', value);
        }
      },
      itemBuilder: (BuildContext context) {
        return [
          PopupMenuItem<String>(
            enabled: false,
            padding: EdgeInsets.zero,
            child: PopupMenuButton<String>(
              offset: const Offset(200, 0),
              color: const Color(0xFF2d3e4f),
              constraints: const BoxConstraints(
                minWidth: 280,
                maxWidth: 350,
              ),
              onSelected: (value) {
                Navigator.of(context).pop(); // Close parent menu
                _handleMenuSelection(context, 'Regular Exams', value);
              },
              itemBuilder: (BuildContext context) {
                return [
                  'Check & Define CIE Format (UG/PG)',
                  'Check & Define CIE Format (PhD)',
                  'CIE Marks',
                  'Makeup Mid Marks',
                  'Consolidated Marks Report(New)',
                  'End Term Marks',
                ].map((String choice) {
                  return PopupMenuItem<String>(
                    value: choice,
                    child: Text(
                      choice,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                      ),
                    ),
                  );
                }).toList();
              },
              child: Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    Text(
                      'Regular Exams',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                      ),
                    ),
                    Icon(
                      Icons.arrow_right,
                      color: Colors.white,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
          ),
          PopupMenuItem<String>(
            value: 'Supply Exams',
            child: const Text(
              'Supply Exams',
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
              ),
            ),
          ),
        ];
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Text(
              'Marks Entry',
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(width: 4),
            Icon(
              Icons.arrow_drop_down,
              color: Colors.white,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  void _handleMenuSelection(
      BuildContext context, String menuTitle, String item) {
    // Map menu items to navigation routes
    final routeMap = {
      // Attendance submenu
      'Attendance Entry': 'attendance',
      'Attendance Entry-Multi Batch Selection': 'attendance_multi',
      'Lab/Tutorial Attendance Entry': 'attendance_lab',
      'View | Update | Delete Day Attendance': 'attendance_update',
      'Register View': 'attendance_register',
      'SSM': 'ssm',

      // Marks Entry submenu
      'Supply Exams': 'marks_supply',

      // Regular Exams submenu items
      'Check & Define CIE Format (UG/PG)': 'cie_format_ug',
      'Check & Define CIE Format (PhD)': 'cie_format_phd',
      'CIE Marks': 'cie_marks',
      'Makeup Mid Marks': 'makeup_marks',
      'Consolidated Marks Report(New)': 'consolidated_marks',
      'End Term Marks': 'endterm_marks',

      // Academics submenu
      'Regulations': 'regulations',
      'Calendar': 'calendar',
      'Syllabus': 'syllabus',
      'Exam Time Table/ Date Sheet': 'exam_timetable',
      'Invigilation Duties': 'invigilation',
      'Exams Notice Board': 'exams_notice',
      'Time Table': 'timetable',
      'Library': 'library',
      'Staff Handbook': 'staff_handbook',
      'Student Handbook': 'student_handbook',

      // Professional Outline submenu
      'View Profile': 'profile',
      'Update Basic Data': 'update_profile',
      'Course Preference': 'course_preference',
      'Preference Report': 'preference_report',
      'Feedback': 'feedback',
      'Bio-metric Log Records': 'biometric',
      'Employee Directory': 'employee_directory',
      'Download': 'download',
    };

    final route = routeMap[item];
    if (route != null) {
      _navigateToRoute(context, route);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$item - Coming Soon')),
      );
    }
  }

  void _navigateToRoute(BuildContext context, String route) {
    late final Widget page;

    switch (route) {
      case 'profile':
        page = const FacultyProfileScreen();
      case 'attendance':
      case 'attendance_multi':
      case 'attendance_lab':
      case 'attendance_update':
      case 'attendance_register':
        page = const FacultyAttendanceScreen();
      case 'calendar':
      case 'syllabus':
      case 'exam_timetable':
      case 'timetable':
      case 'regulations':
        page = const FacultyAcademicsScreen();
      case 'marks_regular':
      case 'marks_supply':
      case 'cie_marks':
      case 'makeup_marks':
      case 'consolidated_marks':
      case 'endterm_marks':
        page = const FacultyResultsScreen();
      case 'feedback':
        page = const FacultyFeedbackScreen();
      default:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$route - Coming Soon')),
        );
        return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => page),
    );
  }
}
