import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../screens/role_selection_screen.dart';
import 'screens/academics_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/course_registration_screen.dart';
import 'screens/attendance_screen.dart';
import 'screens/results_screen.dart';
import 'screens/feedback_screen.dart';
import 'screens/exams_screen.dart';
import 'screens/university_clubs_screen.dart';

class StudentHome extends StatelessWidget {
  const StudentHome({super.key});

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
      case 'University Clubs':
        page = const UniversityClubsScreen();
        break;
      case 'Central Library':
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

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

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
            _buildTimetableLink(context),
            Padding(
              padding: EdgeInsets.all(isMobile ? 12 : 16),
              child: Column(
                children: [
                  _buildProfileCard(context),
                  const SizedBox(height: 20),
                  _buildInfoCardsGrid(context),
                  const SizedBox(height: 12),
                  _buildLargeInfoCard(
                    'VIJAYA CHANDRA JADALA',
                    'Contact No: 7032704281',
                    'Mentoring Staff',
                    Colors.amber,
                    context,
                  ),
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

  Widget _buildWelcomeSection(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Container(
      color: const Color(0xFF1e3a5f),
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      child: Text(
        'Welcome to GOTTIMUKKULA SHIVA KRISHNA REDDY - 2203A51291 - BTECH - CSE',
        style: TextStyle(
          color: Colors.yellow,
          fontSize: isMobile ? 12 : 14,
          fontWeight: FontWeight.bold,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildTimetableLink(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return GestureDetector(
      onTap: () {},
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

  Widget _buildProfileCard(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final profileImageSize = isMobile ? 80.0 : 100.0;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: profileImageSize,
          height: profileImageSize,
          color: Colors.grey[300],
          child: const Icon(Icons.person, size: 40),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '2203A51291 - GOTTIMUKKULA SHIVA KRISHNA REDDY',
                style: TextStyle(
                  fontSize: isMobile ? 14 : 16,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Text(
                'Father Name - GOTTIMUKKULA SRINIVAS REDDY',
                style: TextStyle(fontSize: isMobile ? 11 : 12),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                'Batch Number - 22CSBTB09',
                style: TextStyle(fontSize: isMobile ? 11 : 12),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCardsGrid(BuildContext context) {
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
        _buildInfoCard(
          'Year-Sem',
          '22CSBTB09-4-2',
          Colors.teal,
          context,
        ),
        _buildInfoCard(
          'Attendance %',
          '0',
          Colors.green,
          context,
        ),
        _buildInfoCard(
          'Overall CGPA %',
          '8.676',
          Colors.green,
          context,
        ),
        _buildInfoCard(
          'No.of Courses | Total Backlogs',
          '50 | 0',
          Colors.blue,
          context,
        ),
      ],
    );
  }

  Widget _buildInfoCard(
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

  Widget _buildLargeInfoCard(
    String title,
    String subtitle,
    String footer,
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: isMobile ? 12 : 14,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: isMobile ? 10 : 12,
              color: Colors.black,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
          Text(
            footer,
            style: TextStyle(
              fontSize: isMobile ? 11 : 12,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              'More info >',
              style: TextStyle(
                fontSize: isMobile ? 10 : 11,
                color: Colors.black.withOpacity(0.7),
              ),
            ),
          ),
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
}