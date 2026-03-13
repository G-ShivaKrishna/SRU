import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../screens/role_selection_screen.dart';
import '../../services/audit_log_service.dart';
import '../../services/user_service.dart';
import '../../services/session_service.dart';

// ─── Fee type configuration ───────────────────────────────────────────────────
class _FeeTypeConfig {
  final String label;
  final String paymentType;
  final String windowsCollection;
  final String windowIdField;
  const _FeeTypeConfig({
    required this.label,
    required this.paymentType,
    required this.windowsCollection,
    required this.windowIdField,
  });
}

const _feeTypes = <_FeeTypeConfig>[
  _FeeTypeConfig(
    label: 'Supply Exam Fee',
    paymentType: 'supply',
    windowsCollection: 'supplyWindows',
    windowIdField: 'supplyWindowId',
  ),
  _FeeTypeConfig(
    label: 'Makeup Mid Fee',
    paymentType: 'makeup_mid',
    windowsCollection: 'makeupMidWindows',
    windowIdField: 'makeupWindowId',
  ),
  _FeeTypeConfig(
    label: 'Regular Exam Fee',
    paymentType: 'regular_exam',
    windowsCollection: 'regularExamWindows',
    windowIdField: 'regularExamWindowId',
  ),
];

class FeePaymentHome extends StatefulWidget {
  const FeePaymentHome({super.key});

  static const String routeName = '/feePaymentHome';

  @override
  State<FeePaymentHome> createState() => _FeePaymentHomeState();
}

