import 'package:flutter/material.dart';
import '../../../widgets/app_header.dart';

class FacultyCourseAssignmentScreen extends StatefulWidget {
  const FacultyCourseAssignmentScreen({super.key});

  @override
  State<FacultyCourseAssignmentScreen> createState() =>
      _FacultyCourseAssignmentScreenState();
}

class _FacultyCourseAssignmentScreenState
    extends State<FacultyCourseAssignmentScreen> {
  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Course Assignment'),
        backgroundColor: const Color(0xFF1e3a5f),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const AppHeader(),
            Padding(
              padding: EdgeInsets.all(isMobile ? 12 : 16),
              child: _buildCourseAssignments(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCourseAssignments(BuildContext context) {
    final currentSemCourses = [
      {
        'code': '22CS301',
        'name': 'Design and Analysis of Algorithms',
        'section': 'A, B',
        'credits': '3',
        'type': 'Theory'
      },
      {
        'code': '22CS302',
        'name': 'Operating Systems',
        'section': 'A',
        'credits': '3',
        'type': 'Theory'
      },
      {
        'code': '22CS303L',
        'name': 'DBMS Lab',
        'section': 'A, B, C',
        'credits': '2',
        'type': 'Lab'
      },
    ];

    final previousSemCourses = [
      {
        'code': '22CS201',
        'name': 'Data Structures',
        'section': 'A, B',
        'credits': '3',
        'type': 'Theory'
      },
      {
        'code': '22CS202',
        'name': 'Database Fundamentals',
        'section': 'A',
        'credits': '3',
        'type': 'Theory'
      },
    ];

    return Column(
      children: [
        _buildSemesterCard(
            'Current Semester (2025-26)', currentSemCourses, context),
        const SizedBox(height: 16),
        _buildSemesterCard(
            'Previous Semester (2024-25)', previousSemCourses, context),
      ],
    );
  }

  Widget _buildSemesterCard(
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
              label: Text('Course Code',
                  style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(
              label: Text('Course Name',
                  style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(
              label: Text('Section(s)',
                  style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(
              label: Text('Credits',
                  style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(
              label:
                  Text('Type', style: TextStyle(fontWeight: FontWeight.bold))),
        ],
        rows: courses.map((course) {
          return DataRow(
            cells: [
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
              DataCell(Text(course['section']!)),
              DataCell(Text(course['credits']!)),
              DataCell(
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: course['type'] == 'Theory'
                        ? Colors.blue[100]
                        : Colors.orange[100],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    course['type']!,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: course['type'] == 'Theory'
                          ? Colors.blue[900]
                          : Colors.orange[900],
                    ),
                  ),
                ),
              ),
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
            _buildMobileCourseRow('Course Code', course['code']!),
            _buildMobileCourseRow('Course Name', course['name']!),
            _buildMobileCourseRow('Section(s)', course['section']!),
            _buildMobileCourseRow('Credits', course['credits']!),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Type',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1e3a5f),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: course['type'] == 'Theory'
                          ? Colors.blue[100]
                          : Colors.orange[100],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      course['type']!,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: course['type'] == 'Theory'
                            ? Colors.blue[900]
                            : Colors.orange[900],
                      ),
                    ),
                  ),
                ],
              ),
            ),
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
            width: 100,
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
}
