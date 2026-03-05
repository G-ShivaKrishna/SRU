import 'package:flutter/material.dart';
import 'screens/makeup_mid_registration_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../screens/role_selection_screen.dart';
import '../../config/dev_config.dart';
import '../faculty/screens/student_handbook_screen.dart';
import '../faculty/screens/syllabus_screen.dart';
import 'screens/academics_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/subject_registration_screen.dart';
import 'screens/attendance_screen.dart';
import 'screens/results_screen.dart';
import 'screens/student_cie_marks_screen.dart';
import 'screens/student_cie_memo_screen.dart';
import 'screens/supply_exam_memo_screen.dart';
import 'screens/feedback_screen.dart';
import 'screens/exams_screen.dart';
import 'screens/central_library_screen.dart';

import 'screens/grievance_screen.dart';

class StudentHome extends StatefulWidget {
  const StudentHome({super.key});

  static const String routeName = '/studentHome';

  @override
  State<StudentHome> createState() => _StudentHomeState();
}

class _StudentHomeState extends State<StudentHome> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  User? _currentUser;
  Map<String, dynamic>? _studentData;
  bool _isLoading = true;
  double _computedCgpa = 0.0;
  bool _cgpaLoaded = false;
  double _attendancePct = 0.0;
  bool _attendanceLoaded = false;
  List<Map<String, dynamic>> _courseWiseStats = []; // {code,name,held,present}
  Map<String, List<int>> _dailyHeldPresent =
      {}; // key=dd-MM-yyyy, value=[held,present]
  int _backlogCount = 0;
  bool _backlogLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadStudentData();
  }

  Future<void> _loadStudentData() async {
    try {
      final user = _auth.currentUser;

      // Only use demo data when both bypass and useDemoData are enabled
      if (DevConfig.bypassLogin && DevConfig.useDemoData) {
        setState(() {
          _studentData = {
            'name': 'Demo Student',
            'hallTicketNumber': '2203A51318',
            'department': 'cse',
            'batchNumber': '18',
            'email': 'demo@sru.edu.in',
            'program': 'BTECH',
            'year': '3',
            'semester': '6',
            'attendance': '85',
            'cgpa': '8.5',
            'backlogs': '0',
            'mentorName': 'Dr. Demo Mentor',
            'mentorPhone': '9999999999',
            'mentorEmail': 'mentor@sru.edu.in',
          };
          _isLoading = false;
        });
        return;
      }

      // No user logged in - fetch would fail
      if (user == null) {
        setState(() => _isLoading = false);
        return;
      }

      _currentUser = user;
      // Extract roll number from email and convert to uppercase for Firestore query
      final email = _currentUser?.email ?? '';
      final rollNumber = email.split('@')[0].toUpperCase();

      final doc = await _firestore.collection('students').doc(rollNumber).get();
      if (doc.exists) {
        final studentData = doc.data()!;
        // Fetch mentor information based on batch
        final batchNumber = studentData['batchNumber']?.toString();
        if (batchNumber != null && batchNumber.isNotEmpty) {
          await _fetchMentorData(studentData, batchNumber);
        }
        setState(() {
          _studentData = studentData;
          _isLoading = false;
        });
        // Compute CGPA from marks in the background
        _computeCgpa(rollNumber);
        // Compute live attendance % from the attendance collection
        // Only count records after the last promotion date so the new
        // semester starts fresh at 0%.
        final lastPromotedTs =
            studentData['lastPromotedAt'] as dynamic; // Timestamp?
        DateTime? sinceDate;
        try {
          if (lastPromotedTs != null) {
            final dt = (lastPromotedTs as dynamic).toDate() as DateTime;
            // Normalize to start of day to avoid time comparison issues
            sinceDate = DateTime(dt.year, dt.month, dt.day);
          }
        } catch (_) {
          debugPrint('[Attendance] Error parsing lastPromotedAt timestamp');
        }
        _computeAttendancePct(rollNumber, sinceDate: sinceDate);
        _computeBacklogs(rollNumber);
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  /// Counts active backlogs by reading `studentMarks`, `cieMemoReleases`,
  /// and `supplyMarks` — mirrors the logic in results_screen.dart.
  Future<void> _computeBacklogs(String rollNumber) async {
    try {
      // 1. Release map: year_sem -> minPassMarks
      final relSnap = await _firestore.collection('cieMemoReleases').get();
      String normSem(String s) {
        const m = {'i': '1', 'ii': '2', 'iii': '3', 'iv': '4'};
        return m[s.toLowerCase().trim()] ?? s.trim();
      }

      final releaseMap = <String, int>{};
      for (final d in relSnap.docs) {
        final r = d.data();
        final key = '${r['year']}_${normSem(r['semester']?.toString() ?? '')}';
        releaseMap[key] = (r['minPassMarks'] is int)
            ? r['minPassMarks'] as int
            : int.tryParse(r['minPassMarks']?.toString() ?? '') ?? 40;
      }

      // 2. Supply PASS map: subjectCode -> true
      final supplySnap = await _firestore
          .collection('supplyMarks')
          .where('rollNo', isEqualTo: rollNumber)
          .get();
      final supplyPassSet = <String>{};
      for (final d in supplySnap.docs) {
        final data = d.data();
        if ((data['result'] as String? ?? '') == 'PASS') {
          final code = data['subjectCode']?.toString() ?? '';
          if (code.isNotEmpty) supplyPassSet.add(code);
        }
      }

      // 3. All marks for this student
      final marksSnap = await _firestore
          .collection('studentMarks')
          .where('studentId', isEqualTo: rollNumber)
          .get();

      if (marksSnap.docs.isEmpty) {
        if (mounted) setState(() => _backlogLoaded = true);
        return;
      }

      // 4. Group by subjectCode
      final bySubject = <String, List<Map<String, dynamic>>>{};
      for (final doc in marksSnap.docs) {
        final d = Map<String, dynamic>.from(doc.data());
        final code = d['subjectCode']?.toString() ?? '';
        if (code.isEmpty) continue;
        bySubject.putIfAbsent(code, () => []).add(d);
      }

      // 5. Determine active backlogs
      int active = 0;
      for (final entries in bySubject.values) {
        // Sort chronologically
        entries.sort((a, b) {
          final ya = int.tryParse(a['year']?.toString() ?? '') ?? 0;
          final yb = int.tryParse(b['year']?.toString() ?? '') ?? 0;
          if (ya != yb) return ya.compareTo(yb);
          return normSem(a['semester']?.toString() ?? '')
              .compareTo(normSem(b['semester']?.toString() ?? ''));
        });

        for (int i = 0; i < entries.length; i++) {
          final e = entries[i];
          final key =
              '${e['year']}_${normSem(e['semester']?.toString() ?? '')}';
          final minPass = releaseMap[key] ?? 40;
          final raw = e['componentMarks'] as Map<String, dynamic>? ?? {};
          int total = 0;
          for (final v in raw.values) {
            total += (v is int) ? v : int.tryParse(v.toString()) ?? 0;
          }
          if (total >= minPass) continue; // passed — not a backlog

          // Failed — check if cleared later
          final code = e['subjectCode']?.toString() ?? '';
          bool clearedLater = false;
          for (int j = i + 1; j < entries.length; j++) {
            final later = entries[j];
            final lKey =
                '${later['year']}_${normSem(later['semester']?.toString() ?? '')}';
            final lMin = releaseMap[lKey] ?? 40;
            final lRaw = later['componentMarks'] as Map<String, dynamic>? ?? {};
            int lTotal = 0;
            for (final v in lRaw.values) {
              lTotal += (v is int) ? v : int.tryParse(v.toString()) ?? 0;
            }
            if (lTotal >= lMin) {
              clearedLater = true;
              break;
            }
          }
          if (!clearedLater && supplyPassSet.contains(code)) {
            clearedLater = true;
          }
          if (!clearedLater) active++;
        }
      }

      if (mounted) {
        setState(() {
          _backlogCount = active;
          _backlogLoaded = true;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _backlogLoaded = true);
    }
  }

  /// Fetch mentor information from backend based on year and batch assignment
  Future<void> _fetchMentorData(
      Map<String, dynamic> studentData, String batchNumber) async {
    try {
      // Get student's year
      final year = studentData['year'];
      final yearInt = year is int ? year : int.tryParse(year.toString());

      if (yearInt == null) {
        // No valid year found
        studentData['mentorName'] = 'Not Assigned';
        studentData['mentorPhone'] = 'N/A';
        studentData['mentorEmail'] = 'N/A';
        return;
      }

      // Look for mentor assignment for this year+batch combination
      final assignmentSnap = await _firestore
          .collection('mentorAssignments')
          .where('year', isEqualTo: yearInt)
          .where('batchNumber', isEqualTo: batchNumber)
          .limit(1)
          .get();

      if (assignmentSnap.docs.isEmpty) {
        // No mentor assigned for this year+batch
        studentData['mentorName'] = 'Not Assigned';
        studentData['mentorPhone'] = 'N/A';
        studentData['mentorEmail'] = 'N/A';
        return;
      }

      final assignmentData = assignmentSnap.docs.first.data();
      final mentorFacultyName = assignmentData['facultyName']?.toString();

      if (mentorFacultyName == null || mentorFacultyName.isEmpty) {
        studentData['mentorName'] = 'Not Assigned';
        studentData['mentorPhone'] = 'N/A';
        studentData['mentorEmail'] = 'N/A';
        return;
      }

      // Get mentor's details from faculty collection
      final facultySnap = await _firestore
          .collection('faculty')
          .where('name', isEqualTo: mentorFacultyName)
          .limit(1)
          .get();

      if (facultySnap.docs.isNotEmpty) {
        final facultyData = facultySnap.docs.first.data();
        studentData['mentorName'] =
            facultyData['name']?.toString() ?? mentorFacultyName;
        studentData['mentorPhone'] = facultyData['phone']?.toString() ?? 'N/A';
        studentData['mentorEmail'] = facultyData['email']?.toString() ?? 'N/A';
      } else {
        // Faculty not found, use assignment name
        studentData['mentorName'] = mentorFacultyName;
        studentData['mentorPhone'] = 'N/A';
        studentData['mentorEmail'] = 'N/A';
      }
    } catch (e) {
      debugPrint('[Mentor] Error fetching mentor data: $e');
      studentData['mentorName'] = 'Error Loading';
      studentData['mentorPhone'] = 'N/A';
      studentData['mentorEmail'] = 'N/A';
    }
  }

  /// Fetches all attendance docs for this student and computes:
  ///  • Overall attendance %
  ///  • Per-subject stats (for Course Wise chart)
  ///  • Per-day stats (for Last Week chart)
  Future<void> _computeAttendancePct(String rollNumber,
      {DateTime? sinceDate}) async {
    try {
      final snap = await _firestore.collection('attendance').get();
      int held = 0;
      int present = 0;
      final Map<String, Map<String, dynamic>> cwMap = {};
      final Map<String, List<int>> dayMap = {};

      for (final doc in snap.docs) {
        final d = doc.data();
        final periods = List<dynamic>.from(d['periods'] ?? []);
        if (periods.isEmpty) continue;
        final students = List<dynamic>.from(d['students'] ?? []);
        final record = students.cast<Map?>().firstWhere(
              (s) =>
                  (s?['rollNo'] as String? ?? '').toUpperCase() == rollNumber,
              orElse: () => null,
            );
        if (record == null) continue;

        final count = periods.length;
        final isPresent = record['present'] == true;
        final code = (d['subjectCode'] as String? ?? '').trim();
        final name = (d['subjectName'] as String? ?? code).trim();
        final dateStr = (d['dateStr'] as String? ?? '');

        // Skip records before the last semester promotion date
        if (sinceDate != null && dateStr.isNotEmpty) {
          try {
            final p = dateStr.split('-');
            if (p.length == 3) {
              // Parse dd-MM-yyyy format
              final day = int.parse(p[0]);
              final month = int.parse(p[1]);
              final year = int.parse(p[2]);
              final recDate = DateTime(year, month, day);

              // Only include records from sinceDate onwards (inclusive)
              if (recDate.isBefore(sinceDate)) {
                continue; // Skip this old record
              }
            }
          } catch (e) {
            debugPrint('[Attendance] Error parsing date "$dateStr": $e');
          }
        }

        held += count;
        if (isPresent) present += count;

        // Course-wise accumulation
        cwMap.putIfAbsent(
            code, () => {'code': code, 'name': name, 'held': 0, 'present': 0});
        cwMap[code]!['held'] = (cwMap[code]!['held'] as int) + count;
        if (isPresent) {
          cwMap[code]!['present'] = (cwMap[code]!['present'] as int) + count;
        }

        // Daily accumulation
        if (dateStr.isNotEmpty) {
          dayMap.putIfAbsent(dateStr, () => [0, 0]);
          dayMap[dateStr]![0] += count;
          if (isPresent) dayMap[dateStr]![1] += count;
        }
      }

      final courseList = cwMap.values.toList()
        ..sort((a, b) => (a['code'] as String).compareTo(b['code'] as String));

      if (mounted) {
        setState(() {
          _attendancePct = held == 0 ? 0 : (present / held) * 100;
          _attendanceLoaded = true;
          _courseWiseStats = courseList;
          _dailyHeldPresent = dayMap;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _attendanceLoaded = true);
    }
  }

  /// Computes CGPA from all studentMarks for this student.
  /// Groups marks by (year, semester), computes SGPA per semester,
  /// then averages: CGPA = sum(SGPAs) / numberOfSemesters.
  Future<void> _computeCgpa(String rollNumber) async {
    try {
      final snap = await _firestore
          .collection('studentMarks')
          .where('studentId', isEqualTo: rollNumber)
          .get();

      if (snap.docs.isEmpty) {
        if (mounted) setState(() => _cgpaLoaded = true);
        return;
      }

      // ----- helpers (mirrors _SubjectEntry logic) -----
      bool isEte(String name) {
        final l = name.toLowerCase();
        return l.contains('end term') ||
            l.contains('ete') ||
            l.contains('end-term') ||
            l.contains('external');
      }

      int gradePointFor(double pct) {
        if (pct >= 90) return 10;
        if (pct >= 80) return 9;
        if (pct >= 70) return 8;
        if (pct >= 60) return 7;
        if (pct >= 50) return 6;
        if (pct >= 40) return 5;
        return 0;
      }

      String normSem(String s) {
        switch (s.trim().toUpperCase()) {
          case 'I':
          case '1':
            return '1';
          case 'II':
          case '2':
            return '2';
          default:
            return s.trim();
        }
      }

      // ----- accumulate credit points per semester -----
      // key: "year-sem"
      final Map<String, double> semCreditPoints = {};
      final Map<String, int> semTotalCredits = {};

      for (final doc in snap.docs) {
        final d = doc.data();

        final rawYear = d['year']?.toString() ?? '';
        final rawSem = d['semester']?.toString() ?? '';
        final semKey = '$rawYear-${normSem(rawSem)}';

        final rawMarks = d['componentMarks'] as Map<String, dynamic>? ?? {};
        int cieSum = 0, eteSum = 0;
        for (final e in rawMarks.entries) {
          final v = e.value;
          final val = (v is int)
              ? v
              : (v is num)
                  ? v.floor()
                  : int.tryParse(v.toString()) ?? 0;
          if (isEte(e.key)) {
            eteSum += val;
          } else {
            cieSum += val;
          }
        }
        final grand = cieSum + eteSum;
        final maxAll = d['maxMarks'] is int
            ? d['maxMarks'] as int
            : (d['maxMarks'] is num)
                ? (d['maxMarks'] as num).floor()
                : int.tryParse(d['maxMarks']?.toString() ?? '') ?? 0;
        final rawCr = d['credits'];
        final cr = (rawCr is int)
            ? rawCr
            : (rawCr is num)
                ? rawCr.floor()
                : int.tryParse(rawCr?.toString() ?? '') ?? 3;

        if (maxAll <= 0) continue;
        final pct = (grand / maxAll) * 100;
        final gp = gradePointFor(pct);
        final cp = gp * cr.toDouble();

        semCreditPoints[semKey] = (semCreditPoints[semKey] ?? 0.0) + cp;
        semTotalCredits[semKey] = (semTotalCredits[semKey] ?? 0) + cr;
      }

      if (semCreditPoints.isEmpty) {
        if (mounted) setState(() => _cgpaLoaded = true);
        return;
      }

      // SGPA per semester
      double sgpaSum = 0.0;
      int semCount = 0;
      for (final key in semCreditPoints.keys) {
        final tc = semTotalCredits[key] ?? 0;
        if (tc > 0) {
          sgpaSum += semCreditPoints[key]! / tc;
          semCount++;
        }
      }

      if (semCount == 0) {
        if (mounted) setState(() => _cgpaLoaded = true);
        return;
      }
      final cgpa = sgpaSum / semCount;

      if (!mounted) return;
      setState(() {
        _computedCgpa = cgpa;
        _cgpaLoaded = true;
      });
    } catch (e) {
      debugPrint('[CGPA] computation error: $e');
      if (mounted) {
        setState(() {
          _computedCgpa = 0.0;
          _cgpaLoaded = true;
        });
      }
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
        page = const SubjectRegistrationScreen();
        break;
      case 'Attendance':
        page = const AttendanceScreen();
        break;
      case 'Results':
        page = const ResultsScreen();
        break;
      case 'CIE Marks':
        page = const StudentCieMarksScreen();
        break;
      case 'Semester Memo':
        page = const StudentCieMemoScreen();
        break;
      case 'Supply Exam Memo':
        page = const SupplyExamMemoScreen();
        break;
      case 'Backlogs':
        page = const ResultsScreen(initialTab: 0);
        break;
      case 'Supply Exam':
        page = const ResultsScreen(initialTab: 1);
        break;
      case 'Makeup Mid':
        page = const MakeupMidRegistrationScreen();
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
      case 'Submit Grievance':
        page = const GrievanceScreen(initialIndex: 0);
        break;
      case 'Grievance Status':
        page = const GrievanceScreen(initialIndex: 1);
        break;
      case 'Grievance':
        page = const GrievanceScreen();
        break;
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
    final rollNumber =
        _currentUser?.email?.split('@')[0].toUpperCase() ?? 'DEMO';
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
                  _buildLastWeekChartSection(context),
                  const SizedBox(height: 24),
                  _buildCourseWiseChartSection(context),
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
      'Grievance',
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
    // Remove 'Results' from main items; add sub-items directly
    final visibleItems =
        menuItems.where((item) => item != 'Home' && item != 'Results').toList();

    return Container(
      color: const Color(0xFF1e3a5f),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: visibleItems.take(4).map((item) {
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
              final overflowItems = visibleItems
                  .where((item) => ![
                        'Academics',
                        'Profile',
                        'Course Reg.',
                        'Attendance'
                      ].contains(item))
                  .toList();
              return [
                // Results group header + submenu items for Results
                const PopupMenuItem<String>(
                  enabled: false,
                  height: 30,
                  child: Text(
                    'Results',
                    style: TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                        fontWeight: FontWeight.bold),
                  ),
                ),
                const PopupMenuItem<String>(
                  value: 'CIE Marks',
                  child: Padding(
                    padding: EdgeInsets.only(left: 12),
                    child: Text('CIE Marks',
                        style: TextStyle(color: Colors.white)),
                  ),
                ),
                const PopupMenuItem<String>(
                  value: 'Semester Memo',
                  child: Padding(
                    padding: EdgeInsets.only(left: 12),
                    child: Text('Semester Memo',
                        style: TextStyle(color: Colors.white)),
                  ),
                ),
                const PopupMenuItem<String>(
                  value: 'Supply Exam Memo',
                  child: Padding(
                    padding: EdgeInsets.only(left: 12),
                    child: Text('Supply Exam Memo',
                        style: TextStyle(color: Colors.white)),
                  ),
                ),
                const PopupMenuItem<String>(
                  value: 'Backlogs',
                  child: Padding(
                    padding: EdgeInsets.only(left: 12),
                    child:
                        Text('Backlogs', style: TextStyle(color: Colors.white)),
                  ),
                ),
                const PopupMenuItem<String>(
                  value: 'Supply Exam',
                  child: Padding(
                    padding: EdgeInsets.only(left: 12),
                    child: Text('Supply Exam',
                        style: TextStyle(color: Colors.white)),
                  ),
                ),
                const PopupMenuItem<String>(
                  value: 'Makeup Mid',
                  child: Padding(
                    padding: EdgeInsets.only(left: 12),
                    child: Text('Makeup Mid',
                        style: TextStyle(color: Colors.white)),
                  ),
                ),
                const PopupMenuDivider(),
                ...overflowItems.map((item) => PopupMenuItem<String>(
                      value: item,
                      child: Text(item,
                          style: const TextStyle(color: Colors.white)),
                    )),
              ];
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
            if (item == 'Academics') {
              // ── Academics dropdown ──────────────────────────────
              return PopupMenuButton<String>(
                offset: const Offset(0, 40),
                color: const Color(0xFF1e3a5f),
                onSelected: (value) {
                  if (value == 'Calendar') {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (context) => const AcademicsScreen()),
                    );
                  } else if (value == 'Handbook') {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (context) => const StudentHandbookScreen()),
                    );
                  } else if (value == 'Syllabus') {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (context) => const SyllabusScreen()),
                    );
                  } else {
                    _navigateToPage(context, value);
                  }
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem(
                    value: 'Calendar',
                    child:
                        Text('Calendar', style: TextStyle(color: Colors.white)),
                  ),
                  const PopupMenuItem(
                    value: 'Handbook',
                    child:
                        Text('Handbook', style: TextStyle(color: Colors.white)),
                  ),
                  const PopupMenuItem(
                    value: 'Syllabus',
                    child:
                        Text('Syllabus', style: TextStyle(color: Colors.white)),
                  ),
                ],
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  child: Row(
                    children: [
                      Text(
                        'Academics',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(width: 3),
                      Icon(Icons.arrow_drop_down,
                          color: Colors.white70, size: 16),
                    ],
                  ),
                ),
              );
            }
            if (item == 'Results') {
              // ── Results dropdown ──────────────────────────────
              return PopupMenuButton<String>(
                offset: const Offset(0, 40),
                color: const Color(0xFF1e3a5f),
                onSelected: (value) => _navigateToPage(context, value),
                itemBuilder: (ctx) => [
                  const PopupMenuItem(
                    value: 'CIE Marks',
                    child: Text('CIE Marks',
                        style: TextStyle(color: Colors.white)),
                  ),
                  const PopupMenuItem(
                    value: 'Semester Memo',
                    child: Text('Semester Memo',
                        style: TextStyle(color: Colors.white)),
                  ),
                  const PopupMenuItem(
                    value: 'Supply Exam Memo',
                    child: Text('Supply Exam Memo',
                        style: TextStyle(color: Colors.white)),
                  ),
                  const PopupMenuItem(
                    value: 'Backlogs',
                    child:
                        Text('Backlogs', style: TextStyle(color: Colors.white)),
                  ),
                  const PopupMenuItem(
                    value: 'Supply Exam',
                    child: Text('Supply Exam',
                        style: TextStyle(color: Colors.white)),
                  ),
                  const PopupMenuItem(
                    value: 'Makeup Mid',
                    child: Text('Makeup Mid',
                        style: TextStyle(color: Colors.white)),
                  ),
                ],
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  child: Row(
                    children: [
                      Text(
                        'Results',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(width: 3),
                      Icon(Icons.arrow_drop_down,
                          color: Colors.white70, size: 16),
                    ],
                  ),
                ),
              );
            }
            if (item == 'Grievance') {
              // ── Grievance dropdown ────────────────────────────
              return PopupMenuButton<String>(
                offset: const Offset(0, 40),
                color: const Color(0xFF1e3a5f),
                onSelected: (value) => _navigateToPage(context, value),
                itemBuilder: (ctx) => [
                  const PopupMenuItem(
                    value: 'Submit Grievance',
                    child: Text('Submit Grievance',
                        style: TextStyle(color: Colors.white)),
                  ),
                  const PopupMenuItem(
                    value: 'Grievance Status',
                    child: Text('Grievance Status',
                        style: TextStyle(color: Colors.white)),
                  ),
                ],
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  child: Row(
                    children: [
                      Text(
                        'Grievance',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(width: 3),
                      Icon(Icons.arrow_drop_down,
                          color: Colors.white70, size: 16),
                    ],
                  ),
                ),
              );
            }
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

    // Build Year-Semester string from separate fields
    final year = _studentData?['year']?.toString();
    final semester = _studentData?['semester']?.toString();
    final yearSemester = (year != null && semester != null)
        ? '$year-$semester'
        : _studentData?['yearSemester']?.toString() ?? 'N/A';

    // Only show core academic cards (no Calendar, Handbook, Syllabus)
    final academicsItems = [
      {
        'label': 'Year-Semester',
        'value': yearSemester,
        'color': Colors.teal,
      },
      {
        'label': 'Attendance %',
        'value': _attendanceLoaded
            ? '${_attendancePct.toStringAsFixed(1)}%'
            : (_studentData?['attendance'] != null
                ? '${_studentData!['attendance']}%'
                : '...'),
        'color': Colors.green,
      },
      {
        'label': 'CGPA',
        'value': _cgpaLoaded
            ? _computedCgpa.toStringAsFixed(2)
            : (_studentData?['cgpa']?.toString() ?? '...'),
        'color': Colors.orange,
      },
      {
        'label': 'Backlogs',
        'value': _backlogLoaded
            ? '$_backlogCount'
            : (_studentData?['backlogs']?.toString() ?? '...'),
        'color': Colors.red,
      },
    ];

    return GridView.count(
      crossAxisCount: crossAxisCount,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: childAspectRatio,
      children: academicsItems.map((item) {
        final String label = item['label'] as String;
        final String value = item['value'] as String;
        final Color color = item['color'] as Color;
        return _buildAcademicsCard(
          label,
          value,
          color,
          context,
        );
      }).toList(),
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
          value.isNotEmpty
              ? Text(
                  value,
                  style: TextStyle(
                    fontSize: isMobile ? 20 : 26,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                )
              : Icon(
                  label == 'Calendar'
                      ? Icons.calendar_today
                      : label == 'Handbook'
                          ? Icons.menu_book
                          : label == 'Syllabus'
                              ? Icons.description
                              : Icons.info,
                  color: Colors.white,
                  size: isMobile ? 24 : 32,
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

  // ── Shared chart container ────────────────────────────────────────────────

  Widget _chartContainer({
    required String title,
    required bool isMobile,
    required Widget child,
  }) {
    return Container(
      color: const Color(0xFF2d3e4f),
      padding: EdgeInsets.all(isMobile ? 12 : 20),
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
          child,
        ],
      ),
    );
  }

  // ── Last Week vertical bar chart ─────────────────────────────────────────

  Widget _buildLastWeekChartSection(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final maxBarH = isMobile ? 110.0 : 150.0;

    return _chartContainer(
      title: 'Last Week Attendance %',
      isMobile: isMobile,
      child: !_attendanceLoaded
          ? const Center(
              child: Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: CircularProgressIndicator(color: Colors.white54),
            ))
          : Column(children: [
              SizedBox(
                height: maxBarH + 60,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: List.generate(7, (i) {
                    final now = DateTime.now();
                    final d = now.subtract(Duration(days: 6 - i));
                    const labels = [
                      'Mon',
                      'Tue',
                      'Wed',
                      'Thu',
                      'Fri',
                      'Sat',
                      'Sun'
                    ];
                    final key = '${d.day.toString().padLeft(2, '0')}-'
                        '${d.month.toString().padLeft(2, '0')}-'
                        '${d.year}';
                    final hp = _dailyHeldPresent[key];
                    final heldN = hp != null ? hp[0] : 0;
                    final presentN = hp != null ? hp[1] : 0;
                    final pct = heldN == 0
                        ? 0.0
                        : (presentN.toDouble() / heldN.toDouble()) * 100.0;
                    final barColor = heldN == 0
                        ? Colors.white12
                        : pct >= 75
                            ? const Color(0xFF4CAF50)
                            : pct >= 60
                                ? const Color(0xFFFFA726)
                                : const Color(0xFFEF5350);
                    final barH = heldN == 0
                        ? 4.0
                        : (maxBarH * pct / 100.0).clamp(4.0, maxBarH);

                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            if (heldN > 0)
                              Text(
                                '${pct.toStringAsFixed(0)}%',
                                style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold),
                              )
                            else
                              const SizedBox(height: 14),
                            const SizedBox(height: 3),
                            Container(
                              height: barH,
                              decoration: BoxDecoration(
                                color: barColor,
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(4),
                                  topRight: Radius.circular(4),
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              labels[d.weekday - 1],
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 10),
                            ),
                            Text(
                              '${d.day}/${d.month}',
                              style: const TextStyle(
                                  color: Colors.white54, fontSize: 9),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(height: 12),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                _legendDot(const Color(0xFF4CAF50), '≥75%'),
                const SizedBox(width: 16),
                _legendDot(const Color(0xFFFFA726), '60-74%'),
                const SizedBox(width: 16),
                _legendDot(const Color(0xFFEF5350), '<60%'),
              ]),
            ]),
    );
  }

  Widget _legendDot(Color color, String label) => Row(children: [
        Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label,
            style: const TextStyle(color: Colors.white60, fontSize: 10)),
      ]);

  // ── Course Wise horizontal bar chart ──────────────────────────────────────

  Widget _buildCourseWiseChartSection(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return _chartContainer(
      title: 'Course Wise Attendance %',
      isMobile: isMobile,
      child: !_attendanceLoaded
          ? const Center(
              child: Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: CircularProgressIndicator(color: Colors.white54),
            ))
          : _courseWiseStats.isEmpty
              ? const Center(
                  child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Text('No attendance data available',
                      style: TextStyle(color: Colors.white54)),
                ))
              : Column(
                  children: _courseWiseStats.map((s) {
                    final held = (s['held'] as num).toInt();
                    final present = (s['present'] as num).toInt();
                    final pct = held == 0
                        ? 0.0
                        : (present.toDouble() / held.toDouble()) * 100.0;
                    final barColor = pct >= 75
                        ? const Color(0xFF4CAF50)
                        : pct >= 60
                            ? const Color(0xFFFFA726)
                            : const Color(0xFFEF5350);
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${s['code']}  •  ${s['name']}',
                                  style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${pct.toStringAsFixed(1)}%',
                                style: TextStyle(
                                    color: barColor,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Stack(children: [
                            Container(
                              height: 14,
                              decoration: BoxDecoration(
                                color: Colors.white12,
                                borderRadius: BorderRadius.circular(7),
                              ),
                            ),
                            FractionallySizedBox(
                              widthFactor: (pct / 100).clamp(0.0, 1.0),
                              child: Container(
                                height: 14,
                                decoration: BoxDecoration(
                                  color: barColor,
                                  borderRadius: BorderRadius.circular(7),
                                ),
                              ),
                            ),
                          ]),
                          const SizedBox(height: 2),
                          Text(
                            '$present / $held classes attended',
                            style: const TextStyle(
                                color: Colors.white38, fontSize: 9),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
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
