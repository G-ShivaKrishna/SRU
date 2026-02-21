import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../widgets/app_header.dart';

class AttendanceRegisterScreen extends StatefulWidget {
  const AttendanceRegisterScreen({super.key});

  @override
  State<AttendanceRegisterScreen> createState() =>
      _AttendanceRegisterScreenState();
}

class _AttendanceRegisterScreenState extends State<AttendanceRegisterScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? _selectedSemester = 'SEM-1';
  String? _selectedSession = '2025-2026';
  bool _isLoading = false;

  List<Map<String, dynamic>> _courseAttendanceData = [];

  final List<String> _semesters = ['SEM-1', 'SEM-2', 'SEM-3'];
  final List<String> _sessions = ['2025-2026', '2024-2025', '2023-2024'];

  @override
  void initState() {
    super.initState();
    _loadAttendanceData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance Register View'),
        backgroundColor: const Color(0xFF1e3a5f),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AppHeader(),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildFilters(),
                  const SizedBox(height: 16),
                  _buildSummaryCards(),
                  const SizedBox(height: 24),
                  _buildCourseWiseReport(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Filter By',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedSession,
                    decoration: const InputDecoration(
                      labelText: 'Academic Session',
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                    items: _sessions.map((session) {
                      return DropdownMenuItem(
                        value: session,
                        child: Text(session),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedSession = value;
                        _loadAttendanceData();
                      });
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedSemester,
                    decoration: const InputDecoration(
                      labelText: 'Semester',
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                    items: _semesters.map((semester) {
                      return DropdownMenuItem(
                        value: semester,
                        child: Text(semester),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedSemester = value;
                        _loadAttendanceData();
                      });
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCards() {
    final totalCourses = _courseAttendanceData.length;
    final averageAttendance = totalCourses > 0
        ? (_courseAttendanceData
                    .fold<double>(
                        0,
                        (sum, course) =>
                            sum + (course['attendancePercentage'] as double))
                    .toDouble() /
                totalCourses)
            .toStringAsFixed(1)
        : '0';

    final coursesAbove75 = _courseAttendanceData
        .where((course) => (course['attendancePercentage'] as double) >= 75)
        .length;

    return Row(
      children: [
        Expanded(
          child: _buildSummaryCard(
            'Total Courses',
            '$totalCourses',
            Colors.blue,
            Icons.book,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildSummaryCard(
            'Avg Attendance',
            '$averageAttendance%',
            Colors.green,
            Icons.trending_up,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildSummaryCard(
            'Above 75%',
            '$coursesAbove75',
            Colors.orange,
            Icons.check_circle,
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(
    String title,
    String value,
    Color color,
    IconData icon,
  ) {
    return Card(
      elevation: 2,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
          ),
        ),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCourseWiseReport() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Course Wise Attendance Report',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        if (_isLoading)
          const Center(child: CircularProgressIndicator())
        else if (_courseAttendanceData.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 32.0),
              child: Column(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 48,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'No attendance data available',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _courseAttendanceData.length,
            itemBuilder: (context, index) {
              final course = _courseAttendanceData[index];
              return _buildCourseCard(course, index + 1);
            },
          ),
      ],
    );
  }

  Widget _buildCourseCard(Map<String, dynamic> course, int index) {
    final attendancePercentage =
        (course['attendancePercentage'] as double).toStringAsFixed(1);
    final attendanceStatus =
        _getAttendanceStatus(double.parse(attendancePercentage));

    return Card(
      margin: const EdgeInsets.only(bottom: 12.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: const Color(0xFF1e3a5f),
                  child: Text(
                    '$index',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        course['courseName'] ?? 'Course ${index}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Code: ${course['courseCode'] ?? 'N/A'}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getStatusColor(attendanceStatus['color']),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    attendanceStatus['status'],
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Attendance',
                            style: TextStyle(fontSize: 12),
                          ),
                          Text(
                            '$attendancePercentage%',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: double.parse(attendancePercentage) / 100,
                          minHeight: 8,
                          backgroundColor: Colors.grey[300],
                          valueColor: AlwaysStoppedAnimation<Color>(
                            _getStatusColor(attendanceStatus['color']),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(
                  'Classes',
                  '${course['totalClasses'] ?? 0}',
                  Icons.calendar_today,
                ),
                _buildStatItem(
                  'Present',
                  '${course['presentDays'] ?? 0}',
                  Icons.check_circle,
                ),
                _buildStatItem(
                  'Absent',
                  '${course['absentDays'] ?? 0}',
                  Icons.cancel,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 20, color: const Color(0xFF1e3a5f)),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  Map<String, dynamic> _getAttendanceStatus(double percentage) {
    if (percentage >= 85) {
      return {'status': 'Excellent', 'color': 'green'};
    } else if (percentage >= 75) {
      return {'status': 'Good', 'color': 'blue'};
    } else if (percentage >= 65) {
      return {'status': 'Average', 'color': 'orange'};
    } else {
      return {'status': 'Low', 'color': 'red'};
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'green':
        return Colors.green;
      case 'blue':
        return Colors.blue;
      case 'orange':
        return Colors.orange;
      case 'red':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Future<void> _loadAttendanceData() async {
    setState(() => _isLoading = true);

    try {
      // Mock data - Replace with actual Firestore query
      await Future.delayed(const Duration(milliseconds: 500));

      final mockData = [
        {
          'courseName': 'Data Structures',
          'courseCode': 'CSE201',
          'attendancePercentage': 92.5,
          'totalClasses': 40,
          'presentDays': 37,
          'absentDays': 3,
          'section': 'A',
        },
        {
          'courseName': 'Web Development',
          'courseCode': 'CSE301',
          'attendancePercentage': 88.0,
          'totalClasses': 35,
          'presentDays': 30,
          'absentDays': 5,
          'section': 'B',
        },
        {
          'courseName': 'Database Management',
          'courseCode': 'CSE202',
          'attendancePercentage': 95.0,
          'totalClasses': 40,
          'presentDays': 38,
          'absentDays': 2,
          'section': 'A',
        },
        {
          'courseName': 'Operating Systems',
          'courseCode': 'CSE302',
          'attendancePercentage': 78.5,
          'totalClasses': 40,
          'presentDays': 31,
          'absentDays': 9,
          'section': 'C',
        },
        {
          'courseName': 'Artificial Intelligence',
          'courseCode': 'CSE401',
          'attendancePercentage': 85.0,
          'totalClasses': 38,
          'presentDays': 32,
          'absentDays': 6,
          'section': 'B',
        },
        {
          'courseName': 'Computer Networks',
          'courseCode': 'CSE303',
          'attendancePercentage': 91.0,
          'totalClasses': 41,
          'presentDays': 37,
          'absentDays': 4,
          'section': 'A',
        },
      ];

      setState(() {
        _courseAttendanceData = mockData;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading data: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }
}
