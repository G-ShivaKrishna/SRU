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
  String? editingDocId;
  List<String> batches = [];
  List<String> faculties = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      // Get unique batch numbers from students collection
      final studentSnap = await FirebaseFirestore.instance.collection('students').get();
      final batchSet = <String>{};
      for (var doc in studentSnap.docs) {
        final batchNum = doc.data()['batchNumber']?.toString();
        if (batchNum != null && batchNum.isNotEmpty) {
          batchSet.add(batchNum);
        }
      }

      // Get faculty names from faculty collection (field is 'name', not 'facultyName')
      final facultySnap = await FirebaseFirestore.instance.collection('faculty').get();
      final facultyList = facultySnap.docs
          .map((doc) => doc.data()['name']?.toString() ?? '')
          .where((val) => val.isNotEmpty)
          .toList();

      setState(() {
        batches = batchSet.toList()..sort();
        faculties = facultyList..sort();
        isLoading = false;
      });
    } catch (e) {
      setState(() { isLoading = false; });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading data: $e')),
      );
    }
  }

  Future<void> _saveAssignment(String batchNumber, String facultyName) async {
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
        // Check if assignment already exists for this batch
        final existingSnap = await FirebaseFirestore.instance
            .collection('mentorAssignments')
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
                'Mentor "$facultyName" assigned to batch "$batchNumber" successfully!'),
            duration: const Duration(seconds: 2),
          ),
        );
        // Clear selections
        setState(() {
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

  void _editAssignment(String docId, String batchNumber, String facultyName) {
    setState(() {
      editingDocId = docId;
      selectedBatch = batchNumber;
      selectedFaculty = facultyName;
    });
  }

  void _cancelEdit() {
    setState(() {
      editingDocId = null;
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
                            DropdownButtonFormField<String>(
                              decoration: const InputDecoration(labelText: 'Select Batch'),
                              value: selectedBatch,
                              items: batches.isNotEmpty
                                  ? batches
                                      .map((batch) => DropdownMenuItem(
                                            value: batch,
                                            child: Text(batch),
                                          ))
                                      .toList()
                                  : [
                                      const DropdownMenuItem(
                                        value: null,
                                        child: Text('No batches found'),
                                      )
                                    ],
                              onChanged: batches.isNotEmpty
                                  ? (val) => setState(() => selectedBatch = val)
                                  : null,
                            ),
                            const SizedBox(height: 16),
                            DropdownButtonFormField<String>(
                              decoration: const InputDecoration(labelText: 'Select Faculty'),
                              value: selectedFaculty,
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
                                    onPressed: selectedBatch != null &&
                                            selectedFaculty != null &&
                                            batches.isNotEmpty &&
                                            faculties.isNotEmpty
                                        ? () {
                                            _saveAssignment(
                                                selectedBatch!, selectedFaculty!);
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
                            final batchNumber =
                                assignment['batchNumber'] ?? '';
                            final facultyName =
                                assignment['facultyName'] ?? '';
                            final docId = assignment.id;

                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: ListTile(
                                title: Text('Batch: $batchNumber'),
                                subtitle: Text('Mentor: $facultyName'),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit),
                                      color: Colors.blue,
                                      onPressed: () {
                                        _editAssignment(docId, batchNumber,
                                            facultyName);
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
                                                  'Are you sure you want to delete the assignment of Batch $batchNumber from mentor $facultyName?'),
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
