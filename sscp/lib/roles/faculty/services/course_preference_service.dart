/// Service to manage course preference submissions
class CoursePreferenceService {
  static final CoursePreferenceService _instance =
      CoursePreferenceService._internal();

  factory CoursePreferenceService() {
    return _instance;
  }

  CoursePreferenceService._internal();

  /// Map to store submitted preferences: key = className, value = PreferenceData
  final Map<String, PreferenceData> _submissions = {};

  /// Save submitted courses
  void savePreferences(String className, String title, List<String> courses) {
    _submissions[className] = PreferenceData(
      className: className,
      title: title,
      courses: List<String>.from(courses),
      submittedAt: DateTime.now(),
    );
  }

  /// Get submitted courses for a specific class
  PreferenceData? getPreferences(String className) {
    return _submissions[className];
  }

  /// Get all submitted preferences
  Map<String, PreferenceData> getAllPreferences() {
    return _submissions;
  }

  /// Get the most recently submitted preference
  PreferenceData? getLatestPreferences() {
    if (_submissions.isEmpty) {
      return null;
    }

    PreferenceData? latest;
    for (final entry in _submissions.values) {
      if (latest == null || entry.submittedAt.isAfter(latest.submittedAt)) {
        latest = entry;
      }
    }
    return latest;
  }

  /// Check if preferences exist for a class
  bool hasPreferences(String className) {
    return _submissions.containsKey(className);
  }

  /// Clear a specific preference
  void clearPreferences(String className) {
    _submissions.remove(className);
  }

  /// Clear all preferences
  void clearAllPreferences() {
    _submissions.clear();
  }
}

/// Model class to store preference data
class PreferenceData {
  final String className;
  final String title;
  final List<String> courses;
  final DateTime submittedAt;

  PreferenceData({
    required this.className,
    required this.title,
    required this.courses,
    required this.submittedAt,
  });
}
