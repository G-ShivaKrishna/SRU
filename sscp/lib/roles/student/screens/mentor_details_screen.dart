import 'package:flutter/material.dart';
import '../../faculty/screens/mentor_student_access_screen.dart';

class MentorDetailsScreen extends StatelessWidget {
  final String mentorName;
  final String mentorEmail;
  final String mentorPhone;

  const MentorDetailsScreen({
    super.key,
    required this.mentorName,
    required this.mentorEmail,
    required this.mentorPhone,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mentor Details'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Name: $mentorName', style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 12),
            Text('Email: $mentorEmail', style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 12),
            Text('Phone: $mentorPhone', style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                // Example student list, replace with real data
                final students = [
                  {'name': 'Student A', 'roll': '2203A51318', 'email': 'a@sru.edu.in'},
                  {'name': 'Student B', 'roll': '2203A51319', 'email': 'b@sru.edu.in'},
                ];
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => MentorStudentAccessScreen(students: students),
                  ),
                );
              },
              child: const Text('View All Student Details'),
            ),
          ],
        ),
      ),
    );
  }
}
