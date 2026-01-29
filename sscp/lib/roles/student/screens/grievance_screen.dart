import 'package:flutter/material.dart';

class GrievanceScreen extends StatelessWidget {
  const GrievanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Grievance'),
        backgroundColor: const Color(0xFF1e3a5f),
      ),
      body: const Center(
        child: Text('Grievance Screen'),
      ),
    );
  }
}
