import 'package:flutter/material.dart';
import '../../../widgets/app_header.dart';

class UniversityClubsScreen extends StatelessWidget {
  const UniversityClubsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('University Clubs'),
        backgroundColor: const Color(0xFF1e3a5f),
      ),
      body: Column(
        children: [
          const AppHeader(),
          const Expanded(
            child: Center(
              child: Text('University Clubs Screen'),
            ),
          ),
        ],
      ),
    );
  }
}
