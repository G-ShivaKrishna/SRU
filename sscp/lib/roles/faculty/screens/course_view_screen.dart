import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../widgets/app_header.dart';

/// A single course assigned to this faculty by the admin.
class _AssignedCourse {
  final String subjectCode;
  final String subjectName;
  final List<String> assignedBatches;
  final String academicYear;
  final String semester;
  final int year;
  final String subjectType;

  const _AssignedCourse({
    required this.subjectCode,
    required this.subjectName,
    required this.assignedBatches,
    required this.academicYear,
    required this.semester,
    required this.year,
    required this.subjectType,
  });

  factory _AssignedCourse.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return _AssignedCourse(
      subjectCode: d['subjectCode'] ?? '',
      subjectName: d['subjectName'] ?? '',
      assignedBatches: List<String>.from(d['assignedBatches'] ?? []),
      academicYear: d['academicYear'] ?? '',
      semester: d['semester'] ?? '',
      year: (d['year'] ?? 0) is int ? d['year'] : int.tryParse(d['year'].toString()) ?? 0,
      subjectType: d['subjectType'] ?? 'Theory',
    );
  }
}

class CourseViewScreen extends StatefulWidget {
  const CourseViewScreen({super.key});

  @override
  State<CourseViewScreen> createState() => _CourseViewScreenState();
}

