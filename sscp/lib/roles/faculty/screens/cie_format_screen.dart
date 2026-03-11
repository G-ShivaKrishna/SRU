import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../widgets/app_header.dart';

// ─── Data models ───────────────────────────────────────────────────────────────

class _MarksComponent {
  String name;
  int marks;
  String type; // 'internal' | 'external'

  _MarksComponent(
      {required this.name, required this.marks, required this.type});

  Map<String, dynamic> toMap() => {'name': name, 'marks': marks, 'type': type};

  static _MarksComponent fromMap(Map<String, dynamic> m) => _MarksComponent(
        name: m['name'] ?? '',
        marks: (m['marks'] ?? 0) is int
            ? m['marks']
            : int.tryParse(m['marks'].toString()) ?? 0,
        type: m['type'] ?? 'internal',
      );

  _MarksComponent copy() =>
      _MarksComponent(name: name, marks: marks, type: type);
}

class _Assignment {
  final String docId;
  final String subjectCode;
  final String subjectName;
  final List<String> batches;
  final String academicYear;
  final String semester;
  final int year;

  const _Assignment({
    required this.docId,
    required this.subjectCode,
    required this.subjectName,
    required this.batches,
    required this.academicYear,
    required this.semester,
    required this.year,
  });
}

class _Definition {
  final String assignmentId;
  int totalMarks;
  List<_MarksComponent> components;
  final DateTime? updatedAt;

  _Definition({
    required this.assignmentId,
    required this.totalMarks,
    required this.components,
    this.updatedAt,
  });

  int get componentSum => components.fold(0, (s, c) => s + c.marks);
  bool get isValid => componentSum == totalMarks && totalMarks > 0;
}

// ─── Screen ────────────────────────────────────────────────────────────────────

class CieFormatScreen extends StatefulWidget {
  const CieFormatScreen({super.key});

  @override
  State<CieFormatScreen> createState() => _CieFormatScreenState();
}

class _CieFormatScreenState extends State<CieFormatScreen> {
  final _auth = FirebaseAuth.instance;
  final _fs = FirebaseFirestore.instance;

  bool _isLoading = true;
  String? _loadError;

  List<_Assignment> _assignments = [];
  // assignmentId → definition (if saved)
  Map<String, _Definition> _definitions = {};
  // sorted academic years
  List<String> _sortedYears = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  // ── Load ───────────────────────────────────────────────────────────────────

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('Not logged in');
      final userEmail = user.email!;

      // Query faculty collection by email to get actual facultyId (doc ID)
      final facultyDocs = await _fs
          .collection('faculty')
          .where('email', isEqualTo: userEmail)
          .limit(1)
          .get();
      if (facultyDocs.docs.isEmpty) {
        throw Exception('Faculty profile not found');
      }
      final facultyId = facultyDocs.docs.first.id;

      // Load assignments
      final snap = await _fs
          .collection('facultyAssignments')
          .where('facultyId', isEqualTo: facultyId)
          .get();

      final assignments = <_Assignment>[];
      for (final doc in snap.docs) {
        final d = doc.data();
        if ((d['isActive'] ?? true) == true) {
          assignments.add(_Assignment(
            docId: doc.id,
            subjectCode: d['subjectCode'] ?? '',
            subjectName: d['subjectName'] ?? '',
            batches: List<String>.from(d['assignedBatches'] ?? []),
            academicYear: d['academicYear'] ?? '',
            semester: d['semester'] ?? '',
            year: (d['year'] ?? 0) is int
                ? d['year']
                : int.tryParse(d['year'].toString()) ?? 0,
          ));
        }
      }

      // Load existing definitions (one query per faculty to avoid composite index)
      final defSnap = await _fs
          .collection('marksDefinition')
          .where('facultyId', isEqualTo: facultyId)
          .get();

