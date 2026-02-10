import 'package:flutter/material.dart';
import '../../screens/role_selection_screen.dart';

class FacultyHome extends StatelessWidget {
  const FacultyHome({super.key});

  static const String routeName = '/facultyHome';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Faculty Dashboard'),
        backgroundColor: Colors.green,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                  builder: (context) => const RoleSelectionScreen()),
            );
          },
        ),
      ),
      body: const Center(
        child: Text('Faculty Dashboard - Coming Soon'),
      ),
    );
  }
}
