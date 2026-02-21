import 'package:flutter/material.dart';
import '../../../widgets/app_header.dart';
import '../services/course_preference_service.dart';
import 'course_preference_detail_screen.dart';

class PreferenceReportScreen extends StatefulWidget {
  const PreferenceReportScreen({
    super.key,
    this.title = 'Course Preference Report',
    this.courses = const [],
  });

  final String title;
  final List<String> courses;

  @override
  State<PreferenceReportScreen> createState() => _PreferenceReportScreenState();
}

class _PreferenceReportScreenState extends State<PreferenceReportScreen> {
  late final CoursePreferenceService _service = CoursePreferenceService();

  List<String> _getCoursesToDisplay() {
    // If courses were passed directly, use those
    if (widget.courses.isNotEmpty) {
      return widget.courses;
    }

    // If title indicates a specific preference (not the default), try to load it
    if (widget.title != 'Course Preference Report') {
      final titleParts = widget.title.split(' Select Course Preference Order');
      if (titleParts.isNotEmpty) {
        final className = titleParts[0];
        final prefs = _service.getPreferences(className);
        if (prefs != null) {
          return prefs.courses;
        }
      }
    }

    // If no specific preference found, return all saved preferences courses
    final allPrefs = _service.getAllPreferences();
    if (allPrefs.isEmpty) {
      return [];
    }

    // Combine all courses from all preferences with headers
    List<String> allCourses = [];
    for (final entry in allPrefs.entries) {
      allCourses.addAll(entry.value.courses);
    }
    return allCourses;
  }

  PreferenceData? _getEditablePreference() {
    if (widget.courses.isNotEmpty) {
      final titleParts = widget.title.split(' Select Course Preference Order');
      final className =
          titleParts.isNotEmpty ? titleParts[0] : 'Course Preference';
      return PreferenceData(
        className: className,
        title: widget.title,
        courses: widget.courses,
        submittedAt: DateTime.now(),
      );
    }

    if (widget.title != 'Course Preference Report') {
      final titleParts = widget.title.split(' Select Course Preference Order');
      if (titleParts.isNotEmpty) {
        final className = titleParts[0];
        return _service.getPreferences(className);
      }
    }

    return _service.getLatestPreferences();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                        'Course Preference Report',
                        style: Theme.of(context).textTheme.headlineSmall,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.title,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      Builder(builder: (context) {
                        final coursesToShow = _getCoursesToDisplay();
                        if (coursesToShow.isEmpty) {
                          return Container(
                            padding: const EdgeInsets.all(32),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Column(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  color: Colors.orange,
                                  size: 48,
                                ),
                                SizedBox(height: 16),
                                Text(
                                  'No courses submitted yet',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        return SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            columns: const [
                              DataColumn(label: Text('S.No')),
                              DataColumn(label: Text('Course Code')),
                              DataColumn(label: Text('Course Name')),
                              DataColumn(label: Text('Department')),
                            ],
                            rows: List<DataRow>.generate(
                              coursesToShow.length,
                              (index) {
                                final course = coursesToShow[index];
                                final parts = course.split('(');
                                final courseName =
                                    parts.isNotEmpty ? parts[0].trim() : 'N/A';
                                final courseCode = courseName.contains('-')
                                    ? courseName.split('-')[0].trim()
                                    : 'N/A';
                                final courseTitle = courseName.contains('-')
                                    ? courseName.split('-')[1].trim()
                                    : courseName;
                                final dept = parts.length > 1
                                    ? parts[1].replaceAll(')', '').trim()
                                    : 'N/A';

                                return DataRow(
                                  cells: [
                                    DataCell(Text('${index + 1}')),
                                    DataCell(Text(courseCode)),
                                    DataCell(Text(courseTitle)),
                                    DataCell(Text(dept)),
                                  ],
                                );
                              },
                            ),
                          ),
                        );
                      }),
                      const SizedBox(height: 32),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ElevatedButton.icon(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.arrow_back),
                            label: const Text('Back'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey.shade400,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          ElevatedButton.icon(
                            onPressed: () {
                              final preference = _getEditablePreference();
                              if (preference == null ||
                                  preference.courses.isEmpty) {
                                _showMessage('No submitted courses to edit');
                                return;
                              }

                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => CoursePreferenceDetailScreen(
                                    title: preference.title,
                                    initialSelectedCourses: preference.courses,
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.edit),
                            label: const Text('Edit'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1976D2),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                            ),
                          ),
                        ],
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
}