      final definitions = <String, _Definition>{};
      for (final doc in defSnap.docs) {
        final d = doc.data();
        final assignId = d['assignmentId'] as String? ?? doc.id;
        definitions[assignId] = _Definition(
          assignmentId: assignId,
          totalMarks: (d['totalMarks'] ?? 0) is int
              ? d['totalMarks']
              : int.tryParse(d['totalMarks'].toString()) ?? 0,
          components: (d['components'] as List<dynamic>? ?? [])
              .map((c) => _MarksComponent.fromMap(Map<String, dynamic>.from(c)))
              .toList(),
          updatedAt: (d['updatedAt'] as Timestamp?)?.toDate(),
        );
      }

      // Group by academic year
      final years = <String>{};
      for (final a in assignments) {
        years.add(a.academicYear.isNotEmpty ? a.academicYear : 'Unknown');
      }
      final sortedYears = years.toList()..sort((a, b) => b.compareTo(a));

      if (!mounted) return;
      setState(() {
        _assignments = assignments;
        _definitions = definitions;
        _sortedYears = sortedYears;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e.toString();
        _isLoading = false;
      });
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

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
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_loadError != null) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text('Error: $_loadError', textAlign: TextAlign.center),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry')),
        ]),
      );
    }
    if (_assignments.isEmpty) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.assignment_outlined, size: 72, color: Colors.grey[400]),
          const SizedBox(height: 16),
          const Text('No assigned courses found',
              style: TextStyle(fontSize: 18, color: Colors.grey)),
          const SizedBox(height: 8),
          const Text(
            'You need to have courses assigned by the admin\nbefore defining marks format.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.grey),
          ),
        ]),
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Center(
                child: Text(
                  'Check & Define CIE Format',
                  style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87),
                ),
              ),
              const SizedBox(height: 6),
              const Center(
                child: Text(
                  'Define the total marks and their distribution for each assigned course',
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 20),
              ..._sortedYears.asMap().entries.map((e) => Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _buildYearSection(e.value, e.key == 0),
                  )),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildYearSection(String year, bool isCurrent) {
    final courses = _assignments.where((a) {
      final ay = a.academicYear.isNotEmpty ? a.academicYear : 'Unknown';
      return ay == year;
    }).toList();

    final headerColor =
        isCurrent ? const Color(0xFF1e3a5f) : const Color(0xFF546e7a);
    final defined =
        courses.where((c) => _definitions.containsKey(c.docId)).length;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: headerColor,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(7)),
            ),
            child: Row(
              children: [
                const Icon(Icons.menu_book, color: Colors.white70, size: 18),
                const SizedBox(width: 8),
                Text(
                  isCurrent
                      ? 'Current Academic Year ($year)'
                      : 'Academic Year ($year)',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(12)),
                  child: Text(
                    '$defined/${courses.length} defined',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          // Course rows
          ...courses.asMap().entries.map((entry) {
            if (entry.key > 0) {
              return Column(children: [
                Divider(height: 1, color: Colors.grey[200]),
                _buildCourseRow(entry.value),
              ]);
            }
            return _buildCourseRow(entry.value);
          }),
        ],
      ),
    );
  }

  Widget _buildCourseRow(_Assignment a) {
    final def = _definitions[a.docId];
    final isDefined = def != null;
    final isMobile = MediaQuery.of(context).size.width < 700;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: isMobile
          ? _buildCourseRowMobile(a, def, isDefined)
          : _buildCourseRowDesktop(a, def, isDefined),
    );
  }

  Widget _buildCourseRowDesktop(
      _Assignment a, _Definition? def, bool isDefined) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Subject info
        Expanded(
          flex: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1e3a5f).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(a.subjectCode,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: Color(0xFF1e3a5f))),
                ),
                const SizedBox(width: 8),
                Flexible(
                    child: Text(a.subjectName,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13))),
              ]),
              const SizedBox(height: 6),
              Wrap(spacing: 6, runSpacing: 4, children: [
                _infoChip(Icons.calendar_today, a.academicYear),
                _infoChip(Icons.layers, 'Year ${a.year}  Sem ${a.semester}'),
                ...a.batches.map((b) => _batchChip(b)),
              ]),
            ],
          ),
        ),
        const SizedBox(width: 16),
        // Definition summary
        Expanded(
          flex: 3,
          child: isDefined
              ? _buildDefSummary(def!)
              : const Text('Not defined yet',
                  style: TextStyle(color: Colors.grey, fontSize: 12)),
        ),
        const SizedBox(width: 16),
        // Action button
        ElevatedButton.icon(
          onPressed: () => _openDefineDialog(a, def),
          icon: Icon(isDefined ? Icons.edit : Icons.add, size: 16),
          label: Text(isDefined ? 'Edit' : 'Define'),
          style: ElevatedButton.styleFrom(
            backgroundColor:
                isDefined ? Colors.orange[700] : const Color(0xFF1e3a5f),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            textStyle: const TextStyle(fontSize: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildCourseRowMobile(
      _Assignment a, _Definition? def, bool isDefined) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1e3a5f).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(a.subjectCode,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                              color: Color(0xFF1e3a5f))),
                    ),
                  ]),
                  const SizedBox(height: 4),
                  Text(a.subjectName,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 4),
                  Text(
                      'Year ${a.year} • Sem ${a.semester} • ${a.batches.join(", ")}',
                      style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                ],
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () => _openDefineDialog(a, def),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    isDefined ? Colors.orange[700] : const Color(0xFF1e3a5f),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                textStyle: const TextStyle(fontSize: 12),
              ),
              child: Text(isDefined ? 'Edit' : 'Define'),
            ),
          ],
        ),
        if (isDefined) ...[
          const SizedBox(height: 8),
          _buildDefSummary(def!),
        ],
      ],
    );
  }

  Widget _buildDefSummary(_Definition def) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const Icon(Icons.check_circle, size: 14, color: Colors.green),
          const SizedBox(width: 4),
          Text('Total: ${def.totalMarks} marks',
              style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  color: Colors.green)),
          const SizedBox(width: 8),
          if (def.updatedAt != null)
            Text(
              'Updated ${_dateStr(def.updatedAt!)}',
              style: TextStyle(fontSize: 11, color: Colors.grey[500]),
            ),
        ]),
        const SizedBox(height: 4),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: def.components
              .map((c) => Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: c.type == 'external'
                          ? Colors.orange.withOpacity(0.12)
                          : Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: c.type == 'external'
                              ? Colors.orange.withOpacity(0.4)
                              : Colors.blue.withOpacity(0.3)),
                    ),
                    child: Text(
                      '${c.name}: ${c.marks}',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: c.type == 'external'
                              ? Colors.orange[800]
                              : Colors.blue[800]),
                    ),
                  ))
              .toList(),
        ),
      ],
    );
  }

  // ── Dialog ─────────────────────────────────────────────────────────────────

  void _openDefineDialog(_Assignment a, _Definition? existing) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _DefineMarksDialog(
        assignment: a,
        existing: existing,
        onSave: (def) async {
          await _saveDefinition(a, def);
        },
      ),
    );
  }

  Future<void> _saveDefinition(_Assignment a, _Definition def) async {
    try {
      final user = _auth.currentUser!;
      final facultyId = user.email!.split('@')[0].toUpperCase();
      final now = Timestamp.now();

      // ── Check if components changed vs existing definition ──────────────
      final existing = _definitions[a.docId];
      bool componentsChanged = false;
      if (existing != null) {
        final oldKeys = existing.components.map((c) => c.name).toSet();
        final newKeys = def.components.map((c) => c.name).toSet();
        componentsChanged = oldKeys.length != newKeys.length ||
            !oldKeys.every((k) => newKeys.contains(k));
      }

      // ── If components changed, confirm and wipe old studentMarks ────────
      if (componentsChanged) {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Format Changed — Clear Existing Marks?'),
            content: const Text(
              'The component structure has changed.\n\n'
              'All previously entered marks for this subject will be deleted '
              'so faculty can re-enter them with the new format.\n\n'
              'This cannot be undone.',
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red, foregroundColor: Colors.white),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Clear & Save'),
              ),
            ],
          ),
        );
        if (confirm != true) return;

        // Delete all studentMarks for this assignment in batches
        QuerySnapshot toDelete;
        do {
          toDelete = await _fs
              .collection('studentMarks')
              .where('assignmentId', isEqualTo: a.docId)
              .limit(400)
              .get();
          if (toDelete.docs.isEmpty) break;
          final batch = _fs.batch();
          for (final doc in toDelete.docs) {
            batch.delete(doc.reference);
          }
          await batch.commit();
        } while (toDelete.docs.length == 400);
      }

      await _fs.collection('marksDefinition').doc(a.docId).set({
        'facultyId': facultyId,
        'assignmentId': a.docId,
        'subjectCode': a.subjectCode,
        'subjectName': a.subjectName,
        'academicYear': a.academicYear,
        'semester': a.semester,
        'year': a.year,
        'batches': a.batches,
        'totalMarks': def.totalMarks,
        'components': def.components.map((c) => c.toMap()).toList(),
        'definedAt': existing != null
            ? (existing.updatedAt != null
                ? Timestamp.fromDate(existing.updatedAt!)
                : now)
            : now,
        'updatedAt': now,
      });

      // Update local state
      if (mounted) {
        setState(() {
          _definitions[a.docId] = _Definition(
            assignmentId: a.docId,
            totalMarks: def.totalMarks,
            components: def.components.map((c) => c.copy()).toList(),
            updatedAt: DateTime.now(),
          );
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(componentsChanged
                  ? 'Format updated & old marks cleared. Please re-enter marks.'
                  : 'Marks format saved successfully'),
              backgroundColor:
                  componentsChanged ? Colors.orange[700] : Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed to save: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  Widget _infoChip(IconData icon, String label) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 12, color: Colors.grey[600]),
      const SizedBox(width: 3),
      Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[700])),
    ]);
  }

  Widget _batchChip(String batch) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFF1e3a5f).withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF1e3a5f).withOpacity(0.25)),
      ),
      child: Text(batch,
          style: const TextStyle(fontSize: 11, color: Color(0xFF1e3a5f))),
    );
  }

  String _dateStr(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

// ─── Define Marks Dialog ───────────────────────────────────────────────────────

class _DefineMarksDialog extends StatefulWidget {
  final _Assignment assignment;
  final _Definition? existing;
  final Future<void> Function(_Definition) onSave;

  const _DefineMarksDialog(
      {required this.assignment, this.existing, required this.onSave});

  @override
  State<_DefineMarksDialog> createState() => _DefineMarksDialogState();
}

class _DefineMarksDialogState extends State<_DefineMarksDialog> {
  late final TextEditingController _totalCtrl;
  late List<_MarksComponent> _components;
  bool _saving = false;
  String? _error;

  // default template
  static const _defaultComponents = [
    ('Mid Sem 1', 15, 'internal'),
    ('Mid Sem 2', 15, 'internal'),
    ('Assignment/Quiz', 10, 'internal'),
    ('End Term Exam', 60, 'external'),
  ];

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      _totalCtrl =
          TextEditingController(text: widget.existing!.totalMarks.toString());
      _components = widget.existing!.components.map((c) => c.copy()).toList();
    } else {
      _totalCtrl = TextEditingController(text: '100');
      _components = _defaultComponents
          .map((t) => _MarksComponent(name: t.$1, marks: t.$2, type: t.$3))
          .toList();
    }
  }

  @override
  void dispose() {
    _totalCtrl.dispose();
    super.dispose();
  }

  int get _totalMarks => int.tryParse(_totalCtrl.text) ?? 0;
  int get _componentSum => _components.fold(0, (s, c) => s + c.marks);
  int get _remaining => _totalMarks - _componentSum;

  void _addComponent() {
    setState(() {
      _components.add(_MarksComponent(name: '', marks: 0, type: 'internal'));
    });
  }

  void _removeComponent(int i) {
    setState(() => _components.removeAt(i));
  }

  Future<void> _save() async {
    _validate();
    if (_error != null) return;
    setState(() => _saving = true);
    try {
      final def = _Definition(
        assignmentId: widget.assignment.docId,
        totalMarks: _totalMarks,
        components: _components.map((c) => c.copy()).toList(),
      );
      await widget.onSave(def);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() {
        _saving = false;
        _error = e.toString();
      });
    }
  }

  void _validate() {
    if (_totalMarks <= 0) {
      setState(() => _error = 'Total marks must be greater than 0');
      return;
    }
    for (final c in _components) {
      if (c.name.trim().isEmpty) {
        setState(() => _error = 'All components must have a name');
        return;
      }
      if (c.marks <= 0) {
        setState(() => _error = 'All component marks must be greater than 0');
        return;
      }
    }
    if (_remaining != 0) {
      setState(() => _error = _remaining > 0
          ? 'Components sum is less than total by $_remaining marks'
          : 'Components sum exceeds total by ${-_remaining} marks');
      return;
    }
    setState(() => _error = null);
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.assignment;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 620),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: const BoxDecoration(
                color: Color(0xFF1e3a5f),
                borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Define Marks Format',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16)),
                  const SizedBox(height: 2),
                  Text('${a.subjectCode} • ${a.subjectName}',
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 12)),
                  const SizedBox(height: 2),
                  Text(
                      'Year ${a.year} | Sem ${a.semester} | ${a.batches.join(", ")}',
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
            ),
            // Body
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Total marks
                    Row(
                      children: [
                        const Text('Total Marks',
                            style: TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 14)),
                        const SizedBox(width: 16),
                        SizedBox(
                          width: 120,
                          child: TextField(
                            controller: _totalCtrl,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly
                            ],
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              isDense: true,
                            ),
                            onChanged: (_) => setState(() {
                              _error = null;
                            }),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // Components header
                    Row(
                      children: [
                        const Expanded(
                            child: Text('Mark Components',
                                style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14))),
                        TextButton.icon(
                          onPressed: _addComponent,
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('Add Component'),
                          style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFF1e3a5f)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Components table header
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(6)),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: const Row(
                        children: [
                          Expanded(
                              flex: 3,
                              child: Text('Name',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1)),
                          SizedBox(width: 8),
                          SizedBox(
                              width: 70,
                              child: Text('Marks',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12))),
                          SizedBox(width: 8),
                          SizedBox(
                              width: 105,
                              child: Text('Type',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12))),
                          SizedBox(width: 40),
                        ],
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        border: Border(
                          left: BorderSide(color: Colors.grey[300]!),
                          right: BorderSide(color: Colors.grey[300]!),
                          bottom: BorderSide(color: Colors.grey[300]!),
                        ),
                        borderRadius: const BorderRadius.vertical(
                            bottom: Radius.circular(6)),
                      ),
                      child: Column(
                        children: _components.asMap().entries.map((entry) {
                          final i = entry.key;
                          final c = entry.value;
                          return _ComponentRow(
                            component: c,
                            isLast: i == _components.length - 1,
                            onDelete: () => _removeComponent(i),
                            onChange: () => setState(() {
                              _error = null;
                            }),
                          );
                        }).toList(),
                      ),
                    ),
                    // Sum indicator
                    const SizedBox(height: 12),
                    _buildSumIndicator(),
                    // Error
                    if (_error != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.red[50],
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.red[300]!),
                        ),
                        child: Text(_error!,
                            style: TextStyle(
                                color: Colors.red[700], fontSize: 12)),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            // Actions
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.grey[200]!)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed:
                        _saving ? null : () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.save, size: 16),
                    label: Text(_saving ? 'Saving...' : 'Save Format'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1e3a5f),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSumIndicator() {
    final sum = _componentSum;
    final total = _totalMarks;
    final isOk = sum == total && total > 0;
    final over = sum > total;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isOk
            ? Colors.green[50]
            : over
                ? Colors.red[50]
                : Colors.orange[50],
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
            color: isOk
                ? Colors.green[300]!
                : over
                    ? Colors.red[300]!
                    : Colors.orange[300]!),
      ),
      child: Row(
        children: [
          Icon(
            isOk ? Icons.check_circle : Icons.info_outline,
            size: 16,
            color: isOk
                ? Colors.green[700]
                : over
                    ? Colors.red[700]
                    : Colors.orange[700],
          ),
          const SizedBox(width: 8),
          Text(
            'Components sum: $sum / $total',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: isOk
                  ? Colors.green[700]
                  : over
                      ? Colors.red[700]
                      : Colors.orange[700],
            ),
          ),
          const SizedBox(width: 8),
          if (!isOk)
            Text(
              over ? '(${sum - total} over)' : '(${total - sum} remaining)',
              style: TextStyle(
                  fontSize: 12,
                  color: over ? Colors.red[700] : Colors.orange[700]),
            ),
          if (isOk)
            Text('✓ Balanced',
                style: TextStyle(fontSize: 12, color: Colors.green[700])),
        ],
      ),
    );
  }
}

