import 'package:flutter/material.dart';
import '../../../widgets/app_header.dart';

class CourseRegistrationScreen extends StatefulWidget {
  const CourseRegistrationScreen({super.key});

  @override
  State<CourseRegistrationScreen> createState() =>
      _CourseRegistrationScreenState();
}

class _CourseRegistrationScreenState extends State<CourseRegistrationScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool isRegistrationOpen = false; // Toggle based on admin approval

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Course Registration'),
        backgroundColor: const Color(0xFF1e3a5f),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          const AppHeader(),
          _buildHeaderSection(context),
          if (!isRegistrationOpen)
            _buildDisabledMessage(context)
          else
            const SizedBox.shrink(),
          Container(
            color: const Color(0xFF1e3a5f),
            child: TabBar(
              controller: _tabController,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              indicatorColor: Colors.yellow,
              tabs: const [
                Tab(text: 'Register'),
                Tab(text: 'Edit'),
                Tab(text: 'Status'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildRegisterTab(context),
                _buildEditTab(context),
                _buildStatusTab(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderSection(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Container(
      color: const Color(0xFF1e3a5f),
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      child: Column(
        children: [
          Text(
            'Student Course Registration View',
            style: TextStyle(
              color: Colors.yellow,
              fontSize: isMobile ? 14 : 16,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            '2025-26',
            style: TextStyle(
              color: Colors.white,
              fontSize: isMobile ? 12 : 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDisabledMessage(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      margin: EdgeInsets.all(isMobile ? 12 : 16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3CD),
        border: Border.all(color: const Color(0xFFFFE69C)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            'Edit or Update Option Disabled Now.',
            style: TextStyle(
              fontSize: isMobile ? 14 : 16,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF856404),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Contact Dean Academics',
            style: TextStyle(
              fontSize: isMobile ? 12 : 14,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF856404),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildRegisterTab(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    if (!isRegistrationOpen) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(isMobile ? 16 : 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              Text(
                'Registration is Currently Closed',
                style: TextStyle(
                  fontSize: isMobile ? 14 : 16,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Please contact Dean Academics to enable registration.',
                style: TextStyle(
                  fontSize: isMobile ? 12 : 14,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  padding: EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: isMobile ? 10 : 12,
                  ),
                ),
                onPressed: () {
                  _tabController.animateTo(2);
                },
                child: const Text(
                  'View Status',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return _buildRegistrationForm(context);
  }

  Widget _buildRegistrationForm(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Padding(
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionCard(
              'Year Course Registration',
              [
                _buildCourseTable(),
              ],
              context),
          const SizedBox(height: 16),
          _buildSectionCard(
              'Lab/Tutorial Mapping Information',
              [
                _buildLabTable(),
              ],
              context),
        ],
      ),
    );
  }

  Widget _buildEditTab(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Padding(
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      child: Column(
        children: [
          if (!isRegistrationOpen)
            Container(
              padding: EdgeInsets.all(isMobile ? 12 : 16),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3CD),
                border: Border.all(color: const Color(0xFFFFE69C)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Edit option is disabled. Contact Dean Academics to enable.',
                style: TextStyle(
                  fontSize: isMobile ? 12 : 14,
                  color: const Color(0xFF856404),
                ),
                textAlign: TextAlign.center,
              ),
            )
          else
            _buildSectionCard(
                'Edit Course Registration',
                [
                  _buildCourseTable(),
                ],
                context),
        ],
      ),
    );
  }

  Widget _buildStatusTab(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    final semesterCourses = {
      '1-1': [
        {
          'sNo': '1',
          'code': '22CS101',
          'name': 'PC-PROGRAMMING IN C',
          'credits': '3'
        },
        {
          'sNo': '2',
          'code': '22CS102',
          'name': 'MATHEMATICAL FOUNDATIONS OF CS',
          'credits': '3'
        },
        {
          'sNo': '3',
          'code': '22CS103',
          'name': 'DIGITAL LOGIC DESIGN',
          'credits': '3'
        },
        {
          'sNo': '4',
          'code': '22CS104',
          'name': 'ENVIRONMENTAL STUDIES',
          'credits': '2'
        },
        {
          'sNo': '5',
          'code': '22CS105',
          'name': 'PROFESSIONAL ETHICS',
          'credits': '2'
        },
      ],
      '1-2': [
        {
          'sNo': '1',
          'code': '22CS201',
          'name': 'DATA STRUCTURES',
          'credits': '3'
        },
        {
          'sNo': '2',
          'code': '22CS202',
          'name': 'DATABASE FUNDAMENTALS',
          'credits': '3'
        },
        {
          'sNo': '3',
          'code': '22CS203',
          'name': 'WEB TECHNOLOGIES',
          'credits': '3'
        },
        {
          'sNo': '4',
          'code': '22CS204',
          'name': 'ENGINEERING PHYSICS',
          'credits': '2'
        },
      ],
      '2-1': [
        {
          'sNo': '1',
          'code': '22CS301',
          'name': 'DESIGN AND ANALYSIS OF ALGORITHMS',
          'credits': '3'
        },
        {
          'sNo': '2',
          'code': '22CS302',
          'name': 'OPERATING SYSTEMS',
          'credits': '3'
        },
        {'sNo': '3', 'code': '22CS303', 'name': 'DBMS', 'credits': '3'},
        {
          'sNo': '4',
          'code': '22CS304',
          'name': 'PYTHON PROGRAMMING',
          'credits': '3'
        },
      ],
      '2-2': [
        {
          'sNo': '1',
          'code': '22CS401',
          'name': 'JAVA PROGRAMMING',
          'credits': '3'
        },
        {
          'sNo': '2',
          'code': '22CS402',
          'name': 'WEB DEVELOPMENT',
          'credits': '3'
        },
        {
          'sNo': '3',
          'code': '22CS403',
          'name': 'NETWORK PROGRAMMING',
          'credits': '3'
        },
      ],
    };

    return Padding(
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      child: Column(
        children: semesterCourses.entries.map((entry) {
          final semKey = entry.key;
          final parts = semKey.split('-');
          final year = parts[0];
          final sem = parts[1];
          final courses = entry.value;

          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _buildSemesterCourseCard(
              'Year $year - Semester $sem',
              courses,
              context,
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSemesterCourseCard(
    String title,
    List<Map<String, String>> courses,
    BuildContext context,
  ) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!, width: 1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(isMobile ? 12 : 14),
            decoration: BoxDecoration(
              color: const Color(0xFF1e3a5f),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(7),
                topRight: Radius.circular(7),
              ),
            ),
            child: Text(
              title,
              style: TextStyle(
                color: Colors.white,
                fontSize: isMobile ? 13 : 15,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(isMobile ? 12 : 14),
            child: isMobile
                ? _buildMobileCoursesList(courses)
                : _buildDesktopCoursesTable(courses),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopCoursesTable(List<Map<String, String>> courses) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(
              label:
                  Text('S.No.', style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(
              label: Text('Course Code',
                  style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(
              label: Text('Course Name',
                  style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(
              label: Text('Credits',
                  style: TextStyle(fontWeight: FontWeight.bold))),
        ],
        rows: courses.map((course) {
          return DataRow(
            cells: [
              DataCell(Text(course['sNo']!)),
              DataCell(Text(course['code']!)),
              DataCell(
                SizedBox(
                  width: 300,
                  child: Text(
                    course['name']!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              DataCell(Text(course['credits']!)),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMobileCoursesList(List<Map<String, String>> courses) {
    return Column(
      children: courses.asMap().entries.map((entry) {
        int index = entry.key;
        Map<String, String> course = entry.value;

        return Column(
          children: [
            if (index > 0) Divider(color: Colors.grey[300], height: 16),
            _buildMobileCourseRow('S.No.', course['sNo']!),
            _buildMobileCourseRow('Code', course['code']!),
            _buildMobileCourseRow('Course Name', course['name']!),
            _buildMobileCourseRow('Credits', course['credits']!),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildMobileCourseRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1e3a5f),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 11,
                color: Colors.black87,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCourseTable() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('S.No.')),
          DataColumn(label: Text('Course Code')),
          DataColumn(label: Text('Course Name')),
          DataColumn(label: Text('Credits')),
        ],
        rows: [
          DataRow(cells: [
            const DataCell(Text('1')),
            const DataCell(Text('22CS301')),
            const DataCell(Text('Data Structures')),
            const DataCell(Text('3')),
          ]),
          DataRow(cells: [
            const DataCell(Text('2')),
            const DataCell(Text('22CS302')),
            const DataCell(Text('Database Systems')),
            const DataCell(Text('3')),
          ]),
          DataRow(cells: [
            const DataCell(Text('3')),
            const DataCell(Text('22CS303')),
            const DataCell(Text('Operating Systems')),
            const DataCell(Text('3')),
          ]),
        ],
      ),
    );
  }

  Widget _buildLabTable() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Lab Code')),
          DataColumn(label: Text('Lab Name')),
          DataColumn(label: Text('Batch')),
        ],
        rows: [
          DataRow(cells: [
            const DataCell(Text('22CSL301')),
            const DataCell(Text('Data Structures Lab')),
            const DataCell(Text('A')),
          ]),
          DataRow(cells: [
            const DataCell(Text('22CSL302')),
            const DataCell(Text('Database Lab')),
            const DataCell(Text('B')),
          ]),
        ],
      ),
    );
  }

  Widget _buildSectionCard(
    String title,
    List<Widget> children,
    BuildContext context,
  ) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!, width: 1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(isMobile ? 12 : 14),
            decoration: BoxDecoration(
              color: const Color(0xFF1e3a5f),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(7),
                topRight: Radius.circular(7),
              ),
            ),
            child: Text(
              title,
              style: TextStyle(
                color: Colors.white,
                fontSize: isMobile ? 13 : 15,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(isMobile ? 12 : 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }
}
