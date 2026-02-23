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

  // You can change these to match your Firestore structure
  final String batchCollection = 'batch'; // or 'batches'
  final String batchField = 'name'; // or 'batchNumber'
  final String facultyCollection = 'faculty'; // not 'faculties'
  final String facultyField = 'facultyName'; // or 'name'

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      final batchSnap = await FirebaseFirestore.instance.collection(batchCollection).get();
      final facultySnap = await FirebaseFirestore.instance.collection(facultyCollection).get();
      setState(() {
        batches = batchSnap.docs
            .map((doc) => doc.data()[batchField]?.toString() ?? '')
            .where((val) => val.isNotEmpty)
            .toList();
        faculties = facultySnap.docs
            .map((doc) => doc.data()[facultyField]?.toString() ?? '')
            .where((val) => val.isNotEmpty)
            .toList();
        isLoading = false;
      });
    } catch (e) {
      setState(() { isLoading = false; });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading data: $e')),
      );
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
                            // TODO: Save assignment to backend
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Mentor assigned successfully!')),
                            );
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
