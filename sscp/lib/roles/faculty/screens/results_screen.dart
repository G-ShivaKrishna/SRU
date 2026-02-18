import 'package:flutter/material.dart';
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

  final courses = ['22CS301 - DAA', '22CS302 - OS', '22CS303 - DBMS'];
  final sections = ['A', 'B', 'C', 'D'];
  final examTypes = ['Mid Sem 1', 'Mid Sem 2', 'End Sem'];

  final List<Map<String, dynamic>> students = [
    {'rollNo': '22CSBTB01', 'name': 'STUDENT 1', 'marks': ''},
    {'rollNo': '22CSBTB02', 'name': 'STUDENT 2', 'marks': ''},
    {'rollNo': '22CSBTB03', 'name': 'STUDENT 3', 'marks': ''},
    {'rollNo': '22CSBTB04', 'name': 'STUDENT 4', 'marks': ''},
    {'rollNo': '22CSBTB05', 'name': 'STUDENT 5', 'marks': ''},
  ];

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
            const AppHeader(),
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
      setState(() => isStudentListLoaded = true);
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
            decoration: BoxDecoration(
              color: const Color(0xFF1e3a5f),
              borderRadius: const BorderRadius.only(
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
                }).toList(),
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
