import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../widgets/app_header.dart';

// ─── Models ────────────────────────────────────────────────────────────────────

class _CieAssignment {
  final String docId;
  final String subjectCode;
  final String subjectName;
  final List<String> batches;
  final String academicYear;
  final String semester;
  final int year;

  const _CieAssignment({
    required this.docId,
    required this.subjectCode,
    required this.subjectName,
    required this.batches,
    required this.academicYear,
    required this.semester,
    required this.year,
  });
}

class _Component {
  final String name;
  final int maxMarks;
  final String type;
  const _Component({required this.name, required this.maxMarks, required this.type});
}

class _StudentRow {
  final String studentId;
  final String studentName;
  // componentName → TextEditingController
  final Map<String, TextEditingController> controllers;
  bool isSaved;
  bool isSaving = false;

  _StudentRow({
    required this.studentId,
    required this.studentName,
    required this.controllers,
    this.isSaved = false,
  });

  int totalEntered(List<_Component> comps) {
    int t = 0;
    for (final c in comps) {
      t += int.tryParse(controllers[c.name]?.text ?? '') ?? 0;
    }
    return t;
  }

  bool hasAnyValue(List<_Component> comps) =>
      comps.any((c) => (controllers[c.name]?.text ?? '').isNotEmpty);

  void dispose() {
    for (final ctrl in controllers.values) {
      ctrl.dispose();
    }
  }
}

// ─── Screen ────────────────────────────────────────────────────────────────────

class CieMarksScreen extends StatefulWidget {
  const CieMarksScreen({super.key});

  @override
  State<CieMarksScreen> createState() => _CieMarksScreenState();
}

class _CieMarksScreenState extends State<CieMarksScreen> {
  final _auth = FirebaseAuth.instance;
  final _fs = FirebaseFirestore.instance;

  // ── Phase 1: selection ──────────────────
  bool _loadingAssignments = true;
  String? _assignmentError;
  List<_CieAssignment> _assignments = [];
  _CieAssignment? _selectedAssignment;
  String? _selectedBatch;

  // ── Phase 2: marks entry ────────────────
  bool _loadingMarks = false;
  String? _marksError;
  List<_Component> _components = [];
  List<_StudentRow> _studentRows = [];
  int _maxTotalMarks = 0;
  bool _marksLoaded = false;

  // save-all state
  bool _savingAll = false;

  @override
  void initState() {
    super.initState();
    _loadAssignments();
  }

  @override
  void dispose() {
    for (final row in _studentRows) {
      row.dispose();
    }
    super.dispose();
  }

  // ── Load assignments ──────────────────────────────────────────────────────

