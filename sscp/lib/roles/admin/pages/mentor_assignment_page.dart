import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MentorAssignmentPage extends StatefulWidget {
  const MentorAssignmentPage({super.key});

  @override
  State<MentorAssignmentPage> createState() => _MentorAssignmentPageState();
}

class _MentorAssignmentPageState extends State<MentorAssignmentPage> {
  String? selectedBatch;
  String? selectedFaculty;
  int? selectedYear;
  String? editingDocId;
  List<String> batches = [];
  List<String> faculties = [];
  Map<int, List<String>> batchesByYear = {};
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      // Get batches grouped by year from students collection
      final studentSnap = await FirebaseFirestore.instance.collection('students').get();
      final tempBatchesByYear = <int, Set<String>>{};
      
      for (var doc in studentSnap.docs) {
        final data = doc.data();
        final batchNum = data['batchNumber']?.toString();
        final year = data['year'];
        
        if (batchNum != null && batchNum.isNotEmpty && year != null) {
          final yearInt = year is int ? year : int.tryParse(year.toString());
          if (yearInt != null) {
            tempBatchesByYear.putIfAbsent(yearInt, () => <String>{});
            tempBatchesByYear[yearInt]!.add(batchNum);
          }
        }
      }

      // Convert to sorted lists
      final sortedBatchesByYear = <int, List<String>>{};
      for (var entry in tempBatchesByYear.entries) {
        sortedBatchesByYear[entry.key] = entry.value.toList()..sort();
      }

      // Get faculty names from faculty collection
      final facultySnap = await FirebaseFirestore.instance.collection('faculty').get();
      final facultyList = facultySnap.docs
          .map((doc) => doc.data()['name']?.toString() ?? '')
          .where((val) => val.isNotEmpty)
          .toList();

