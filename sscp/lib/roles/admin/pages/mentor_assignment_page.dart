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
        await FirebaseFirestore.instance.collection('mentorAssignments').add({
          'batchNumber': batchNumber,
          'facultyName': facultyName,
          'createdAt': FieldValue.serverTimestamp(),
        });
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Assign Mentor to Batch'),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: 'Select Batch'),
                    value: selectedBatch,
                    items: batches.isNotEmpty
                        ? batches.map((batch) => DropdownMenuItem(
                            value: batch,
                            child: Text(batch),
                          )).toList()
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
                        ? faculties.map((faculty) => DropdownMenuItem(
                            value: faculty,
                            child: Text(faculty),
                          )).toList()
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
                  ElevatedButton(
                    onPressed: selectedBatch != null && selectedFaculty != null && batches.isNotEmpty && faculties.isNotEmpty
                        ? () {
                            _saveAssignment(selectedBatch!, selectedFaculty!);
                          }
                        : null,
                    child: const Text('Assign Mentor'),
                  ),
                ],
              ),
            ),
    );
  }
}
