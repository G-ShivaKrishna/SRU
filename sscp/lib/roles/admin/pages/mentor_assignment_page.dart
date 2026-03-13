import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

const int _mentorBatchLimit = 2;

class MentorAssignmentPage extends StatefulWidget {
  const MentorAssignmentPage({super.key});

  @override
  State<MentorAssignmentPage> createState() => _MentorAssignmentPageState();
}

class _MentorAssignmentPageState extends State<MentorAssignmentPage> {
  Set<String> selectedBatches = {};
  String? selectedDepartment;
  String? selectedFacultyId;
  int? selectedYear;
  String? editingDocId;
  List<_FacultyOption> faculties = [];
  Map<int, Map<String, List<String>>> batchesByYearAndDepartment = {};
  Map<String, int> facultyAssignmentCounts = {};
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    if (mounted) {
      setState(() => isLoading = true);
    }

    try {
      final results = await Future.wait<dynamic>([
        FirebaseFirestore.instance.collection('students').get(),
        FirebaseFirestore.instance.collection('faculty').get(),
        FirebaseFirestore.instance.collection('mentorAssignments').get(),
      ]);

      final studentSnap = results[0] as QuerySnapshot<Map<String, dynamic>>;
      final facultySnap = results[1] as QuerySnapshot<Map<String, dynamic>>;
      final mentorAssignmentSnap =
          results[2] as QuerySnapshot<Map<String, dynamic>>;

      final tempBatchesByYearAndDepartment = <int, Map<String, Set<String>>>{};
      for (final doc in studentSnap.docs) {
        final data = doc.data();
        final batchNumber = (data['batchNumber'] ?? '').toString().trim();
        final department =
            (data['department'] ?? '').toString().trim().toUpperCase();
        final year = _parseInt(data['year']);

        if (batchNumber.isEmpty || department.isEmpty || year == null) {
          continue;
        }

        tempBatchesByYearAndDepartment.putIfAbsent(
          year,
          () => <String, Set<String>>{},
        );
        tempBatchesByYearAndDepartment[year]!
            .putIfAbsent(department, () => <String>{});
        tempBatchesByYearAndDepartment[year]![department]!.add(batchNumber);
      }

      final sortedBatchesByYearAndDepartment =
          <int, Map<String, List<String>>>{};
      for (final yearEntry in tempBatchesByYearAndDepartment.entries) {
        final batchesByDepartment = <String, List<String>>{};
        final departmentEntries = yearEntry.value.entries.toList()
          ..sort((a, b) => a.key.compareTo(b.key));
        for (final departmentEntry in departmentEntries) {
          batchesByDepartment[departmentEntry.key] =
              departmentEntry.value.toList()..sort();
        }
        sortedBatchesByYearAndDepartment[yearEntry.key] = batchesByDepartment;
      }

      final facultyOptions = facultySnap.docs
          .map(
            (doc) => _FacultyOption(
              id: doc.id.trim().toUpperCase(),
              name: (doc.data()['name'] ?? '').toString().trim(),
              email: (doc.data()['email'] ?? '').toString().trim(),
            ),
          )
          .where((faculty) => faculty.name.isNotEmpty)
          .toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

      final countsById = <String, int>{};
      final countsByName = <String, int>{};
      for (final doc in mentorAssignmentSnap.docs) {
        final data = doc.data();
        final facultyId = _normalizeValue(data['facultyId']);
        final facultyName = _normalizeValue(data['facultyName']);

        if (facultyId.isNotEmpty) {
          countsById[facultyId] = (countsById[facultyId] ?? 0) + 1;
        } else if (facultyName.isNotEmpty) {
          countsByName[facultyName] = (countsByName[facultyName] ?? 0) + 1;
        }
      }

      final nextFacultyAssignmentCounts = <String, int>{};
      for (final faculty in facultyOptions) {
        nextFacultyAssignmentCounts[faculty.id] = countsById[faculty.id] ??
            countsByName[_normalizeValue(faculty.name)] ??
            0;
      }

      if (!mounted) {
        return;
      }

      setState(() {
        batchesByYearAndDepartment = sortedBatchesByYearAndDepartment;
        faculties = facultyOptions;
        facultyAssignmentCounts = nextFacultyAssignmentCounts;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        batchesByYearAndDepartment = {};
        faculties = [];
        facultyAssignmentCounts = {};
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading data: $e')),
      );
    }
  }

