import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'user_service.dart';

class AiAssistantAnswer {
  final String text;
  final List<String> suggestions;

  const AiAssistantAnswer({required this.text, this.suggestions = const []});
}

enum _StudentAiIntent {
  marks,
  backlog,
  attendance,
  cgpa,
  profile,
  help,
  unknown,
}

class _StudentMarkRecord {
  final String subjectCode;
  final String subjectName;
  final int year;
  final String semester;
  final int cie;
  final int ete;
  final int total;
  final int maxMarks;

  const _StudentMarkRecord({
    required this.subjectCode,
    required this.subjectName,
    required this.year,
    required this.semester,
    required this.cie,
    required this.ete,
    required this.total,
    required this.maxMarks,
  });
}

class StudentAiAssistantService {
  final FirebaseAuth _auth;
  final FirebaseFirestore _fs;

  StudentAiAssistantService({FirebaseAuth? auth, FirebaseFirestore? firestore})
      : _auth = auth ?? FirebaseAuth.instance,
        _fs = firestore ?? FirebaseFirestore.instance;

  Future<AiAssistantAnswer> getAnswer(String question) async {
    final text = question.trim();
    if (text.isEmpty) {
      return const AiAssistantAnswer(
        text: 'Ask me anything about your academic data. Example: "show my latest CIE marks".',
      );
    }

    final user = _auth.currentUser;
    if (user == null) {
      return const AiAssistantAnswer(
        text: 'Please login again. I cannot read student data without an active session.',
      );
    }

    final rollNo = _getRollNo(user);
    if (rollNo.isEmpty) {
      return const AiAssistantAnswer(
        text: 'I could not detect your roll number from login details.',
      );
    }

    final intent = _detectIntent(text.toLowerCase());

    try {
      switch (intent) {
        case _StudentAiIntent.marks:
          return _answerMarks(rollNo, text.toLowerCase());
        case _StudentAiIntent.backlog:
          return _answerBacklogs(rollNo);
        case _StudentAiIntent.attendance:
          return _answerAttendance(rollNo);
        case _StudentAiIntent.cgpa:
          return _answerCgpa(rollNo);
        case _StudentAiIntent.profile:
          return _answerProfile(rollNo);
        case _StudentAiIntent.help:
        case _StudentAiIntent.unknown:
          return _helpAnswer();
      }
    } catch (_) {
      return const AiAssistantAnswer(
        text: 'Something went wrong while reading your data. Please try again.',
      );
    }
  }

  String _getRollNo(User user) {
    return UserService.getCurrentUserId() ??
        (user.email ?? '').split('@').first.toUpperCase();
  }

  _StudentAiIntent _detectIntent(String q) {
    if (q.contains('help') || q.contains('what can you do')) {
      return _StudentAiIntent.help;
    }
    if (q.contains('attendance') || q.contains('present')) {
      return _StudentAiIntent.attendance;
    }
    if (q.contains('cgpa') || q.contains('gpa')) {
      return _StudentAiIntent.cgpa;
    }
    if (q.contains('backlog') || q.contains('supply') || q.contains('failed')) {
      return _StudentAiIntent.backlog;
    }
    if (q.contains('profile') ||
        q.contains('department') ||
        q.contains('year') ||
        q.contains('semester') ||
        q.contains('batch')) {
      return _StudentAiIntent.profile;
    }
    if (q.contains('marks') ||
        q.contains('score') ||
        q.contains('cie') ||
        q.contains('mid') ||
        q.contains('subject')) {
      return _StudentAiIntent.marks;
    }
    return _StudentAiIntent.unknown;
  }

