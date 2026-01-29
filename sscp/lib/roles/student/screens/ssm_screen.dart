import 'package:flutter/material.dart';

class SSMScreen extends StatelessWidget {
  const SSMScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SSM'),
        backgroundColor: const Color(0xFF1e3a5f),
      ),
      body: const Center(
        child: Text('SSM Screen'),
      ),
    );
  }
}