      setState(() {
        batchesByYear = sortedBatchesByYear;
        faculties = facultyList..sort();
        isLoading = false;
      });
    } catch (e) {
      setState(() { 
        batchesByYear = {};
        faculties = [];
        isLoading = false; 
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: $e')),
        );
      }
    }
  }

  Future<void> _saveAssignment(int year, String batchNumber, String facultyName) async {
    try {
      if (editingDocId != null) {
        // Update existing assignment
        await FirebaseFirestore.instance
            .collection('mentorAssignments')
            .doc(editingDocId!)
            .update({
          'facultyName': facultyName,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        // Check if assignment already exists for this year+batch combination
        final existingSnap = await FirebaseFirestore.instance
            .collection('mentorAssignments')
            .where('year', isEqualTo: year)
            .where('batchNumber', isEqualTo: batchNumber)
            .limit(1)
            .get();

        if (existingSnap.docs.isNotEmpty) {
          // Update existing assignment
          await existingSnap.docs.first.reference.update({
            'facultyName': facultyName,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        } else {
          // Create new assignment
          await FirebaseFirestore.instance
              .collection('mentorAssignments')
              .add({
            'year': year,
            'batchNumber': batchNumber,
            'facultyName': facultyName,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Mentor "$facultyName" assigned to Year $year - Batch $batchNumber successfully!'),
            duration: const Duration(seconds: 2),
          ),
        );
        // Clear selections
        setState(() {
          selectedYear = null;
          selectedBatch = null;
          selectedFaculty = null;
          editingDocId = null;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving assignment: $e')),
        );
      }
    }
  }

  Future<void> _deleteAssignment(String docId) async {
    try {
      await FirebaseFirestore.instance
          .collection('mentorAssignments')
          .doc(docId)
          .delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Assignment deleted successfully!'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting assignment: $e')),
        );
      }
    }
  }

  void _editAssignment(String docId, int year, String batchNumber, String facultyName) {
    setState(() {
      editingDocId = docId;
      selectedYear = year;
      selectedBatch = batchNumber;
      selectedFaculty = facultyName;
    });
  }

  void _cancelEdit() {
    setState(() {
      editingDocId = null;
      selectedYear = null;
      selectedBatch = null;
      selectedFaculty = null;
    });
  }

  @override
  Widget build(BuildContext context) {
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
                    // Assignment Form
                    Card(
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              editingDocId != null ? 'Edit Mentor Assignment' : 'Create New Assignment',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 16),
                            
                            // Year Dropdown
                            DropdownButtonFormField<int>(
                              decoration: const InputDecoration(
                                labelText: 'Select Year',
                                border: OutlineInputBorder(),
                              ),
                              initialValue: selectedYear,
                              items: batchesByYear.keys.isEmpty
                                  ? [
                                      const DropdownMenuItem(
                                        value: null,
                                        child: Text('No years available'),
                                      )
                                    ]
                                  : (batchesByYear.keys.toList()..sort())
                                      .map((year) {
                                        return DropdownMenuItem(
                                          value: year,
                                          child: Text('Year $year'),
                                        );
                                      }).toList(),
                              onChanged: batchesByYear.keys.isEmpty
                                  ? null
                                  : (val) {
                                      setState(() {
                                        selectedYear = val;
                                        selectedBatch = null; // Reset batch when year changes
                                      });
                                    },
                            ),
                            const SizedBox(height: 16),
                            
                            // Batch Dropdown (filtered by selected year)
                            DropdownButtonFormField<String>(
                              decoration: const InputDecoration(
                                labelText: 'Select Batch',
                                border: OutlineInputBorder(),
                              ),
                              initialValue: selectedBatch,
                              items: selectedYear != null && batchesByYear[selectedYear] != null && batchesByYear[selectedYear]!.isNotEmpty
                                  ? batchesByYear[selectedYear]!
                                      .map((batch) => DropdownMenuItem(
                                            value: batch,
                                            child: Text(batch),
                                          ))
                                      .toList()
                                  : [
                                      const DropdownMenuItem(
                                        value: null,
                                        child: Text('Select year first'),
                                      )
                                    ],
                              onChanged: selectedYear != null && batchesByYear[selectedYear] != null
                                  ? (val) => setState(() => selectedBatch = val)
                                  : null,
                            ),
                            const SizedBox(height: 16),
                            DropdownButtonFormField<String>(
                              decoration: const InputDecoration(
                                labelText: 'Select Faculty',
                                border: OutlineInputBorder(),
                              ),
                              initialValue: selectedFaculty,
                              items: faculties.isNotEmpty
                                  ? faculties
                                      .map((faculty) => DropdownMenuItem(
                                            value: faculty,
                                            child: Text(faculty),
                                          ))
                                      .toList()
                                  : [
                                      const DropdownMenuItem(
                                        value: null,
                                        child: Text('No faculties found'),
                                      )
                                    ],
                              onChanged: faculties.isNotEmpty
                                  ? (val) => setState(() => selectedFaculty = val)
                                  : null,
                            ),
                            const SizedBox(height: 24),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: selectedYear != null &&
                                            selectedBatch != null &&
                                            selectedFaculty != null &&
                                            faculties.isNotEmpty
                                        ? () {
                                            _saveAssignment(
                                                selectedYear!, selectedBatch!, selectedFaculty!);
                                          }
                                        : null,
                                    child: Text(editingDocId != null
                                        ? 'Update Assignment'
                                        : 'Assign Mentor'),
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
                                ]
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    // List of Assigned Mentors
                    Text(
                      'Assigned Mentors',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('mentorAssignments')
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                              child: CircularProgressIndicator());
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
                            final data = assignment.data() as Map<String, dynamic>;
                            final year = data['year'] ?? 'N/A';
                            final batchNumber = data['batchNumber'] ?? '';
                            final facultyName = data['facultyName'] ?? '';
                            final docId = assignment.id;

                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: ListTile(
                                title: Text('Year $year - Batch $batchNumber'),
                                subtitle: Text('Mentor: $facultyName'),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit),
                                      color: Colors.blue,
                                      onPressed: () {
                                        final yearInt = year is int ? year : int.tryParse(year.toString()) ?? 1;
                                        _editAssignment(docId, yearInt, batchNumber, facultyName);
                                        // Scroll to top to see form
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
                                        showDialog(
                                          context: context,
                                          builder: (BuildContext dialogContext) {
                                            return AlertDialog(
                                              title: const Text('Delete Assignment'),
                                              content: Text(
                                                  'Are you sure you want to delete the assignment of Year $year - Batch $batchNumber from mentor $facultyName?'),
                                              actions: [
                                                TextButton(
                                                  onPressed: () {
                                                    Navigator.pop(
                                                        dialogContext);
                                                  },
                                                  child: const Text('Cancel'),
                                                ),
                                                TextButton(
                                                  onPressed: () {
                                                    Navigator.pop(
                                                        dialogContext);
                                                    _deleteAssignment(docId);
                                                  },
                                                  child: const Text('Delete',
                                                      style: TextStyle(
                                                          color: Colors.red)),
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
