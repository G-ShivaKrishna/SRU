import 'package:flutter/material.dart';
import '../../../services/student_access_service.dart';

class StudentAdmissionEditPage extends StatefulWidget {
  const StudentAdmissionEditPage({super.key});

  @override
  State<StudentAdmissionEditPage> createState() =>
      _StudentAdmissionEditPageState();
}

class _StudentAdmissionEditPageState extends State<StudentAdmissionEditPage> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _admissionYearController =
      TextEditingController();
  final TextEditingController _admissionTypeController =
      TextEditingController();
  final TextEditingController _dateOfAdmissionController =
      TextEditingController();

  List<Map<String, dynamic>> _searchResults = [];
  Map<String, dynamic>? _selectedStudent;
  bool _isLoading = false;
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _admissionYearController.dispose();
    _admissionTypeController.dispose();
    _dateOfAdmissionController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    if (_searchController.text.isEmpty) {
      setState(() {
        _searchResults = [];
        _selectedStudent = null;
        _clearFormControllers();
      });
    }
  }

  void _clearFormControllers() {
    _admissionYearController.clear();
    _admissionTypeController.clear();
    _dateOfAdmissionController.clear();
  }

  Future<void> _searchStudents() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a search query')),
      );
      return;
    }

    setState(() {
      _isSearching = true;
    });

    try {
      final results = await StudentAccessService.searchStudents(query);
      setState(() {
        _searchResults = results;
        _selectedStudent = null;
        _clearFormControllers();
      });

      if (results.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No students found')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error searching: $e')),
      );
    } finally {
      setState(() {
        _isSearching = false;
      });
    }
  }

  void _selectStudent(Map<String, dynamic> student) {
    setState(() {
      _selectedStudent = student;
      // Load existing values
      _admissionYearController.text = student['admissionYear'] ?? '';
      _admissionTypeController.text = student['admissionType'] ?? '';
      _dateOfAdmissionController.text = student['dateOfAdmission'] ?? '';
    });
  }

  Future<void> _updateAdmissionInfo() async {
    if (_selectedStudent == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a student')),
      );
      return;
    }

    if (_admissionYearController.text.isEmpty &&
        _admissionTypeController.text.isEmpty &&
        _dateOfAdmissionController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please fill at least one field to update')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final hallTicketNumber =
          _selectedStudent!['hallTicketNumber'] ?? _selectedStudent!['id'];
      final result =
          await StudentAccessService.updateStudentAdmissionInfoAsAdmin(
        hallTicketNumber,
        _admissionYearController.text.isEmpty
            ? null
            : _admissionYearController.text.trim(),
        _admissionTypeController.text.isEmpty
            ? null
            : _admissionTypeController.text.trim(),
        _dateOfAdmissionController.text.isEmpty
            ? null
            : _dateOfAdmissionController.text.trim(),
      );

      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message']),
            backgroundColor: Colors.green,
          ),
        );
        setState(() {
          _selectedStudent = null;
          _clearFormControllers();
          _searchController.clear();
          _searchResults = [];
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'])),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating admission info: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Student Admission Information'),
        backgroundColor: const Color(0xFF1e3a5f),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(isMobile ? 12 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Search Section
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Search Student',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              decoration: InputDecoration(
                                hintText: 'Enter hall ticket number or name',
                                prefixIcon: const Icon(Icons.search),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 12,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: _isSearching ? null : _searchStudents,
                            icon: _isSearching
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.search),
                            label: const Text('Search'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Search Results
              if (_searchResults.isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Student Results',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _searchResults.length,
                      itemBuilder: (context, index) {
                        final student = _searchResults[index];
                        final isSelected = _selectedStudent != null &&
                            _selectedStudent!['id'] == student['id'];

                        return Card(
                          color: isSelected
                              ? const Color(0xFF1e3a5f).withOpacity(0.1)
                              : Colors.white,
                          child: ListTile(
                            onTap: () => _selectStudent(student),
                            leading: CircleAvatar(
                              backgroundColor: const Color(0xFF1e3a5f),
                              child: Text(
                                (student['name'] ?? 'S')
                                    .toString()
                                    .characters
                                    .first
                                    .toUpperCase(),
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                            title: Text(
                              student['name'] ?? 'Unknown',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'ID: ${student['hallTicketNumber'] ?? student['id']}',
                                ),
                                Text(
                                  'Department: ${student['department'] ?? 'N/A'}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ],
                            ),
                            trailing: isSelected
                                ? const Icon(Icons.check_circle,
                                    color: Color(0xFF1e3a5f))
                                : null,
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                  ],
                ),

              // Edit Admission Information Section
              if (_selectedStudent != null)
                Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Edit Admission Information',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Student: ${_selectedStudent!['name']} (${_selectedStudent!['hallTicketNumber'] ?? _selectedStudent!['id']})',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildFormField(
                          'Admission Year',
                          'e.g., 2022',
                          _admissionYearController,
                          isMobile,
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: 12),
                        _buildFormField(
                          'Admission Type',
                          'e.g., Regular, Lateral',
                          _admissionTypeController,
                          isMobile,
                        ),
                        const SizedBox(height: 12),
                        _buildFormField(
                          'Date of Admission',
                          'e.g., 2022-08-15',
                          _dateOfAdmissionController,
                          isMobile,
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.orange[50],
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.orange, width: 1),
                          ),
                          child: const Text(
                            '📝 Update all or some fields. Leave empty to keep existing values.',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.orange,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _isLoading ? null : _updateAdmissionInfo,
                            icon: _isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                          Colors.white),
                                    ),
                                  )
                                : const Icon(Icons.save),
                            label: Text(
                              _isLoading ? 'Updating...' : 'Update Information',
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              backgroundColor: const Color(0xFF1e3a5f),
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: Colors.grey[400],
                              disabledForegroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFormField(
    String label,
    String hint,
    TextEditingController controller,
    bool isMobile, {
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        contentPadding: EdgeInsets.symmetric(
          horizontal: 12,
          vertical: isMobile ? 10 : 12,
        ),
        prefixIcon: Icon(_getIconForField(label)),
      ),
    );
  }

  IconData _getIconForField(String label) {
    switch (label.toLowerCase()) {
      case 'admission year':
        return Icons.calendar_today;
      case 'admission type':
        return Icons.badge;
      case 'course name':
        return Icons.school;
      case 'date of admission':
        return Icons.date_range;
      default:
        return Icons.edit;
    }
  }
}
