import 'package:flutter/material.dart';
import '../../../widgets/app_header.dart';

class FacultyAttendanceScreen extends StatefulWidget {
  const FacultyAttendanceScreen({super.key});

  @override
  State<FacultyAttendanceScreen> createState() =>
      _FacultyAttendanceScreenState();
}

class _FacultyAttendanceScreenState extends State<FacultyAttendanceScreen> {
  DateTime? selectedDate;
  String? selectedCourse;
  String? selectedSection;
  bool isStudentListLoaded = false;

  final courses = [
    '22CS301 - DAA',
    '22CS302 - OS',
    '22CS303 - DBMS',
    '22CS304 - Python'
  ];
  final sections = ['A', 'B', 'C', 'D'];

  final List<Map<String, dynamic>> students = [
    {'rollNo': '22CSBTB01', 'name': 'STUDENT 1', 'present': false},
    {'rollNo': '22CSBTB02', 'name': 'STUDENT 2', 'present': false},
    {'rollNo': '22CSBTB03', 'name': 'STUDENT 3', 'present': false},
    {'rollNo': '22CSBTB04', 'name': 'STUDENT 4', 'present': false},
    {'rollNo': '22CSBTB05', 'name': 'STUDENT 5', 'present': false},
  ];

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mark Attendance'),
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
                  if (isStudentListLoaded) _buildAttendanceList(context),
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
            'Select Class Details',
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
                _buildDateField('Date', selectedDate, (date) {
                  setState(() => selectedDate = date);
                }),
                const SizedBox(height: 12),
                _buildDropdownField('Course', selectedCourse, courses, (value) {
                  setState(() => selectedCourse = value);
                }),
                const SizedBox(height: 12),
                _buildDropdownField('Section', selectedSection, sections,
                    (value) {
                  setState(() => selectedSection = value);
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
                      child: _buildDateField('Date', selectedDate, (date) {
                        setState(() => selectedDate = date);
                      }),
                    ),
                    const SizedBox(width: 16),
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

  Widget _buildDateField(
    String label,
    DateTime? selectedDate,
    Function(DateTime) onDateSelected,
  ) {
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
        GestureDetector(
          onTap: () async {
            final pickedDate = await showDatePicker(
              context: context,
              initialDate: selectedDate ?? DateTime.now(),
              firstDate: DateTime(2020),
              lastDate: DateTime.now(),
            );
            if (pickedDate != null) {
              onDateSelected(pickedDate);
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[400]!),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  selectedDate != null
                      ? '${selectedDate.day.toString().padLeft(2, '0')}/${selectedDate.month.toString().padLeft(2, '0')}/${selectedDate.year}'
                      : 'mm/dd/yyyy',
                  style: TextStyle(
                    fontSize: 12,
                    color: selectedDate != null ? Colors.black : Colors.grey,
                  ),
                ),
                Icon(Icons.calendar_today, size: 18, color: Colors.grey[600]),
              ],
            ),
          ),
        ),
      ],
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
    if (selectedDate != null &&
        selectedCourse != null &&
        selectedSection != null) {
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

  Widget _buildAttendanceList(BuildContext context) {
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
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Mark Attendance - $selectedCourse Section $selectedSection',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isMobile ? 12 : 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Row(
                  children: [
                    TextButton(
                      onPressed: () {
                        setState(() {
                          for (var student in students) {
                            student['present'] = true;
                          }
                        });
                      },
                      child: const Text(
                        'Mark All',
                        style: TextStyle(color: Colors.yellow, fontSize: 12),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          for (var student in students) {
                            student['present'] = false;
                          }
                        });
                      },
                      child: const Text(
                        'Clear All',
                        style: TextStyle(color: Colors.red, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ],
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
                      _buildStudentRow(student, isMobile),
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
                          content: Text('Attendance saved successfully!'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    },
                    child: const Text(
                      'Submit Attendance',
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

  Widget _buildStudentRow(Map<String, dynamic> student, bool isMobile) {
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
          Checkbox(
            value: student['present'],
            activeColor: Colors.green,
            onChanged: (value) {
              setState(() {
                student['present'] = value ?? false;
              });
            },
          ),
        ],
      ),
    );
  }
}