  Future<void> _loadAssignments() async {
    setState(() { _loadingAssignments = true; _assignmentError = null; });
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('Not logged in');
      final facultyId = user.email!.split('@')[0].toUpperCase();

      final snap = await _fs
          .collection('facultyAssignments')
          .where('facultyId', isEqualTo: facultyId)
          .get();

      final list = <_CieAssignment>[];
      for (final doc in snap.docs) {
        final d = doc.data();
        if ((d['isActive'] ?? true) == true) {
          list.add(_CieAssignment(
            docId: doc.id,
            subjectCode: d['subjectCode'] ?? '',
            subjectName: d['subjectName'] ?? '',
            batches: List<String>.from(d['assignedBatches'] ?? []),
            academicYear: d['academicYear'] ?? '',
            semester: d['semester'] ?? '',
            year: (d['year'] ?? 0) is int ? d['year'] : int.tryParse(d['year'].toString()) ?? 0,
          ));
        }
      }

      if (!mounted) return;
      setState(() { _assignments = list; _loadingAssignments = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _assignmentError = e.toString(); _loadingAssignments = false; });
    }
  }

  // ── Load students + marks ─────────────────────────────────────────────────

  Future<void> _loadMarksEntry() async {
    final assignment = _selectedAssignment;
    final batch = _selectedBatch;
    if (assignment == null || batch == null) return;

    // Dispose old rows
    for (final row in _studentRows) row.dispose();

    setState(() { _loadingMarks = true; _marksError = null; _marksLoaded = false; _studentRows = []; });

    try {
      // 1. Load marksDefinition for this assignment
      final defDoc = await _fs.collection('marksDefinition').doc(assignment.docId).get();
      if (!defDoc.exists) {
        setState(() {
          _marksError = 'No marks format defined for this subject yet.\nGo to Marks Entry → Regular Exams → "Check & Define CIE Format" first.';
          _loadingMarks = false;
        });
        return;
      }
      final defData = defDoc.data()!;
      final compList = (defData['components'] as List<dynamic>? ?? [])
          .map((c) => _Component(
                name: c['name'] ?? '',
                maxMarks: (c['marks'] ?? 0) is int ? c['marks'] : int.tryParse(c['marks'].toString()) ?? 0,
                type: c['type'] ?? 'internal',
              ))
          .toList();

      // 2. Parse batch → department + batchNumber  e.g. "CSE-A" → dept="CSE", bn="A"
      final parts = batch.split('-');
      final dept = parts.length >= 2 ? parts.sublist(0, parts.length - 1).join('-') : batch;
      final batchNumber = parts.length >= 2 ? parts.last : '';

      // 3. Load students: single where (no composite index), filter in Dart
      final studentSnap = await _fs
          .collection('students')
          .where('department', isEqualTo: dept)
          .get();

      final students = studentSnap.docs.where((doc) {
        final d = doc.data();
        final bn = (d['batchNumber'] ?? '').toString();
        final yr = (d['year'] ?? 0) is int ? d['year'] as int : int.tryParse(d['year'].toString()) ?? 0;
        final status = (d['status'] ?? 'active').toString();
        return bn == batchNumber &&
            yr == assignment.year &&
            status != 'graduated' &&
            status != 'inactive';
      }).toList();

      // Sort by hallTicketNumber / doc ID
      students.sort((a, b) => a.id.compareTo(b.id));

      // 4. Load existing marks for this assignment (all batches, filter in Dart)
      final marksSnap = await _fs
          .collection('studentMarks')
          .where('assignmentId', isEqualTo: assignment.docId)
          .get();

      final existingMarks = <String, Map<String, dynamic>>{};
      for (final doc in marksSnap.docs) {
        final d = doc.data();
        if ((d['batch'] ?? '') == batch) {
          final sid = (d['studentId'] ?? '').toString();
          existingMarks[sid] = Map<String, dynamic>.from(d['componentMarks'] ?? {});
        }
      }

      // 5. Build rows
      final rows = students.map((doc) {
        final d = doc.data();
        final sid = doc.id;
        final name = (d['studentName'] ?? d['name'] ?? '').toString();
        final saved = existingMarks[sid];
        final controllers = <String, TextEditingController>{};
        for (final comp in compList) {
          final existing = saved != null
              ? (saved[comp.name] ?? '').toString()
              : '';
          controllers[comp.name] = TextEditingController(text: existing == '0' && saved == null ? '' : (existing == '0' ? '' : existing));
        }
        return _StudentRow(
          studentId: sid,
          studentName: name.isNotEmpty ? name : sid,
          controllers: controllers,
          isSaved: saved != null,
        );
      }).toList();

      if (!mounted) return;
      setState(() {
        _components = compList;
        _studentRows = rows;
        _maxTotalMarks = defData['totalMarks'] is int
            ? defData['totalMarks']
            : int.tryParse(defData['totalMarks'].toString()) ?? 0;
        _loadingMarks = false;
        _marksLoaded = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _marksError = e.toString(); _loadingMarks = false; });
    }
  }

  // ── Save single student ───────────────────────────────────────────────────

  Future<void> _saveRow(_StudentRow row) async {
    final assignment = _selectedAssignment!;
    final batch = _selectedBatch!;
    setState(() => row.isSaving = true);
    try {
      final facultyId = _auth.currentUser!.email!.split('@')[0].toUpperCase();
      final compMarks = <String, int>{};
      for (final c in _components) {
        compMarks[c.name] = int.tryParse(row.controllers[c.name]?.text ?? '') ?? 0;
      }
      final total = compMarks.values.fold(0, (s, v) => s + v);

      final docId = '${assignment.docId}_${batch.replaceAll('-', '_')}_${row.studentId}';
      await _fs.collection('studentMarks').doc(docId).set({
        'facultyId': facultyId,
        'assignmentId': assignment.docId,
        'subjectCode': assignment.subjectCode,
        'subjectName': assignment.subjectName,
        'academicYear': assignment.academicYear,
        'semester': assignment.semester,
        'year': assignment.year,
        'batch': batch,
        'studentId': row.studentId,
        'studentName': row.studentName,
        'componentMarks': compMarks,
        'totalMarks': total,
        'maxMarks': _maxTotalMarks,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;
      setState(() { row.isSaved = true; row.isSaving = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() => row.isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save ${row.studentId}: $e'), backgroundColor: Colors.red),
      );
    }
  }

  // ── Save all ──────────────────────────────────────────────────────────────

  Future<void> _saveAll() async {
    if (_studentRows.isEmpty) return;

    // Validate all rows
    for (final row in _studentRows) {
      for (final comp in _components) {
        final val = int.tryParse(row.controllers[comp.name]?.text ?? '');
        if (val == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${row.studentId}: "${comp.name}" must be a number'), backgroundColor: Colors.red),
          );
          return;
        }
        if (val < 0 || val > comp.maxMarks) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${row.studentId}: "${comp.name}" must be 0–${comp.maxMarks}'), backgroundColor: Colors.red),
          );
          return;
        }
      }
    }

    setState(() => _savingAll = true);
    final assignment = _selectedAssignment!;
    final batch = _selectedBatch!;
    final facultyId = _auth.currentUser!.email!.split('@')[0].toUpperCase();
    final now = FieldValue.serverTimestamp();

    try {
      final wb = _fs.batch();
      for (final row in _studentRows) {
        final compMarks = <String, int>{};
        for (final c in _components) {
          compMarks[c.name] = int.tryParse(row.controllers[c.name]?.text ?? '') ?? 0;
        }
        final total = compMarks.values.fold(0, (s, v) => s + v);
        final docId = '${assignment.docId}_${batch.replaceAll('-', '_')}_${row.studentId}';
        wb.set(
          _fs.collection('studentMarks').doc(docId),
          {
            'facultyId': facultyId,
            'assignmentId': assignment.docId,
            'subjectCode': assignment.subjectCode,
            'subjectName': assignment.subjectName,
            'academicYear': assignment.academicYear,
            'semester': assignment.semester,
            'year': assignment.year,
            'batch': batch,
            'studentId': row.studentId,
            'studentName': row.studentName,
            'componentMarks': compMarks,
            'totalMarks': total,
            'maxMarks': _maxTotalMarks,
            'updatedAt': now,
          },
          SetOptions(merge: true),
        );
      }
      await wb.commit();
      if (!mounted) return;
      setState(() {
        for (final row in _studentRows) row.isSaved = true;
        _savingAll = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Marks saved for ${_studentRows.length} students'), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _savingAll = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: $e'), backgroundColor: Colors.red),
      );
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Column(
        children: [
          const AppHeader(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loadingAssignments) return const Center(child: CircularProgressIndicator());
    if (_assignmentError != null) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.error_outline, size: 64, color: Colors.red),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(_assignmentError!, textAlign: TextAlign.center),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(onPressed: _loadAssignments, icon: const Icon(Icons.refresh), label: const Text('Retry')),
      ]));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Center(
                child: Text('CIE Marks Entry',
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.black87)),
              ),
              const SizedBox(height: 4),
              const Center(
                child: Text('Enter internal/external marks for your assigned courses',
                    style: TextStyle(color: Colors.grey, fontSize: 13), textAlign: TextAlign.center),
              ),
              const SizedBox(height: 20),
              _buildSelectionCard(),
              if (_loadingMarks) ...[
                const SizedBox(height: 32),
                const Center(child: CircularProgressIndicator()),
              ] else if (_marksError != null) ...[
                const SizedBox(height: 20),
                _buildErrorBox(_marksError!),
              ] else if (_marksLoaded) ...[
                const SizedBox(height: 20),
                _buildMarksTable(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ── Selection card ─────────────────────────────────────────────────────────

  Widget _buildSelectionCard() {
    final isMobile = MediaQuery.of(context).size.width < 700;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.tune, color: Color(0xFF1e3a5f), size: 18),
            const SizedBox(width: 8),
            const Text('Select Subject & Batch', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1e3a5f))),
          ]),
          const SizedBox(height: 16),
          if (_assignments.isEmpty)
            const Text('No active assignments found. Contact admin to assign courses.', style: TextStyle(color: Colors.grey))
          else ...[
            isMobile ? _buildSelectionMobile() : _buildSelectionDesktop(),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: (_selectedAssignment != null && _selectedBatch != null) ? _loadMarksEntry : null,
                icon: const Icon(Icons.search),
                label: const Text('Load Students'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1e3a5f),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSelectionDesktop() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(flex: 3, child: _buildSubjectDropdown()),
        const SizedBox(width: 16),
        Expanded(flex: 2, child: _buildBatchDropdown()),
      ],
    );
  }

  Widget _buildSelectionMobile() {
    return Column(children: [
      _buildSubjectDropdown(),
      const SizedBox(height: 12),
      _buildBatchDropdown(),
    ]);
  }

  Widget _buildSubjectDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Subject *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1e3a5f))),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: _selectedAssignment?.docId,
          isExpanded: true,
          decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
          hint: const Text('Select subject'),
          items: _assignments.map((a) {
            return DropdownMenuItem(
              value: a.docId,
              child: Text('${a.subjectCode} – ${a.subjectName}  (Y${a.year} Sem${a.semester})',
                  overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
            );
          }).toList(),
          onChanged: (id) {
            final a = _assignments.firstWhere((x) => x.docId == id);
            setState(() {
              _selectedAssignment = a;
              _selectedBatch = a.batches.length == 1 ? a.batches.first : null;
              _marksLoaded = false;
              _marksError = null;
              for (final row in _studentRows) row.dispose();
              _studentRows = [];
            });
          },
        ),
      ],
    );
  }

  Widget _buildBatchDropdown() {
    final batches = _selectedAssignment?.batches ?? [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Batch *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1e3a5f))),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: batches.contains(_selectedBatch) ? _selectedBatch : null,
          isExpanded: true,
          decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
          hint: const Text('Select batch'),
          items: batches.map((b) => DropdownMenuItem(value: b, child: Text(b))).toList(),
          onChanged: batches.isEmpty ? null : (b) {
            setState(() {
              _selectedBatch = b;
              _marksLoaded = false;
              _marksError = null;
              for (final row in _studentRows) row.dispose();
              _studentRows = [];
            });
          },
        ),
      ],
    );
  }

  // ── Error box ──────────────────────────────────────────────────────────────

  Widget _buildErrorBox(String msg) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        border: Border.all(color: Colors.orange[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: Colors.orange[700], size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(msg, style: TextStyle(color: Colors.orange[800]))),
        ],
      ),
    );
  }

  // ── Marks table ────────────────────────────────────────────────────────────

  Widget _buildMarksTable() {
    final isMobile = MediaQuery.of(context).size.width < 800;
    final a = _selectedAssignment!;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFF1e3a5f),
              borderRadius: BorderRadius.vertical(top: Radius.circular(7)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${a.subjectCode} – ${a.subjectName}',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 4),
                Wrap(spacing: 12, children: [
                  _headerInfo('Batch: $_selectedBatch'),
                  _headerInfo('Year ${a.year}  |  Sem ${a.semester}'),
                  _headerInfo('AY: ${a.academicYear}'),
                  _headerInfo('Max Marks: $_maxTotalMarks'),
                  _headerInfo('${_studentRows.length} students'),
                  _headerInfo('Components: ${_components.map((c) => "${c.name} (${c.maxMarks})").join("  •  ")}'),
                ]),
              ],
            ),
          ),
          // Students
          if (_studentRows.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Column(children: [
                  Icon(Icons.people_outline, size: 48, color: Colors.grey[400]),
                  const SizedBox(height: 12),
                  const Text('No students found in this batch.', style: TextStyle(color: Colors.grey, fontSize: 14)),
                  const SizedBox(height: 4),
                  Text('Check that students have department & batchNumber matching "$_selectedBatch".',
                      style: TextStyle(color: Colors.grey[500], fontSize: 12), textAlign: TextAlign.center),
                ]),
              ),
            )
          else
            isMobile
                ? _buildMobileList()
                : _buildDesktopTable(),
          // Save all footer
          if (_studentRows.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.grey[200]!)),
                color: Colors.grey[50],
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(7)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${_studentRows.where((r) => r.isSaved).length}/${_studentRows.length} saved',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  ElevatedButton.icon(
                    onPressed: _savingAll ? null : _saveAll,
                    icon: _savingAll
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.save, size: 16),
                    label: Text(_savingAll ? 'Saving...' : 'Save All Marks'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[700],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _headerInfo(String text) {
    return Text(text, style: const TextStyle(color: Colors.white70, fontSize: 11));
  }

  // ── Desktop table ──────────────────────────────────────────────────────────

  Widget _buildDesktopTable() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        constraints: BoxConstraints(minWidth: MediaQuery.of(context).size.width - 64),
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(Colors.grey[100]),
          columnSpacing: 16,
          columns: [
            const DataColumn(label: Text('S.No', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
            const DataColumn(label: Text('Roll No', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
            const DataColumn(label: SizedBox(width: 180, child: Text('Student Name', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)))),
            ..._components.map((c) => DataColumn(
                label: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(c.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                    Text('/ ${c.maxMarks}', style: TextStyle(fontSize: 10, color: Colors.grey[600])),
                  ],
                ))),
            const DataColumn(label: Text('Total', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
            const DataColumn(label: Text('', style: TextStyle(fontSize: 12))),
          ],
          rows: _studentRows.asMap().entries.map((entry) {
            final i = entry.key;
            final row = entry.value;
            final total = row.totalEntered(_components);
            final isOver = total > _maxTotalMarks;
            return DataRow(
              color: WidgetStateProperty.resolveWith((states) {
                if (row.isSaved) return Colors.green.withOpacity(0.04);
                return null;
              }),
              cells: [
                DataCell(Text('${i + 1}', style: const TextStyle(fontSize: 12))),
                DataCell(Text(row.studentId, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500))),
                DataCell(SizedBox(width: 180, child: Text(row.studentName, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis))),
                ..._components.map((c) => DataCell(_marksField(row, c))),
                DataCell(Text(
                  '$total / $_maxTotalMarks',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: isOver ? Colors.red : total == _maxTotalMarks ? Colors.green : Colors.black87,
                  ),
                )),
                DataCell(
                  row.isSaving
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : IconButton(
                          icon: Icon(
                            row.isSaved ? Icons.check_circle : Icons.save_outlined,
                            size: 18,
                            color: row.isSaved ? Colors.green : const Color(0xFF1e3a5f),
                          ),
                          tooltip: row.isSaved ? 'Saved – click to re-save' : 'Save this row',
                          onPressed: () => _saveRow(row),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _marksField(_StudentRow row, _Component comp) {
    return SizedBox(
      width: 70,
      child: StatefulBuilder(builder: (ctx, setMarksState) {
        return TextField(
          controller: row.controllers[comp.name],
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13),
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            border: const OutlineInputBorder(),
            errorText: (() {
              final val = int.tryParse(row.controllers[comp.name]?.text ?? '');
              if (val != null && val > comp.maxMarks) return '>max';
              return null;
            })(),
          ),
          onChanged: (_) {
            setMarksState(() {});
            setState(() { row.isSaved = false; });
          },
        );
      }),
    );
  }

  // ── Mobile list ────────────────────────────────────────────────────────────

  Widget _buildMobileList() {
    return Column(
      children: _studentRows.asMap().entries.map((entry) {
        final i = entry.key;
        final row = entry.value;
        return Column(children: [
          if (i > 0) Divider(height: 1, color: Colors.grey[200]),
          _buildMobileStudentCard(i + 1, row),
        ]);
      }).toList(),
    );
  }

  Widget _buildMobileStudentCard(int serial, _StudentRow row) {
    final total = row.totalEntered(_components);
    final isOver = total > _maxTotalMarks;

    return Container(
      color: row.isSaved ? Colors.green.withOpacity(0.04) : null,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: const Color(0xFF1e3a5f).withOpacity(0.1),
                child: Text('$serial', style: const TextStyle(fontSize: 11, color: Color(0xFF1e3a5f), fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(row.studentId, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    Text(row.studentName, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                  ],
                ),
              ),
              Text(
                '$total / $_maxTotalMarks',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13,
                    color: isOver ? Colors.red : total == _maxTotalMarks ? Colors.green : Colors.black87),
              ),
              const SizedBox(width: 8),
              row.isSaving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : IconButton(
                      icon: Icon(row.isSaved ? Icons.check_circle : Icons.save_outlined,
                          size: 20, color: row.isSaved ? Colors.green : const Color(0xFF1e3a5f)),
                      onPressed: () => _saveRow(row),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _components.map((c) => SizedBox(
              width: 120,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${c.name} (/${c.maxMarks})', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Color(0xFF1e3a5f))),
                  const SizedBox(height: 4),
                  TextField(
                    controller: row.controllers[c.name],
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 13),
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => setState(() => row.isSaved = false),
                  ),
                ],
              ),
            )).toList(),
          ),
        ],
      ),
    );
  }
}