  Future<void> _saveAssignment(
    int year,
    String department,
    Set<String> batches,
    _FacultyOption faculty,
  ) async {
    try {
      final mentorAssignmentsCol =
          FirebaseFirestore.instance.collection('mentorAssignments');

      if (editingDocId != null) {
        // Edit mode — single batch update
        final batchNumber = batches.first;
        final existingCount = await _countAssignmentsForFaculty(
          faculty,
          ignoreDocId: editingDocId,
        );
        if (existingCount >= _mentorBatchLimit) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Mentor "${faculty.name}" already has $_mentorBatchLimit batch assignments. Remove one before assigning another batch.',
              ),
            ),
          );
          return;
        }
        await mentorAssignmentsCol.doc(editingDocId!).update({
          'year': year,
          'department': department,
          'batchNumber': batchNumber,
          'facultyId': faculty.id,
          'facultyName': faculty.name,
          'facultyEmail': faculty.email,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        // Create mode — assign all selected batches
        final existingCount = await _countAssignmentsForFaculty(faculty);
        if (existingCount + batches.length > _mentorBatchLimit) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Cannot assign ${batches.length} batch(es). Mentor "${faculty.name}" has $existingCount/$_mentorBatchLimit batches assigned.',
              ),
            ),
          );
          return;
        }
        for (final batchNumber in batches) {
          final existingSnap = await mentorAssignmentsCol
              .where('year', isEqualTo: year)
              .where('department', isEqualTo: department)
              .where('batchNumber', isEqualTo: batchNumber)
              .limit(1)
              .get();
          final payload = <String, dynamic>{
            'year': year,
            'department': department,
            'batchNumber': batchNumber,
            'facultyId': faculty.id,
            'facultyName': faculty.name,
            'facultyEmail': faculty.email,
            'updatedAt': FieldValue.serverTimestamp(),
          };
          if (existingSnap.docs.isNotEmpty) {
            await existingSnap.docs.first.reference.update(payload);
          } else {
            await mentorAssignmentsCol.add({
              ...payload,
              'createdAt': FieldValue.serverTimestamp(),
            });
          }
        }
      }

      await _fetchData();
      if (!mounted) return;

      final batchLabel = batches.join(', ');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Mentor "${faculty.name}" assigned to Year $year - $department - Batch(es) $batchLabel successfully.',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
      setState(() {
        selectedYear = null;
        selectedDepartment = null;
        selectedBatches = {};
        selectedFacultyId = null;
        editingDocId = null;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving assignment: $e')),
      );
    }
  }

  Future<int> _countAssignmentsForFaculty(
    _FacultyOption faculty, {
    String? ignoreDocId,
  }) async {
    final snap =
        await FirebaseFirestore.instance.collection('mentorAssignments').get();

    var count = 0;
    for (final doc in snap.docs) {
      if (doc.id == ignoreDocId) {
        continue;
      }

      if (_assignmentMatchesFaculty(doc.data(), faculty)) {
        count++;
      }
    }
    return count;
  }

  bool _assignmentMatchesFaculty(
    Map<String, dynamic> data,
    _FacultyOption faculty,
  ) {
    final assignmentFacultyId = _normalizeValue(data['facultyId']);
    if (assignmentFacultyId.isNotEmpty) {
      return assignmentFacultyId == faculty.id;
    }

    return _normalizeValue(data['facultyName']) ==
        _normalizeValue(faculty.name);
  }

  Future<void> _deleteAssignment(String docId) async {
    try {
      await FirebaseFirestore.instance
          .collection('mentorAssignments')
          .doc(docId)
          .delete();
      await _fetchData();

      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Assignment deleted successfully!'),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting assignment: $e')),
      );
    }
  }

  void _editAssignment(
    String docId,
    int year,
    String department,
    String batchNumber,
    String facultyName, {
    String? facultyId,
  }) {
    setState(() {
      editingDocId = docId;
      selectedYear = year;
      selectedDepartment = department.trim().toUpperCase();
      selectedBatches = {batchNumber};
      selectedFacultyId = _resolveFacultySelectionId(facultyId, facultyName);
    });
  }

  void _cancelEdit() {
    setState(() {
      editingDocId = null;
      selectedYear = null;
      selectedDepartment = null;
      selectedBatches = {};
      selectedFacultyId = null;
    });
  }

  List<String> _availableDepartmentsForSelectedYear() {
    if (selectedYear == null) {
      return const [];
    }
    return (batchesByYearAndDepartment[selectedYear] ??
            const <String, List<String>>{})
        .keys
        .toList()
      ..sort();
  }

  List<String> _availableBatchesForSelectedScope() {
    if (selectedYear == null || selectedDepartment == null) {
      return const [];
    }
    return batchesByYearAndDepartment[selectedYear]?[selectedDepartment!] ??
        const [];
  }

  _FacultyOption? _findFacultyById(String? facultyId) {
    if (facultyId == null || facultyId.trim().isEmpty) {
      return null;
    }

    final normalizedFacultyId = facultyId.trim().toUpperCase();
    for (final faculty in faculties) {
      if (faculty.id == normalizedFacultyId) {
        return faculty;
      }
    }
    return null;
  }

  String? _resolveFacultySelectionId(String? facultyId, String facultyName) {
    final exactMatch = _findFacultyById(facultyId);
    if (exactMatch != null) {
      return exactMatch.id;
    }

    final normalizedFacultyName = _normalizeValue(facultyName);
    for (final faculty in faculties) {
      if (_normalizeValue(faculty.name) == normalizedFacultyName) {
        return faculty.id;
      }
    }
    return null;
  }

  int _assignmentCountFor(String? facultyId, String facultyName) {
    final exactMatch = _findFacultyById(facultyId);
    if (exactMatch != null) {
      return facultyAssignmentCounts[exactMatch.id] ?? 0;
    }

    final normalizedFacultyName = _normalizeValue(facultyName);
    for (final faculty in faculties) {
      if (_normalizeValue(faculty.name) == normalizedFacultyName) {
        return facultyAssignmentCounts[faculty.id] ?? 0;
      }
    }
    return 0;
  }

  String _normalizeValue(Object? value) {
    return value?.toString().trim().toUpperCase() ?? '';
  }

  int? _parseInt(Object? value) {
    if (value is int) {
      return value;
    }
    return int.tryParse(value?.toString() ?? '');
  }

  @override
  Widget build(BuildContext context) {
    final selectedFaculty = _findFacultyById(selectedFacultyId);
    final selectedFacultyLoad = selectedFaculty == null
        ? null
        : facultyAssignmentCounts[selectedFaculty.id] ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Assign Mentor to Batch'),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Card(
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              editingDocId != null
                                  ? 'Edit Mentor Assignment'
                                  : 'Create New Assignment',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Each mentor can be assigned to at most $_mentorBatchLimit batches.',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: Colors.grey.shade700),
                            ),
                            const SizedBox(height: 16),
                            DropdownButtonFormField<int>(
                              decoration: const InputDecoration(
                                labelText: 'Select Year',
                                border: OutlineInputBorder(),
                              ),
                              initialValue: selectedYear,
                              items: (batchesByYearAndDepartment.keys.toList()
                                    ..sort())
                                  .map(
                                    (year) => DropdownMenuItem<int>(
                                      value: year,
                                      child: Text('Year $year'),
                                    ),
                                  )
                                  .toList(),
                              onChanged: batchesByYearAndDepartment.isEmpty
                                  ? null
                                  : (value) {
                                      setState(() {
                                        selectedYear = value;
                                        selectedDepartment = null;
                                        selectedBatches = {};
                                      });
                                    },
                            ),
                            const SizedBox(height: 16),
                            DropdownButtonFormField<String>(
                              decoration: const InputDecoration(
                                labelText: 'Select Branch',
                                border: OutlineInputBorder(),
                              ),
                              initialValue: selectedDepartment,
                              items: _availableDepartmentsForSelectedYear()
                                  .map(
                                    (department) => DropdownMenuItem<String>(
                                      value: department,
                                      child: Text(department),
                                    ),
                                  )
                                  .toList(),
                              onChanged: selectedYear != null
                                  ? (value) {
                                      setState(() {
                                        selectedDepartment = value;
                                        selectedBatches = {};
                                      });
                                    }
                                  : null,
                            ),
                            const SizedBox(height: 16),
                            InputDecorator(
                              decoration: InputDecoration(
                                labelText: editingDocId != null
                                    ? 'Select Batch'
                                    : 'Select Batch(es) — up to $_mentorBatchLimit',
                                border: const OutlineInputBorder(),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                              ),
                              child: _availableBatchesForSelectedScope().isEmpty
                                  ? Text(
                                      selectedDepartment == null
                                          ? 'Select a branch first'
                                          : 'No batches available',
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                      ),
                                    )
                                  : Wrap(
                                      spacing: 8,
                                      runSpacing: 4,
                                      children:
                                          _availableBatchesForSelectedScope()
                                              .map(
                                        (batch) {
                                          final isSelected =
                                              selectedBatches.contains(batch);
                                          final maxReached =
                                              selectedBatches.length >=
                                                  (editingDocId != null
                                                      ? 1
                                                      : _mentorBatchLimit);
                                          return FilterChip(
                                            label: Text(batch),
                                            selected: isSelected,
                                            onSelected:
                                                selectedDepartment != null
                                                    ? (value) {
                                                        setState(() {
                                                          if (value &&
                                                              !maxReached) {
                                                            selectedBatches = {
                                                              ...selectedBatches,
                                                              batch,
                                                            };
                                                          } else if (!value) {
                                                            selectedBatches =
                                                                Set<String>.from(
                                                              selectedBatches,
                                                            )..remove(batch);
                                                          }
                                                        });
                                                      }
                                                    : null,
                                          );
                                        },
                                      ).toList(),
                                    ),
                            ),
                            const SizedBox(height: 16),
                            DropdownButtonFormField<String>(
                              decoration: const InputDecoration(
                                labelText: 'Select Faculty',
                                border: OutlineInputBorder(),
                              ),
                              initialValue: selectedFacultyId,
                              items: faculties
                                  .map(
                                    (faculty) => DropdownMenuItem<String>(
                                      value: faculty.id,
                                      child: Text(
                                        '${faculty.name}  (${facultyAssignmentCounts[faculty.id] ?? 0}/$_mentorBatchLimit)',
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: faculties.isEmpty
                                  ? null
                                  : (value) =>
                                      setState(() => selectedFacultyId = value),
                            ),
                            if (selectedFacultyLoad != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                selectedFacultyLoad >= _mentorBatchLimit
                                    ? 'This mentor is already at capacity ($_mentorBatchLimit/$_mentorBatchLimit batches).'
                                    : 'Current load: $selectedFacultyLoad/$_mentorBatchLimit batches.',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: selectedFacultyLoad >=
                                              _mentorBatchLimit
                                          ? Colors.orange.shade800
                                          : Colors.grey.shade700,
                                    ),
                              ),
                            ],
                            const SizedBox(height: 24),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: selectedYear != null &&
                                            selectedDepartment != null &&
                                            selectedBatches.isNotEmpty &&
                                            selectedFaculty != null
                                        ? () => _saveAssignment(
                                              selectedYear!,
                                              selectedDepartment!,
                                              selectedBatches,
                                              selectedFaculty,
                                            )
                                        : null,
                                    child: Text(
                                      editingDocId != null
                                          ? 'Update Assignment'
                                          : 'Assign Mentor',
                                    ),
                                  ),
                                ),
                                if (editingDocId != null) ...[
                                  const SizedBox(width: 12),
                                  ElevatedButton(
                                    onPressed: _cancelEdit,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.grey,
                                    ),
                                    child: const Text('Cancel'),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      'Assigned Mentors',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: FirebaseFirestore.instance
                          .collection('mentorAssignments')
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                          return const Center(
                            child: Text('No mentor assignments yet'),
                          );
                        }

                        final assignments = snapshot.data!.docs;
                        return ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: assignments.length,
                          itemBuilder: (context, index) {
                            final assignment = assignments[index];
                            final data = assignment.data();
                            final year = data['year'] ?? 'N/A';
                            final department = (data['department'] ?? '')
                                .toString()
                                .trim()
                                .toUpperCase();
                            final batchNumber =
                                (data['batchNumber'] ?? '').toString();
                            final facultyName =
                                (data['facultyName'] ?? '').toString();
                            final facultyId = data['facultyId']?.toString();
                            final docId = assignment.id;
                            final assignmentCount =
                                _assignmentCountFor(facultyId, facultyName);

                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: ListTile(
                                title: Text(
                                  department.isEmpty
                                      ? 'Year $year - Batch $batchNumber'
                                      : 'Year $year - $department - Batch $batchNumber',
                                ),
                                subtitle: Text(
                                  'Mentor: $facultyName  •  Load: $assignmentCount/$_mentorBatchLimit batches',
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit),
                                      color: Colors.blue,
                                      onPressed: () {
                                        final yearInt = year is int
                                            ? year
                                            : int.tryParse(year.toString()) ??
                                                1;
                                        _editAssignment(
                                          docId,
                                          yearInt,
                                          department,
                                          batchNumber,
                                          facultyName,
                                          facultyId: facultyId,
                                        );
                                        Scrollable.ensureVisible(
                                          context,
                                          alignment: 0.0,
                                          duration:
                                              const Duration(milliseconds: 300),
                                        );
                                      },
                                      tooltip: 'Edit',
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete),
                                      color: Colors.red,
                                      onPressed: () {
                                        showDialog<void>(
                                          context: context,
                                          builder: (dialogContext) {
                                            return AlertDialog(
                                              title: const Text(
                                                  'Delete Assignment'),
                                              content: Text(
                                                department.isEmpty
                                                    ? 'Are you sure you want to delete the assignment of Year $year - Batch $batchNumber from mentor $facultyName?'
                                                    : 'Are you sure you want to delete the assignment of Year $year - $department - Batch $batchNumber from mentor $facultyName?',
                                              ),
                                              actions: [
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.pop(
                                                          dialogContext),
                                                  child: const Text('Cancel'),
                                                ),
                                                TextButton(
                                                  onPressed: () {
                                                    Navigator.pop(
                                                        dialogContext);
                                                    _deleteAssignment(docId);
                                                  },
                                                  child: const Text(
                                                    'Delete',
                                                    style: TextStyle(
                                                      color: Colors.red,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            );
                                          },
                                        );
                                      },
                                      tooltip: 'Delete',
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _FacultyOption {
  const _FacultyOption({
    required this.id,
    required this.name,
    required this.email,
  });

  final String id;
  final String name;
  final String email;
}
