import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class HodAssignmentPage extends StatefulWidget {
  const HodAssignmentPage({super.key});

  @override
  State<HodAssignmentPage> createState() => _HodAssignmentPageState();
}

class _HodAssignmentPageState extends State<HodAssignmentPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isLoading = true;
  String? _selectedDepartment;
  String? _selectedFacultyId;

  List<_FacultyOption> _facultyOptions = [];
  Map<String, _FacultyOption> _facultyById = {};
  List<String> _departments = [];

  @override
  void initState() {
    super.initState();
    _loadFaculty();
  }

  Future<void> _loadFaculty() async {
    if (mounted) {
      setState(() => _isLoading = true);
    }

    try {
      final snap = await _firestore.collection('faculty').get();
      final options = <_FacultyOption>[];
      final depts = <String>{};

      for (final doc in snap.docs) {
        final data = doc.data();
        final name = (data['name'] ?? '').toString().trim();
        final dept = _normalizeDepartment(data['department']);
        if (name.isEmpty || dept.isEmpty) continue;

        final email = (data['email'] ?? '').toString().trim();
        final phone = _readPhone(data);

        options.add(
          _FacultyOption(
            id: doc.id.trim().toUpperCase(),
            name: name,
            department: dept,
            email: email,
            phone: phone,
            reference: doc.reference,
          ),
        );
        depts.add(dept);
      }

      options
          .sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      final sortedDepartments = depts.toList()..sort();

      if (!mounted) return;
      setState(() {
        _facultyOptions = options;
        _facultyById = {for (final f in options) f.id: f};
        _departments = sortedDepartments;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load faculty: $e')),
      );
    }
  }

  String _normalizeDepartment(Object? value) {
    return value?.toString().trim().toUpperCase() ?? '';
  }

  String _readPhone(Map<String, dynamic> data) {
    for (final key in ['phone', 'phoneNumber', 'mobile', 'contact']) {
      final value = (data[key] ?? '').toString().trim();
      if (value.isNotEmpty) return value;
    }
    return 'N/A';
  }

  List<_FacultyOption> _facultyForSelectedDepartment() {
    if (_selectedDepartment == null) return const [];
    return _facultyOptions
        .where((f) => f.department == _selectedDepartment)
        .toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  Future<void> _saveHodAssignment() async {
    final department = _selectedDepartment;
    final facultyId = _selectedFacultyId;

    if (department == null || department.isEmpty || facultyId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select both department and HOD.')),
      );
      return;
    }

    final selectedHod = _facultyById[facultyId];
    if (selectedHod == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selected HOD not found.')),
      );
      return;
    }

    final departmentFaculty =
        _facultyOptions.where((f) => f.department == department).toList();

    if (departmentFaculty.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No faculty found for this department.')),
      );
      return;
    }

    try {
      final batch = _firestore.batch();

      final assignmentRef =
          _firestore.collection('hodAssignments').doc(department);
      batch.set(
        assignmentRef,
        {
          'department': department,
          'hodFacultyId': selectedHod.id,
          'hodName': selectedHod.name,
          'hodEmail': selectedHod.email,
          'hodPhone': selectedHod.phone,
          'updatedAt': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      for (final faculty in departmentFaculty) {
        batch.update(faculty.reference, {
          'hodFacultyId': selectedHod.id,
          'hodName': selectedHod.name,
          'hodEmail': selectedHod.email,
          'hodPhone': selectedHod.phone,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('HOD assigned for $department: ${selectedHod.name}'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save HOD assignment: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('HOD Assignment'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadFaculty,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Assign HOD By Department',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Select a department and choose the faculty who should act as HOD.',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: Colors.grey.shade700),
                          ),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<String>(
                            decoration: const InputDecoration(
                              labelText: 'Department',
                              border: OutlineInputBorder(),
                            ),
                            initialValue: _selectedDepartment,
                            items: _departments
                                .map(
                                  (dept) => DropdownMenuItem<String>(
                                    value: dept,
                                    child: Text(dept),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              setState(() {
                                _selectedDepartment = value;
                                _selectedFacultyId = null;
                              });
                            },
                          ),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<String>(
                            decoration: const InputDecoration(
                              labelText: 'Select HOD',
                              border: OutlineInputBorder(),
                            ),
                            initialValue: _selectedFacultyId,
                            items: _facultyForSelectedDepartment()
                                .map(
                                  (f) => DropdownMenuItem<String>(
                                    value: f.id,
                                    child: Text('${f.name} (${f.id})'),
                                  ),
                                )
                                .toList(),
                            onChanged: _selectedDepartment == null
                                ? null
                                : (value) {
                                    setState(() {
                                      _selectedFacultyId = value;
                                    });
                                  },
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _saveHodAssignment,
                              icon: const Icon(Icons.save),
                              label: const Text('Save HOD Assignment'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: _firestore
                            .collection('hodAssignments')
                            .orderBy('department')
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 24),
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }

                          final docs = snapshot.data?.docs ?? const [];
                          if (docs.isEmpty) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              child: Text('No HOD assignments yet.'),
                            );
                          }

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Current HOD Assignments',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 12),
                              ...docs.map((doc) {
                                final d = doc.data();
                                final dept = (d['department'] ?? '').toString();
                                final hodName =
                                    (d['hodName'] ?? 'N/A').toString();
                                final hodEmail =
                                    (d['hodEmail'] ?? 'N/A').toString();
                                final hodPhone =
                                    (d['hodPhone'] ?? 'N/A').toString();
                                final hodFacultyId =
                                    (d['hodFacultyId'] ?? 'N/A').toString();

                                return ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: const CircleAvatar(
                                    child: Icon(Icons.person),
                                  ),
                                  title: Text('$dept - $hodName'),
                                  subtitle: Text(
                                    'ID: $hodFacultyId\nEmail: $hodEmail\nPhone: $hodPhone',
                                  ),
                                  isThreeLine: true,
                                );
                              }),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _FacultyOption {
  final String id;
  final String name;
  final String department;
  final String email;
  final String phone;
  final DocumentReference<Map<String, dynamic>> reference;

  const _FacultyOption({
    required this.id,
    required this.name,
    required this.department,
    required this.email,
    required this.phone,
    required this.reference,
  });
}
