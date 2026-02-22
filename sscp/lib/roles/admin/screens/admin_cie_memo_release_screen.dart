import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../widgets/app_header.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Data model for a CIE Memo Release
// ─────────────────────────────────────────────────────────────────────────────

class CieMemoRelease {
  final String id;
  final String year;
  final String semester;
  final String branch;
  final String academicYear;
  final String examSession;
  final DateTime releasedAt;
  final String releasedBy;
  final bool isActive;
  final int minPassMarks;

  const CieMemoRelease({
    required this.id,
    required this.year,
    required this.semester,
    required this.branch,
    required this.academicYear,
    required this.examSession,
    required this.releasedAt,
    required this.releasedBy,
    required this.isActive,
    this.minPassMarks = 40,
  });

  factory CieMemoRelease.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data()! as Map<String, dynamic>;
    return CieMemoRelease(
      id: doc.id,
      year: (d['year'] ?? '').toString(),
      semester: (d['semester'] ?? '').toString(),
      branch: (d['branch'] ?? 'ALL').toString(),
      academicYear: (d['academicYear'] ?? '').toString(),
      examSession: (d['examSession'] ?? '').toString(),
      releasedAt: (d['releasedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      releasedBy: (d['releasedBy'] ?? '').toString(),
      isActive: d['isActive'] as bool? ?? true,
      minPassMarks: (d['minPassMarks'] is int)
          ? d['minPassMarks'] as int
          : int.tryParse(d['minPassMarks']?.toString() ?? '') ?? 40,
    );
  }

  String get displayLabel =>
      'Year $year • Sem $semester • ${branch == 'ALL' ? 'All Branches' : branch}';
}

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────

class AdminCieMemoReleaseScreen extends StatefulWidget {
  const AdminCieMemoReleaseScreen({super.key});

  @override
  State<AdminCieMemoReleaseScreen> createState() =>
      _AdminCieMemoReleaseScreenState();
}

class _AdminCieMemoReleaseScreenState extends State<AdminCieMemoReleaseScreen> {
  final _fs = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  // ── Form state ──────────────────────────────────────────────────────────────
  String _selYear = '4';
  String _selSemester = '1';
  String _selBranch = 'CSE';
  final _academicYearCtrl = TextEditingController(text: '2025-26');
  final _examSessionCtrl = TextEditingController(text: 'NOV 2025');
  final _minPassMarksCtrl = TextEditingController(text: '40');

  bool _releasing = false;

  static const _years = ['1', '2', '3', '4'];
  static const _semesters = ['1', '2'];
  static const _branches = [
    'ALL',
    'CSE',
    'ECE',
    'EEE',
    'MECH',
    'CIVIL',
    'IT',
    'MBA',
    'MCA',
  ];

  @override
  void dispose() {
    _academicYearCtrl.dispose();
    _examSessionCtrl.dispose();
    _minPassMarksCtrl.dispose();
    super.dispose();
  }

  // ── Release action ──────────────────────────────────────────────────────────

  Future<void> _releaseMemo() async {
    if (_academicYearCtrl.text.trim().isEmpty ||
        _examSessionCtrl.text.trim().isEmpty) {
      _snack('Please fill Academic Year and Exam Session', isError: true);
      return;
    }

    final minMarks = int.tryParse(_minPassMarksCtrl.text.trim());
    if (minMarks == null || minMarks < 0 || minMarks > 100) {
      _snack('Minimum pass marks must be a number between 0 and 100',
          isError: true);
      return;
    }

    // Check duplicate active release — single .where() to avoid composite index
    try {
      final existing = await _fs
          .collection('cieMemoReleases')
          .where('isActive', isEqualTo: true)
          .get();

      final isDuplicate = existing.docs.any((doc) {
        final d = doc.data();
        return d['year']?.toString() == _selYear &&
            d['semester']?.toString() == _selSemester &&
            d['branch']?.toString() == _selBranch;
      });

      if (isDuplicate) {
        _snack(
            'A memo is already released for Year $_selYear Sem $_selSemester $_selBranch. Revoke it first.',
            isError: true);
        return;
      }
    } catch (e) {
      _snack('Could not verify existing releases: $e', isError: true);
      return;
    }

    final confirmed = await _confirmDialog();
    if (!confirmed) return;

    setState(() => _releasing = true);

    try {
      final user = _auth.currentUser;
      final releasedBy = user?.email ?? 'admin';

      await _fs.collection('cieMemoReleases').add({
        'year': _selYear,
        'semester': _selSemester,
        'branch': _selBranch,
        'academicYear': _academicYearCtrl.text.trim(),
        'examSession': _examSessionCtrl.text.trim(),
        'minPassMarks': minMarks,
        'releasedAt': FieldValue.serverTimestamp(),
        'releasedBy': releasedBy,
        'isActive': true,
      });

      _snack(
          'CIE Memo released for Year $_selYear Sem $_selSemester ${_selBranch == 'ALL' ? '(All Branches)' : _selBranch}');
    } catch (e) {
      _snack('Failed to release memo: $e', isError: true);
    } finally {
      if (mounted) setState(() => _releasing = false);
    }
  }

