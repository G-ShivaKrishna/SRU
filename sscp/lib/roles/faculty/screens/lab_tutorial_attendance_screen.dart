import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../widgets/app_header.dart';

class LabTutorialAttendanceScreen extends StatefulWidget {
  const LabTutorialAttendanceScreen({super.key});

  @override
  State<LabTutorialAttendanceScreen> createState() =>
      _LabTutorialAttendanceScreenState();
}

class _LabTutorialAttendanceScreenState
    extends State<LabTutorialAttendanceScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String _attendanceType = 'Lab'; // Lab or Tutorial
  String? _selectedCourse;
  String? _selectedSection;
  DateTime _selectedDate = DateTime.now();
  String? _selectedSlot;

  List<Map<String, dynamic>> _students = [];
  Map<String, bool> _attendanceStatus = {};
  bool _isLoading = false;

  final List<String> _courses = ['CSE101', 'CSE201', 'CSE301', 'CSE401'];
  final List<String> _sections = ['A', 'B', 'C', 'D'];
  final List<String> _labSlots = ['Slot 1 (9:00-12:00)', 'Slot 2 (1:00-4:00)'];
  final List<String> _tutorialSlots = [
    'Tutorial 1',
    'Tutorial 2',
    'Tutorial 3'
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lab/Tutorial Attendance Entry'),
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
                  _buildTypeSelector(),
                  const SizedBox(height: 16),
                  _buildDateSelector(),
                  const SizedBox(height: 16),
                  _buildFilters(),
                  const SizedBox(height: 16),
                  if (_students.isNotEmpty) ...[
                    _buildAttendanceControls(),
                    const SizedBox(height: 16),
                    _buildStudentList(),
                    const SizedBox(height: 16),
                    _buildSubmitButton(),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Attendance Type',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: RadioListTile<String>(
                    title: const Text('Lab'),
                    value: 'Lab',
                    groupValue: _attendanceType,
                    onChanged: (value) {
                      setState(() {
                        _attendanceType = value!;
                        _selectedSlot = null;
                      });
                    },
                    activeColor: const Color(0xFF1e3a5f),
                  ),
                ),
                Expanded(
                  child: RadioListTile<String>(
                    title: const Text('Tutorial'),
                    value: 'Tutorial',
                    groupValue: _attendanceType,
                    onChanged: (value) {
                      setState(() {
                        _attendanceType = value!;
                        _selectedSlot = null;
                      });
                    },
                    activeColor: const Color(0xFF1e3a5f),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateSelector() {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.calendar_today),
        title: const Text('Date'),
        subtitle: Text(
          DateFormat('EEEE, MMMM d, yyyy').format(_selectedDate),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        trailing: Text(
          _selectedDate.day == DateTime.now().day &&
                  _selectedDate.month == DateTime.now().month &&
                  _selectedDate.year == DateTime.now().year
              ? 'Today'
              : '',
          style: const TextStyle(
            color: Colors.green,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildFilters() {
    final slots = _attendanceType == 'Lab' ? _labSlots : _tutorialSlots;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedCourse,
                    decoration: const InputDecoration(
                      labelText: 'Course',
                      border: OutlineInputBorder(),
                    ),
                    items: _courses.map((course) {
                      return DropdownMenuItem(
                        value: course,
                        child: Text(course),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedCourse = value;
                        _loadStudents();
                      });
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedSection,
                    decoration: const InputDecoration(
                      labelText: 'Section',
                      border: OutlineInputBorder(),
                    ),
                    items: _sections.map((section) {
                      return DropdownMenuItem(
                        value: section,
                        child: Text(section),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedSection = value;
                        _loadStudents();
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedSlot,
              decoration: InputDecoration(
                labelText: _attendanceType == 'Lab' ? 'Lab Slot' : 'Tutorial',
                border: const OutlineInputBorder(),
              ),
              items: slots.map((slot) {
                return DropdownMenuItem(
                  value: slot,
                  child: Text(slot),
                );
              }).toList(),
              onChanged: (value) {
                setState(() => _selectedSlot = value);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttendanceControls() {
    final presentCount = _attendanceStatus.values.where((v) => v).length;
    final absentCount = _attendanceStatus.values.where((v) => !v).length;

    return Card(
      color: _attendanceType == 'Lab'
          ? Colors.blue.shade50
          : Colors.purple.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              decoration: BoxDecoration(
                color: _attendanceType == 'Lab'
                    ? Colors.blue.shade100
                    : Colors.purple.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$_attendanceType Attendance',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _attendanceType == 'Lab'
                      ? Colors.blue.shade900
                      : Colors.purple.shade900,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    Text(
                      '$presentCount',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                    const Text('Present'),
                  ],
                ),
                Column(
                  children: [
                    Text(
                      '$absentCount',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                    const Text('Absent'),
                  ],
                ),
                Column(
                  children: [
                    Text(
                      '${_students.length}',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Text('Total'),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: _markAllPresent,
                  icon: const Icon(Icons.check_circle),
                  label: const Text('Mark All Present'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _markAllAbsent,
                  icon: const Icon(Icons.cancel),
                  label: const Text('Mark All Absent'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentList() {
    return Card(
      child: ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _students.length,
        itemBuilder: (context, index) {
          final student = _students[index];
          final studentId = student['id'];
          final isPresent = _attendanceStatus[studentId] ?? false;

          return ListTile(
            leading: CircleAvatar(
              backgroundColor: isPresent ? Colors.green : Colors.red,
              child: Text(
                '${index + 1}',
                style: const TextStyle(color: Colors.white),
              ),
            ),
            title: Text(student['name']),
            subtitle: Text(student['hallTicket']),
            trailing: Switch(
              value: isPresent,
              onChanged: (value) {
                setState(() {
                  _attendanceStatus[studentId] = value;
                });
              },
              activeColor: Colors.green,
            ),
          );
        },
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _canSubmit() ? _submitAttendance : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1e3a5f),
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
        child: _isLoading
            ? const CircularProgressIndicator(color: Colors.white)
            : Text(
                'Submit $_attendanceType Attendance',
                style: const TextStyle(fontSize: 16),
              ),
      ),
    );
  }

  bool _canSubmit() {
    return _selectedCourse != null &&
        _selectedSection != null &&
        _selectedSlot != null &&
        _students.isNotEmpty &&
        !_isLoading;
  }

  void _markAllPresent() {
    setState(() {
      for (var student in _students) {
        _attendanceStatus[student['id']] = true;
      }
    });
  }

  void _markAllAbsent() {
    setState(() {
      for (var student in _students) {
        _attendanceStatus[student['id']] = false;
      }
    });
  }

  Future<void> _loadStudents() async {
    if (_selectedCourse == null || _selectedSection == null) return;

    setState(() => _isLoading = true);

    try {
      // Mock data - Replace with actual Firestore query
      await Future.delayed(const Duration(seconds: 1));

      final mockStudents = List.generate(30, (index) {
        return {
          'id': 'STU${index + 1}',
          'name': 'Student ${index + 1}',
          'hallTicket': '20B01A${(index + 1).toString().padLeft(2, '0')}01',
        };
      });

      setState(() {
        _students = mockStudents;
        _attendanceStatus = {
          for (var student in _students) student['id']: true
        };
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading students: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _submitAttendance() async {
    setState(() => _isLoading = true);

    try {
      final attendanceData = {
        'date': Timestamp.fromDate(_selectedDate),
        'type': _attendanceType,
        'course': _selectedCourse,
        'section': _selectedSection,
        'slot': _selectedSlot,
        'attendance': _attendanceStatus,
        'submittedAt': FieldValue.serverTimestamp(),
        'submittedBy': 'faculty_id',
      };

      // await _firestore.collection('attendance').add(attendanceData);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$_attendanceType attendance submitted successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error submitting attendance: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }
}
