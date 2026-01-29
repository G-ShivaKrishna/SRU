import 'package:flutter/material.dart';

class UniversityClubsScreen extends StatelessWidget {
  const UniversityClubsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('University Clubs'),
        backgroundColor: const Color(0xFF1e3a5f),
      ),
      body: const Center(
        child: Text('University Clubs Screen'),
      ),
    );
  }
}
