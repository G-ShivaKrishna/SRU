import 'package:flutter/material.dart';

class MentorStudentAccessScreen extends StatelessWidget {
  final List<Map<String, String>> students;

  const MentorStudentAccessScreen({super.key, required this.students});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mentor: Student Details'),
      ),
      body: ListView.builder(
        itemCount: students.length,
        itemBuilder: (context, index) {
          final student = students[index];
          return Card(
            margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            child: ListTile(
              title: Text(student['name'] ?? ''),
              subtitle: Text('Roll: ${student['roll'] ?? ''}\nEmail: ${student['email'] ?? ''}'),
              trailing: IconButton(
                icon: const Icon(Icons.info_outline),
                onPressed: () {
                  // TODO: Show pin-to-pin details
                },
              ),
            ),
          );
        },
      ),
    );
  }
}
