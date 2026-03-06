import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../services/user_service.dart';
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

  // Current subject index for step-by-step flow
  int _currentIndex = 0;

  // Rating state for current subject
  final Map<String, int> _ratings = {};
  final TextEditingController _commentsController = TextEditingController();
  bool _isSubmitting = false;

  late final List<String> _categories;

  @override
  void initState() {
    super.initState();
    _categories = _feedbackService.getFeedbackCategories();
    _initializeRatings();
    _loadData();
  }

  @override
  void dispose() {
    _commentsController.dispose();
    super.dispose();
  }

  void _initializeRatings() {
    _ratings.clear();
    for (final category in _categories) {
      _ratings[category] = 0;
    }
    _commentsController.clear();
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
      final rollNumber = UserService.getCurrentUserId() ?? email.split('@')[0].toUpperCase();
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

        // Sort: assigned faculty subjects first (alphabetically), then unassigned
        _subjects.sort((a, b) {
          final aAssigned = (a['facultyName'] != null && a['facultyName'] != '' && a['facultyName'] != 'Not Assigned');
          final bAssigned = (b['facultyName'] != null && b['facultyName'] != '' && b['facultyName'] != 'Not Assigned');
          if (aAssigned && !bAssigned) return -1;
          if (!aAssigned && bAssigned) return 1;
          // Both assigned or both unassigned: sort by subjectName
          return (a['subjectName'] ?? '').toString().compareTo((b['subjectName'] ?? '').toString());
        });

        // Only allow feedback for assigned faculty subjects
        // Find the first unsubmitted and assigned subject
        _currentIndex = _subjects.indexWhere((s) =>
          s['submitted'] != true &&
          s['facultyName'] != null &&
          s['facultyName'] != '' &&
          s['facultyName'] != 'Not Assigned');
        if (_currentIndex == -1) {
          _currentIndex = _subjects.length; // All completed or none assigned
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

    // All subjects completed
    if (_currentIndex >= _subjects.length) {
      return _buildCompletionView();
    }

    return _buildFeedbackForm();
  }

  Widget _buildCompletionView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check_circle,
                size: 80,
                color: Colors.green.shade600,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'All Feedback Submitted!',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1e3a5f),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Thank you for providing feedback for all ${_subjects.length} subjects.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 32),
            OutlinedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Back to Home'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeedbackForm() {
    // Guard: If index is out of range, show completion view or empty
    if (_subjects.isEmpty || _currentIndex < 0 || _currentIndex >= _subjects.length) {
      return const SizedBox.shrink();
    }
    final subject = _subjects[_currentIndex];
    final isMobile = MediaQuery.of(context).size.width < 600;

    final assigned = subject['facultyName'] != null && subject['facultyName'] != '' && subject['facultyName'] != 'Not Assigned';

    if (!assigned) {
      // Show message if faculty not assigned
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.info_outline, size: 64, color: Colors.orange[300]),
              const SizedBox(height: 16),
              Text(
                subject['subjectName'] ?? '',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1e3a5f)),
              ),
              const SizedBox(height: 8),
              const Text(
                'Faculty not assigned for this subject.',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _skipSubject,
                icon: const Icon(Icons.arrow_forward),
                label: const Text('Next Subject'),
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Progress indicator
          _buildProgressIndicator(),
          const SizedBox(height: 20),

          // Subject header
          _buildSubjectHeader(subject),
          const SizedBox(height: 24),

          // Rating categories
          ..._categories.map((category) => _buildRatingRow(category)),

          const SizedBox(height: 20),

          // Comments field
          TextField(
            controller: _commentsController,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: 'Additional Comments (Optional)',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              hintText: 'Share your thoughts...',
            ),
          ),

          const SizedBox(height: 24),

          // Submit button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1e3a5f),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: _isSubmitting ? null : _submitFeedback,
              child: _isSubmitting
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(
                      _currentIndex < _subjects.length - 1
                          ? 'Submit & Next'
                          : 'Submit Feedback',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),

          const SizedBox(height: 12),

          // Skip button (optional)
          if (_currentIndex < _subjects.length - 1)
            Center(
              child: TextButton(
                onPressed: _skipSubject,
                child: Text(
                  'Skip this subject',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator() {
    final totalPending =
        _subjects.where((s) => s['submitted'] != true).length;
    final completed = _subjects.length - totalPending;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Subject ${_currentIndex + 1} of ${_subjects.length}',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF1e3a5f),
              ),
            ),
            Text(
              '$completed completed',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: (_currentIndex + 1) / _subjects.length,
          backgroundColor: Colors.grey[200],
          valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF1e3a5f)),
          minHeight: 6,
          borderRadius: BorderRadius.circular(3),
        ),
      ],
    );
  }

  Widget _buildSubjectHeader(Map<String, dynamic> subject) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1e3a5f),
        borderRadius: BorderRadius.circular(12),
      ),
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
          const SizedBox(height: 4),
          Text(
            subject['subjectName'] ?? '',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.person, size: 16, color: Colors.white70),
              const SizedBox(width: 8),
              Text(
                'Faculty: ${subject['facultyName'] ?? 'Not Assigned'}',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRatingRow(String category) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            category,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: Color(0xFF1e3a5f),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: List.generate(5, (index) {
              final rating = index + 1;
              final isSelected = rating <= (_ratings[category] ?? 0);
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _ratings[category] = rating;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    isSelected ? Icons.star : Icons.star_border,
                    color: isSelected ? Colors.amber : Colors.grey[400],
                    size: 32,
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  void _skipSubject() {
    setState(() {
      _initializeRatings();
      // Find next unsubmitted subject
      int nextIndex = _currentIndex + 1;
      while (nextIndex < _subjects.length && _subjects[nextIndex]['submitted'] == true) {
        nextIndex++;
      }
      // If all are submitted, set to _subjects.length to trigger completion view
      if (nextIndex >= _subjects.length) {
        _currentIndex = _subjects.length;
      } else {
        _currentIndex = nextIndex;
      }
    });
  }

  Future<void> _submitFeedback() async {
    // Validate all ratings are provided
    final unrated = _ratings.entries.where((e) => e.value == 0).toList();
    if (unrated.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please rate: ${unrated.first.key}'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      if (_subjects.isEmpty || _currentIndex < 0 || _currentIndex >= _subjects.length) {
        setState(() => _isSubmitting = false);
        return;
      }
      final subject = _subjects[_currentIndex];
      final rollNumber = _studentData?['hallTicketNumber'] ??
          _auth.currentUser?.email?.split('@')[0].toUpperCase() ??
          '';

      await _feedbackService.submitFeedback(
        studentId: rollNumber,
        sessionId: _activeSession?['sessionId'] ?? '',
        subjectCode: subject['subjectCode'],
        subjectName: subject['subjectName'],
        facultyId: subject['facultyId'],
        ratings: _ratings,
        comments: _commentsController.text.trim(),
      );

      // Mark as submitted
      _subjects[_currentIndex]['submitted'] = true;

      // Reset ratings for next subject
      _initializeRatings();

      // Move to next unsubmitted subject
      int nextIndex = _currentIndex + 1;
      while (nextIndex < _subjects.length && _subjects[nextIndex]['submitted'] == true) {
        nextIndex++;
      }
      // If all are submitted, set to _subjects.length to trigger completion view
      setState(() {
        _isSubmitting = false;
        if (nextIndex >= _subjects.length) {
          _currentIndex = _subjects.length;
        } else {
          _currentIndex = nextIndex;
        }
      });

      if (mounted && nextIndex < _subjects.length) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Feedback submitted! Moving to next subject...'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      setState(() => _isSubmitting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