  Future<void> _revokeMemo(CieMemoRelease release) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Revoke CIE Memo?'),
        content: Text(
            'This will hide the memo from students for:\n${release.displayLabel} — ${release.examSession}\n\nStudents will no longer be able to view it.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Revoke', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await _fs
        .collection('cieMemoReleases')
        .doc(release.id)
        .update({'isActive': false});
    _snack('Memo revoked for ${release.displayLabel}');
  }

  Future<bool> _confirmDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Release CIE Memo?'),
        content: Text(
            'This will make CIE marks visible as a formatted memo to:\n\n'
            '• Year: $_selYear  •  Semester: $_selSemester\n'
            '• Branch: ${_selBranch == 'ALL' ? 'All Branches' : _selBranch}\n'
            '• Academic Year: ${_academicYearCtrl.text.trim()}\n'
            '• Exam Session: ${_examSessionCtrl.text.trim()}\n\n'
            'Students will be able to view their CIE marks memo immediately.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1e3a5f)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Release', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.red : Colors.green,
    ));
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 700;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('CIE Memo Release'),
        backgroundColor: const Color(0xFF1e3a5f),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          const AppHeader(),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(isMobile ? 12 : 20),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 900),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildReleaseForm(isMobile),
                      const SizedBox(height: 28),
                      _buildReleaseHistory(isMobile),
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

  // ── Release form ─────────────────────────────────────────────────────────────

  Widget _buildReleaseForm(bool isMobile) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 14 : 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ────────────────────────────────────────────────────────
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1e3a5f),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.assignment_turned_in,
                      color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Release New CIE Memo',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1e3a5f),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Once released, students matching the Year, Semester and Branch will be able to view their CIE marks as a formatted memo.',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            const Divider(height: 28),

            // ── Form grid ─────────────────────────────────────────────────────
            isMobile ? _buildFormMobile() : _buildFormDesktop(),

            const SizedBox(height: 20),

            // ── Release button ────────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1e3a5f),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: _releasing ? null : _releaseMemo,
                icon: _releasing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.lock_open, color: Colors.white),
                label: Text(
                  _releasing ? 'Releasing...' : 'Release CIE Memo to Students',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormDesktop() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
                child: _dropdownField('Year', _years, _selYear,
                    (v) => setState(() => _selYear = v!))),
            const SizedBox(width: 16),
            Expanded(
                child: _dropdownField('Semester', _semesters, _selSemester,
                    (v) => setState(() => _selSemester = v!))),
            const SizedBox(width: 16),
            Expanded(
                child: _dropdownField('Branch', _branches, _selBranch,
                    (v) => setState(() => _selBranch = v!))),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
                child: _textField(
                    'Academic Year', _academicYearCtrl, 'e.g. 2025-26')),
            const SizedBox(width: 16),
            Expanded(
                child: _textField(
                    'Exam Session', _examSessionCtrl, 'e.g. NOV 2025')),
            const SizedBox(width: 16),
            Expanded(
              child: _numericField(
                'Min. Pass Marks (out of 100)',
                _minPassMarksCtrl,
                'e.g. 40',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFormMobile() {
    return Column(
      children: [
        _dropdownField(
            'Year', _years, _selYear, (v) => setState(() => _selYear = v!)),
        const SizedBox(height: 12),
        _dropdownField('Semester', _semesters, _selSemester,
            (v) => setState(() => _selSemester = v!)),
        const SizedBox(height: 12),
        _dropdownField('Branch', _branches, _selBranch,
            (v) => setState(() => _selBranch = v!)),
        const SizedBox(height: 12),
        _textField('Academic Year', _academicYearCtrl, 'e.g. 2025-26'),
        const SizedBox(height: 12),
        _textField('Exam Session', _examSessionCtrl, 'e.g. NOV 2025'),
        const SizedBox(height: 12),
        _numericField(
            'Min. Pass Marks (out of 100)', _minPassMarksCtrl, 'e.g. 40'),
      ],
    );
  }

  Widget _dropdownField(String label, List<String> items, String value,
      ValueChanged<String?> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1e3a5f))),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: value,
          decoration: InputDecoration(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            isDense: true,
          ),
          items: items
              .map((e) => DropdownMenuItem(
                  value: e,
                  child: Text(e, style: const TextStyle(fontSize: 13))))
              .toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _textField(String label, TextEditingController ctrl, String hint) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1e3a5f))),
        const SizedBox(height: 6),
        TextFormField(
          controller: ctrl,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(fontSize: 12, color: Colors.grey[400]),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            isDense: true,
          ),
          style: const TextStyle(fontSize: 13),
        ),
      ],
    );
  }

  Widget _numericField(String label, TextEditingController ctrl, String hint) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1e3a5f))),
        const SizedBox(height: 6),
        TextFormField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(fontSize: 12, color: Colors.grey[400]),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            isDense: true,
            suffixText: '/ 100',
            suffixStyle: TextStyle(fontSize: 12, color: Colors.grey[500]),
          ),
          style: const TextStyle(fontSize: 13),
        ),
      ],
    );
  }

  // ── Release history ──────────────────────────────────────────────────────────

  Widget _buildReleaseHistory(bool isMobile) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 14 : 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.teal,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.history_edu,
                      color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Released Memos',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1e3a5f),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            StreamBuilder<QuerySnapshot>(
              stream: _fs
                  .collection('cieMemoReleases')
                  .orderBy('releasedAt', descending: true)
                  .snapshots(),
              builder: (ctx, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (!snap.hasData || snap.data!.docs.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      children: [
                        Icon(Icons.assignment_outlined,
                            size: 48, color: Colors.grey[400]),
                        const SizedBox(height: 12),
                        Text(
                          'No memos released yet.\nUse the form above to release the first CIE memo.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  );
                }

                final releases = snap.data!.docs
                    .map((d) => CieMemoRelease.fromFirestore(d))
                    .toList();

                if (isMobile) {
                  return Column(
                    children:
                        releases.map((r) => _buildReleaseTile(r)).toList(),
                  );
                }

                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(
                        const Color(0xFF1e3a5f).withOpacity(0.08)),
                    columns: const [
                      DataColumn(
                          label: Text('Year',
                              style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(
                          label: Text('Sem',
                              style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(
                          label: Text('Branch',
                              style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(
                          label: Text('Academic Year',
                              style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(
                          label: Text('Exam Session',
                              style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(
                          label: Text('Status',
                              style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(
                          label: Text('Min Pass',
                              style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(
                          label: Text('Released At',
                              style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(
                          label: Text('Action',
                              style: TextStyle(fontWeight: FontWeight.bold))),
                    ],
                    rows: releases.map((r) {
                      return DataRow(cells: [
                        DataCell(Text(r.year)),
                        DataCell(Text(r.semester)),
                        DataCell(Text(r.branch)),
                        DataCell(Text(r.academicYear)),
                        DataCell(Text(r.examSession)),
                        DataCell(_statusBadge(r.isActive)),
                        DataCell(Text('${r.minPassMarks}/100')),
                        DataCell(Text(_formatDate(r.releasedAt))),
                        DataCell(
                          r.isActive
                              ? TextButton.icon(
                                  onPressed: () => _revokeMemo(r),
                                  icon: const Icon(Icons.lock,
                                      size: 16, color: Colors.red),
                                  label: const Text('Revoke',
                                      style: TextStyle(
                                          color: Colors.red, fontSize: 12)),
                                )
                              : const Text('Revoked',
                                  style: TextStyle(
                                      color: Colors.grey, fontSize: 12)),
                        ),
                      ]);
                    }).toList(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReleaseTile(CieMemoRelease r) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: r.isActive ? Colors.green.shade50 : Colors.grey.shade100,
        border: Border.all(
            color: r.isActive ? Colors.green.shade300 : Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Year ${r.year}  •  Sem ${r.semester}  •  ${r.branch == 'ALL' ? 'All Branches' : r.branch}',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
              _statusBadge(r.isActive),
            ],
          ),
          const SizedBox(height: 6),
          Text('${r.academicYear} — ${r.examSession}',
              style: TextStyle(fontSize: 12, color: Colors.grey[700])),
          Text(
              'Min Pass: ${r.minPassMarks}/100  •  Released: ${_formatDate(r.releasedAt)}',
              style: TextStyle(fontSize: 11, color: Colors.grey[500])),
          if (r.isActive) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _revokeMemo(r),
                icon: const Icon(Icons.lock, size: 15, color: Colors.red),
                label:
                    const Text('Revoke', style: TextStyle(color: Colors.red)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.red),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _statusBadge(bool isActive) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isActive
            ? Colors.green.withOpacity(0.15)
            : Colors.grey.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: isActive ? Colors.green.shade400 : Colors.grey.shade400),
      ),
      child: Text(
        isActive ? 'Active' : 'Revoked',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: isActive ? Colors.green.shade700 : Colors.grey.shade600,
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final months = [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${dt.day} ${months[dt.month]} ${dt.year}  ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
