import 'package:flutter/material.dart';
import '../../../widgets/app_header.dart';
import '../services/course_preference_service.dart';

class CoursePreferenceDetailScreen extends StatefulWidget {
  const CoursePreferenceDetailScreen({
    super.key,
    required this.roundId,
    required this.title,
    required this.dept,
    required this.acYear,
    this.initialSelectedCourses = const [],
  });

  final String roundId;
  final String title;
  final String dept;
  final String acYear;
  final List<SubjectItem> initialSelectedCourses;

  @override
  State<CoursePreferenceDetailScreen> createState() =>
      _CoursePreferenceDetailScreenState();
}

class _CoursePreferenceDetailScreenState
    extends State<CoursePreferenceDetailScreen> {
  final _service = CoursePreferenceService();

  bool _isLoading = true;
  String? _loadError;

  int? _selectedAvailableIndex;
  int? _selectedChosenIndex;

  List<SubjectItem> _availableCourses = [];
  List<SubjectItem> _selectedCourses = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    // Step 1: Load previously submitted preference — must succeed to continue.
    PreferenceData? existing;
    try {
      existing = await _service.getPreferenceForRound(widget.roundId);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = 'Could not load your previous submission: $e';
        _isLoading = false;
      });
      return;
    }

    // Step 2: Load available subjects — if this fails, still show the
    // previously submitted selection so the faculty can at least see their choices.
    List<SubjectItem> allSubjects = [];
    String? subjectLoadError;
    try {
      allSubjects = await _service.getSubjects(
          dept: widget.dept.isNotEmpty ? widget.dept : null);
    } catch (e) {
      subjectLoadError = e.toString();
    }

    if (!mounted) return;

    final preSelected =
        existing != null ? existing.courses : widget.initialSelectedCourses;
    final selectedCodes = preSelected.map((s) => s.code).toSet();

    setState(() {
      _selectedCourses = List<SubjectItem>.from(preSelected);
      _availableCourses =
          allSubjects.where((s) => !selectedCodes.contains(s.code)).toList();
      _isLoading = false;
    });

    // Show a non-blocking warning if subjects failed (previous selection is still visible).
    if (subjectLoadError != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            'Could not load available subjects: $subjectLoadError\nYour previous selection is shown on the right.'),
        duration: const Duration(seconds: 6),
        backgroundColor: Colors.orange[800],
      ));
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
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _loadError != null
                    ? _buildError()
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 1200),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Text(widget.title,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                        fontSize: 28,
                                        fontWeight: FontWeight.bold)),
                                const SizedBox(height: 8),
                                const Text(
                                  'Select a minimum of 4 and a maximum of 7 courses in preference order',
                                  style: TextStyle(
                                      color: Colors.red,
                                      fontWeight: FontWeight.w600),
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
                                        horizontal: 32, vertical: 12),
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

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text('Failed to load subjects: $_loadError'),
          const SizedBox(height: 20),
          ElevatedButton(onPressed: _loadData, child: const Text('Retry')),
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
            title: 'Available Courses:',
            items: _availableCourses,
            selectedIndex: _selectedAvailableIndex,
            onSelect: (i) => setState(() {
              _selectedAvailableIndex = i;
              _selectedChosenIndex = null;
            }),
          ),
        ),
        const SizedBox(width: 16),
        Column(children: [
          _buildActionButton('Add', const Color(0xFF1976D2), _handleAdd),
          const SizedBox(height: 12),
          _buildActionButton('Remove', const Color(0xFF6C757D), _handleRemove),
          const SizedBox(height: 24),
          _buildActionButton('Up', const Color(0xFF1AA6B8), _handleMoveUp),
          const SizedBox(height: 12),
          _buildActionButton('Down', const Color(0xFF1AA6B8), _handleMoveDown),
        ]),
        const SizedBox(width: 16),
        Expanded(
          child: _buildCourseList(
            title: 'Selected Courses in Preference Order:',
            items: _selectedCourses,
            selectedIndex: _selectedChosenIndex,
            onSelect: (i) => setState(() {
              _selectedChosenIndex = i;
              _selectedAvailableIndex = null;
            }),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout() {
    return Column(children: [
      _buildCourseList(
        title: 'Available Courses:',
        items: _availableCourses,
        selectedIndex: _selectedAvailableIndex,
        onSelect: (i) => setState(() {
          _selectedAvailableIndex = i;
          _selectedChosenIndex = null;
        }),
      ),
      const SizedBox(height: 12),
      Wrap(
        spacing: 12,
        runSpacing: 12,
        alignment: WrapAlignment.center,
        children: [
          _buildActionButton('Add', const Color(0xFF1976D2), _handleAdd),
          _buildActionButton('Remove', const Color(0xFF6C757D), _handleRemove),
          _buildActionButton('Up', const Color(0xFF1AA6B8), _handleMoveUp),
          _buildActionButton('Down', const Color(0xFF1AA6B8), _handleMoveDown),
        ],
      ),
      const SizedBox(height: 12),
      _buildCourseList(
        title: 'Selected Courses in Preference Order:',
        items: _selectedCourses,
        selectedIndex: _selectedChosenIndex,
        onSelect: (i) => setState(() {
          _selectedChosenIndex = i;
          _selectedAvailableIndex = null;
        }),
      ),
    ]);
  }

  Widget _buildCourseList({
    required String title,
    required List<SubjectItem> items,
    required int? selectedIndex,
    required ValueChanged<int> onSelect,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style:
                const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Container(
          height: 300,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey),
            borderRadius: BorderRadius.circular(4),
          ),
          child: items.isEmpty
              ? Center(
                  child: Text('No courses available',
                      style: TextStyle(color: Colors.grey[500])))
              : ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final isSelected = index == selectedIndex;
                    return InkWell(
                      onTap: () => onSelect(index),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 6),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF1976D2).withOpacity(0.1)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              items[index].displayLabel,
                              style: TextStyle(
                                fontSize: 13,
                                color: isSelected
                                    ? const Color(0xFF1976D2)
                                    : Colors.black87,
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
                            ),
                            if (items[index].subjectType.isNotEmpty &&
                                items[index].subjectType != 'Core')
                              Text(
                                items[index].subjectType,
                                style: TextStyle(
                                    fontSize: 10, color: Colors.grey[600]),
                              ),
                          ],
                        ),
                      ),
                    );
                  }),
        ),
        const SizedBox(height: 4),
        Text('${items.length} course(s)',
            style: TextStyle(fontSize: 11, color: Colors.grey[600])),
      ],
    );
  }

  Widget _buildActionButton(
      String label, Color color, VoidCallback onPressed) {
    return SizedBox(
      width: 110,
      height: 38,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.white,
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6)),
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
    if (_selectedChosenIndex == null || _selectedChosenIndex == 0) return;
    final i = _selectedChosenIndex!;
    setState(() {
      final item = _selectedCourses.removeAt(i);
      _selectedCourses.insert(i - 1, item);
      _selectedChosenIndex = i - 1;
    });
  }

  void _handleMoveDown() {
    if (_selectedChosenIndex == null ||
        _selectedChosenIndex == _selectedCourses.length - 1) return;
    final i = _selectedChosenIndex!;
    setState(() {
      final item = _selectedCourses.removeAt(i);
      _selectedCourses.insert(i + 1, item);
      _selectedChosenIndex = i + 1;
    });
  }

  Future<void> _handleSubmit() async {
    if (_selectedCourses.length < 4) {
      _showMessage('Select at least 4 courses');
      return;
    }
    if (_selectedCourses.length > 7) {
      _showMessage('Maximum of 7 courses allowed');
      return;
    }
    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()));
    try {
      await _service.saveCoursePreference(
        roundId: widget.roundId,
        className: widget.title
            .split(' Select Course Preference Order')
            .first,
        title: widget.title,
        acYear: widget.acYear,
        dept: widget.dept,
        subjects: _selectedCourses,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      _showMessage('Course preferences submitted successfully!');
      await Future.delayed(const Duration(milliseconds: 800));
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      _showMessage('Failed to save: $e');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}