class _CourseViewScreenState extends State<CourseViewScreen> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  bool _isLoading = true;
  String? _loadError;

  /// academicYear -> list of assigned courses
  Map<String, List<_AssignedCourse>> _grouped = {};

  /// Sorted years: most recent first
  List<String> _sortedYears = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _isLoading = true; _loadError = null; });
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('Not logged in');

      // Fetch facultyId from faculty collection using custom email
      // Email prefix doesn't match facultyId (e.g., email="ravi@edu.com" but facultyId="FAC001")
      final userEmail = user.email?.toLowerCase().trim() ?? '';
      String? facultyId;

      // Query faculty collection by custom email
      final facultyDocs = await _firestore
          .collection('faculty')
          .where('email', isEqualTo: userEmail)
          .limit(1)
          .get();

      if (facultyDocs.docs.isEmpty) {
        throw Exception(
            'Faculty record not found. Please contact admin to verify your email.');
      }

      facultyId = facultyDocs.docs.first.id; // Get actual facultyId from doc ID

      // Single where clause avoids composite index requirement;
      // isActive filtering is done in Dart.
      final snap = await _firestore
          .collection('facultyAssignments')
          .where('facultyId', isEqualTo: facultyId)
          .get();

      final allDocs = snap.docs;

      // Filter by isActive in Dart to avoid composite index requirement
      final activeCourses = <_AssignedCourse>[];
      for (final doc in allDocs) {
        final d = doc.data();
        if ((d['isActive'] ?? true) == true) {
          activeCourses.add(_AssignedCourse.fromDoc(doc));
        }
      }

      // Group by academicYear
      final grouped = <String, List<_AssignedCourse>>{};
      for (final c in activeCourses) {
        grouped.putIfAbsent(c.academicYear.isNotEmpty ? c.academicYear : 'Unknown', () => []).add(c);
      }

      // Sort within each year: sort by year (student year), then semester, then code
      for (final list in grouped.values) {
        list.sort((a, b) {
          final yCmp = a.year.compareTo(b.year);
          if (yCmp != 0) return yCmp;
          final sCmp = a.semester.compareTo(b.semester);
          if (sCmp != 0) return sCmp;
          return a.subjectCode.compareTo(b.subjectCode);
        });
      }

      // Sort academic years: most recent first
      final sortedYears = grouped.keys.toList()
        ..sort((a, b) => b.compareTo(a));

      if (!mounted) return;
      setState(() {
        _grouped = grouped;
        _sortedYears = sortedYears;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _loadError = e.toString(); _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Column(
        children: [
          const AppHeader(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _loadError != null
                    ? _buildError()
                    : _grouped.isEmpty
                        ? _buildEmpty()
                        : SingleChildScrollView(
                            padding: const EdgeInsets.all(16),
                            child: Center(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 1200),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Center(
                                      child: Text(
                                        'Course View',
                                        style: TextStyle(
                                          fontSize: 26,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    const Center(
                                      child: Text(
                                        'Courses assigned to you by the admin from your submitted preferences',
                                        style: TextStyle(color: Colors.grey, fontSize: 13),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                    const SizedBox(height: 20),
                                    ..._sortedYears.asMap().entries.map((e) {
                                      final isFirst = e.key == 0;
                                      return Padding(
                                        padding: const EdgeInsets.only(bottom: 16),
                                        child: _buildYearCard(
                                          e.value,
                                          _grouped[e.value]!,
                                          isCurrent: isFirst,
                                        ),
                                      );
                                    }),
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

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text('Failed to load assignments:\n$_loadError',
                textAlign: TextAlign.center),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.school_outlined, size: 72, color: Colors.grey[400]),
          const SizedBox(height: 16),
          const Text(
            'No courses assigned yet',
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          const Text(
            'The admin has not assigned any courses to you yet.\nPlease submit your course preferences first.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.grey),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh'),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1e3a5f), foregroundColor: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildYearCard(String acYear, List<_AssignedCourse> courses, {required bool isCurrent}) {
    final isMobile = MediaQuery.of(context).size.width < 700;
    final label = isCurrent ? 'Current Academic Year ($acYear)' : 'Academic Year ($acYear)';
    final headerColor = isCurrent ? const Color(0xFF1e3a5f) : const Color(0xFF546e7a);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: headerColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(7)),
            ),
            child: Row(
              children: [
                const Icon(Icons.menu_book, color: Colors.white70, size: 18),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${courses.length} course${courses.length == 1 ? '' : 's'}',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          // Table
          Padding(
            padding: const EdgeInsets.all(8),
            child: isMobile
                ? _mobileList(courses)
                : _desktopTable(courses),
          ),
        ],
      ),
    );
  }

  Widget _desktopTable(List<_AssignedCourse> courses) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(Colors.grey[100]),
        columns: const [
          DataColumn(label: Text('S.No', style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text('Subject Code', style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text('Subject Name', style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text('Year', style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text('Semester', style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text('Type', style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text('Assigned Batches', style: TextStyle(fontWeight: FontWeight.bold))),
        ],
        rows: courses.asMap().entries.map((entry) {
          final i = entry.key;
          final c = entry.value;
          return DataRow(cells: [
            DataCell(Text('${i + 1}')),
            DataCell(Text(c.subjectCode.isNotEmpty ? c.subjectCode : '-')),
            DataCell(SizedBox(
              width: 260,
              child: Text(c.subjectName, maxLines: 2, overflow: TextOverflow.ellipsis),
            )),
            DataCell(Text(c.year > 0 ? 'Year ${c.year}' : '-')),
            DataCell(Text(c.semester.isNotEmpty ? 'Sem ${c.semester}' : '-')),
            DataCell(_typeBadge(c.subjectType)),
            DataCell(_batchChips(c.assignedBatches)),
          ]);
        }).toList(),
      ),
    );
  }

  Widget _mobileList(List<_AssignedCourse> courses) {
    return Column(
      children: courses.asMap().entries.map((entry) {
        final i = entry.key;
        final c = entry.value;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (i > 0) Divider(color: Colors.grey[300], height: 16),
            _mRow('Subject Code', c.subjectCode.isNotEmpty ? c.subjectCode : '-'),
            _mRow('Subject Name', c.subjectName),
            _mRow('Year / Semester',
                '${c.year > 0 ? "Year ${c.year}" : "-"} / ${c.semester.isNotEmpty ? "Sem ${c.semester}" : "-"}'),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(
                    width: 120,
                    child: Text('Type',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1e3a5f))),
                  ),
                  _typeBadge(c.subjectType),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Assigned Batches',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1e3a5f))),
                  const SizedBox(height: 4),
                  _batchChips(c.assignedBatches),
                ],
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  Widget _mRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1e3a5f))),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 12, color: Colors.black87)),
          ),
        ],
      ),
    );
  }

  Widget _typeBadge(String type) {
    final isLab = type.toLowerCase().contains('lab');
    final isTutorial = type.toLowerCase().contains('tutorial');
    final color = isLab ? Colors.orange : isTutorial ? Colors.purple : Colors.blue;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        type.isNotEmpty ? type : 'Theory',
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color[800]),
      ),
    );
  }

  Widget _batchChips(List<String> batches) {
    if (batches.isEmpty) return const Text('-', style: TextStyle(fontSize: 12));
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: batches.map((b) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFF1e3a5f).withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF1e3a5f).withOpacity(0.3)),
        ),
        child: Text(b, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Color(0xFF1e3a5f))),
      )).toList(),
    );
  }
}