  Future<AiAssistantAnswer> _answerMarks(String rollNo, String question) async {
    final records = await _loadMarks(rollNo);
    if (records.isEmpty) {
      return const AiAssistantAnswer(
        text: 'No marks are available yet.',
        suggestions: [
          'Show my attendance',
          'How many backlogs do I have?',
        ],
      );
    }

    final subjectSpecific = _filterBySubject(records, question);
    final selected = subjectSpecific.isNotEmpty ? subjectSpecific : records;
    final top = selected.take(4).toList();

    final lines = <String>[];
    if (subjectSpecific.isNotEmpty) {
      lines.add('Here are your marks for the requested subject:');
    } else {
      lines.add('Here are your latest marks:');
    }

    for (final r in top) {
      lines.add(
          '- ${r.subjectCode} (${r.subjectName}): CIE ${r.cie}, ETE ${r.ete}, Total ${r.total}/${r.maxMarks} (Y${r.year}-S${r.semester})');
    }

    if (selected.length > top.length) {
      lines.add('And ${selected.length - top.length} more record(s).');
    }

    return AiAssistantAnswer(
      text: lines.join('\n'),
      suggestions: const [
        'Show my CGPA',
        'How many active backlogs?',
        'Show my attendance percentage',
      ],
    );
  }

  Future<AiAssistantAnswer> _answerBacklogs(String rollNo) async {
    final releaseSnap = await _fs.collection('cieMemoReleases').get();
    final marksSnap = await _fs
        .collection('studentMarks')
        .where('studentId', isEqualTo: rollNo)
        .get();
    final supplySnap = await _fs
        .collection('supplyMarks')
        .where('rollNo', isEqualTo: rollNo)
        .get();

    String normSem(String s) {
      const map = {'i': '1', 'ii': '2', 'iii': '3', 'iv': '4'};
      return map[s.toLowerCase().trim()] ?? s.trim();
    }

    final releaseMap = <String, int>{};
    for (final d in releaseSnap.docs) {
      final data = d.data();
      final key = '${data['year']}_${normSem(data['semester']?.toString() ?? '')}';
      releaseMap[key] = (data['minPassMarks'] is int)
          ? data['minPassMarks'] as int
          : int.tryParse(data['minPassMarks']?.toString() ?? '') ?? 40;
    }

    final supplyPassed = <String>{};
    for (final d in supplySnap.docs) {
      final data = d.data();
      if ((data['result']?.toString() ?? '').toUpperCase() == 'PASS') {
        final code = data['subjectCode']?.toString() ?? '';
        if (code.isNotEmpty) {
          supplyPassed.add(code);
        }
      }
    }

    final bySubject = <String, List<Map<String, dynamic>>>{};
    for (final d in marksSnap.docs) {
      final data = Map<String, dynamic>.from(d.data());
      final code = data['subjectCode']?.toString() ?? '';
      if (code.isEmpty) {
        continue;
      }
      bySubject.putIfAbsent(code, () => []).add(data);
    }

    final activeBacklogs = <String>[];

    for (final entry in bySubject.entries) {
      final code = entry.key;
      final values = entry.value;

      values.sort((a, b) {
        final ya = int.tryParse(a['year']?.toString() ?? '') ?? 0;
        final yb = int.tryParse(b['year']?.toString() ?? '') ?? 0;
        if (ya != yb) {
          return ya.compareTo(yb);
        }
        return normSem(a['semester']?.toString() ?? '')
            .compareTo(normSem(b['semester']?.toString() ?? ''));
      });

      for (int i = 0; i < values.length; i++) {
        final current = values[i];
        final minPass = releaseMap[
                '${current['year']}_${normSem(current['semester']?.toString() ?? '')}'] ??
            40;
        final total = _sumMarks(current['componentMarks']);
        if (total >= minPass) {
          continue;
        }

        bool clearedLater = false;
        for (int j = i + 1; j < values.length; j++) {
          final later = values[j];
          final laterMin = releaseMap[
                  '${later['year']}_${normSem(later['semester']?.toString() ?? '')}'] ??
              40;
          final laterTotal = _sumMarks(later['componentMarks']);
          if (laterTotal >= laterMin) {
            clearedLater = true;
            break;
          }
        }

        if (!clearedLater && supplyPassed.contains(code)) {
          clearedLater = true;
        }

        if (!clearedLater) {
          final name = current['subjectName']?.toString() ?? '';
          activeBacklogs.add(name.isEmpty ? code : '$code ($name)');
        }
      }
    }

    if (activeBacklogs.isEmpty) {
      return const AiAssistantAnswer(
        text: 'Great news. You currently have 0 active backlogs.',
        suggestions: [
          'Show my latest marks',
          'Show my CGPA',
        ],
      );
    }

    final preview = activeBacklogs.take(5).join(', ');
    return AiAssistantAnswer(
      text: 'You currently have ${activeBacklogs.length} active backlog(s): $preview',
      suggestions: const [
        'Show my latest marks',
        'Show my attendance percentage',
      ],
    );
  }

