import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../widgets/app_header.dart';

class MultiBatchAttendanceScreen extends StatefulWidget {
  const MultiBatchAttendanceScreen({super.key});

  @override
  State<MultiBatchAttendanceScreen> createState() =>
      _MultiBatchAttendanceScreenState();
}

class _MultiBatchAttendanceScreenState
    extends State<MultiBatchAttendanceScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? _selectedCourse;
  DateTime _selectedDate = DateTime.now();
  String? _selectedPeriod;
  Set<String> _selectedBatches = {};

  List<Map<String, dynamic>> _students = [];
  Map<String, bool> _attendanceStatus = {};
  bool _isLoading = false;

  final List<String> _courses = ['CSE101', 'CSE201', 'CSE301', 'CSE401'];
  final List<String> _batches = ['Batch 1', 'Batch 2', 'Batch 3', 'Batch 4'];
  final List<String> _periods = ['1', '2', '3', '4', '5', '6', '7', '8'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Multi-Batch Attendance Entry'),
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
                  _buildDateSelector(),
                  const SizedBox(height: 16),
                  _buildFilters(),
                  const SizedBox(height: 16),
                  _buildBatchSelector(),
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            DropdownButtonFormField<String>(
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
                });
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedPeriod,
              decoration: const InputDecoration(
                labelText: 'Period',
                border: OutlineInputBorder(),
              ),
              items: _periods.map((period) {
                return DropdownMenuItem(
                  value: period,
                  child: Text('Period $period'),
                );
              }).toList(),
              onChanged: (value) {
                setState(() => _selectedPeriod = value);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBatchSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select Batches',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _batches.map((batch) {
                final isSelected = _selectedBatches.contains(batch);
                return FilterChip(
                  label: Text(batch),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedBatches.add(batch);
                      } else {
                        _selectedBatches.remove(batch);
                      }
                      _loadStudents();
                    });
                  },
                  selectedColor: const Color(0xFF1e3a5f).withOpacity(0.3),
                  checkmarkColor: const Color(0xFF1e3a5f),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _selectedBatches = Set.from(_batches);
                      _loadStudents();
                    });
                  },
                  icon: const Icon(Icons.select_all),
                  label: const Text('Select All'),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _selectedBatches.clear();
                      _students.clear();
                      _attendanceStatus.clear();
                    });
                  },
                  icon: const Icon(Icons.clear),
                  label: const Text('Clear All'),
                ),
              ],
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
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
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
            const SizedBox(height: 8),
            Text(
              'Selected Batches: ${_selectedBatches.join(', ')}',
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
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
            subtitle: Text('${student['hallTicket']} - ${student['batch']}'),
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
            : const Text(
                'Submit Attendance',
                style: TextStyle(fontSize: 16),
              ),
      ),
    );
  }

  bool _canSubmit() {
    return _selectedCourse != null &&
        _selectedPeriod != null &&
        _selectedBatches.isNotEmpty &&
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
    if (_selectedCourse == null || _selectedBatches.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      // Mock data - Replace with actual Firestore query
      await Future.delayed(const Duration(seconds: 1));

      final mockStudents = <Map<String, dynamic>>[];
      for (var i = 0; i < _selectedBatches.length; i++) {
        final batch = _selectedBatches.elementAt(i);
        for (var j = 0; j < 10; j++) {
          mockStudents.add({
            'id': 'STU${batch}_${j + 1}',
            'name': 'Student ${batch} - ${j + 1}',
            'hallTicket':
                '20B01A${(i * 10 + j + 1).toString().padLeft(2, '0')}01',
            'batch': batch,
          });
        }
      }

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
        'course': _selectedCourse,
        'batches': _selectedBatches.toList(),
        'period': _selectedPeriod,
        'attendance': _attendanceStatus,
        'submittedAt': FieldValue.serverTimestamp(),
        'submittedBy': 'faculty_id',
      };

      // await _firestore.collection('attendance').add(attendanceData);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Multi-batch attendance submitted successfully!'),
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