// ─── Component Row ─────────────────────────────────────────────────────────────

class _ComponentRow extends StatefulWidget {
  final _MarksComponent component;
  final bool isLast;
  final VoidCallback onDelete;
  final VoidCallback onChange;

  const _ComponentRow({
    required this.component,
    required this.isLast,
    required this.onDelete,
    required this.onChange,
  });

  @override
  State<_ComponentRow> createState() => _ComponentRowState();
}

class _ComponentRowState extends State<_ComponentRow> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _marksCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.component.name);
    _marksCtrl = TextEditingController(
        text: widget.component.marks > 0
            ? widget.component.marks.toString()
            : '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _marksCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        border: widget.isLast
            ? null
            : Border(bottom: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Row(
        children: [
          // Name
          Expanded(
            flex: 3,
            child: TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                hintText: 'e.g., Mid Sem 1',
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                isDense: true,
              ),
              style: const TextStyle(fontSize: 13),
              onChanged: (v) {
                widget.component.name = v;
                widget.onChange();
              },
            ),
          ),
          const SizedBox(width: 8),
          // Marks
          SizedBox(
            width: 70,
            child: TextField(
              controller: _marksCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                hintText: '0',
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                isDense: true,
              ),
              style: const TextStyle(fontSize: 13),
              onChanged: (v) {
                widget.component.marks = int.tryParse(v) ?? 0;
                widget.onChange();
              },
            ),
          ),
          const SizedBox(width: 8),
          // Type
          SizedBox(
            width: 105,
            child: DropdownButtonFormField<String>(
              initialValue: widget.component.type,
              isDense: true,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              ),
              items: const [
                DropdownMenuItem(
                    value: 'internal',
                    child: Text('Internal', style: TextStyle(fontSize: 12))),
                DropdownMenuItem(
                    value: 'external',
                    child: Text('External', style: TextStyle(fontSize: 12))),
              ],
              onChanged: (v) {
                setState(() => widget.component.type = v ?? 'internal');
                widget.onChange();
              },
            ),
          ),
          const SizedBox(width: 8),
          // Delete
          SizedBox(
            width: 32,
            child: IconButton(
              icon:
                  const Icon(Icons.delete_outline, size: 18, color: Colors.red),
              onPressed: widget.onDelete,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ),
        ],
      ),
    );
  }
}