  Future<AiAssistantAnswer> _answerAttendance(String rollNo) async {
    final snap = await _fs.collection('attendance').get();

    int held = 0;
    int present = 0;

    for (final d in snap.docs) {
      final data = d.data();
      final periods = List<dynamic>.from(data['periods'] ?? []);
      if (periods.isEmpty) {
        continue;
      }

      final students = List<dynamic>.from(data['students'] ?? []);
      Map? found;
      for (final s in students) {
        if (s is Map &&
            (s['rollNo']?.toString().toUpperCase() ?? '') == rollNo) {
          found = s;
          break;
        }
      }
      if (found == null) {
        continue;
      }

      final count = periods.length;
      held += count;
      if (found['present'] == true) {
        present += count;
      }
    }

    final pct = held == 0 ? 0.0 : (present / held) * 100;
    return AiAssistantAnswer(
      text:
          'Your current attendance is ${pct.toStringAsFixed(1)}% ($present/$held classes).',
      suggestions: const [
        'Show my latest marks',
        'How many backlogs do I have?',
      ],
    );
  }

  Future<AiAssistantAnswer> _answerCgpa(String rollNo) async {
    final marksSnap = await _fs
        .collection('studentMarks')
        .where('studentId', isEqualTo: rollNo)
        .get();

    if (marksSnap.docs.isEmpty) {
      return const AiAssistantAnswer(
        text: 'No marks found yet to compute CGPA.',
      );
    }

    int gradePoint(double pct) {
      if (pct >= 90) {
        return 10;
      }
      if (pct >= 80) {
        return 9;
      }
      if (pct >= 70) {
        return 8;
      }
      if (pct >= 60) {
        return 7;
      }
      if (pct >= 50) {
        return 6;
      }
      if (pct >= 40) {
        return 5;
      }
      return 0;
    }

    String normSem(String s) {
      switch (s.trim().toUpperCase()) {
        case 'I':
        case '1':
          return '1';
        case 'II':
        case '2':
          return '2';
        default:
          return s.trim();
      }
    }

    final semCreditPoints = <String, double>{};
    final semCredits = <String, int>{};

    for (final d in marksSnap.docs) {
      final data = d.data();
      final semKey =
          '${data['year']?.toString() ?? '0'}-${normSem(data['semester']?.toString() ?? '')}';

      final maxMarks = _asInt(data['maxMarks']);
      if (maxMarks <= 0) {
        continue;
      }

      final total = _sumMarks(data['componentMarks']);
      final credits = _asInt(data['credits'], fallback: 3);
      final gp = gradePoint((total / maxMarks) * 100);
      semCreditPoints[semKey] = (semCreditPoints[semKey] ?? 0.0) + (gp * credits);
      semCredits[semKey] = (semCredits[semKey] ?? 0) + credits;
    }

    double sgpaSum = 0;
    int count = 0;
    for (final key in semCreditPoints.keys) {
      final totalCredits = semCredits[key] ?? 0;
      if (totalCredits == 0) {
        continue;
      }
      sgpaSum += semCreditPoints[key]! / totalCredits;
      count++;
    }

    if (count == 0) {
      return const AiAssistantAnswer(text: 'Unable to compute CGPA right now.');
    }

    final cgpa = sgpaSum / count;
    return AiAssistantAnswer(
      text: 'Your computed CGPA is ${cgpa.toStringAsFixed(2)}.',
      suggestions: const [
        'Show my latest marks',
        'Show my attendance percentage',
      ],
    );
  }

