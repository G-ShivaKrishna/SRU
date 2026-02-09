import 'package:flutter/material.dart';
import '../../screens/role_selection_screen.dart';
import 'faculty_home.dart';

class FacultyLoginScreen extends StatelessWidget {
  const FacultyLoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Faculty Login'),
        backgroundColor: Colors.green,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => const RoleSelectionScreen()),
            );
          },
        ),
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => const FacultyHome()),
            );
          },
          child: const Text('Go to Faculty Dashboard (Demo)'),
        ),
      ),
    );
  }
}
