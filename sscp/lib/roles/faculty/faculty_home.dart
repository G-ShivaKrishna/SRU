import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math' as math;
import '../../screens/role_selection_screen.dart';
import '../../config/dev_config.dart';
import '../../services/feedback_service.dart';
import '../../services/user_service.dart';
import '../../services/session_service.dart';
import '../../services/notification_service.dart';
import 'screens/profile_screen.dart';
import 'screens/attendance_entry_screen.dart';
import 'screens/multi_batch_attendance_screen.dart';
import 'screens/lab_tutorial_attendance_screen.dart';
import 'screens/view_update_delete_attendance_screen.dart';
import 'screens/attendance_register_screen.dart';
import 'screens/academics_screen.dart';
import 'screens/results_screen.dart';
import 'screens/feedback_screen.dart';
import 'screens/academic_regulations_screen.dart';
import 'screens/calendar_screen.dart';
import 'screens/syllabus_screen.dart';
import 'screens/exam_timetable_screen.dart';
import 'screens/invigilator_duties_screen.dart';
import 'screens/notice_board_screen.dart';
import 'screens/student_handbook_screen.dart';
import 'screens/faculty_handbook_screen.dart';
import 'screens/update_basic_data_screen.dart';
import 'screens/course_preference_screen.dart';
import 'screens/supply_marks_screen.dart';
import 'screens/makeup_mid_marks_screen.dart';
import 'screens/preference_report_screen.dart';
import 'screens/course_view_screen.dart';
import 'screens/cie_format_screen.dart';
import 'screens/cie_marks_screen.dart';
import 'screens/consolidated_marks_screen.dart';
import 'screens/employee_directory_screen.dart';
import 'screens/mentor_student_access_screen.dart';

class FacultyHome extends StatefulWidget {
  const FacultyHome({super.key});

  static const String routeName = '/facultyHome';

  @override
  State<FacultyHome> createState() => _FacultyHomeState();
}

