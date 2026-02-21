import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../widgets/app_header.dart';

class ViewUpdateDeleteAttendanceScreen extends StatefulWidget {
  const ViewUpdateDeleteAttendanceScreen({super.key});

  @override
  State<ViewUpdateDeleteAttendanceScreen> createState() =>
      _ViewUpdateDeleteAttendanceScreenState();
}

class _ViewUpdateDeleteAttendanceScreenState
    extends State<ViewUpdateDeleteAttendanceScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  DateTime _selectedDate = DateTime.now();
  String? _selectedCourse;
  String? _selectedSection;
  String? _selectedPeriod;

  List<Map<String, dynamic>> _attendanceRecords = [];
  Map<String, bool> _attendanceStatus = {};
  bool _isLoading = false;
  bool _isEditMode = false;

  final List<String> _courses = ['CSE101', 'CSE201', 'CSE301', 'CSE401'];
  final List<String> _sections = ['A', 'B', 'C', 'D'];
  final List<String> _periods = ['1', '2', '3', '4', '5', '6', '7', '8'];

  @override
  Widget build(BuildContext context) {
    final isToday = _isDateToday(_selectedDate);

    return Scaffold(
      appBar: AppBar(
        title: const Text('View | Update | Delete Attendance'),
        backgroundColor: const Color(0xFF1e3a5f),
        actions: [
          if (!isToday)
            IconButton(
              icon: const Icon(Icons.edit_calendar),
              onPressed: _showRequestAccessDialog,
              tooltip: 'Request Edit Access',
            ),
        ],
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
                  _buildDatePicker(),
                  const SizedBox(height: 16),
                  if (!isToday) _buildPastDateWarning(),
                  if (!isToday) const SizedBox(height: 16),
                  _buildFilters(),
                  const SizedBox(height: 16),
                  if (_attendanceRecords.isNotEmpty) ...[
                    _buildAttendanceSummary(),
                    const SizedBox(height: 16),
                    _buildAttendanceList(),
                    const SizedBox(height: 16),
                    if (isToday) _buildActionButtons(),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDatePicker() {
    return Card(
      child: InkWell(
        onTap: () => _selectDate(context),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              const Icon(Icons.calendar_today, color: Color(0xFF1e3a5f)),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Select Date',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat('EEEE, MMMM d, yyyy').format(_selectedDate),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              if (_isDateToday(_selectedDate))
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'TODAY',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPastDateWarning() {
    return Card(
      color: Colors.orange.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.orange),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Past Date Selected',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'You can only view past attendance. To edit, request admin access.',
                    style: TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: _showRequestAccessDialog,
                    icon: const Icon(Icons.send, size: 16),
                    label: const Text('Request Edit Access'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                    ),
                  ),
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
                        _loadAttendance();
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
                        _loadAttendance();
                      });
                    },
                  ),
                ),
              ],
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
                setState(() {
                  _selectedPeriod = value;
                  _loadAttendance();
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttendanceSummary() {
    final presentCount = _attendanceStatus.values.where((v) => v).length;
    final absentCount = _attendanceStatus.values.where((v) => !v).length;
    final totalCount = _attendanceRecords.length;
    final percentage = totalCount > 0
        ? (presentCount / totalCount * 100).toStringAsFixed(1)
        : '0';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildSummaryItem('Present', presentCount, Colors.green),
                _buildSummaryItem('Absent', absentCount, Colors.red),
                _buildSummaryItem('Total', totalCount, Colors.blue),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: totalCount > 0 ? presentCount / totalCount : 0,
              backgroundColor: Colors.red.shade100,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
              minHeight: 8,
            ),
            const SizedBox(height: 8),
            Text(
              '$percentage% Attendance',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String label, int count, Color color) {
    return Column(
      children: [
        Text(
          '$count',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildAttendanceList() {
    final isToday = _isDateToday(_selectedDate);

    return Card(
      child: ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _attendanceRecords.length,
        itemBuilder: (context, index) {
          final student = _attendanceRecords[index];
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
            trailing: isToday && _isEditMode
                ? Switch(
                    value: isPresent,
                    onChanged: (value) {
                      setState(() {
                        _attendanceStatus[studentId] = value;
                      });
                    },
                    activeColor: Colors.green,
                  )
                : Chip(
                    label: Text(
                      isPresent ? 'Present' : 'Absent',
                      style: const TextStyle(color: Colors.white),
                    ),
                    backgroundColor: isPresent ? Colors.green : Colors.red,
                  ),
          );
        },
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        if (!_isEditMode) ...[
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () {
                setState(() => _isEditMode = true);
              },
              icon: const Icon(Icons.edit),
              label: const Text('Edit Attendance'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _confirmDelete,
              icon: const Icon(Icons.delete),
              label: const Text('Delete'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ] else ...[
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _saveChanges,
              icon: const Icon(Icons.save),
              label: const Text('Save Changes'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () {
                setState(() {
                  _isEditMode = false;
                  _loadAttendance(); // Reload original data
                });
              },
              icon: const Icon(Icons.cancel),
              label: const Text('Cancel'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ],
      ],
    );
  }

  bool _isDateToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF1e3a5f),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _isEditMode = false;
        _loadAttendance();
      });
    }
  }

  Future<void> _showRequestAccessDialog() async {
    DateTime? fromDate;
    DateTime? toDate;

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Request Edit Access'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Request admin permission to edit attendance for past dates.',
                      style: TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Select Date Range:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      title: const Text('From Date'),
                      subtitle: Text(
                        fromDate != null
                            ? DateFormat('MMM d, yyyy').format(fromDate!)
                            : 'Select date',
                      ),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: fromDate ??
                              DateTime.now().subtract(const Duration(days: 7)),
                          firstDate: DateTime.now()
                              .subtract(const Duration(days: 365)),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) {
                          setDialogState(() => fromDate = picked);
                        }
                      },
                    ),
                    ListTile(
                      title: const Text('To Date'),
                      subtitle: Text(
                        toDate != null
                            ? DateFormat('MMM d, yyyy').format(toDate!)
                            : 'Select date',
                      ),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: toDate ?? (fromDate ?? DateTime.now()),
                          firstDate: fromDate ??
                              DateTime.now()
                                  .subtract(const Duration(days: 365)),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) {
                          setDialogState(() => toDate = picked);
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: fromDate != null && toDate != null
                      ? () {
                          Navigator.pop(context);
                          _sendEditRequest(fromDate!, toDate!);
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1e3a5f),
                  ),
                  child: const Text('Send Request'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _sendEditRequest(DateTime fromDate, DateTime toDate) async {
    try {
      final requestData = {
        'facultyId': 'faculty_id', // Replace with actual faculty ID
        'requestType': 'edit_attendance',
        'fromDate': Timestamp.fromDate(fromDate),
        'toDate': Timestamp.fromDate(toDate),
        'course': _selectedCourse,
        'section': _selectedSection,
        'requestedAt': FieldValue.serverTimestamp(),
        'status': 'pending',
      };

      // await _firestore.collection('edit_requests').add(requestData);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Edit access request sent to admin successfully!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sending request: $e')),
      );
    }
  }

  Future<void> _loadAttendance() async {
    if (_selectedCourse == null ||
        _selectedSection == null ||
        _selectedPeriod == null) return;

    setState(() => _isLoading = true);

    try {
      // Mock data - Replace with actual Firestore query
      await Future.delayed(const Duration(seconds: 1));

      final mockRecords = List.generate(30, (index) {
        final isPresent = index % 4 != 0; // Mock: 75% attendance
        return {
          'id': 'STU${index + 1}',
          'name': 'Student ${index + 1}',
          'hallTicket': '20B01A${(index + 1).toString().padLeft(2, '0')}01',
          'isPresent': isPresent,
        };
      });

      setState(() {
        _attendanceRecords = mockRecords;
        _attendanceStatus = {
          for (var record in _attendanceRecords)
            record['id']: record['isPresent'] as bool
        };
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading attendance: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveChanges() async {
    setState(() => _isLoading = true);

    try {
      // Update attendance in Firestore
      final updateData = {
        'attendance': _attendanceStatus,
        'lastModifiedAt': FieldValue.serverTimestamp(),
        'modifiedBy': 'faculty_id',
      };

      // await _firestore.collection('attendance').doc('recordId').update(updateData);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Attendance updated successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      setState(() => _isEditMode = false);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating attendance: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: const Text(
          'Are you sure you want to delete this attendance record? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _deleteAttendance();
    }
  }

  Future<void> _deleteAttendance() async {
    setState(() => _isLoading = true);

    try {
      // Delete from Firestore
      // await _firestore.collection('attendance').doc('recordId').delete();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Attendance deleted successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting attendance: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }
}
