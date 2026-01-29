import 'package:flutter/material.dart';

class CentralLibraryScreen extends StatelessWidget {
  const CentralLibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Central Library'),
        backgroundColor: const Color(0xFF1e3a5f),
      ),
      body: const Center(
        child: Text('Central Library Screen'),
      ),
    );
  }
}