class _FacultyHomeState extends State<FacultyHome> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FeedbackService _feedbackService = FeedbackService();
  User? _currentUser;
  Map<String, dynamic>? _facultyData;
  String _facultyId = '';
  bool _isLoading = true;
  bool _feedbackLoaded = false;
  List<Map<String, dynamic>> _feedbackSummary = [];
  Map<String, int> _feedbackTargetCounts = {};

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
          _facultyId = 'FAC001';
          _feedbackLoaded = true;
          _feedbackSummary = [
            {
              'subjectCode': 'CS301',
              'subjectName': 'Data Structures',
              'averageRating': 4.6,
              'totalResponses': 52,
            },
            {
              'subjectCode': 'CS302',
              'subjectName': 'Operating Systems',
              'averageRating': 4.4,
              'totalResponses': 47,
            },
            {
              'subjectCode': 'CS303',
              'subjectName': 'Database Systems',
              'averageRating': 4.5,
              'totalResponses': 50,
            },
          ];
          _feedbackTargetCounts = {'CS301||': 60, 'CS302||': 60, 'CS303||': 60};
          _isLoading = false;
        });
        return;
      }

      if (user == null) {
        setState(() => _isLoading = false);
        return;
      }

      _currentUser = user;
      final email = (_currentUser?.email ?? '').toLowerCase().trim();
      final cachedId = (UserService.getCurrentUserId() ?? '').trim();

      DocumentSnapshot<Map<String, dynamic>>? resolvedDoc;
      String resolvedFacultyId = cachedId.toUpperCase();

      if (cachedId.isNotEmpty) {
        final byId = await _firestore.collection('faculty').doc(cachedId).get();
        if (byId.exists) {
          resolvedDoc = byId;
          resolvedFacultyId = byId.id.toUpperCase();
        }
      }

      if (resolvedDoc == null && email.isNotEmpty) {
        final byFirebaseEmail = await _firestore
            .collection('faculty')
            .where('firebaseEmail', isEqualTo: email)
            .limit(1)
            .get();
        if (byFirebaseEmail.docs.isNotEmpty) {
          resolvedDoc = byFirebaseEmail.docs.first;
          resolvedFacultyId = resolvedDoc.id.toUpperCase();
        }
      }

      if (resolvedDoc == null && email.isNotEmpty) {
        final byEmail = await _firestore
            .collection('faculty')
            .where('email', isEqualTo: email)
            .limit(1)
            .get();
        if (byEmail.docs.isNotEmpty) {
          resolvedDoc = byEmail.docs.first;
          resolvedFacultyId = resolvedDoc.id.toUpperCase();
        }
      }

      if (resolvedDoc != null) {
        _facultyData = resolvedDoc.data();

        final alternateIds = <String>{
          resolvedFacultyId,
          cachedId,
          (_facultyData?['facultyId'] ?? '').toString(),
          (_facultyData?['employeeId'] ?? '').toString(),
        }.where((e) => e.trim().isNotEmpty).toList();

        // Fetch average feedback from backend
        try {
          final avgFeedback = await _feedbackService.getOverallAverageFeedback(
            facultyId: resolvedFacultyId,
            alternateFacultyIds: alternateIds,
          );
          _facultyData?['avgFeedback'] = avgFeedback.toString();
        } catch (e) {
          // If feedback calculation fails, use default value
          _facultyData?['avgFeedback'] = '0.0';
        }

        try {
          final summary = await _feedbackService.getFacultyFeedbackSummary(
            facultyId: resolvedFacultyId,
            alternateFacultyIds: alternateIds,
          );
          _feedbackSummary = summary;
          _feedbackTargetCounts = await _computeFeedbackTargetCounts(
            facultyId: resolvedFacultyId,
            alternateFacultyIds: alternateIds,
            summary: summary,
          );
        } catch (_) {
          _feedbackSummary = [];
          _feedbackTargetCounts = {};
        }

        try {
          final stats = await _computeFacultyDashboardStats(
            facultyId: resolvedFacultyId,
            alternateFacultyIds: alternateIds,
          );
          _facultyData?['courses'] = stats['courses'] ?? '0';
          _facultyData?['totalStudents'] = stats['totalStudents'] ?? '0';
        } catch (_) {
          _facultyData?['courses'] = (_facultyData?['courses'] ?? '0')
              .toString();
          _facultyData?['totalStudents'] =
              (_facultyData?['totalStudents'] ?? '0').toString();
        }

        _feedbackLoaded = true;

        if (resolvedFacultyId.isNotEmpty) {
          await NotificationService.instance.registerRoleToken(
            role: 'faculty',
            roleId: resolvedFacultyId,
          );
        }

        setState(() {
          _facultyId = resolvedFacultyId;
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
    final facultyId =
        (_facultyId.isNotEmpty
                ? _facultyId
                : (UserService.getCurrentUserId() ?? ''))
            .trim()
            .toUpperCase();
    if (facultyId.isNotEmpty) {
      try {
        await NotificationService.instance.unregisterRoleToken(
          role: 'faculty',
          roleId: facultyId,
        );
      } catch (e) {
        debugPrint('Faculty token unregister failed: $e');
      }
    }

    await SessionService.clearRole();
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
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final isMobile = MediaQuery.of(context).size.width < 600;
    final name = (_facultyData?['name'] ?? 'Faculty').toString();
    final facultyId = _facultyId.isNotEmpty
        ? _facultyId
        : ((UserService.getCurrentUserId() ?? '').trim().toUpperCase().isEmpty
              ? 'N/A'
              : (UserService.getCurrentUserId() ?? '').trim().toUpperCase());
    final department = (_facultyData?['department'] ?? 'Department').toString();
    final designation = (_facultyData?['designation'] ?? 'Faculty').toString();
    final email = (_facultyData?['email'] ?? _currentUser?.email ?? 'N/A')
        .toString();
    final experience = (_facultyData?['experience'] ?? 'N/A').toString();

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Academics & Administration Portal'),
        backgroundColor: const Color(0xFF1e3a5f),
        foregroundColor: Colors.white,
        actions: [
          if (!isMobile) ...[
            TextButton(
              onPressed: () {},
              child: const Text(
                'Password',
                style: TextStyle(color: Colors.white),
              ),
            ),
            TextButton(
              onPressed: _logout,
              child: const Text(
                'Logout',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ] else ...[
            IconButton(icon: const Icon(Icons.logout), onPressed: _logout),
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
              context,
              name,
              facultyId,
              designation,
              department,
            ),
            _buildTimetableLink(context),
            Padding(
              padding: EdgeInsets.all(isMobile ? 12 : 16),
              child: Column(
                children: [
                  _buildFacultyDetailsCard(
                    context,
                    facultyId,
                    name,
                    email,
                    department,
                    designation,
                    experience,
                  ),
                  const SizedBox(height: 24),
                  _buildFacultyStatsGrid(context),
                  const SizedBox(height: 24),
                  _buildHODCard(context),
                  const SizedBox(height: 24),
                  _buildFeedbackRatingsSection(context),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Width estimate matching admin nav bar.
  double _navItemWidth(String label) => label.length * 7.5 + 46;

  Widget _buildNavigationMenu(BuildContext context) {
    const topItems = <String>[
      'Home',
      'Academics',
      'Profile',
      'Course',
      'Attendance',
      'Marks',
      'Feedback',
      'Employee Directory',
      'Mentorship',
    ];
    const subMenus = <String, List<String>>{
      'Academics': [
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
      ],
      'Profile': ['View Profile', 'Update Basic Data'],
      'Course': ['Course Preference', 'Course View', 'Preference Report'],
      'Attendance': [
        'Attendance Entry',
        'Attendance Entry-Multi Batch Selection',
        'Lab/Tutorial Attendance Entry',
        'View | Update | Delete Day Attendance',
        'Register View',
        'SSM',
      ],
      'Marks': [
        'Check & Define CIE Format (UG/PG)',
        'Total Marks',
        'Makeup Mid Marks',
        'Consolidated Marks Report(New)',
        'Supply Exam Marks',
      ],
    };

    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxWidth;
        const moreButtonWidth = 90.0;
        final budget = available - 8;
        final totalWidth = topItems.fold(
          0.0,
          (s, item) => s + _navItemWidth(item),
        );

        List<String> visible;
        List<String> overflowTop;

        if (totalWidth <= budget) {
          visible = List<String>.from(topItems);
          overflowTop = [];
        } else {
          visible = [];
          overflowTop = [];
          double used = 0;
          for (final item in topItems) {
            final w = _navItemWidth(item);
            if (used + w + moreButtonWidth <= budget) {
              visible.add(item);
              used += w;
            } else {
              overflowTop.add(item);
            }
          }
        }

        const moreSubMenus = <String, List<String>>{
          'Profile': ['View Profile', 'Update Basic Data'],
          'Course': ['Course Preference', 'Course View', 'Preference Report'],
          'Attendance': [
            'Attendance Entry',
            'Attendance Entry-Multi Batch Selection',
            'Lab/Tutorial Attendance Entry',
            'View | Update | Delete Day Attendance',
            'Register View',
            'SSM',
          ],
          'Marks': [
            'Check & Define CIE Format (UG/PG)',
            'Total Marks',
            'Makeup Mid Marks',
            'Consolidated Marks Report(New)',
            'Supply Exam Marks',
          ],
          'Feedback': ['Feedback'],
          'Employee Directory': ['Employee Directory'],
          'Mentorship': ['Mentorship'],
        };

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
                    final subs = subMenus[item];
                    final showChevron =
                        item != visible.last || overflowTop.isNotEmpty;
                    final labelWidget = Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 10,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isHome)
                            const Icon(
                              Icons.home,
                              color: Colors.white70,
                              size: 14,
                            ),
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
                              child: Icon(
                                Icons.chevron_right,
                                color: Colors.white38,
                                size: 14,
                              ),
                            ),
                        ],
                      ),
                    );
                    if (subs != null) {
                      return PopupMenuButton<String>(
                        offset: const Offset(0, 42),
                        color: const Color(0xFF1e3a5f),
                        onSelected: (value) =>
                            _handleMenuSelection(context, item, value),
                        itemBuilder: (_) => subs
                            .map(
                              (s) => PopupMenuItem<String>(
                                value: s,
                                height: 40,
                                child: Text(
                                  s,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                        child: labelWidget,
                      );
                    }
                    return InkWell(
                      onTap: isHome
                          ? null
                          : () => _handleMenuSelection(context, '', item),
                      hoverColor: Colors.white.withOpacity(0.12),
                      child: labelWidget,
                    );
                  }),
                  if (overflowTop.isNotEmpty)
                    _FacultyOverflowNavButton(
                      subMenus: moreSubMenus,
                      onSelected: (item) =>
                          _handleMenuSelection(context, '', item),
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
    String facultyId,
    String designation,
    String department,
  ) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Container(
      width: double.infinity,
      color: const Color(0xFF1e3a5f),
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      child: Text(
        'Welcome to $name - Faculty ID: $facultyId - $designation - $department',
        style: TextStyle(
          color: Colors.yellow,
          fontSize: isMobile ? 12 : 14,
          fontWeight: FontWeight.bold,
        ),
        textAlign: TextAlign.right,
      ),
    );
  }

  Widget _buildTimetableLink(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    return GestureDetector(
      onTap: () => launchUrl(
        Uri.parse('https://timetable.sruniv.com/report'),
        mode: LaunchMode.externalApplication,
      ),
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

  Widget _buildFacultyDetailsCard(
    BuildContext context,
    String facultyId,
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
                child: Icon(
                  Icons.person,
                  color: Colors.blue.shade700,
                  size: 32,
                ),
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
                      'Faculty ID: $facultyId',
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
          _buildDetailRow('Faculty ID', facultyId, isMobile),
          const SizedBox(height: 12),
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
    final crossAxisCount = isMobile
        ? 2
        : (MediaQuery.of(context).size.width < 1024 ? 2 : 4);
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
          (_facultyData?['courses'] ?? '0').toString(),
          Colors.teal,
          context,
        ),
        _buildStatsCard(
          'Total Students',
          (_facultyData?['totalStudents'] ?? '0').toString(),
          Colors.green,
          context,
        ),
        _buildStatsCard(
          'Avg Feedback',
          (_facultyData?['avgFeedback'] ?? '0.0').toString(),
          Colors.orange,
          context,
        ),
        _buildStatsCard(
          'Classes/Week',
          (_facultyData?['classesPerWeek'] ?? '0').toString(),
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
              Icon(
                Icons.person_outline,
                color: Colors.amber.shade700,
                size: 24,
              ),
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

  Widget _buildFeedbackRatingsSection(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final avgRating =
        double.tryParse((_facultyData?['avgFeedback'] ?? '0').toString()) ??
        0.0;
    final topItems = _feedbackSummary.take(6).toList();
    final totalSubmitted = topItems.fold<int>(
      0,
      (sum, item) => sum + ((item['totalResponses'] as num?)?.toInt() ?? 0),
    );
    final totalTarget = topItems.fold<int>(0, (sum, item) {
      final key = _feedbackSummaryKey(item);
      final submitted = (item['totalResponses'] as num?)?.toInt() ?? 0;
      final target = _feedbackTargetCounts[key] ?? submitted;
      return sum + math.max(submitted, target);
    });
    final totalPending = math.max(totalTarget - totalSubmitted, 0);

    return Container(
      color: const Color(0xFF2d3e4f),
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Student Feedback Ratings',
            style: TextStyle(
              color: Colors.white,
              fontSize: isMobile ? 14 : 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          if (!_feedbackLoaded)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: CircularProgressIndicator(color: Colors.white54),
              ),
            )
          else if (topItems.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'No feedback ratings submitted yet',
                style: TextStyle(color: Colors.white60),
              ),
            )
          else ...[
            Row(
              children: [
                Text(
                  avgRating.toStringAsFixed(2),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isMobile ? 24 : 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '/ 5.00',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: isMobile ? 12 : 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Overall average rating',
              style: TextStyle(
                color: Colors.white60,
                fontSize: isMobile ? 11 : 12,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Feedback submissions: $totalSubmitted/$totalTarget  (Pending: $totalPending)',
              style: TextStyle(
                color: Colors.white60,
                fontSize: isMobile ? 10 : 11,
              ),
            ),
            const SizedBox(height: 12),
            ...topItems.map((item) {
              final subjectCode = (item['subjectCode'] ?? '').toString();
              final subjectName = (item['subjectName'] ?? '').toString();
              final submitted = (item['totalResponses'] as num?)?.toInt() ?? 0;
              final rating = (item['averageRating'] as num?)?.toDouble() ?? 0.0;
              final key = _feedbackSummaryKey(item);
              final target = math.max(
                _feedbackTargetCounts[key] ?? submitted,
                submitted,
              );
              final pending = math.max(target - submitted, 0);
              final ratio = target == 0
                  ? 0.0
                  : (submitted / target).clamp(0.0, 1.0);
              final barColor = const Color(0xFF00C853);

              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '$subjectCode - $subjectName',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${rating.toStringAsFixed(2)}  ($submitted/$target)',
                          style: TextStyle(
                            color: barColor,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$pending students left to submit',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 9,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Stack(
                      children: [
                        Container(
                          height: 12,
                          decoration: BoxDecoration(
                            color: Colors.white12,
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        FractionallySizedBox(
                          widthFactor: ratio,
                          child: Container(
                            height: 12,
                            decoration: BoxDecoration(
                              color: barColor,
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  String _normalizeToken(String value) {
    return value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  int _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.floor();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  Set<String> _buildBatchTokens(List<String> values) {
    final tokens = <String>{};
    for (final value in values) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) continue;
      tokens.add(_normalizeToken(trimmed));
      final parts = trimmed
          .split(RegExp(r'[-_/\s]+'))
          .map(_normalizeToken)
          .where((p) => p.isNotEmpty);
      tokens.addAll(parts);
    }
    return tokens;
  }

  String _normalizeSemester(String raw) {
    final value = raw.trim().toUpperCase();
    switch (value) {
      case '1':
      case 'I':
      case '01':
        return '1';
      case '2':
      case 'II':
      case '02':
        return '2';
      case '3':
      case 'III':
      case '03':
        return '3';
      case '4':
      case 'IV':
      case '04':
        return '4';
      case '5':
      case 'V':
      case '05':
        return '5';
      case '6':
      case 'VI':
      case '06':
        return '6';
      case '7':
      case 'VII':
      case '07':
        return '7';
      case '8':
      case 'VIII':
      case '08':
        return '8';
      default:
        return _normalizeToken(raw);
    }
  }

  String _feedbackSummaryKey(Map<String, dynamic> item) {
    final subject = (item['subjectCode'] ?? '').toString().trim().toUpperCase();
    final semester = (item['semester'] ?? '').toString().trim().toUpperCase();
    final year = (item['academicYear'] ?? '').toString().trim().toUpperCase();
    return '$subject|$semester|$year';
  }

  bool _studentMatchesAssignment(
    Map<String, dynamic> student,
    Map<String, dynamic> assignment,
  ) {
    final assignmentYear = _parseInt(assignment['year']);
    final studentYear = _parseInt(student['year']);
    if (assignmentYear > 0 &&
        studentYear > 0 &&
        assignmentYear != studentYear) {
      return false;
    }

    final assignmentDept = _normalizeToken(
      (assignment['department'] ?? '').toString(),
    );
    final studentDept = _normalizeToken(
      (student['department'] ?? '').toString(),
    );
    if (assignmentDept.isNotEmpty &&
        studentDept.isNotEmpty &&
        assignmentDept != studentDept) {
      return false;
    }

    final assignedBatches = List<String>.from(
      assignment['assignedBatches'] ?? const [],
    );
    if (assignedBatches.isEmpty) {
      return true;
    }

    final assignedTokens = _buildBatchTokens(assignedBatches);
    final studentTokens = _buildBatchTokens([
      (student['batchNumber'] ?? '').toString(),
      (student['section'] ?? '').toString(),
    ]);

    if (studentTokens.isEmpty) {
      return false;
    }

    return assignedTokens.intersection(studentTokens).isNotEmpty;
  }

  Future<Map<String, int>> _computeFeedbackTargetCounts({
    required String facultyId,
    required List<String> alternateFacultyIds,
    required List<Map<String, dynamic>> summary,
  }) async {
    if (summary.isEmpty) return {};

    final idCandidates = <String>{
      facultyId,
      ...alternateFacultyIds,
    }.map((e) => e.trim()).where((e) => e.isNotEmpty).toSet();

    final assignmentsById = <String, Map<String, dynamic>>{};
    final ids = idCandidates.toList();

    for (var i = 0; i < ids.length; i += 10) {
      final chunk = ids.sublist(i, (i + 10).clamp(0, ids.length));
      if (chunk.isEmpty) continue;
      final snap = await _firestore
          .collection('facultyAssignments')
          .where('facultyId', whereIn: chunk)
          .where('isActive', isEqualTo: true)
          .get();
      for (final doc in snap.docs) {
        assignmentsById[doc.id] = doc.data();
      }
    }

    if (assignmentsById.isEmpty) {
      final normalizedIds = idCandidates.map(_normalizeToken).toSet();
      final snap = await _firestore
          .collection('facultyAssignments')
          .where('isActive', isEqualTo: true)
          .get();
      for (final doc in snap.docs) {
        final data = doc.data();
        final fid = _normalizeToken((data['facultyId'] ?? '').toString());
        if (normalizedIds.contains(fid)) {
          assignmentsById[doc.id] = data;
        }
      }
    }

    if (assignmentsById.isEmpty) {
      return {};
    }

    final studentsSnap = await _firestore.collection('students').get();
    final students = studentsSnap.docs;

    final result = <String, int>{};

    for (final item in summary) {
      final subjectToken = _normalizeToken(
        (item['subjectCode'] ?? '').toString(),
      );
      final semesterToken = _normalizeSemester(
        (item['semester'] ?? '').toString(),
      );
      final academicYear = (item['academicYear'] ?? '').toString().trim();
      final key = _feedbackSummaryKey(item);

      if (subjectToken.isEmpty) {
        result[key] = 0;
        continue;
      }

      final matchingAssignments = assignmentsById.values.where((a) {
        final aSubject = _normalizeToken((a['subjectCode'] ?? '').toString());
        if (aSubject != subjectToken) return false;

        if (semesterToken.isNotEmpty) {
          final aSem = _normalizeSemester((a['semester'] ?? '').toString());
          if (aSem.isNotEmpty && aSem != semesterToken) return false;
        }

        if (academicYear.isNotEmpty) {
          final aYear = (a['academicYear'] ?? '').toString().trim();
          if (aYear.isNotEmpty && aYear != academicYear) return false;
        }

        return true;
      }).toList();

      if (matchingAssignments.isEmpty) {
        result[key] = 0;
        continue;
      }

      final eligibleStudents = <String>{};
      for (final studentDoc in students) {
        final student = studentDoc.data();
        for (final assignment in matchingAssignments) {
          if (_studentMatchesAssignment(student, assignment)) {
            eligibleStudents.add(studentDoc.id.toUpperCase());
            break;
          }
        }
      }

      result[key] = eligibleStudents.length;
    }

    return result;
  }

  Future<Map<String, String>> _computeFacultyDashboardStats({
    required String facultyId,
    required List<String> alternateFacultyIds,
  }) async {
    final idCandidates = <String>{
      facultyId,
      ...alternateFacultyIds,
    }.map((e) => e.trim()).where((e) => e.isNotEmpty).toSet();

    final assignmentsById = <String, Map<String, dynamic>>{};
    final ids = idCandidates.toList();

    for (var i = 0; i < ids.length; i += 10) {
      final chunk = ids.sublist(i, (i + 10).clamp(0, ids.length));
      if (chunk.isEmpty) continue;

      final snap = await _firestore
          .collection('facultyAssignments')
          .where('facultyId', whereIn: chunk)
          .where('isActive', isEqualTo: true)
          .get();

      for (final doc in snap.docs) {
        assignmentsById[doc.id] = doc.data();
      }
    }

    if (assignmentsById.isEmpty) {
      final normalizedIds = idCandidates.map(_normalizeToken).toSet();
      final snap = await _firestore
          .collection('facultyAssignments')
          .where('isActive', isEqualTo: true)
          .get();

      for (final doc in snap.docs) {
        final data = doc.data();
        final fid = _normalizeToken((data['facultyId'] ?? '').toString());
        if (normalizedIds.contains(fid)) {
          assignmentsById[doc.id] = data;
        }
      }
    }

    if (assignmentsById.isEmpty) {
      return {'courses': '0', 'totalStudents': '0'};
    }

    final uniqueSubjects = <String>{};
    for (final assignment in assignmentsById.values) {
      final code = (assignment['subjectCode'] ?? '').toString().trim();
      final name = (assignment['subjectName'] ?? '').toString().trim();
      final key = _normalizeToken(code.isNotEmpty ? code : name);
      if (key.isNotEmpty) {
        uniqueSubjects.add(key);
      }
    }

    final studentsSnap = await _firestore.collection('students').get();
    final uniqueStudents = <String>{};

    for (final studentDoc in studentsSnap.docs) {
      final student = studentDoc.data();
      for (final assignment in assignmentsById.values) {
        if (_studentMatchesAssignment(student, assignment)) {
          uniqueStudents.add(studentDoc.id.toUpperCase());
          break;
        }
      }
    }

    return {
      'courses': uniqueSubjects.length.toString(),
      'totalStudents': uniqueStudents.length.toString(),
    };
  }

  // ignore: unused_element
  Widget _buildMenuButton(BuildContext context, String title, String? route) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: TextButton(
        onPressed: route == null
            ? null
            : () => _navigateToRoute(context, route),
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

  // ignore: unused_element
  Widget _buildProfessionalOutlineMenu(BuildContext context) {
    const items = [
      'View Profile',
      'Update Basic Data',
      'Course View',
      'Course Preference',
      'Preference Report',
      'Feedback',
      'Employee Directory',
    ];
    const downloadItems = [
      'M.Tech/M.Sc Internship Template',
      'M.Tech/M.Sc PROJECT Template',
      'MBA Internship Template Download',
      'MBA PROJECT Template Download',
    ];
    return PopupMenuButton<String>(
      offset: const Offset(0, 48),
      color: const Color(0xFF2d3e4f),
      constraints: const BoxConstraints(minWidth: 250, maxWidth: 350),
      onSelected: (value) =>
          _handleMenuSelection(context, 'Professional Outline', value),
      itemBuilder: (BuildContext ctx) {
        final List<PopupMenuEntry<String>> entries = [
          ...items.map(
            (item) => PopupMenuItem<String>(
              value: item,
              child: Text(
                item,
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),
          ),
          PopupMenuItem<String>(
            enabled: false,
            padding: EdgeInsets.zero,
            height: 48,
            child: _DownloadSubMenu(
              items: downloadItems,
              onSelected: (value) {
                Navigator.of(ctx).pop();
                _handleMenuSelection(context, 'Professional Outline', value);
              },
            ),
          ),
        ];
        return entries;
      },
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Professional Outline',
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(width: 4),
            Icon(Icons.arrow_drop_down, color: Colors.white, size: 20),
          ],
        ),
      ),
    );
  }

  // ignore: unused_element
  Widget _buildDropdownMenu(
    BuildContext context,
    String title,
    List<String> items,
  ) {
    return PopupMenuButton<String>(
      offset: const Offset(0, 48),
      color: const Color(0xFF2d3e4f),
      constraints: const BoxConstraints(minWidth: 250, maxWidth: 350),
      onSelected: (value) => _handleMenuSelection(context, title, value),
      itemBuilder: (BuildContext context) {
        return items.map<PopupMenuEntry<String>>((String choice) {
          if (choice == '---') {
            return const PopupMenuDivider();
          }
          if (choice.startsWith('##')) {
            return PopupMenuItem<String>(
              enabled: false,
              height: 30,
              child: Text(
                choice.substring(2).trim(),
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                ),
              ),
            );
          }
          return PopupMenuItem<String>(
            value: choice,
            child: Text(
              choice,
              style: const TextStyle(color: Colors.white, fontSize: 13),
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
            const Icon(Icons.arrow_drop_down, color: Colors.white, size: 20),
          ],
        ),
      ),
    );
  }

  // ignore: unused_element
  Widget _buildMarksEntryMenu(BuildContext context) {
    return PopupMenuButton<String>(
      offset: const Offset(0, 48),
      color: const Color(0xFF2d3e4f),
      constraints: const BoxConstraints(minWidth: 200, maxWidth: 300),
      onSelected: (value) {
        if (value == 'Regular Exams') {
          // Don't navigate, let the submenu handle it
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
              constraints: const BoxConstraints(minWidth: 280, maxWidth: 350),
              onSelected: (value) {
                Navigator.of(context).pop(); // Close parent menu
                _handleMenuSelection(context, 'Regular Exams', value);
              },
              itemBuilder: (BuildContext context) {
                return [
                  'Check & Define CIE Format (UG/PG)',
                  'Total Marks',
                  'Makeup Mid Marks',
                  'Consolidated Marks Report(New)',
                  'Supply Exam Marks',
                ].map((String choice) {
                  return PopupMenuItem<String>(
                    value: choice,
                    child: Text(
                      choice,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                    ),
                  );
                }).toList();
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Regular Exams',
                      style: TextStyle(color: Colors.white, fontSize: 13),
                    ),
                    Icon(Icons.arrow_right, color: Colors.white, size: 20),
                  ],
                ),
              ),
            ),
          ),
        ];
      },
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Marks Entry',
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(width: 4),
            Icon(Icons.arrow_drop_down, color: Colors.white, size: 20),
          ],
        ),
      ),
    );
  }

  void _handleMenuSelection(
    BuildContext context,
    String menuTitle,
    String item,
  ) {
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

      // Regular Exams submenu items
      'Check & Define CIE Format (UG/PG)': 'cie_format_ug',
      'Total Marks': 'cie_marks',
      'Makeup Mid Marks': 'makeup_marks',
      'Consolidated Marks Report(New)': 'consolidated_marks',
      'Supply Exam Marks': 'supply_marks',

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
      'Course View': 'course_view',
      'Course Preference': 'course_preference',
      'Preference Report': 'preference_report',
      'Feedback': 'feedback',
      'Employee Directory': 'employee_directory',
      'Mentorship': 'mentor',

      // Download submenu
      'M.Tech/M.Sc Internship Template': 'download_mtech_internship',
      'M.Tech/M.Sc PROJECT Template': 'download_mtech_project',
      'MBA Internship Template Download': 'download_mba_internship',
      'MBA PROJECT Template Download': 'download_mba_project',
    };

    final route = routeMap[item];
    if (route != null) {
      _navigateToRoute(context, route);
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$item - Coming Soon')));
    }
  }

  void _navigateToRoute(BuildContext context, String route) {
    late final Widget page;

    switch (route) {
      case 'profile':
        page = const FacultyProfileScreen();
      case 'attendance':
        page = const AttendanceEntryScreen();
      case 'attendance_multi':
        page = const MultiBatchAttendanceScreen();
      case 'attendance_lab':
        page = const LabTutorialAttendanceScreen();
      case 'attendance_update':
        page = const ViewUpdateDeleteAttendanceScreen();
      case 'attendance_register':
        page = const AttendanceRegisterScreen();
      case 'regulations':
        page = const AcademicRegulationsScreen();
      case 'calendar':
        page = const CalendarScreen();
      case 'syllabus':
        page = const SyllabusScreen();
      case 'exam_timetable':
        page = const ExamTimetableScreen();
      case 'invigilation':
        page = const InvigilatorDutiesScreen();
      case 'exams_notice':
        page = const NoticeBoardScreen();
      case 'student_handbook':
        page = const StudentHandbookScreen();
      case 'staff_handbook':
        page = const FacultyHandbookScreen();
      case 'timetable':
        page = const FacultyAcademicsScreen();
      case 'marks_regular':
      case 'marks_supply':
        page = const FacultyResultsScreen();
      case 'supply_marks':
        page = const SupplyMarksScreen();
      case 'makeup_marks':
        page = const MakeupMidMarksScreen();

      case 'consolidated_marks':
        page = const ConsolidatedMarksScreen();
      case 'cie_marks':
        page = const CieMarksScreen();
      case 'cie_format_ug':
      case 'cie_format_phd':
        page = const CieFormatScreen();
      case 'feedback':
        page = const FacultyFeedbackScreen();
      case 'update_profile':
        page = const UpdateBasicDataScreen();
      case 'course_preference':
        page = const CoursePreferenceScreen();
      case 'preference_report':
        page = const PreferenceReportScreen();
      case 'course_view':
        page = const CourseViewScreen();
      case 'employee_directory':
        page = const EmployeeDirectoryScreen();
      case 'mentor':
        page = const MentorStudentAccessScreen();
      case 'download_mtech_internship':
        launchUrl(
          Uri.parse(
            'https://github.com/SumithReddy007/DOCS/raw/main/MTECH_MSC_INTERNSHIP.pptx',
          ),
          mode: LaunchMode.externalApplication,
        );
        return;
      case 'download_mtech_project':
        launchUrl(
          Uri.parse(
            'https://github.com/SumithReddy007/DOCS/raw/main/MTECH_MSC_PROJECT.pptx',
          ),
          mode: LaunchMode.externalApplication,
        );
        return;
      case 'download_mba_internship':
        launchUrl(
          Uri.parse(
            'https://github.com/SumithReddy007/DOCS/raw/main/MBA_Internship.pptx',
          ),
          mode: LaunchMode.externalApplication,
        );
        return;
      case 'download_mba_project':
        launchUrl(
          Uri.parse(
            'https://github.com/SumithReddy007/DOCS/raw/main/MBA_PROJECT.pptx',
          ),
          mode: LaunchMode.externalApplication,
        );
        return;
      default:
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$route - Coming Soon')));
        return;
    }

    Navigator.of(context).push(MaterialPageRoute(builder: (context) => page));
  }
}

class _DownloadSubMenu extends StatelessWidget {
  final List<String> items;
  final void Function(String) onSelected;

  const _DownloadSubMenu({required this.items, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      offset: const Offset(240, -8),
      color: const Color(0xFF2d3e4f),
      constraints: const BoxConstraints(minWidth: 250, maxWidth: 320),
      onSelected: onSelected,
      itemBuilder: (context) => items
          .map(
            (item) => PopupMenuItem<String>(
              value: item,
              child: Text(
                item,
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),
          )
          .toList(),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 0),
        child: Row(
          mainAxisSize: MainAxisSize.max,
          children: [
            Expanded(
              child: Text(
                'Download',
                style: TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),
            Icon(Icons.arrow_right, color: Colors.white70, size: 18),
          ],
        ),
      ),
    );
  }
}

class _FacultyOverflowNavButton extends StatelessWidget {
  final Map<String, List<String>> subMenus;
  final void Function(String) onSelected;

  const _FacultyOverflowNavButton({
    required this.subMenus,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        showModalBottomSheet(
          context: context,
          backgroundColor: const Color(0xFF1e3a5f),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          isScrollControlled: true,
          builder: (_) => DraggableScrollableSheet(
            initialChildSize: 0.5,
            minChildSize: 0.3,
            maxChildSize: 0.85,
            expand: false,
            builder: (_, scrollController) => ListView(
              controller: scrollController,
              children: subMenus.entries.map((entry) {
                // Single-item group → render as direct ListTile
                if (entry.value.length == 1 && entry.value.first == entry.key) {
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    title: Text(
                      entry.key,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      onSelected(entry.value.first);
                    },
                  );
                }
                return ExpansionTile(
                  title: Text(
                    entry.key,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  iconColor: Colors.white70,
                  collapsedIconColor: Colors.white54,
                  children: entry.value
                      .map(
                        (item) => ListTile(
                          contentPadding: const EdgeInsets.only(
                            left: 32,
                            right: 16,
                          ),
                          title: Text(
                            item,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                            ),
                          ),
                          onTap: () {
                            Navigator.pop(context);
                            onSelected(item);
                          },
                        ),
                      )
                      .toList(),
                );
              }).toList(),
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'More',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(width: 4),
            Icon(Icons.arrow_drop_down, color: Colors.white70, size: 18),
          ],
        ),
      ),
    );
  }
}