class _FeePaymentHomeState extends State<FeePaymentHome> {
  _FeeTypeConfig _selectedType = _feeTypes[0];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fee Payment Portal'),
        backgroundColor: const Color(0xFF1e3a5f),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () async {
            await SessionService.clearRole();
            await FirebaseAuth.instance.signOut();
            if (context.mounted) {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const RoleSelectionScreen()),
              );
            }
          },
        ),
      ),
      body: Column(
        children: [
          // ── Fee type selector ──────────────────────────────────────────
          Container(
            color: const Color(0xFF1e3a5f).withValues(alpha: 0.06),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: DropdownButtonFormField<_FeeTypeConfig>(
              initialValue: _selectedType,
              decoration: const InputDecoration(
                labelText: 'Select Fee Type',
                border: OutlineInputBorder(),
                isDense: true,
                filled: true,
                fillColor: Colors.white,
                prefixIcon: Icon(Icons.category_outlined),
              ),
              items: _feeTypes
                  .map((t) => DropdownMenuItem(
                        value: t,
                        child: Text(t.label),
                      ))
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _selectedType = v);
              },
            ),
          ),
          // ── Fee update panel (recreated on type change) ────────────────
          Expanded(
            child: _FeeUpdatePanel(
              key: ValueKey(_selectedType.paymentType),
              config: _selectedType,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Panel: windows dropdown + roll number input + paid/unpaid buttons + records
// ─────────────────────────────────────────────────────────────────────────────

class _FeeUpdatePanel extends StatefulWidget {
  final _FeeTypeConfig config;
  const _FeeUpdatePanel({super.key, required this.config});

  @override
  State<_FeeUpdatePanel> createState() => _FeeUpdatePanelState();
}

class _FeeUpdatePanelState extends State<_FeeUpdatePanel> {
  final _db = FirebaseFirestore.instance;
  final _rollCtrl = TextEditingController();
  bool _saving = false;
  String? _selectedWindowId;

  // Backlog / subjects state (supply only)
  List<Map<String, dynamic>> _backlogs = [];
  Set<String> _selectedSubjectCodes = {};
  bool _backlogsLoading = false;
  String _lastFetchedRoll = '';

  @override
  void dispose() {
    _rollCtrl.dispose();
    super.dispose();
  }

  bool get _isSupply => widget.config.paymentType == 'supply';
  bool get _isMakeupMid => widget.config.paymentType == 'makeup_mid';
  bool get _needsSubjectPicker => _isSupply || _isMakeupMid;

  /// Computes active backlogs from studentMarks + cieMemoReleases + supplyMarks,
  /// mirroring the same logic used in student_home.dart / results_screen.dart.
  Future<void> _loadBacklogs(String rollNo) async {
    if (!_isSupply || rollNo.isEmpty || _selectedWindowId == null) return;
    if (rollNo == _lastFetchedRoll) return;
    setState(() {
      _backlogsLoading = true;
      _backlogs = [];
      _selectedSubjectCodes = {};
      _lastFetchedRoll = rollNo;
    });
    try {
      String normSem(String s) {
        const m = {'i': '1', 'ii': '2', 'iii': '3', 'iv': '4'};
        return m[s.toLowerCase().trim()] ?? s.trim();
      }

      // 1. Release map: year_sem -> minPassMarks
      final relSnap = await _db.collection('cieMemoReleases').get();
      final releaseMap = <String, int>{};
      for (final d in relSnap.docs) {
        final r = d.data();
        final key = '${r['year']}_${normSem(r['semester']?.toString() ?? '')}';
        releaseMap[key] = (r['minPassMarks'] is int)
            ? r['minPassMarks'] as int
            : int.tryParse(r['minPassMarks']?.toString() ?? '') ?? 40;
      }

      // 2. Supply PASS set: codes cleared via supply exam
      final supplySnap = await _db
          .collection('supplyMarks')
          .where('rollNo', isEqualTo: rollNo)
          .get();
      final supplyPassSet = <String>{};
      for (final d in supplySnap.docs) {
        final data = d.data();
        if ((data['result'] as String? ?? '') == 'PASS') {
          final code = data['subjectCode']?.toString() ?? '';
          if (code.isNotEmpty) supplyPassSet.add(code);
        }
      }

      // 3. All marks for this student
      final marksSnap = await _db
          .collection('studentMarks')
          .where('studentId', isEqualTo: rollNo)
          .get();

      if (marksSnap.docs.isEmpty) {
        if (mounted) setState(() => _backlogsLoading = false);
        return;
      }

      // 4. Group by subjectCode
      final bySubject = <String, List<Map<String, dynamic>>>{};
      for (final doc in marksSnap.docs) {
        final d = Map<String, dynamic>.from(doc.data());
        final code = d['subjectCode']?.toString() ?? '';
        if (code.isEmpty) continue;
        bySubject.putIfAbsent(code, () => []).add(d);
      }

      // 5. Determine active (uncleared) backlogs
      final result = <Map<String, dynamic>>[];
      for (final entries in bySubject.values) {
        entries.sort((a, b) {
          final ya = int.tryParse(a['year']?.toString() ?? '') ?? 0;
          final yb = int.tryParse(b['year']?.toString() ?? '') ?? 0;
          if (ya != yb) return ya.compareTo(yb);
          return normSem(a['semester']?.toString() ?? '')
              .compareTo(normSem(b['semester']?.toString() ?? ''));
        });

        for (int i = 0; i < entries.length; i++) {
          final e = entries[i];
          final key =
              '${e['year']}_${normSem(e['semester']?.toString() ?? '')}';
          final minPass = releaseMap[key] ?? 40;
          final raw = e['componentMarks'] as Map<String, dynamic>? ?? {};
          int total = 0;
          for (final v in raw.values) {
            total += (v is int) ? v : int.tryParse(v.toString()) ?? 0;
          }
          if (total >= minPass) continue; // passed — not a backlog

          final code = e['subjectCode']?.toString() ?? '';
          bool clearedLater = false;
          for (int j = i + 1; j < entries.length; j++) {
            final later = entries[j];
            final lKey =
                '${later['year']}_${normSem(later['semester']?.toString() ?? '')}';
            final lMin = releaseMap[lKey] ?? 40;
            final lRaw = later['componentMarks'] as Map<String, dynamic>? ?? {};
            int lTotal = 0;
            for (final v in lRaw.values) {
              lTotal += (v is int) ? v : int.tryParse(v.toString()) ?? 0;
            }
            if (lTotal >= lMin) {
              clearedLater = true;
              break;
            }
          }
          if (!clearedLater && supplyPassSet.contains(code)) {
            clearedLater = true;
          }
          if (!clearedLater) {
            result.add({
              'subjectCode': code,
              'subjectName': e['subjectName']?.toString() ?? code,
              'semester': e['semester']?.toString() ?? '',
              'year': e['year']?.toString() ?? '',
            });
          }
        }
      }

      if (mounted) {
        setState(() {
          _backlogs = result;
          _backlogsLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _backlogsLoading = false);
    }
  }

  /// Fetches subjects the student registered for in course registrations (studentSubjectSelections).
  Future<void> _loadMakeupSubjects(String rollNo) async {
    if (!_isMakeupMid || rollNo.isEmpty || _selectedWindowId == null) return;
    if (rollNo == _lastFetchedRoll) return;
    setState(() {
      _backlogsLoading = true;
      _backlogs = [];
      _selectedSubjectCodes = {};
      _lastFetchedRoll = rollNo;
    });
    try {
      // 1. Get student's current year + semester
      final studentDoc = await _db.collection('students').doc(rollNo).get();
      String yearStr = '';
      String semStr = '';
      if (studentDoc.exists) {
        final sData = studentDoc.data()!;
        yearStr = sData['year']?.toString() ?? '';
        semStr = sData['semester']?.toString() ?? '';
      }

      // 2. Query studentSubjectSelections by studentId, match current year+sem
      final selSnap = await _db
          .collection('studentSubjectSelections')
          .where('studentId', isEqualTo: rollNo)
          .get();

      Map<String, dynamic>? selData;
      if (selSnap.docs.isNotEmpty) {
        if (yearStr.isNotEmpty && semStr.isNotEmpty) {
          final match = selSnap.docs.where((d) {
            final data = d.data();
            return data['year']?.toString() == yearStr &&
                data['semester']?.toString() == semStr;
          });
          selData = match.isNotEmpty ? match.first.data() : null;
        }
        selData ??= selSnap.docs.last.data();
      }

      final result = <Map<String, dynamic>>[];
      if (selData != null) {
        final allIds = [
          ...List<String>.from(selData['coreSubjectIds'] ?? []),
          ...List<String>.from(selData['selectedOEIds'] ?? []),
          ...List<String>.from(selData['selectedPEIds'] ?? []),
        ];
        for (int i = 0; i < allIds.length; i += 10) {
          final chunk = allIds.sublist(
              i, i + 10 > allIds.length ? allIds.length : i + 10);
          final snap = await _db
              .collection('subjects')
              .where(FieldPath.documentId, whereIn: chunk)
              .get();
          for (final doc in snap.docs) {
            final d = doc.data();
            final code = d['code']?.toString() ?? '';
            if (code.isEmpty) continue;
            result.add({
              'subjectCode': code,
              'subjectName': d['name']?.toString() ?? code,
              'semester': d['semester']?.toString() ?? semStr,
              'year': d['year']?.toString() ?? yearStr,
            });
          }
        }
      }

      result.sort((a, b) =>
          (a['subjectCode'] as String).compareTo(b['subjectCode'] as String));
      if (mounted) {
        setState(() {
          _backlogs = result;
          // Auto-select all registered subjects
          _selectedSubjectCodes = result
              .map((b) => b['subjectCode']?.toString() ?? '')
              .toSet()
            ..remove('');
          _backlogsLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _backlogsLoading = false);
    }
  }

  void _triggerSubjectLoad(String rollNo) {
    if (_isSupply) _loadBacklogs(rollNo);
    if (_isMakeupMid) _loadMakeupSubjects(rollNo);
  }

  Future<void> _openSubjectPicker(BuildContext context) async {
    final tmp = Set<String>.from(_selectedSubjectCodes);
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title:
              Text(_isSupply ? 'Select Backlog Subjects' : 'Select Subjects'),
          content: SizedBox(
            width: double.maxFinite,
            child: _backlogs.isEmpty
                ? Text(_isSupply
                    ? 'No backlogs found for this student.'
                    : 'No subjects found for this student.')
                : ListView(
                    shrinkWrap: true,
                    children: _backlogs.map((b) {
                      final code = b['subjectCode']?.toString() ??
                          b['code']?.toString() ??
                          '';
                      final name = b['subjectName']?.toString() ??
                          b['name']?.toString() ??
                          code;
                      final sem = b['semester']?.toString() ?? '';
                      return CheckboxListTile(
                        dense: true,
                        value: tmp.contains(code),
                        onChanged: (v) => setS(() {
                          if (v == true) {
                            tmp.add(code);
                          } else {
                            tmp.remove(code);
                          }
                        }),
                        title: Text(name, style: const TextStyle(fontSize: 13)),
                        subtitle: code.isNotEmpty
                            ? Text(
                                '$code${sem.isNotEmpty ? ' · Sem $sem' : ''}',
                                style: const TextStyle(fontSize: 11))
                            : null,
                        activeColor: const Color(0xFF1e3a5f),
                        controlAffinity: ListTileControlAffinity.leading,
                      );
                    }).toList(),
                  ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                setState(() => _selectedSubjectCodes = tmp);
                Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1e3a5f),
                  foregroundColor: Colors.white),
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _update(String status) async {
    final rollNo = _rollCtrl.text.trim().toUpperCase();
    if (rollNo.isEmpty) {
      _snack('Enter roll number', error: true);
      return;
    }
    if (_selectedWindowId == null) {
      _snack('Select a window / session', error: true);
      return;
    }

    setState(() => _saving = true);
    try {
      final windowDoc = await _db
          .collection(widget.config.windowsCollection)
          .doc(_selectedWindowId)
          .get();
      if (!windowDoc.exists) {
        _snack('Selected window not found', error: true);
        return;
      }

      final winData = windowDoc.data() ?? {};
      final windowTitle = winData['title']?.toString() ?? _selectedWindowId!;
      final examSession = winData['examSession']?.toString() ?? '';
      final feePerSubject = (winData['fee'] as num?)?.toDouble() ?? 0;
      final subjectCount =
          _needsSubjectPicker ? _selectedSubjectCodes.length : 1;
      final amount = status == 'paid'
          ? feePerSubject * (subjectCount > 0 ? subjectCount : 1)
          : 0.0;

      String studentName = '';
      if (status == 'paid') {
        final studentDoc = await _db.collection('students').doc(rollNo).get();
        studentName = studentDoc.data()?['name']?.toString() ?? '';
      }

      // Collect selected subject details
      final selectedSubjects = _backlogs
          .where((b) {
            final code =
                b['subjectCode']?.toString() ?? b['code']?.toString() ?? '';
            return _selectedSubjectCodes.contains(code);
          })
          .map((b) => {
                'code':
                    b['subjectCode']?.toString() ?? b['code']?.toString() ?? '',
                'name':
                    b['subjectName']?.toString() ?? b['name']?.toString() ?? '',
              })
          .toList();

      final staffEmail = FirebaseAuth.instance.currentUser?.email ?? '';
      final staffId = UserService.getCurrentUserId() ??
          staffEmail.split('@').first.toUpperCase();
      final docId =
          '${widget.config.paymentType}_${_selectedWindowId!}_$rollNo';

      await _db.collection('feePayments').doc(docId).set({
        'paymentType': widget.config.paymentType,
        'feeTypeLabel': widget.config.label,
        'windowId': _selectedWindowId,
        'windowTitle': windowTitle,
        'windowIdField': widget.config.windowIdField,
        'rollNo': rollNo,
        if (studentName.isNotEmpty) 'studentName': studentName,
        'examSession': examSession,
        'amount': amount,
        'status': status,
        if (_needsSubjectPicker && selectedSubjects.isNotEmpty)
          'subjects': selectedSubjects,
        if (_needsSubjectPicker) 'feePerSubject': feePerSubject,
        if (_needsSubjectPicker) 'subjectCount': subjectCount,
        'updatedBy': staffId,
        'updatedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      AuditLogService().logFeePayment(
        staffId: staffId,
        paymentType: widget.config.paymentType,
        windowId: _selectedWindowId!,
        studentRollNo: rollNo,
        status: status,
        amount: amount,
        additionalDetails: {
          'windowTitle': windowTitle,
          'examSession': examSession,
          'studentName': studentName,
          'feeType': widget.config.label,
          if (selectedSubjects.isNotEmpty) 'subjects': selectedSubjects,
        },
      );

      _snack('$rollNo marked as ${status.toUpperCase()}');
      _rollCtrl.clear();
      setState(() {
        _selectedSubjectCodes = {};
        _backlogs = [];
        _lastFetchedRoll = '';
      });
    } catch (e) {
      _snack('Failed: $e', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? Colors.red : Colors.green,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _db
          .collection(widget.config.windowsCollection)
          .where('isActive', isEqualTo: true)
          .snapshots(),
      builder: (context, snap) {
        // Show all windows that admin has marked active — trust isActive flag
        final windows = (snap.data?.docs ?? []).toList();

        // Reset window selection if it's no longer in the list
        if (_selectedWindowId != null &&
            windows.isNotEmpty &&
            !windows.any((w) => w.id == _selectedWindowId)) {
          _selectedWindowId = null;
        }

        final rollNo = _rollCtrl.text.trim().toUpperCase();
        final rollFilled = rollNo.isNotEmpty;
        final canAct = !_saving && rollFilled && _selectedWindowId != null;

        // Compute fee-per-subject from the selected window (for UI display)
        double _feePerSubject = 0;
        if (_selectedWindowId != null && windows.isNotEmpty) {
          final selWin = windows.where((w) => w.id == _selectedWindowId);
          if (selWin.isNotEmpty) {
            final wData = selWin.first.data() as Map<String, dynamic>;
            _feePerSubject = (wData['fee'] as num?)?.toDouble() ?? 0;
          }
        }
        final _totalFee = _needsSubjectPicker
            ? _feePerSubject * _selectedSubjectCodes.length
            : _feePerSubject;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Input card ──────────────────────────────────────────────
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.payment,
                            color: Color(0xFF1e3a5f), size: 20),
                        const SizedBox(width: 8),
                        Text(
                          widget.config.label,
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Window selector
                    if (snap.connectionState == ConnectionState.waiting)
                      const Center(
                          child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: CircularProgressIndicator(),
                      ))
                    else if (windows.isEmpty)
                      _InfoBox(
                        icon: Icons.info_outline,
                        color: Colors.orange,
                        text:
                            'No active windows declared by admin for "${widget.config.label}". Ask admin to create one.',
                      )
                    else
                      DropdownButtonFormField<String>(
                        initialValue: _selectedWindowId,
                        decoration: const InputDecoration(
                          labelText: 'Window / Session',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: windows.map((doc) {
                          final d = doc.data() as Map<String, dynamic>;
                          final title = d['title']?.toString() ?? doc.id;
                          final session = d['examSession']?.toString() ?? '';
                          final fee = d['fee'];
                          return DropdownMenuItem(
                            value: doc.id,
                            child: Text(
                              [
                                title,
                                if (session.isNotEmpty) session,
                                if (fee != null) '₹$fee',
                              ].join(' · '),
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: (v) {
                          setState(() {
                            _selectedWindowId = v;
                            _lastFetchedRoll = ''; // reset so backlogs reload
                          });
                          // Re-fetch if roll is already filled
                          final roll = _rollCtrl.text.trim().toUpperCase();
                          if (_needsSubjectPicker &&
                              roll.isNotEmpty &&
                              v != null) {
                            _triggerSubjectLoad(roll);
                          }
                        },
                      ),

                    const SizedBox(height: 12),
                    // Roll number
                    TextField(
                      controller: _rollCtrl,
                      textCapitalization: TextCapitalization.characters,
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        labelText: 'Student Roll Number',
                        hintText: 'e.g. 2203A51001',
                        border: const OutlineInputBorder(),
                        isDense: true,
                        prefixIcon: const Icon(Icons.person_outline),
                        helperText: _needsSubjectPicker
                            ? 'Press Enter / Search to load subjects'
                            : null,
                      ),
                      onChanged: (_) => setState(() {}),
                      onSubmitted: (v) {
                        final roll = v.trim().toUpperCase();
                        if (_needsSubjectPicker &&
                            roll.isNotEmpty &&
                            _selectedWindowId != null) {
                          _triggerSubjectLoad(roll);
                        }
                      },
                      onEditingComplete: () {
                        final roll = _rollCtrl.text.trim().toUpperCase();
                        if (_needsSubjectPicker &&
                            roll.isNotEmpty &&
                            _selectedWindowId != null) {
                          _triggerSubjectLoad(roll);
                        }
                        FocusScope.of(context).unfocus();
                      },
                    ),

                    // ── Subject picker (supply & makeup mid) ──────────
                    if (_needsSubjectPicker &&
                        rollFilled &&
                        _selectedWindowId != null) ...[
                      const SizedBox(height: 12),
                      GestureDetector(
                        onTap: _backlogsLoading
                            ? null
                            : () => _openSubjectPicker(context),
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText:
                                _isSupply ? 'Backlog Subjects' : 'Subjects',
                            border: const OutlineInputBorder(),
                            isDense: true,
                            suffixIcon: _backlogsLoading
                                ? const Padding(
                                    padding: EdgeInsets.all(10),
                                    child: SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2)),
                                  )
                                : const Icon(Icons.arrow_drop_down),
                          ),
                          child: Text(
                            _backlogsLoading
                                ? 'Loading...'
                                : _backlogs.isEmpty
                                    ? (_isSupply
                                        ? 'No backlogs found'
                                        : 'No subjects found')
                                    : _selectedSubjectCodes.isEmpty
                                        ? 'Tap to select subjects (${_backlogs.length} subject${_backlogs.length == 1 ? '' : 's'})'
                                        : '${_selectedSubjectCodes.length} of ${_backlogs.length} selected',
                            style: TextStyle(
                              fontSize: 14,
                              color: _selectedSubjectCodes.isNotEmpty
                                  ? Colors.black87
                                  : Colors.grey.shade600,
                            ),
                          ),
                        ),
                      ),
                      if (_selectedSubjectCodes.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: _backlogs.where((b) {
                            final code = b['subjectCode']?.toString() ??
                                b['code']?.toString() ??
                                '';
                            return _selectedSubjectCodes.contains(code);
                          }).map((b) {
                            final code = b['subjectCode']?.toString() ??
                                b['code']?.toString() ??
                                '';
                            final name = b['subjectName']?.toString() ??
                                b['name']?.toString() ??
                                code;
                            return Chip(
                              label: Text(
                                name.length > 20
                                    ? '${name.substring(0, 20)}…'
                                    : name,
                                style: const TextStyle(fontSize: 11),
                              ),
                              deleteIcon: const Icon(Icons.close, size: 14),
                              onDeleted: () => setState(
                                  () => _selectedSubjectCodes.remove(code)),
                              backgroundColor: const Color(0xFF1e3a5f)
                                  .withValues(alpha: 0.08),
                            );
                          }).toList(),
                        ),
                      ],
                    ],

                    // ── Fee summary ──────────────────────────────
                    if (_needsSubjectPicker &&
                        _selectedSubjectCodes.isNotEmpty &&
                        _feePerSubject > 0) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color:
                              const Color(0xFF1e3a5f).withValues(alpha: 0.06),
                          border: Border.all(
                              color: const Color(0xFF1e3a5f)
                                  .withValues(alpha: 0.25)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.currency_rupee,
                                size: 16, color: Color(0xFF1e3a5f)),
                            const SizedBox(width: 6),
                            Expanded(
                              child: RichText(
                                text: TextSpan(
                                  style: const TextStyle(
                                      fontSize: 13, color: Colors.black87),
                                  children: [
                                    TextSpan(
                                        text:
                                            '₹${_feePerSubject.toStringAsFixed(0)}',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600)),
                                    TextSpan(
                                        text:
                                            ' × ${_selectedSubjectCodes.length} subject${_selectedSubjectCodes.length == 1 ? '' : 's'} = '),
                                    TextSpan(
                                        text:
                                            '₹${_totalFee.toStringAsFixed(0)}',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                            color: Color(0xFF1e3a5f))),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 14),

                    // Buttons
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: canAct ? () => _update('paid') : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green.shade700,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: Colors.green.shade200,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            icon: _saving
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        color: Colors.white, strokeWidth: 2),
                                  )
                                : const Icon(Icons.check_circle_outline),
                            label: const Text('Mark PAID'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: canAct ? () => _update('unpaid') : null,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.orange.shade800,
                              side: BorderSide(color: Colors.orange.shade400),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            icon: const Icon(Icons.cancel_outlined),
                            label: const Text('Mark UNPAID'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Students can register only when their fee status is PAID for the selected window.',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),

            // ── Payment records ─────────────────────────────────────────
            if (_selectedWindowId != null && rollFilled) ...[
              const SizedBox(height: 14),
              _PaymentRecords(
                db: _db,
                paymentType: widget.config.paymentType,
                windowId: _selectedWindowId!,
                rollNo: rollNo,
              ),
            ],
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Payment records list with paid/unpaid summary counts
// ─────────────────────────────────────────────────────────────────────────────

class _PaymentRecords extends StatelessWidget {
  final FirebaseFirestore db;
  final String paymentType;
  final String windowId;
  final String rollNo;

  const _PaymentRecords({
    required this.db,
    required this.paymentType,
    required this.windowId,
    required this.rollNo,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: db
          .collection('feePayments')
          .where('paymentType', isEqualTo: paymentType)
          .where('windowId', isEqualTo: windowId)
          .where('rollNo', isEqualTo: rollNo)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        var docs = List.of(snap.data?.docs ?? []);
        docs.sort((a, b) {
          final ta = (a.data() as Map)['updatedAt'] as Timestamp?;
          final tb = (b.data() as Map)['updatedAt'] as Timestamp?;
          return (tb?.toDate() ?? DateTime(2000))
              .compareTo(ta?.toDate() ?? DateTime(2000));
        });
        if (docs.length > 50) docs = docs.sublist(0, 50);

        final paidCount =
            docs.where((d) => (d.data() as Map)['status'] == 'paid').length;
        final unpaidCount = docs.length - paidCount;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('Payment Records',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const Spacer(),
                _Badge(label: 'Paid: $paidCount', color: Colors.green),
                const SizedBox(width: 6),
                _Badge(label: 'Unpaid: $unpaidCount', color: Colors.orange),
              ],
            ),
            const SizedBox(height: 8),
            if (docs.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(14),
                  child: Text('No payment records yet.',
                      style: TextStyle(color: Colors.grey)),
                ),
              )
            else
              Card(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                child: Column(
                  children: docs.map((doc) {
                    final d = doc.data() as Map<String, dynamic>;
                    final isPaid = d['status'] == 'paid';
                    final name = d['studentName']?.toString() ?? '';
                    return ListTile(
                      dense: true,
                      leading: CircleAvatar(
                        radius: 14,
                        backgroundColor: isPaid
                            ? Colors.green.shade100
                            : Colors.orange.shade100,
                        child: Icon(
                          isPaid ? Icons.check : Icons.close,
                          size: 14,
                          color: isPaid
                              ? Colors.green.shade700
                              : Colors.orange.shade700,
                        ),
                      ),
                      title: Text(
                        d['rollNo']?.toString() ?? '',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        name.isNotEmpty
                            ? '$name · by ${d['updatedBy'] ?? '-'}'
                            : 'Updated by: ${d['updatedBy'] ?? '-'}',
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isPaid
                              ? Colors.green.shade50
                              : Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                              color: isPaid
                                  ? Colors.green.shade300
                                  : Colors.orange.shade300),
                        ),
                        child: Text(
                          isPaid ? 'PAID' : 'UNPAID',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                            color: isPaid
                                ? Colors.green.shade700
                                : Colors.orange.shade700,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Backlog list for a student — shown in supply fee payment panel
// ─────────────────────────────────────────────────────────────────────────────

class _InfoBox extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;
  const _InfoBox({required this.icon, required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
              child: Text(text,
                  style: const TextStyle(fontSize: 13, color: Colors.black87))),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.bold, color: color)),
    );
  }
}
