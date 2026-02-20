import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ViewOnlyPage extends StatefulWidget {
  const ViewOnlyPage({super.key});

  @override
  State<ViewOnlyPage> createState() => _ViewOnlyPageState();
}

class _ViewOnlyPageState extends State<ViewOnlyPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  List<Map<String, dynamic>> _filteredStudents = [];
  List<Map<String, dynamic>> _filteredFaculty = [];
  List<Map<String, dynamic>> _allStudents = [];
  List<Map<String, dynamic>> _allFaculty = [];
  
  bool _isLoadingStudents = false;
  bool _isLoadingFaculty = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _searchController.addListener(_onSearchChanged);
    _loadAllData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    await Future.wait([_loadStudents(), _loadFaculty()]);
  }

  Future<void> _loadStudents() async {
    setState(() => _isLoadingStudents = true);
    try {
      final snapshot = await _firestore.collection('students').get();
      setState(() {
        _allStudents = snapshot.docs
            .map((doc) => {'id': doc.id, 'rollNumber': doc.id, ...doc.data()})
            .toList();
        _filteredStudents = _allStudents;
      });
    } catch (e) {
      print('Error loading students: $e');
    } finally {
      setState(() => _isLoadingStudents = false);
    }
  }

  Future<void> _loadFaculty() async {
    setState(() => _isLoadingFaculty = true);
    try {
      final snapshot = await _firestore.collection('faculty').get();
      setState(() {
        _allFaculty = snapshot.docs
            .map((doc) => {'id': doc.id, ...doc.data()})
            .toList();
        _filteredFaculty = _allFaculty;
      });
    } catch (e) {
      print('Error loading faculty: $e');
    } finally {
      setState(() => _isLoadingFaculty = false);
    }
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase().trim();
    
    setState(() {
      if (query.isEmpty) {
        _filteredStudents = _allStudents;
        _filteredFaculty = _allFaculty;
      } else {
        _filteredStudents = _allStudents.where((student) {
          final rollNumber = (student['rollNumber'] ?? '').toString().toLowerCase();
          final name = (student['name'] ?? '').toString().toLowerCase();
          final email = (student['email'] ?? '').toString().toLowerCase();
          return rollNumber.contains(query) || name.contains(query) || email.contains(query);
        }).toList();
        
        _filteredFaculty = _allFaculty.where((faculty) {
          final facultyId = (faculty['facultyId'] ?? '').toString().toLowerCase();
          final name = (faculty['name'] ?? '').toString().toLowerCase();
          final email = (faculty['email'] ?? '').toString().toLowerCase();
          return facultyId.contains(query) || name.contains(query) || email.contains(query);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      appBar: AppBar(
        title: const Text('View Data (Read-Only)'),
        backgroundColor: const Color(0xFF1e3a5f),
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Students'),
            Tab(text: 'Faculty'),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(isMobile ? 12 : 16),
            child: ValueListenableBuilder<TextEditingValue>(
              valueListenable: _searchController,
              builder: (context, value, child) {
                return TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search by ID, name, or email...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: value.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                  ),
                );
              },
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildStudentView(isMobile),
                _buildFacultyView(isMobile),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentView(bool isMobile) {
    if (_isLoadingStudents) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_filteredStudents.isEmpty) {
      return Center(
        child: Text(
          _searchController.text.isEmpty
              ? 'No students found'
              : 'No students match your search',
          style: const TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      itemCount: _filteredStudents.length,
      itemBuilder: (context, index) {
        final student = _filteredStudents[index];
        return _buildDataCard(
          student['name'] ?? 'Student',
          {
            'Roll Number': student['rollNumber'] ?? 'N/A',
            'Name': student['name'] ?? 'N/A',
            'Department': student['department'] ?? 'N/A',
            'Semester': student['semester']?.toString() ?? 'N/A',
            'Year': student['year']?.toString() ?? 'N/A',
            'Email': student['email'] ?? 'N/A',
            'Phone': student['phoneNumber'] ?? 'N/A',
            'Status': student['status'] ?? 'Active',
          },
          index,
          isMobile,
          Colors.blue,
          onViewDetails: () => _showStudentDetails(context, student),
        );
      },
    );
  }

  Widget _buildFacultyView(bool isMobile) {
    if (_isLoadingFaculty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_filteredFaculty.isEmpty) {
      return Center(
        child: Text(
          _searchController.text.isEmpty
              ? 'No faculty found'
              : 'No faculty match your search',
          style: const TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      itemCount: _filteredFaculty.length,
      itemBuilder: (context, index) {
        final faculty = _filteredFaculty[index];
        return _buildDataCard(
          faculty['name'] ?? 'Faculty',
          {
            'Faculty ID': faculty['facultyId'] ?? 'N/A',
            'Name': faculty['name'] ?? 'N/A',
            'Department': faculty['department'] ?? 'N/A',
            'Designation': faculty['designation'] ?? 'N/A',
            'Email': faculty['email'] ?? 'N/A',
            'Phone': faculty['phone'] ?? 'N/A',
            'Status': faculty['status'] ?? 'Active',
          },
          index,
          isMobile,
          Colors.green,
          onViewDetails: () => _showFacultyDetails(context, faculty),
        );
      },
    );
  }

  void _showStudentDetails(BuildContext context, Map<String, dynamic> student) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 700),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: Color(0xFF1e3a5f),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(4),
                      topRight: Radius.circular(4),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        student['name'] ?? 'Student Details',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close, color: Colors.white),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDetailSection('Basic Information', [
                        _buildDetailRow('Name', student['name']),
                        _buildDetailRow('Roll Number', student['rollNumber']),
                        _buildDetailRow('Email', student['email']),
                        _buildDetailRow('Phone', student['phoneNumber']),
                        _buildDetailRow('Status', student['status']),
                      ]),
                      const SizedBox(height: 16),
                      _buildDetailSection('Admission Details', [
                        _buildDetailRow('Department', student['department']),
                        _buildDetailRow('Semester', student['semester']?.toString()),
                        _buildDetailRow('Year', student['year']?.toString()),
                        _buildDetailRow('Admission Year',
                            student['admissionYear']),
                        _buildDetailRow(
                            'Admission Type', student['admissionType']),
                        _buildDetailRow('Program', student['program']),
                        _buildDetailRow('Batch Number', student['batchNumber']),
                        _buildDetailRow('Date of Admission',
                            student['dateOfAdmission']),
                      ]),
                      const SizedBox(height: 16),
                      _buildDetailSection('Personal Details', [
                        _buildDetailRow(
                            'Father\'s Name', student['fatherName']),
                        _buildDetailRow('Date of Birth',
                            student['dateOfBirth']),
                        _buildDetailRow('Gender', student['gender']),
                        _buildDetailRow('Blood Group',
                            student['bloodGroup']),
                        _buildDetailRow('Nationality',
                            student['nationality']),
                        _buildDetailRow('Religion', student['religion']),
                        _buildDetailRow('Caste', student['caste']),
                        _buildDetailRow('Mother Tongue',
                            student['motherTongue']),
                        _buildDetailRow('Identification Mark',
                            student['identificationMark']),
                        _buildDetailRow('Place of Birth',
                            student['placeOfBirth']),
                      ]),
                      const SizedBox(height: 16),
                      _buildDetailSection('Address Details', [
                        _buildDetailRow(
                            'Address Line 1', student['addressLine1']),
                        _buildDetailRow(
                            'Address Line 2', student['addressLine2']),
                        _buildDetailRow('City', student['city']),
                        _buildDetailRow('State', student['state']),
                        _buildDetailRow('Country', student['country']),
                        _buildDetailRow('Postal Code', student['postalCode']),
                      ]),
                      const SizedBox(height: 16),
                      _buildDetailSection('Academic Details', [
                        _buildDetailRow(
                            'SSC School', student['sscSchool']),
                        _buildDetailRow('SSC Board', student['sscBoard']),
                        _buildDetailRow(
                            'SSC Percentage', student['sscPercentage']),
                        _buildDetailRow(
                            'Inter College', student['interCollege']),
                        _buildDetailRow('Inter Board', student['interBoard']),
                        _buildDetailRow('Inter Percentage',
                            student['interPercentage']),
                      ]),
                      const SizedBox(height: 16),
                      _buildDetailSection('Important Documents', [
                        _buildDetailRow('Aadhar Number', student['aadharNumber']),
                      ]),
                      if (student['mentor'] != null || 
                          student['mentorName'] != null ||
                          student['courses'] != null ||
                          student['attendance'] != null ||
                          student['marks'] != null)
                        const SizedBox(height: 16),
                      if (student['mentor'] != null || 
                          student['mentorName'] != null)
                        _buildDetailSection('Mentor Information', [
                          _buildDetailRow('Mentor Name', student['mentorName']),
                          _buildDetailRow('Mentor ID', student['mentor']),
                          _buildDetailRow('Mentor Email', student['mentorEmail']),
                          _buildDetailRow('Mentor Phone', student['mentorPhone']),
                        ]),
                      if (student['mentor'] != null || 
                          student['mentorName'] != null)
                        const SizedBox(height: 16),
                      if (student['courses'] != null)
                        _buildDetailSection('Registered Courses', [
                          _buildCoursesView(student['courses']),
                        ]),
                      if (student['courses'] != null)
                        const SizedBox(height: 16),
                      if (student['attendance'] != null)
                        _buildDetailSection('Attendance', [
                          _buildAttendanceView(student['attendance']),
                        ]),
                      if (student['attendance'] != null)
                        const SizedBox(height: 16),
                      if (student['marks'] != null)
                        _buildDetailSection('Marks & Performance', [
                          _buildMarksView(student['marks']),
                        ]),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showFacultyDetails(BuildContext context, Map<String, dynamic> faculty) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: Color(0xFF1e3a5f),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(4),
                      topRight: Radius.circular(4),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        faculty['name'] ?? 'Faculty Details',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close, color: Colors.white),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDetailSection('Basic Information', [
                        _buildDetailRow('Name', faculty['name']),
                        _buildDetailRow('Faculty ID', faculty['facultyId']),
                        _buildDetailRow('Email', faculty['email']),
                        _buildDetailRow('Phone', faculty['phone']),
                        _buildDetailRow('Status', faculty['status']),
                      ]),
                      const SizedBox(height: 16),
                      _buildDetailSection('Professional Details', [
                        _buildDetailRow('Department', faculty['department']),
                        _buildDetailRow('Designation',
                            faculty['designation']),
                        _buildDetailRow('Subjects', faculty['subjects']),
                        _buildDetailRow(
                            'Qualification', faculty['qualification']),
                        _buildDetailRow(
                            'Experience', faculty['experience']),
                      ]),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCoursesView(dynamic courses) {
    if (courses == null) {
      return const Text('No courses registered', style: TextStyle(color: Colors.grey));
    }
    
    List<dynamic> courseList = [];
    if (courses is List) {
      courseList = courses;
    } else if (courses is Map) {
      courseList = courses.values.toList();
    }
    
    if (courseList.isEmpty) {
      return const Text('No courses registered', style: TextStyle(color: Colors.grey));
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: courseList.asMap().entries.map((entry) {
        final course = entry.value;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  course is Map ? (course['name'] ?? course.toString()) : course.toString(),
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
                if (course is Map && course['code'] != null)
                  Text(
                    'Code: ${course['code']}',
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                if (course is Map && course['credits'] != null)
                  Text(
                    'Credits: ${course['credits']}',
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildAttendanceView(dynamic attendance) {
    if (attendance == null) {
      return const Text('No attendance data', style: TextStyle(color: Colors.grey));
    }
    
    if (attendance is Map) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: attendance.entries.map((entry) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  entry.key,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
                Text(
                  '${entry.value}%',
                  style: TextStyle(
                    fontSize: 12,
                    color: (double.tryParse(entry.value.toString()) ?? 0) >= 75
                        ? Colors.green
                        : Colors.orange,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      );
    }
    
    return Text(
      attendance.toString(),
      style: const TextStyle(fontSize: 12),
    );
  }

  Widget _buildMarksView(dynamic marks) {
    if (marks == null) {
      return const Text('No marks data', style: TextStyle(color: Colors.grey));
    }
    
    if (marks is Map) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: marks.entries.map((entry) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.key,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                  if (entry.value is Map)
                    ...((entry.value as Map).entries.map((e) => Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${e.key}:',
                            style: const TextStyle(fontSize: 11),
                          ),
                          Text(
                            e.value.toString(),
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    )))
                  else
                    Text(
                      entry.value.toString(),
                      style: const TextStyle(fontSize: 11),
                    ),
                ],
              ),
            ),
          );
        }).toList(),
      );
    }
    
    return Text(
      marks.toString(),
      style: const TextStyle(fontSize: 12),
    );
  }

  Widget _buildDetailSection(
      String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.only(bottom: 8),
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Color(0xFF1e3a5f), width: 2),
            ),
          ),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1e3a5f),
            ),
          ),
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    );
  }

  Widget _buildDetailRow(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 1,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1e3a5f),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 1,
            child: Text(
              value?.toString() ?? 'N/A',
              style: const TextStyle(
                fontSize: 13,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataCard(
    String title,
    Map<String, String> data,
    int index,
    bool isMobile,
    Color statusColor,
    {required VoidCallback onViewDetails}
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: isMobile ? 13 : 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      data['Status'] ?? 'Active',
                      style: TextStyle(
                        fontSize: 10,
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: onViewDetails,
                    icon: const Icon(Icons.open_in_new, size: 16),
                    label: const Text('View'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: statusColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...data.entries
              .where((e) => e.key != 'Status')
              .map((e) => _buildInfoRow(e.key, e.value, isMobile))
              .toList(),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, bool isMobile) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: isMobile ? 10 : 11,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: isMobile ? 11 : 12,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}
