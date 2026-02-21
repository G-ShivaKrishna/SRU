import 'package:flutter/material.dart';
import '../../../widgets/app_header.dart';
import '../services/course_preference_service.dart';
import 'course_preference_detail_screen.dart';

class PreferenceReportScreen extends StatefulWidget {
  const PreferenceReportScreen({super.key});

  @override
  State<PreferenceReportScreen> createState() => _PreferenceReportScreenState();
}

class _PreferenceReportScreenState extends State<PreferenceReportScreen> {
  final _service = CoursePreferenceService();

  List<PreferenceData> _preferences = [];
  bool _isLoading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final prefs = await _service.getMyPreferences();
      if (!mounted) return;
      setState(() {
        _preferences = prefs;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          const AppHeader(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _loadError != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline,
                                size: 64, color: Colors.red),
                            const SizedBox(height: 16),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 24),
                              child: Text(
                                  'Failed to load preferences:\n$_loadError',
                                  textAlign: TextAlign.center),
                            ),
                            const SizedBox(height: 20),
                            ElevatedButton(
                                onPressed: _loadPreferences,
                                child: const Text('Retry')),
                          ],
                        ),
                      )
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 1200),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                const Text(
                                  'Course Preference Report',
                                  style: TextStyle(
                                      fontSize: 26,
                                      fontWeight: FontWeight.bold),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 24),
                                if (_preferences.isEmpty) _buildEmpty(),
                                ..._preferences
                                    .map((pref) => _buildPrefCard(pref)),
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

  Widget _buildEmpty() {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Column(
        children: [
          Icon(Icons.info_outline, color: Colors.orange, size: 48),
          SizedBox(height: 16),
          Text(
            'No course preferences submitted yet',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildPrefCard(PreferenceData pref) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
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
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    pref.title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14),
                  ),
                ),
                Text(
                  'Submitted: ${_formatDate(pref.submittedAt)}',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          // Table
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const [
                DataColumn(label: Text('S.No')),
                DataColumn(label: Text('Course Code')),
                DataColumn(label: Text('Course Name')),
                DataColumn(label: Text('Dept')),
                DataColumn(label: Text('Yr/Sem')),
                DataColumn(label: Text('Type')),
              ],
              rows: pref.courses.asMap().entries.map((entry) {
                final i = entry.key;
                final s = entry.value;
                return DataRow(cells: [
                  DataCell(Text('${i + 1}')),
                  DataCell(Text(s.code.isNotEmpty ? s.code : '-')),
                  DataCell(Text(s.name)),
                  DataCell(Text(s.dept.isNotEmpty ? s.dept : '-')),
                  DataCell(Text(s.year > 0 ? '${s.year}/${s.semester}' : '-')),
                  DataCell(
                      Text(s.subjectType.isNotEmpty ? s.subjectType : 'Core')),
                ]);
              }).toList(),
            ),
          ),
          // Edit button
          Padding(
            padding: const EdgeInsets.all(12),
            child: ElevatedButton.icon(
              onPressed: () => _openEdit(pref),
              icon: const Icon(Icons.edit, size: 16),
              label: const Text('Edit Preference'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1976D2),
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openEdit(PreferenceData pref) {
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) => CoursePreferenceDetailScreen(
              roundId: pref.roundId,
              title: pref.title,
              dept: pref.dept.isNotEmpty
                  ? pref.dept
                  : (pref.courses.isNotEmpty ? pref.courses.first.dept : ''),
              acYear: pref.acYear,
              initialSelectedCourses: pref.courses,
            ),
          ),
        )
        .then((_) => _loadPreferences());
  }

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/'
        '${dt.month.toString().padLeft(2, '0')}/'
        '${dt.year}';
  }
}
