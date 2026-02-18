import 'package:flutter/material.dart';
import '../../../widgets/app_header.dart';

class FacultyFeedbackScreen extends StatelessWidget {
  const FacultyFeedbackScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Feedback'),
        backgroundColor: const Color(0xFF1e3a5f),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const AppHeader(),
            Padding(
              padding: EdgeInsets.all(isMobile ? 12 : 16),
              child: _buildFeedbackSummary(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeedbackSummary(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    final feedbackData = [
      {
        'course': '22CS301 - Design and Analysis of Algorithms',
        'section': 'A',
        'responses': '45',
        'avgRating': '4.5',
      },
      {
        'course': '22CS302 - Operating Systems',
        'section': 'B',
        'responses': '42',
        'avgRating': '4.3',
      },
      {
        'course': '22CS303 - DBMS',
        'section': 'A',
        'responses': '48',
        'avgRating': '4.6',
      },
    ];

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!, width: 1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(isMobile ? 12 : 14),
            decoration: BoxDecoration(
              color: const Color(0xFF1e3a5f),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(7),
                topRight: Radius.circular(7),
              ),
            ),
            child: Text(
              'Student Feedback Summary',
              style: TextStyle(
                color: Colors.white,
                fontSize: isMobile ? 13 : 15,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(isMobile ? 12 : 14),
            child: Column(
              children: feedbackData.asMap().entries.map((entry) {
                int index = entry.key;
                Map<String, String> feedback = entry.value;

                return Column(
                  children: [
                    if (index > 0) Divider(color: Colors.grey[300], height: 16),
                    _buildFeedbackCard(feedback, isMobile),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeedbackCard(Map<String, String> feedback, bool isMobile) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            feedback['course']!,
            style: TextStyle(
              fontSize: isMobile ? 12 : 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Section: ${feedback['section']}',
                style: TextStyle(
                  fontSize: isMobile ? 11 : 12,
                  color: Colors.grey[600],
                ),
              ),
              Text(
                'Responses: ${feedback['responses']}',
                style: TextStyle(
                  fontSize: isMobile ? 11 : 12,
                  color: Colors.grey[600],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.star, color: Colors.white, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      feedback['avgRating']!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