  Future<AiAssistantAnswer> _answerProfile(String rollNo) async {
    final doc = await _fs.collection('students').doc(rollNo).get();
    if (!doc.exists) {
      return const AiAssistantAnswer(text: 'Student profile not found.');
    }

    final data = doc.data()!;
    final name = data['name']?.toString() ?? 'N/A';
    final department = data['department']?.toString().toUpperCase() ?? 'N/A';
    final year = data['year']?.toString() ?? 'N/A';
    final semester = data['semester']?.toString() ?? 'N/A';
    final batch = data['batchNumber']?.toString() ?? 'N/A';

    return AiAssistantAnswer(
      text:
          'Profile summary:\n- Name: $name\n- Roll No: $rollNo\n- Department: $department\n- Year/Sem: $year/$semester\n- Batch: $batch',
      suggestions: const [
        'Show my latest marks',
        'Show my CGPA',
      ],
    );
  }

  AiAssistantAnswer _helpAnswer() {
    return const AiAssistantAnswer(
      text: 'You can ask me:\n- Show my latest CIE marks\n- Show marks for DBMS\n- How many backlogs do I have?\n- Show my attendance percentage\n- What is my CGPA?\n- Show my profile details',
      suggestions: [
        'Show my latest CIE marks',
        'What is my CGPA?',
        'How many backlogs do I have?',
      ],
    );
  }

  Future<List<_StudentMarkRecord>> _loadMarks(String rollNo) async {
    final snap = await _fs
        .collection('studentMarks')
        .where('studentId', isEqualTo: rollNo)
        .get();

    final records = <_StudentMarkRecord>[];
    for (final doc in snap.docs) {
      final d = doc.data();
      final marks = (d['componentMarks'] as Map<String, dynamic>? ?? {});
      int cie = 0;
      int ete = 0;
      for (final entry in marks.entries) {
        final value = _asInt(entry.value);
        if (_isEte(entry.key)) {
          ete += value;
        } else {
          cie += value;
        }
      }

      final total = cie + ete;
      records.add(_StudentMarkRecord(
        subjectCode: d['subjectCode']?.toString() ?? '',
        subjectName: d['subjectName']?.toString() ?? '',
        year: _asInt(d['year']),
        semester: d['semester']?.toString() ?? '',
        cie: cie,
        ete: ete,
        total: total,
        maxMarks: _asInt(d['maxMarks']),
      ));
    }

    records.sort((a, b) {
      final yearCmp = b.year.compareTo(a.year);
      if (yearCmp != 0) {
        return yearCmp;
      }
      final semCmp = _semesterSortValue(b.semester).compareTo(
        _semesterSortValue(a.semester),
      );
      if (semCmp != 0) {
        return semCmp;
      }
      return a.subjectCode.compareTo(b.subjectCode);
    });

    return records;
  }

  List<_StudentMarkRecord> _filterBySubject(
      List<_StudentMarkRecord> records, String question) {
    final words = question
        .split(RegExp(r'[^a-zA-Z0-9]+'))
        .where((w) => w.length >= 3)
        .toList();
    if (words.isEmpty) {
      return [];
    }

    return records.where((r) {
      final haystack = '${r.subjectCode} ${r.subjectName}'.toLowerCase();
      return words.any(haystack.contains);
    }).toList();
  }

  int _semesterSortValue(String s) {
    final t = s.trim().toUpperCase();
    switch (t) {
      case 'I':
      case '1':
        return 1;
      case 'II':
      case '2':
        return 2;
      case 'III':
      case '3':
        return 3;
      case 'IV':
      case '4':
        return 4;
      default:
        return int.tryParse(t) ?? 0;
    }
  }

  bool _isEte(String name) {
    final lower = name.toLowerCase();
    return lower.contains('end term') ||
        lower.contains('ete') ||
        lower.contains('end-term') ||
        lower.contains('external');
  }

  int _sumMarks(dynamic raw) {
    if (raw is! Map) {
      return 0;
    }
    int total = 0;
    for (final value in raw.values) {
      total += _asInt(value);
    }
    return total;
  }

  int _asInt(dynamic value, {int fallback = 0}) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.floor();
    }
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }
}
