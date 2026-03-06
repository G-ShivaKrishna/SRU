import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../services/audit_log_service.dart';
import '../../../services/user_service.dart';

/// Faculty: Supply Exam Marks Entry
/// - Shows subjects assigned to this faculty via [supplySubjectAssignments]
/// - For each subject, lists only students who registered for that supply window
/// - Pre-fills internal marks from [studentMarks] (sum of non-ETE components)
/// - Faculty enters external marks only
/// - Saves to [supplyMarks] collection
class SupplyMarksScreen extends StatefulWidget {
  const SupplyMarksScreen({super.key});

  @override
  State<SupplyMarksScreen> createState() => _SupplyMarksScreenState();
}

class _SupplyMarksScreenState extends State<SupplyMarksScreen> {
  final _firestore = FirebaseFirestore.instance;
  late final String _facultyId;
  bool _loading = true;

  List<Map<String, dynamic>> _assignments = [];
  Map<String, dynamic>? _selectedAssignment;

  @override
  void initState() {
    super.initState();
    final email = FirebaseAuth.instance.currentUser?.email ?? '';
    _facultyId = UserService.getCurrentUserId() ?? email.split('@')[0].toUpperCase();
    _loadAssignments();
  }

  Future<void> _loadAssignments() async {
    setState(() => _loading = true);
    final snap = await _firestore
        .collection('supplySubjectAssignments')
        .where('facultyId', isEqualTo: _facultyId)
        .get();

    final list = <Map<String, dynamic>>[];
    for (final doc in snap.docs) {
      final data = doc.data();
      // Load window title and check if window is still active
      String windowTitle = data['windowId']?.toString() ?? '';
      bool isWindowActive = false;
      try {
        final winDoc = await _firestore
            .collection('supplyWindows')
            .doc(data['windowId']?.toString())
            .get();
        if (winDoc.exists) {
          final winData = winDoc.data()!;
          windowTitle = (winData['title'] as String?) ?? windowTitle;
          isWindowActive = (winData['isActive'] as bool?) ?? false;
        }
      } catch (_) {}

      // Only include assignments for active/enabled windows
      if (isWindowActive) {
        list.add({
          ...data,
          'docId': doc.id,
          'windowTitle': windowTitle,
        });
      }
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
        title: const Text('Supply Exam Marks'),
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
              : _SupplyMarksEntry(
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
            'No supply exam subjects assigned to you yet.\n'
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
            'Your Assigned Supply Exam Subjects',
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
                    child: Icon(Icons.book, color: Colors.white, size: 18),
                  ),
                  title: Text(
                    '${a['subjectCode']} — ${a['subjectName']}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  subtitle: Text(
                    '${a['windowTitle']}\n${a['examSession'] ?? ''}',
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
// Marks Entry for a specific subject × window
// ═══════════════════════════════════════════════════════════════════════════

class _SupplyMarksEntry extends StatefulWidget {
  final FirebaseFirestore firestore;
  final String facultyId;
  final Map<String, dynamic> assignment;

  const _SupplyMarksEntry({
    required this.firestore,
    required this.facultyId,
    required this.assignment,
  });

  @override
  State<_SupplyMarksEntry> createState() => _SupplyMarksEntryState();
}

class _SupplyMarksEntryState extends State<_SupplyMarksEntry> {
  bool _loading = true;
  List<_SupplyStudent> _students = [];
  final Map<String, TextEditingController> _extCtrl = {};

  String get _windowId => widget.assignment['windowId']?.toString() ?? '';
  String get _subjectCode => widget.assignment['subjectCode']?.toString() ?? '';
  String get _subjectName => widget.assignment['subjectName']?.toString() ?? '';
  String get _examSession => widget.assignment['examSession']?.toString() ?? '';

  @override
  void initState() {
    super.initState();
    _loadStudents();
  }

  @override
  void dispose() {
    for (final c in _extCtrl.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadStudents() async {
    setState(() => _loading = true);

    // 1) All registrations for this window
    final regSnap = await widget.firestore
        .collection('supplyRegistrations')
        .where('supplyWindowId', isEqualTo: _windowId)
        .get();

    // 2) Filter those that include this subject
    final registered = <Map<String, dynamic>>[];
    for (final doc in regSnap.docs) {
      final d = doc.data();
      final subjects = List<Map<String, dynamic>>.from(
          (d['subjects'] as List? ?? [])
              .map((s) => Map<String, dynamic>.from(s as Map)));
      final has =
          subjects.any((s) => s['subjectCode']?.toString() == _subjectCode);
      if (has) registered.add(d);
    }

    // 3) For each registered student, load internal marks + existing supply marks
    final students = <_SupplyStudent>[];
    for (final r in registered) {
      final rollNo = r['rollNo']?.toString() ?? '';
      final studentName = r['studentName']?.toString() ?? rollNo;

      // Internal marks from studentMarks (non-ETE components sum)
      double internal = 0;
      try {
        final marksSnap = await widget.firestore
            .collection('studentMarks')
            .where('studentId', isEqualTo: rollNo)
            .where('subjectCode', isEqualTo: _subjectCode)
            .limit(1)
            .get();
        if (marksSnap.docs.isNotEmpty) {
          final cm = Map<String, dynamic>.from(
              marksSnap.docs.first.data()['componentMarks'] as Map? ?? {});
          double sum = 0;
          for (final entry in cm.entries) {
            final isEte = entry.key.toUpperCase().contains('ETE') ||
                entry.key.toUpperCase().contains('END TERM') ||
                entry.key.toUpperCase().contains('EXTERNAL');
            if (!isEte) {
              final v = entry.value;
              sum += (v is num ? v : double.tryParse(v.toString()) ?? 0);
            }
          }
          internal = sum;
        }
      } catch (_) {}

      // Existing supply marks
      double? savedExternal;
      try {
        final supSnap = await widget.firestore
            .collection('supplyMarks')
            .where('windowId', isEqualTo: _windowId)
            .where('subjectCode', isEqualTo: _subjectCode)
            .where('rollNo', isEqualTo: rollNo)
            .limit(1)
            .get();
        if (supSnap.docs.isNotEmpty) {
          final sd = supSnap.docs.first.data();
          savedExternal = (sd['externalMarks'] as num?)?.toDouble();
        }
      } catch (_) {}

      students.add(_SupplyStudent(
        rollNo: rollNo,
        name: studentName,
        internalMarks: internal,
        savedExternal: savedExternal,
      ));

      // Init text controllers
      _extCtrl[rollNo] = TextEditingController(
          text: savedExternal != null ? savedExternal.toStringAsFixed(0) : '');
    }

    if (mounted) {
      setState(() {
        _students = students;
        _loading = false;
      });
    }
  }

  String _calcGrade(double total) {
    if (total >= 90) return 'O';
    if (total >= 80) return 'A+';
    if (total >= 70) return 'A';
    if (total >= 60) return 'B+';
    if (total >= 50) return 'B';
    if (total >= 45) return 'C';
    return 'F';
  }

  Future<void> _saveAll() async {
    // Validate that the supply window is still active/enabled before saving
    try {
      final winDoc = await widget.firestore
          .collection('supplyWindows')
          .doc(_windowId)
          .get();
      if (!winDoc.exists || (winDoc.data()?['isActive'] ?? false) != true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'This supply window has been disabled by admin. Cannot save marks.'),
            backgroundColor: Colors.red,
          ));
        }
        return;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error checking window status: $e'),
          backgroundColor: Colors.red,
        ));
      }
      return;
    }

    final batch = widget.firestore.batch();
    int saved = 0;

    for (final student in _students) {
      final extStr = _extCtrl[student.rollNo]?.text.trim() ?? '';
      if (extStr.isEmpty) continue;
      final ext = double.tryParse(extStr);
      if (ext == null || ext < 0 || ext > 70) continue;

      final total = student.internalMarks + ext;
      final pass = ext >= 28 && total >= 45;
      final grade = pass ? _calcGrade(total) : 'F';
      final docId = '${_windowId}_${_subjectCode}_${student.rollNo}';

      batch.set(
        widget.firestore.collection('supplyMarks').doc(docId),
        {
          'windowId': _windowId,
          'examSession': _examSession,
          'subjectCode': _subjectCode,
          'subjectName': _subjectName,
          'rollNo': student.rollNo,
          'studentName': student.name,
          'internalMarks': student.internalMarks,
          'externalMarks': ext,
          'totalMarks': total,
          'grade': grade,
          'result': pass ? 'PASS' : 'FAIL',
          'facultyId': widget.facultyId,
          'uploadedAt': FieldValue.serverTimestamp(),
        },
      );
      saved++;
    }

    await batch.commit();

    // Log audit trail
    if (saved > 0) {
      final studentRolls = _students
          .where((s) => (_extCtrl[s.rollNo]?.text.trim() ?? '').isNotEmpty)
          .map((s) => s.rollNo)
          .toList();
      AuditLogService().logMarksPosting(
        facultyId: widget.facultyId,
        marksType: 'supply',
        courseCode: _subjectCode,
        section: _examSession,
        studentRollNos: studentRolls,
        additionalDetails: {
          'windowId': _windowId,
          'examSession': _examSession,
          'studentCount': saved,
        },
      );
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Saved marks for $saved student(s).'),
          backgroundColor: Colors.green));
      // Reload
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
                      'No students have registered for $_subjectCode in this supply window.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ),
                )
              : Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      color: const Color(0xFFe8f0fe),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$_subjectCode — $_subjectName',
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                          Text(
                              'Window: ${widget.assignment['windowTitle']}  •  Session: $_examSession',
                              style: const TextStyle(fontSize: 12)),
                          Text('${_students.length} registered student(s)',
                              style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                    const Padding(
                      padding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      child: Row(
                        children: [
                          Expanded(
                              flex: 2,
                              child: Text('Roll No',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12))),
                          Expanded(
                              flex: 3,
                              child: Text('Name',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12))),
                          SizedBox(
                              width: 56,
                              child: Text('Int',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12))),
                          SizedBox(
                              width: 70,
                              child: Text('Ext /70',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12))),
                          SizedBox(
                              width: 56,
                              child: Text('Total',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12))),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.all(8),
                        itemCount: _students.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, i) {
                          final s = _students[i];
                          return _StudentMarksRow(
                            student: s,
                            extCtrl: _extCtrl[s.rollNo]!,
                          );
                        },
                      ),
                    ),
                    Padding(
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
                    ),
                  ],
                ),
    );
  }
}

