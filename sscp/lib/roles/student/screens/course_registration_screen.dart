import 'package:flutter/material.dart';

class CourseRegistrationScreen extends StatelessWidget {
  const CourseRegistrationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Course Registration'),
        backgroundColor: const Color(0xFF1e3a5f),
      ),
      body: const Center(
        child: Text('Course Registration Screen'),
      ),
    );
  }
}
