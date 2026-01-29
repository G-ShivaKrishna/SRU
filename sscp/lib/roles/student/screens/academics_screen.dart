import 'package:flutter/material.dart';

class AcademicsScreen extends StatelessWidget {
  const AcademicsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Academics'),
        backgroundColor: const Color(0xFF1e3a5f),
      ),
      body: const Center(
        child: Text('Academics Screen'),
      ),
    );
  }
}
