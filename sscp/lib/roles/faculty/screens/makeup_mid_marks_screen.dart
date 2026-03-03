import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Faculty: Makeup Mid Exam Marks Entry
/// - Shows subjects assigned to this faculty via [makeupMidSubjectAssignments]
/// - For each subject, lists students who registered under that makeup window
/// - Faculty enters mid exam marks → saved to [makeupMidMarks]
class MakeupMidMarksScreen extends StatefulWidget {
  const MakeupMidMarksScreen({super.key});

  @override
  State<MakeupMidMarksScreen> createState() => _MakeupMidMarksScreenState();
}

class _MakeupMidMarksScreenState extends State<MakeupMidMarksScreen> {
  final _firestore = FirebaseFirestore.instance;
  late final String _facultyId;
  bool _loading = true;

  List<Map<String, dynamic>> _assignments = [];
  Map<String, dynamic>? _selectedAssignment;

  @override
  void initState() {
    super.initState();
    final email = FirebaseAuth.instance.currentUser?.email ?? '';
    _facultyId = email.split('@')[0].toUpperCase();
    _loadAssignments();
  }

  Future<void> _loadAssignments() async {
    setState(() => _loading = true);

    final snap = await _firestore
        .collection('makeupMidSubjectAssignments')
        .where('facultyId', isEqualTo: _facultyId)
        .get();

    final list = <Map<String, dynamic>>[];
    for (final doc in snap.docs) {
      final data = doc.data();
      // Fetch window info for display
      String windowTitle = data['windowId']?.toString() ?? '';
      int maxMarks = 30;
      try {
        final winDoc = await _firestore
            .collection('makeupMidWindows')
            .doc(data['windowId']?.toString())
            .get();
        if (winDoc.exists) {
          windowTitle = (winDoc.data()?['title'] as String?) ?? windowTitle;
          maxMarks = (winDoc.data()?['maxMarks'] as num?)?.toInt() ?? 30;
        }
      } catch (_) {}
      list.add({
        ...data,
        'docId': doc.id,
        'windowTitle': windowTitle,
        'maxMarks': maxMarks,
      });
    }

    if (mounted) {
      setState(() {
        _assignments = list;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Makeup Mid Marks'),
        backgroundColor: const Color(0xFF1e3a5f),
        foregroundColor: Colors.white,
        actions: [
          if (_selectedAssignment != null)
            TextButton.icon(
              onPressed: () => setState(() => _selectedAssignment = null),
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              label: const Text('Back', style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _selectedAssignment == null
              ? _buildAssignmentList()
              : _MakeupMarksEntry(
                  firestore: _firestore,
                  facultyId: _facultyId,
                  assignment: _selectedAssignment!,
                ),
    );
  }

  Widget _buildAssignmentList() {
    if (_assignments.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No makeup mid subjects assigned to you yet.\n'
            'Please contact the admin.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            'Your Assigned Makeup Mid Subjects',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: _assignments.length,
            itemBuilder: (_, i) {
              final a = _assignments[i];
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFF1e3a5f),
                    child: Icon(Icons.edit_note, color: Colors.white, size: 18),
                  ),
                  title: Text(
                    '${a['subjectCode']} — ${a['subjectName']}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  subtitle: Text(
                    '${a['windowTitle']}\n${a['examSession'] ?? ''}  •  Max: ${a['maxMarks']} marks',
                    style: const TextStyle(fontSize: 12),
                  ),
                  isThreeLine: true,
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => setState(() => _selectedAssignment = a),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Marks Entry for one subject × window
// ═══════════════════════════════════════════════════════════════════════════

class _MakeupMarksEntry extends StatefulWidget {
  final FirebaseFirestore firestore;
  final String facultyId;
  final Map<String, dynamic> assignment;

  const _MakeupMarksEntry({
    required this.firestore,
    required this.facultyId,
    required this.assignment,
  });

  @override
  State<_MakeupMarksEntry> createState() => _MakeupMarksEntryState();
}

class _MakeupMarksEntryState extends State<_MakeupMarksEntry> {
  bool _loading = true;
  List<_MidStudent> _students = [];
  final Map<String, TextEditingController> _marksCtrl = {};

  String get _windowId => widget.assignment['windowId']?.toString() ?? '';
  String get _subjectCode => widget.assignment['subjectCode']?.toString() ?? '';
  String get _subjectName => widget.assignment['subjectName']?.toString() ?? '';
  String get _examSession => widget.assignment['examSession']?.toString() ?? '';
  int get _maxMarks => (widget.assignment['maxMarks'] as num?)?.toInt() ?? 30;

  @override
  void initState() {
    super.initState();
    _loadStudents();
  }

  @override
  void dispose() {
    for (final c in _marksCtrl.values) c.dispose();
    super.dispose();
  }

  Future<void> _loadStudents() async {
    setState(() => _loading = true);

    // 1) All registrations for this window
    final regSnap = await widget.firestore
        .collection('makeupMidRegistrations')
        .where('makeupWindowId', isEqualTo: _windowId)
        .get();

    // 2) Filter those that include this subject
    final registered = <Map<String, dynamic>>[];
    for (final doc in regSnap.docs) {
      final d = doc.data();
      final subjects = List<Map<String, dynamic>>.from(
          (d['subjects'] as List? ?? [])
              .map((s) => Map<String, dynamic>.from(s as Map)));
      if (subjects.any((s) => s['subjectCode']?.toString() == _subjectCode)) {
        registered.add(d);
      }
    }

    // 3) For each student, check if marks already saved
    final students = <_MidStudent>[];
    for (final r in registered) {
      final rollNo = r['rollNo']?.toString() ?? '';
      final studentName = r['studentName']?.toString() ?? rollNo;

      double? savedMarks;
      try {
        final saved = await widget.firestore
            .collection('makeupMidMarks')
            .where('windowId', isEqualTo: _windowId)
            .where('subjectCode', isEqualTo: _subjectCode)
            .where('rollNo', isEqualTo: rollNo)
            .limit(1)
            .get();
        if (saved.docs.isNotEmpty) {
          savedMarks =
              (saved.docs.first.data()['midMarks'] as num?)?.toDouble();
        }
      } catch (_) {}

      students.add(_MidStudent(
        rollNo: rollNo,
        name: studentName,
        savedMarks: savedMarks,
      ));

      _marksCtrl[rollNo] = TextEditingController(
          text: savedMarks != null ? savedMarks.toStringAsFixed(0) : '');
    }

    if (mounted) {
      setState(() {
        _students = students;
        _loading = false;
      });
    }
  }

  Future<void> _saveAll() async {
    bool anyInvalid = false;
    for (final student in _students) {
      final txt = _marksCtrl[student.rollNo]?.text.trim() ?? '';
      if (txt.isEmpty) continue;
      final v = double.tryParse(txt);
      if (v == null || v < 0 || v > _maxMarks) {
        anyInvalid = true;
        break;
      }
    }

    if (anyInvalid) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'Marks must be between 0 and $_maxMarks. Please correct and try again.'),
          backgroundColor: Colors.red));
      return;
    }

    final batch = widget.firestore.batch();
    int saved = 0;
    final validEntries = <Map<String, dynamic>>[];

    for (final student in _students) {
      final txt = _marksCtrl[student.rollNo]?.text.trim() ?? '';
      if (txt.isEmpty) continue;
      final marks = double.tryParse(txt);
      if (marks == null) continue;

      final docId = '${_windowId}_${_subjectCode}_${student.rollNo}';
      batch.set(
        widget.firestore.collection('makeupMidMarks').doc(docId),
        {
          'windowId': _windowId,
          'examSession': _examSession,
          'subjectCode': _subjectCode,
          'subjectName': _subjectName,
          'rollNo': student.rollNo,
          'studentName': student.name,
          'midMarks': marks,
          'maxMarks': _maxMarks,
          'facultyId': widget.facultyId,
          'uploadedAt': FieldValue.serverTimestamp(),
          'cieUpdated': false, // Will update this later if CIE was improved
        },
      );
      validEntries.add({'rollNo': student.rollNo, 'marks': marks});
      saved++;
    }

    await batch.commit();

    // Auto-update CIE studentMarks: replace the lowest mid component
    // with makeup marks if makeup marks are higher
    final updates = <String>[];
    final noMarks = <String>[]; // Students where CIE marks weren't found

    for (final entry in validEntries) {
      final rollNo = entry['rollNo'] as String;
      final makeupMark = entry['marks'] as double;

      final smSnap = await widget.firestore
          .collection('studentMarks')
          .where('studentId', isEqualTo: rollNo)
          .where('subjectCode', isEqualTo: _subjectCode)
          .get();

      // If no CIE marks exist for this subject, skip (student may not have enrolled)
      if (smSnap.docs.isEmpty) {
        noMarks.add(rollNo);
        continue;
      }

      // Try to update the CIE marks
      for (final smDoc in smSnap.docs) {
        try {
          final smData = smDoc.data();
          final compMarks =
              Map<String, dynamic>.from(smData['componentMarks'] ?? {});

          // Find all keys that contain 'mid' (case-insensitive)
          final midKeys = compMarks.keys
              .where((k) => k.toLowerCase().contains('mid'))
              .toList();

          if (midKeys.isEmpty) {
            // No mid components found - skip this student
            continue;
          }

          // Find the key with the lowest current value
          String? lowestKey;
          double lowestVal = double.infinity;
          for (final key in midKeys) {
            final val = (compMarks[key] as num?)?.toDouble() ?? 0;
            if (val < lowestVal) {
              lowestVal = val;
              lowestKey = key;
            }
          }

          // Update if makeup mark is higher
          if (lowestKey != null && makeupMark > lowestVal) {
            compMarks[lowestKey] = makeupMark.toInt();
            final newTotal = compMarks.values
                .fold<num>(0, (s, v) => s + ((v is num) ? v : 0))
                .toInt();

            await widget.firestore
                .collection('studentMarks')
                .doc(smDoc.id)
                .update({
              'componentMarks': compMarks,
              'totalMarks': newTotal,
              'updatedAt': FieldValue.serverTimestamp(),
            });

            // Mark makeup exam doc as having updated CIE
            final makeupDocId = '${_windowId}_${_subjectCode}_$rollNo';
            await widget.firestore
                .collection('makeupMidMarks')
                .doc(makeupDocId)
                .update({
              'cieUpdated': true,
              'updatedComponent': lowestKey,
              'oldValue': lowestVal.toInt(),
              'newValue': makeupMark.toInt(),
            });

            updates.add(
                '$rollNo: $lowestKey ${lowestVal.toInt()}→${makeupMark.toInt()}');
          }
        } catch (e) {
          // Continue processing other students even if one fails
        }
      }
    }

    if (mounted) {
      // Show detailed update summary
      String updateMsg = updates.isEmpty
          ? 'No CIE marks needed update'
          : 'CIE Updated (${updates.length}): ${updates.take(3).join(", ")}${updates.length > 3 ? "..." : ""}';

      String noMarksMsg = noMarks.isEmpty
          ? ''
          : '\n⚠️ ${noMarks.length} student(s) have no CIE marks yet (${noMarks.join(", ")})';

      final message = saved > 0
          ? 'Saved makeup marks for $saved student(s).\n$updateMsg$noMarksMsg'
          : 'No marks to save.';

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(message),
          backgroundColor: updates.isNotEmpty ? Colors.green : Colors.orange,
          duration: const Duration(seconds: 6)));

      // Show detailed dialog if updates or no-marks exist
      if (updates.length > 3 || noMarks.isNotEmpty) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Makeup Mid Processing Summary'),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (updates.isNotEmpty) ...[
                    Text(
                      '✓ ${updates.length} student(s) had CIE marks updated:',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.green),
                    ),
                    const SizedBox(height: 8),
                    Flexible(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: updates
                              .map((u) => Padding(
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 2),
                                    child: Text('• $u',
                                        style: const TextStyle(fontSize: 13)),
                                  ))
                              .toList(),
                        ),
                      ),
                    ),
                  ],
                  if (noMarks.isNotEmpty) ...[
                    if (updates.isNotEmpty) const SizedBox(height: 16),
                    Text(
                      '⚠️ ${noMarks.length} student(s) have no CIE marks yet:',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.orange),
                    ),
                    const SizedBox(height: 8),
                    Flexible(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: noMarks
                              .map((rollNo) => Padding(
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 2),
                                    child: Text('• $rollNo',
                                        style: const TextStyle(fontSize: 13)),
                                  ))
                              .toList(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'These students may not have taken regular CIE exams yet. Their makeup marks are saved but CIE will update once they have CIE marks.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      }

      _loadStudents();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _students.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'No students have registered for $_subjectCode '
                      'in this makeup mid window.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ),
                )
              : Column(
                  children: [
                    _buildHeader(),
                    _buildColumnHeadings(),
                    const Divider(height: 1),
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.all(8),
                        itemCount: _students.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, i) {
                          final s = _students[i];
                          return _MarksRow(
                            student: s,
                            ctrl: _marksCtrl[s.rollNo]!,
                            maxMarks: _maxMarks,
                          );
                        },
                      ),
                    ),
                    _buildSaveButton(),
                  ],
                ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      color: const Color(0xFFe8f0fe),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$_subjectCode — $_subjectName',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          Text(
            'Window: ${widget.assignment['windowTitle']}  •  Session: $_examSession',
            style: const TextStyle(fontSize: 12),
          ),
          Text(
            '${_students.length} registered student(s)  •  Max marks: $_maxMarks',
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildColumnHeadings() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Expanded(
              flex: 2,
              child: Text('Roll No',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
          Expanded(
              flex: 3,
              child: Text('Name',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
          SizedBox(
              width: 80,
              child: Text('Mid Marks',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
        ],
      ),
    );
  }

  Widget _buildSaveButton() {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _saveAll,
          icon: const Icon(Icons.save),
          label: const Text('Save All Marks'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1e3a5f),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// A single student row with editable marks
// ─────────────────────────────────────────────────────────────────────────
class _MarksRow extends StatefulWidget {
  final _MidStudent student;
  final TextEditingController ctrl;
  final int maxMarks;
  const _MarksRow(
      {required this.student, required this.ctrl, required this.maxMarks});

  @override
  State<_MarksRow> createState() => _MarksRowState();
}

class _MarksRowState extends State<_MarksRow> {
  bool _invalid = false;

  void _update() {
    final txt = widget.ctrl.text.trim();
    if (txt.isEmpty) {
      setState(() => _invalid = false);
      return;
    }
    final v = double.tryParse(txt);
    setState(() {
      _invalid = v == null || v < 0 || v > widget.maxMarks;
    });
  }

  @override
  void initState() {
    super.initState();
    widget.ctrl.addListener(_update);
    final v = double.tryParse(widget.ctrl.text.trim());
    _invalid = v != null && (v < 0 || v > widget.maxMarks);
  }

  @override
  void dispose() {
    widget.ctrl.removeListener(_update);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Expanded(
              flex: 2,
              child: Text(widget.student.rollNo,
                  style: const TextStyle(fontSize: 12))),
          Expanded(
              flex: 3,
              child: Text(widget.student.name,
                  style: const TextStyle(fontSize: 12))),
          SizedBox(
            width: 80,
            child: TextField(
              controller: widget.ctrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: _invalid ? Colors.red : Colors.black,
                fontWeight: FontWeight.bold,
              ),
              decoration: InputDecoration(
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                border: const OutlineInputBorder(),
                enabledBorder: OutlineInputBorder(
                  borderSide:
                      BorderSide(color: _invalid ? Colors.red : Colors.grey),
                ),
                hintText: '/${widget.maxMarks}',
                hintStyle: const TextStyle(fontSize: 11),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Data model
// ─────────────────────────────────────────────────────────────────────────
class _MidStudent {
  final String rollNo;
  final String name;
  final double? savedMarks;
  const _MidStudent(
      {required this.rollNo, required this.name, required this.savedMarks});
}
