import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Service to manage course preference submissions
class CoursePreferenceService {
  static final CoursePreferenceService _instance =
      CoursePreferenceService._internal();

  factory CoursePreferenceService() => _instance;

  CoursePreferenceService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  CollectionReference get _roundsCollection =>
      _firestore.collection('coursePreferenceRounds');
  CollectionReference get _preferencesCollection =>
      _firestore.collection('coursePreferences');
  CollectionReference get _subjectsCollection =>
      _firestore.collection('subjects');

  // ─── Rounds (admin-created) ───────────────────────────────────────────────

  /// Fetch active course preference rounds from Firestore.
  /// Falls back to default rounds if the collection is empty.
  Future<List<CoursePreferenceRound>> getRounds() async {
    try {
      final snap = await _roundsCollection
          .where('isActive', isEqualTo: true)
          .orderBy('createdAt', descending: false)
          .get();

      if (snap.docs.isNotEmpty) {
        return snap.docs
            .map((d) => CoursePreferenceRound.fromFirestore(d))
            .toList();
      }
    } catch (_) {}

    // Fallback defaults
    return [
      CoursePreferenceRound(
        id: 'default_1',
        acYear: '2025-26',
        className: 'UG List 1',
        dept: 'CSE',
        fromDate: '2025-11-18',
        toDate: '2025-11-25',
      ),
      CoursePreferenceRound(
        id: 'default_2',
        acYear: '2025-26',
        className: 'UG List 2',
        dept: 'CSE',
        fromDate: '2025-11-18',
        toDate: '2025-11-25',
      ),
    ];
  }

  // ─── Subjects (admin-uploaded) ────────────────────────────────────────────

  /// Fetch active subjects from Firestore, optionally filtered by department.
  /// Dept filtering is done in Dart to avoid requiring a composite Firestore index.
  /// Throws on Firestore errors so callers can surface them.
  Future<List<SubjectItem>> getSubjects({String? dept}) async {
    final snap = await _subjectsCollection
        .where('isActive', isEqualTo: true)
        .get();
    final all = snap.docs.map((d) => SubjectItem.fromFirestore(d)).toList();
    if (dept != null && dept.isNotEmpty) {
      return all
          .where((s) => s.dept.toLowerCase() == dept.toLowerCase())
          .toList();
    }
    return all;
  }

  // ─── Preferences (faculty submissions) ───────────────────────────────────

  /// Save faculty course preferences to Firestore.
  Future<void> saveCoursePreference({
    required String roundId,
    required String className,
    required String title,
    required String acYear,
    required String dept,
    required List<SubjectItem> subjects,
  }) async {
    final user = _auth.currentUser;
    final facultyId = user?.uid ?? 'unknown';
    final facultyEmail = user?.email ?? '';

    await _preferencesCollection
        .doc('${facultyId}_$roundId')
        .set({
      'facultyId': facultyId,
      'facultyEmail': facultyEmail,
      'roundId': roundId,
      'className': className,
      'title': title,
      'acYear': acYear,
      'dept': dept,
      'courses': subjects
          .map((s) => {
                'code': s.code,
                'name': s.name,
                'dept': s.dept,
                'year': s.year,
                'semester': s.semester,
                'subjectType': s.subjectType,
              })
          .toList(),
      'submittedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Get this faculty's submitted preferences, ordered newest first.
  /// Sorting is done in Dart to avoid requiring a composite Firestore index.
  Future<List<PreferenceData>> getMyPreferences() async {
    final user = _auth.currentUser;
    if (user == null) return [];
    final snap = await _preferencesCollection
        .where('facultyId', isEqualTo: user.uid)
        .get();
    final list = snap.docs.map((d) => PreferenceData.fromFirestore(d)).toList();
    list.sort((a, b) => b.submittedAt.compareTo(a.submittedAt));
    return list;
  }

  /// Get the preference for a specific round by this faculty.
  /// Returns null if no submission exists yet. Throws on Firestore errors.
  Future<PreferenceData?> getPreferenceForRound(String roundId) async {
    final user = _auth.currentUser;
    if (user == null) return null;
    final doc = await _preferencesCollection
        .doc('${user.uid}_$roundId')
        .get();
    if (!doc.exists) return null;
    return PreferenceData.fromFirestore(doc);
  }

  // ─── Legacy in-memory (kept for backward compat) ─────────────────────────

  final Map<String, PreferenceData> _submissions = {};

  void savePreferences(String className, String title, List<String> courses) {
    _submissions[className] = PreferenceData(
      roundId: className,
      className: className,
      title: title,
      acYear: '',
      dept: '',
      courses: courses.map((c) => SubjectItem(code: '', name: c, dept: '', year: 0, semester: '')).toList(),
      submittedAt: DateTime.now(),
    );
  }

  PreferenceData? getPreferences(String className) => _submissions[className];

  Map<String, PreferenceData> getAllPreferences() => _submissions;

  PreferenceData? getLatestPreferences() {
    if (_submissions.isEmpty) return null;
    return _submissions.values.reduce(
        (a, b) => a.submittedAt.isAfter(b.submittedAt) ? a : b);
  }
}

// ─── Models ──────────────────────────────────────────────────────────────────

class CoursePreferenceRound {
  final String id;
  final String acYear;
  final String className;
  final String dept;
  final String fromDate;
  final String toDate;

  CoursePreferenceRound({
    required this.id,
    required this.acYear,
    required this.className,
    required this.dept,
    required this.fromDate,
    required this.toDate,
  });

  factory CoursePreferenceRound.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return CoursePreferenceRound(
      id: doc.id,
      acYear: d['acYear'] ?? '',
      className: d['className'] ?? '',
      dept: d['dept'] ?? '',
      fromDate: d['fromDate'] ?? '',
      toDate: d['toDate'] ?? '',
    );
  }
}

class SubjectItem {
  final String code;
  final String name;
  final String dept;
  final int year;
  final String semester;
  final String subjectType;

  SubjectItem({
    required this.code,
    required this.name,
    required this.dept,
    required this.year,
    required this.semester,
    this.subjectType = 'Core',
  });

  factory SubjectItem.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return SubjectItem(
      code: d['code'] ?? '',
      name: d['name'] ?? '',
      dept: d['department'] ?? '',
      year: d['year'] ?? 0,
      semester: d['semester'] ?? '',
      subjectType: d['subjectType'] ?? 'Core',
    );
  }

  /// Display label shown in the list e.g. "CS301-Data Structures(CSE)"
  String get displayLabel => '$code-$name($dept)';
}

class PreferenceData {
  final String roundId;
  final String className;
  final String title;
  final String acYear;
  final String dept;
  final List<SubjectItem> courses;
  final DateTime submittedAt;

  PreferenceData({
    required this.roundId,
    required this.className,
    required this.title,
    required this.acYear,
    required this.dept,
    required this.courses,
    required this.submittedAt,
  });

  factory PreferenceData.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    final rawCourses = (d['courses'] as List<dynamic>?) ?? [];
    return PreferenceData(
      roundId: d['roundId'] ?? doc.id,
      className: d['className'] ?? '',
      title: d['title'] ?? '',
      acYear: d['acYear'] ?? '',
      dept: d['dept'] ?? '',
      courses: rawCourses
          .map((c) => SubjectItem(
                code: c['code'] ?? '',
                name: c['name'] ?? '',
                dept: c['dept'] ?? '',
                year: c['year'] ?? 0,
                semester: c['semester'] ?? '',
                subjectType: c['subjectType'] ?? 'Core',
              ))
          .toList(),
      submittedAt: d['submittedAt'] != null
          ? (d['submittedAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }
}
