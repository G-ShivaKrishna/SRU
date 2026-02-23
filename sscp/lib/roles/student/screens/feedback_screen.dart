import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../widgets/app_header.dart';
import '../../../services/feedback_service.dart';

class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  final FeedbackService _feedbackService = FeedbackService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isLoading = true;
  String? _error;
  bool _feedbackEnabled = false;
  Map<String, dynamic>? _activeSession;
  List<Map<String, dynamic>> _subjects = [];
  Map<String, dynamic>? _studentData;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Get student data
      final user = _auth.currentUser;
      if (user == null) throw Exception('Not logged in');

      final email = user.email ?? '';
      final rollNumber = email.split('@')[0].toUpperCase();
      final studentDoc =
          await _firestore.collection('students').doc(rollNumber).get();

      if (!studentDoc.exists) {
        throw Exception('Student data not found');
      }

      _studentData = studentDoc.data();
      final studentYear = _studentData?['year']?.toString() ?? '';
      final studentBranch =
          (_studentData?['department'] ?? '').toString().toUpperCase();
      final semester = _studentData?['semester']?.toString() ?? '';

      // Check if feedback is enabled
      _feedbackEnabled = await _feedbackService.isFeedbackEnabledForStudent(
        studentYear: studentYear,
        studentBranch: studentBranch,
      );

      if (_feedbackEnabled) {
        _activeSession = await _feedbackService.getActiveFeedbackSession();

        // Get subjects for feedback
        _subjects = await _feedbackService.getStudentFeedbackSubjects(
          studentId: rollNumber,
          studentYear: studentYear,
          studentBranch: studentBranch,
          semester: semester,
        );

        // Check which subjects already have feedback
        if (_activeSession != null) {
          for (int i = 0; i < _subjects.length; i++) {
            final hasSubmitted = await _feedbackService.hasSubmittedFeedback(
              studentId: rollNumber,
              subjectCode: _subjects[i]['subjectCode'],
              sessionId: _activeSession!['sessionId'],
            );
            _subjects[i]['submitted'] = hasSubmitted;
          }
        }
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Feedback'),
        backgroundColor: const Color(0xFF1e3a5f),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          const AppHeader(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? _buildErrorView()
                    : _buildContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'Error: $_error',
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _loadData,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    final isMobile = MediaQuery.of(context).size.width < 600;

    if (!_feedbackEnabled) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.feedback_outlined,
                size: 64,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              const Text(
                'Feedback Not Available',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1e3a5f),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Feedback session is not currently active for your year/branch.\nPlease check back later.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_subjects.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.class_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            const Text(
              'No subjects found for feedback',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Faculty Feedback',
            style: TextStyle(
              fontSize: isMobile ? 20 : 24,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1e3a5f),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Rate your faculty for each subject',
            style: TextStyle(
              fontSize: isMobile ? 12 : 14,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: _subjects.length,
              itemBuilder: (context, index) {
                return _buildSubjectCard(_subjects[index], isMobile);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubjectCard(Map<String, dynamic> subject, bool isMobile) {
    final submitted = subject['submitted'] ?? false;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        border: Border.all(
          color: submitted ? Colors.green : Colors.grey[300]!,
          width: submitted ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: submitted ? Colors.green : const Color(0xFF1e3a5f),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(7),
                topRight: Radius.circular(7),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        subject['subjectCode'] ?? '',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subject['subjectName'] ?? '',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                if (submitted)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green, size: 14),
                        SizedBox(width: 4),
                        Text(
                          'Submitted',
                          style: TextStyle(
                            color: Colors.green,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.person, size: 16, color: Colors.grey),
                    const SizedBox(width: 8),
                    Text(
                      'Faculty: ${subject['facultyName'] ?? 'Not Assigned'}',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          submitted ? Colors.grey : const Color(0xFF1e3a5f),
                    ),
                    onPressed: submitted
                        ? null
                        : () => _showFeedbackDialog(subject),
                    child: Text(
                      submitted ? 'Feedback Submitted' : 'Give Feedback',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showFeedbackDialog(Map<String, dynamic> subject) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _FeedbackFormDialog(
        subject: subject,
        sessionId: _activeSession?['sessionId'] ?? '',
        studentId: _studentData?['hallTicketNumber'] ??
            _auth.currentUser?.email?.split('@')[0].toUpperCase() ??
            '',
        feedbackService: _feedbackService,
      ),
    ).then((submitted) {
      if (submitted == true) {
        _loadData();
      }
    });
  }
}

class _FeedbackFormDialog extends StatefulWidget {
  final Map<String, dynamic> subject;
  final String sessionId;
  final String studentId;
  final FeedbackService feedbackService;

  const _FeedbackFormDialog({
    required this.subject,
    required this.sessionId,
    required this.studentId,
    required this.feedbackService,
  });

  @override
  State<_FeedbackFormDialog> createState() => _FeedbackFormDialogState();
}

class _FeedbackFormDialogState extends State<_FeedbackFormDialog> {
  final _commentsController = TextEditingController();
  final Map<String, int> _ratings = {};
  bool _isSubmitting = false;

  late final List<String> _categories;

  @override
  void initState() {
    super.initState();
    _categories = widget.feedbackService.getFeedbackCategories();
    // Initialize all ratings to 0 (not rated)
    for (final category in _categories) {
      _ratings[category] = 0;
    }
  }

  @override
  void dispose() {
    _commentsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Rate Faculty'),
          const SizedBox(height: 4),
          Text(
            '${widget.subject['subjectCode']} - ${widget.subject['subjectName']}',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.normal),
          ),
        ],
      ),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.85,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Faculty: ${widget.subject['facultyName']}',
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 16),
              const Divider(),
              ..._categories.map((category) => _buildRatingRow(category)),
              const SizedBox(height: 16),
              TextField(
                controller: _commentsController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Additional Comments (Optional)',
                  border: OutlineInputBorder(),
                  hintText: 'Share your thoughts...',
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _submitFeedback,
          child: _isSubmitting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Submit'),
        ),
      ],
    );
  }

  Widget _buildRatingRow(String category) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            category,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: List.generate(5, (index) {
              final rating = index + 1;
              return IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () {
                  setState(() {
                    _ratings[category] = rating;
                  });
                },
                icon: Icon(
                  rating <= (_ratings[category] ?? 0)
                      ? Icons.star
                      : Icons.star_border,
                  color: rating <= (_ratings[category] ?? 0)
                      ? Colors.amber
                      : Colors.grey,
                  size: 28,
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Future<void> _submitFeedback() async {
    // Validate all ratings are provided
    final unrated = _ratings.entries.where((e) => e.value == 0).toList();
    if (unrated.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please rate all categories: ${unrated.first.key}'),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await widget.feedbackService.submitFeedback(
        studentId: widget.studentId,
        sessionId: widget.sessionId,
        subjectCode: widget.subject['subjectCode'],
        subjectName: widget.subject['subjectName'],
        facultyId: widget.subject['facultyId'],
        ratings: _ratings,
        comments: _commentsController.text.trim(),
      );

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Feedback submitted successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() => _isSubmitting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }
}

