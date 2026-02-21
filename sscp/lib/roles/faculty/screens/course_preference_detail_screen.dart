import 'package:flutter/material.dart';
import '../../../widgets/app_header.dart';
import '../services/course_preference_service.dart';

class CoursePreferenceDetailScreen extends StatefulWidget {
  const CoursePreferenceDetailScreen({
    super.key,
    required this.title,
    this.initialSelectedCourses = const [],
  });

  final String title;
  final List<String> initialSelectedCourses;

  @override
  State<CoursePreferenceDetailScreen> createState() =>
      _CoursePreferenceDetailScreenState();
}

class _CoursePreferenceDetailScreenState
    extends State<CoursePreferenceDetailScreen> {
  int? _selectedAvailableIndex;
  int? _selectedChosenIndex;

  final List<String> _availableCourses = [
    '23CS002PC304-AI Assistant Coding(CSE)',
    '23CS202PC305-Competitive Programming(CSE)',
    '23CS302PC303-High Performance Computing(CSE)',
    '24CS301ES205-Cyber Security(CSE)',
    '24CS312ES206-Machine Learning(CSE)',
    '24CS312PC216-Data Structures(CSE)',
    '25CAI314PC102-Problem Solving using Python Programming(CSE)',
  ];

  final List<String> _selectedCourses = [];

  @override
  void initState() {
    super.initState();
    if (widget.initialSelectedCourses.isNotEmpty) {
      _selectedCourses.addAll(widget.initialSelectedCourses);
      _availableCourses
          .removeWhere((course) => _selectedCourses.contains(course));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 900;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          const AppHeader(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1200),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        widget.title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Kindly set the selection limits so that faculty can choose a minimum of 4 and a maximum of 7 courses',
                        style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      if (isMobile)
                        _buildMobileLayout()
                      else
                        _buildDesktopLayout(),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _handleSubmit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2EAD4B),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 12,
                          ),
                        ),
                        child: const Text('Submit'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _buildCourseList(
            title: 'Available Course:',
            items: _availableCourses,
            selectedIndex: _selectedAvailableIndex,
            onSelect: (index) {
              setState(() {
                _selectedAvailableIndex = index;
                _selectedChosenIndex = null;
              });
            },
          ),
        ),
        const SizedBox(width: 16),
        Column(
          children: [
            _buildActionButton('Add', const Color(0xFF1976D2), _handleAdd),
            const SizedBox(height: 12),
            _buildActionButton(
                'Remove', const Color(0xFF6C757D), _handleRemove),
            const SizedBox(height: 24),
            _buildActionButton('Up', const Color(0xFF1AA6B8), _handleMoveUp),
            const SizedBox(height: 12),
            _buildActionButton(
                'Down', const Color(0xFF1AA6B8), _handleMoveDown),
          ],
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildCourseList(
            title: 'Selected Course in Preference order :',
            items: _selectedCourses,
            selectedIndex: _selectedChosenIndex,
            onSelect: (index) {
              setState(() {
                _selectedChosenIndex = index;
                _selectedAvailableIndex = null;
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout() {
    return Column(
      children: [
        _buildCourseList(
          title: 'Available Course:',
          items: _availableCourses,
          selectedIndex: _selectedAvailableIndex,
          onSelect: (index) {
            setState(() {
              _selectedAvailableIndex = index;
              _selectedChosenIndex = null;
            });
          },
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: WrapAlignment.center,
          children: [
            _buildActionButton('Add', const Color(0xFF1976D2), _handleAdd),
            _buildActionButton(
                'Remove', const Color(0xFF6C757D), _handleRemove),
            _buildActionButton('Up', const Color(0xFF1AA6B8), _handleMoveUp),
            _buildActionButton(
                'Down', const Color(0xFF1AA6B8), _handleMoveDown),
          ],
        ),
        const SizedBox(height: 12),
        _buildCourseList(
          title: 'Selected Course in Preference order :',
          items: _selectedCourses,
          selectedIndex: _selectedChosenIndex,
          onSelect: (index) {
            setState(() {
              _selectedChosenIndex = index;
              _selectedAvailableIndex = null;
            });
          },
        ),
      ],
    );
  }

  Widget _buildCourseList({
    required String title,
    required List<String> items,
    required int? selectedIndex,
    required ValueChanged<int> onSelect,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 280,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(4),
          ),
          child: ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, index) {
              final isSelected = index == selectedIndex;
              return InkWell(
                onTap: () => onSelect(index),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF1976D2).withOpacity(0.1)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    items[index],
                    style: TextStyle(
                      fontSize: 13,
                      color:
                          isSelected ? const Color(0xFF1976D2) : Colors.black87,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton(String label, Color color, VoidCallback onPressed) {
    return SizedBox(
      width: 110,
      height: 38,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        ),
        child: Text(label),
      ),
    );
  }

  void _handleAdd() {
    if (_selectedAvailableIndex == null) {
      _showMessage('Select a course to add');
      return;
    }
    if (_selectedCourses.length >= 7) {
      _showMessage('Maximum of 7 courses allowed');
      return;
    }

    final course = _availableCourses[_selectedAvailableIndex!];
    setState(() {
      _availableCourses.removeAt(_selectedAvailableIndex!);
      _selectedAvailableIndex = null;
      _selectedCourses.add(course);
    });
  }

  void _handleRemove() {
    if (_selectedChosenIndex == null) {
      _showMessage('Select a course to remove');
      return;
    }

    final course = _selectedCourses[_selectedChosenIndex!];
    setState(() {
      _selectedCourses.removeAt(_selectedChosenIndex!);
      _selectedChosenIndex = null;
      _availableCourses.add(course);
    });
  }

  void _handleMoveUp() {
    if (_selectedChosenIndex == null || _selectedChosenIndex == 0) {
      return;
    }

    final index = _selectedChosenIndex!;
    setState(() {
      final item = _selectedCourses.removeAt(index);
      _selectedCourses.insert(index - 1, item);
      _selectedChosenIndex = index - 1;
    });
  }

  void _handleMoveDown() {
    if (_selectedChosenIndex == null ||
        _selectedChosenIndex == _selectedCourses.length - 1) {
      return;
    }

    final index = _selectedChosenIndex!;
    setState(() {
      final item = _selectedCourses.removeAt(index);
      _selectedCourses.insert(index + 1, item);
      _selectedChosenIndex = index + 1;
    });
  }

  void _handleSubmit() {
    if (_selectedCourses.length < 4) {
      _showMessage('Select at least 4 courses to submit');
      return;
    }
    if (_selectedCourses.length > 7) {
      _showMessage('Maximum of 7 courses allowed');
      return;
    }

    // Save preferences using the service
    final service = CoursePreferenceService();
    // Extract class name from title (e.g., "UG List 1" from "UG List 1 Select Course Preference Order (2025-26)")
    final titleParts = widget.title.split(' Select Course Preference Order');
    final className =
        titleParts.isNotEmpty ? titleParts[0] : 'Course Preference';

    service.savePreferences(className, widget.title, _selectedCourses);

    _showMessage('Course preferences submitted successfully');
    Future.delayed(const Duration(seconds: 1), () {
      Navigator.of(context).pop();
    });
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}
