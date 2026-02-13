import 'package:flutter/material.dart';
import '../../../services/student_access_service.dart';

class StudentProfileEditAccessPage extends StatefulWidget {
  const StudentProfileEditAccessPage({super.key});

  @override
  State<StudentProfileEditAccessPage> createState() =>
      _StudentProfileEditAccessPageState();
}

class _StudentProfileEditAccessPageState
    extends State<StudentProfileEditAccessPage> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  List<String> _selectedStudents = [];
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
    super.dispose();
  }

  void _onSearchChanged() {
    if (_searchController.text.isEmpty) {
      setState(() {
        _searchResults = [];
        _selectedStudents = [];
      });
    }
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
        _selectedStudents = [];
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

  Future<void> _grantAccessToSelected() async {
    if (_selectedStudents.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one student')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final result = await StudentAccessService.grantEditAccessToMultiple(
        _selectedStudents,
      );

      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message']),
            backgroundColor: Colors.green,
          ),
        );
        setState(() {
          _selectedStudents = [];
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
        SnackBar(content: Text('Error granting access: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _revokeAccess(String hallTicketNumber) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Revoke Edit Access'),
        content: Text(
          'Are you sure you want to revoke edit access for $hallTicketNumber?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              setState(() {
                _isLoading = true;
              });

              try {
                final result = await StudentAccessService.revokeEditAccess(
                  hallTicketNumber,
                );

                if (result['success'] == true) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Edit access revoked'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  _searchStudents();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(result['message'])),
                  );
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error revoking access: $e')),
                );
              } finally {
                setState(() {
                  _isLoading = false;
                });
              }
            },
            child: const Text('Revoke', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Profile Edit Access'),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(isMobile ? 12 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Search section
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Search Students',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText:
                              'Enter roll number (e.g., 2203A51291) or name',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.all(12),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _isSearching ? null : _searchStudents,
                          icon: _isSearching
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.search),
                          label: const Text('Search'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Search results
              if (_searchResults.isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Found ${_searchResults.length} student(s)',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (_selectedStudents.isNotEmpty)
                          Text(
                            '${_selectedStudents.length} selected',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.blue,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ..._buildStudentList(),
                    const SizedBox(height: 16),
                    if (_selectedStudents.isNotEmpty)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _grantAccessToSelected,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor:
                                        AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : const Text(
                                  'Grant Edit Access to Selected',
                                  style: TextStyle(color: Colors.white),
                                ),
                        ),
                      ),
                  ],
                ),

              const SizedBox(height: 24),

              // Students with edit access section
              _buildStudentsWithAccessSection(),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildStudentList() {
    return _searchResults.map((student) {
      final isSelected =
          _selectedStudents.contains(student['hallTicketNumber']);
      final hasAccess = student['canEditProfile'] ?? false;

      return Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: ListTile(
          leading: Checkbox(
            value: isSelected,
            onChanged: (value) {
              setState(() {
                if (value == true) {
                  _selectedStudents.add(student['hallTicketNumber']);
                } else {
                  _selectedStudents.remove(student['hallTicketNumber']);
                }
              });
            },
          ),
          title: Text(student['name'] ?? 'Unknown'),
          subtitle: Text(
            'Roll: ${student['hallTicketNumber']} | ${student['department'] ?? 'N/A'}',
          ),
          trailing: hasAccess
              ? Chip(
                  label: const Text('Access Granted'),
                  backgroundColor: Colors.green[100],
                )
              : null,
          onTap: () {
            setState(() {
              if (isSelected) {
                _selectedStudents.remove(student['hallTicketNumber']);
              } else {
                _selectedStudents.add(student['hallTicketNumber']);
              }
            });
          },
        ),
      );
    }).toList();
  }

  Widget _buildStudentsWithAccessSection() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: StudentAccessService.getStudentsWithEditAccess(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final students = snapshot.data ?? [];

        if (students.isEmpty) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: Text(
                  'No students with edit access',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Students with Edit Access (${students.length})',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ...students.map((student) {
              final grantedAt = student['editAccessGrantedAt'];
              final formattedDate = grantedAt != null
                  ? '${grantedAt.toDate().day}/${grantedAt.toDate().month}/${grantedAt.toDate().year}'
                  : 'Unknown';

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  title: Text(student['name'] ?? 'Unknown'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Roll: ${student['hallTicketNumber']}'),
                      Text('Granted: $formattedDate'),
                    ],
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: _isLoading
                        ? null
                        : () => _revokeAccess(student['hallTicketNumber']),
                  ),
                ),
              );
            }).toList(),
          ],
        );
      },
    );
  }
}
