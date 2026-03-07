import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../widgets/app_header.dart';

class FacultyResultsScreen extends StatefulWidget {
  const FacultyResultsScreen({super.key});

  @override
  State<FacultyResultsScreen> createState() => _FacultyResultsScreenState();
}

class _FacultyResultsScreenState extends State<FacultyResultsScreen> {
  String? selectedCourse;
  String? selectedSection;
  String? selectedExamType;
  bool isStudentListLoaded = false;
  bool isLoadingData = false;

  List<String> courses = [];
  List<String> sections = ['A', 'B', 'C', 'D', 'E', 'F'];
  List<String> examTypes = ['Mid Sem 1', 'Mid Sem 2', 'End Sem'];
  List<Map<String, dynamic>> students = [];

  @override
  void initState() {
    super.initState();
    _loadFacultyCourses();
  }

  Future<void> _loadFacultyCourses() async {
    try {
      setState(() => isLoadingData = true);
      
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Get faculty's email to find their ID
      final email = user.email ?? '';
      final facultyId = email.split('@')[0].toUpperCase();

      // Fetch faculty assignments
      final assignmentSnapshot = await FirebaseFirestore.instance
          .collection('facultyAssignments')
          .where('facultyId', isEqualTo: facultyId)
          .get();

      final courseSet = <String>{};
      for (var doc in assignmentSnapshot.docs) {
        final data = doc.data();
        final subjectCode = data['subjectCode'] ?? '';
        final subjectName = data['subjectName'] ?? '';
        if (subjectCode.isNotEmpty) {
          courseSet.add('$subjectCode - $subjectName');
        }
      }

      setState(() {
        courses = courseSet.toList()..sort();
        isLoadingData = false;
      });
    } catch (e) {
      setState(() => isLoadingData = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading courses: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadStudents() async {
    if (selectedCourse == null || selectedSection == null) return;

    try {
      setState(() => isLoadingData = true);

      // Extract subject code from selected course
      final subjectCode = selectedCourse!.split(' - ').first;

      // Fetch students from facultyAssignments who are enrolled in this course
      final assignmentSnapshot = await FirebaseFirestore.instance
          .collection('facultyAssignments')
          .where('subjectCode', isEqualTo: subjectCode)
          .where('section', isEqualTo: selectedSection)
          .limit(1)
          .get();

      if (assignmentSnapshot.docs.isEmpty) {
        setState(() {
          students = [];
          isLoadingData = false;
        });
        return;
      }

      final assignmentData = assignmentSnapshot.docs.first.data();
      final assignedBatches = List<String>.from(assignmentData['assignedBatches'] ?? []);

      // Fetch students from these batches
      final studentsList = <Map<String, dynamic>>[];
      
      for (var batchNumber in assignedBatches) {
        final studentSnapshot = await FirebaseFirestore.instance
            .collection('students')
            .where('batchNumber', isEqualTo: batchNumber)
            .orderBy('hallTicketNumber')
            .get();

        for (var doc in studentSnapshot.docs) {
          final data = doc.data();
          studentsList.add({
            'id': doc.id,
            'rollNo': data['hallTicketNumber'] ?? doc.id,
            'name': data['name'] ?? 'Unknown',
            'marks': '',
          });
        }
      }

      setState(() {
        students = studentsList;
        isStudentListLoaded = true;
        isLoadingData = false;
      });
    } catch (e) {
      setState(() => isLoadingData = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading students: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Grade Entry & Results'),
        backgroundColor: const Color(0xFF1e3a5f),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const AppHeader(showBack: false),
            Padding(
              padding: EdgeInsets.all(isMobile ? 12 : 16),
              child: Column(
                children: [
                  _buildSelectionCard(context),
                  const SizedBox(height: 24),
                  if (isStudentListLoaded) _buildGradeEntryForm(context),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectionCard(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!, width: 1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Select Exam Details',
            style: TextStyle(
              fontSize: isMobile ? 13 : 14,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1e3a5f),
            ),
          ),
          const SizedBox(height: 16),
          if (isMobile)
            Column(
              children: [
                _buildDropdownField('Course', selectedCourse, courses, (value) {
                  setState(() => selectedCourse = value);
                }),
                const SizedBox(height: 12),
                _buildDropdownField('Section', selectedSection, sections,
                    (value) {
                  setState(() => selectedSection = value);
                }),
                const SizedBox(height: 12),
                _buildDropdownField('Exam Type', selectedExamType, examTypes,
                    (value) {
                  setState(() => selectedExamType = value);
                }),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: _onLoadPressed,
                    child: const Text(
                      'Load Students',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            )
          else
            Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildDropdownField(
                          'Course', selectedCourse, courses, (value) {
                        setState(() => selectedCourse = value);
                      }),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildDropdownField(
                          'Section', selectedSection, sections, (value) {
                        setState(() => selectedSection = value);
                      }),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildDropdownField(
                          'Exam Type', selectedExamType, examTypes, (value) {
                        setState(() => selectedExamType = value);
                      }),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: _onLoadPressed,
                    child: const Text(
                      'Load Students',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildDropdownField(String label, String? value, List<String> items,
      Function(String?) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1e3a5f),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[400]!),
            borderRadius: BorderRadius.circular(4),
          ),
          child: DropdownButton<String>(
            value: value,
            isExpanded: true,
            underline: const SizedBox(),
            hint: Text('Select $label'),
            items: items.map((String item) {
              return DropdownMenuItem<String>(
                value: item,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(item),
                ),
              );
            }).toList(),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  void _onLoadPressed() {
    if (selectedCourse != null &&
        selectedSection != null &&
        selectedExamType != null) {
      _loadStudents();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select all fields'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildGradeEntryForm(BuildContext context) {
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
            decoration: const BoxDecoration(
              color: Color(0xFF1e3a5f),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(7),
                topRight: Radius.circular(7),
              ),
            ),
            child: Text(
              'Enter Grades - $selectedCourse Section $selectedSection - $selectedExamType',
              style: TextStyle(
                color: Colors.white,
                fontSize: isMobile ? 12 : 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(isMobile ? 12 : 14),
            child: Column(
              children: [
                ...students.asMap().entries.map((entry) {
                  int index = entry.key;
                  Map<String, dynamic> student = entry.value;
                  return Column(
                    children: [
                      if (index > 0)
                        Divider(color: Colors.grey[300], height: 16),
                      _buildStudentGradeRow(student, isMobile),
                    ],
                  );
                }),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Grades submitted successfully!'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    },
                    child: const Text(
                      'Submit Grades',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentGradeRow(Map<String, dynamic> student, bool isMobile) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  student['rollNo'],
                  style: TextStyle(
                    fontSize: isMobile ? 12 : 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  student['name'],
                  style: TextStyle(
                    fontSize: isMobile ? 11 : 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 1,
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Marks',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              keyboardType: TextInputType.number,
              style: TextStyle(fontSize: isMobile ? 12 : 13),
              onChanged: (value) {
                student['marks'] = value;
              },
            ),
          ),
        ],
      ),
    );
  }
}