class _StudentMarksRow extends StatefulWidget {
  final _SupplyStudent student;
  final TextEditingController extCtrl;
  const _StudentMarksRow({required this.student, required this.extCtrl});

  @override
  State<_StudentMarksRow> createState() => _StudentMarksRowState();
}

class _StudentMarksRowState extends State<_StudentMarksRow> {
  double? _extPreview;

  void _updatePreview() {
    final v = double.tryParse(widget.extCtrl.text.trim());
    setState(() => _extPreview = v);
  }

  @override
  void initState() {
    super.initState();
    widget.extCtrl.addListener(_updatePreview);
    _extPreview = double.tryParse(widget.extCtrl.text.trim());
  }

  @override
  void dispose() {
    widget.extCtrl.removeListener(_updatePreview);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final internal = widget.student.internalMarks;
    final ext = _extPreview;
    final total = ext != null ? internal + ext : null;
    final pass = ext != null ? (ext >= 28 && total! >= 45) : null;

    Color rowColor = Colors.transparent;
    if (pass == true) rowColor = Colors.green.shade50;
    if (pass == false) rowColor = Colors.red.shade50;

    return Container(
      color: rowColor,
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
                  style: const TextStyle(fontSize: 12),
                  overflow: TextOverflow.ellipsis)),
          SizedBox(
            width: 56,
            child: Text(internal.toStringAsFixed(1),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12)),
          ),
          SizedBox(
            width: 70,
            child: TextFormField(
              controller: widget.extCtrl,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                hintText: '—',
                errorText: ext != null && (ext < 0 || ext > 70) ? '0-70' : null,
              ),
            ),
          ),
          SizedBox(
            width: 56,
            child: Text(
              total != null ? total.toStringAsFixed(1) : '—',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: pass == true
                    ? Colors.green
                    : pass == false
                        ? Colors.red
                        : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SupplyStudent {
  final String rollNo;
  final String name;
  final double internalMarks;
  final double? savedExternal;

  const _SupplyStudent({
    required this.rollNo,
    required this.name,
    required this.internalMarks,
    this.savedExternal,
  });
}
