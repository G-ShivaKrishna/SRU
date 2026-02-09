import 'package:flutter/material.dart';
import '../../screens/role_selection_screen.dart';
import 'admin_home.dart';

class AdminLoginScreen extends StatelessWidget {
  const AdminLoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Login'),
        backgroundColor: Colors.red,
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
              MaterialPageRoute(builder: (context) => const AdminHome()),
            );
          },
          child: const Text('Go to Admin Dashboard (Demo)'),
        ),
      ),
    );
  }
}