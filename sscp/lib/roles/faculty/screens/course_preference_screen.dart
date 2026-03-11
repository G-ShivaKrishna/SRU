import 'package:flutter/material.dart';
import '../../../widgets/app_header.dart';
import '../services/course_preference_service.dart';
import 'course_preference_detail_screen.dart';

class CoursePreferenceScreen extends StatefulWidget {
  const CoursePreferenceScreen({super.key});

  @override
  State<CoursePreferenceScreen> createState() => _CoursePreferenceScreenState();
}

class _CoursePreferenceScreenState extends State<CoursePreferenceScreen> {
  final TextEditingController _searchController = TextEditingController();
  final _service = CoursePreferenceService();

  int _entriesPerPage = 10;
  int _currentPage = 1;
  String _searchQuery = '';

  List<CoursePreferenceRound> _rounds = [];
  bool _isLoading = true;
  String? _facultyDept;

  @override
  void initState() {
    super.initState();
    _loadRounds();
  }

  Future<void> _loadRounds() async {
    setState(() => _isLoading = true);
    final rounds = await _service.getRounds();
    String? facultyDept;
    try {
      facultyDept = await _service.getCurrentFacultyDepartment();
    } catch (_) {
      facultyDept = null;
    }

    if (!mounted) return;
    setState(() {
      _rounds = rounds;
      _facultyDept = facultyDept;
      _isLoading = false;
    });
  }

  String _effectiveDeptForRound(CoursePreferenceRound round) {
    final facultyDept = _facultyDept?.trim() ?? '';
    if (facultyDept.isNotEmpty) return facultyDept;
    return round.dept;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<CoursePreferenceRound> get _filteredItems {
    if (_searchQuery.isEmpty) return _rounds;
    final q = _searchQuery.toLowerCase();
    return _rounds
        .where((r) =>
            r.acYear.toLowerCase().contains(q) ||
            r.className.toLowerCase().contains(q) ||
            r.dept.toLowerCase().contains(q) ||
            r.fromDate.toLowerCase().contains(q) ||
            r.toDate.toLowerCase().contains(q))
        .toList();
  }

  List<CoursePreferenceRound> get _pagedItems {
    final start = (_currentPage - 1) * _entriesPerPage;
    final all = _filteredItems;
    if (start >= all.length) return [];
    final end = start + _entriesPerPage;
    return all.sublist(start, end > all.length ? all.length : end);
  }

  int get _totalPages {
    final total = _filteredItems.length;
    return total == 0 ? 1 : (total / _entriesPerPage).ceil();
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
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1200),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Info banner
                            Container(
                              padding: const EdgeInsets.all(12),
                              margin: const EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.blue.shade200),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.info_outline,
                                      color: Colors.blue.shade700),
                                  const SizedBox(width: 12),
                                  const Expanded(
                                    child: Text(
                                      'Available subjects are managed by admin. Only active subjects from Subject Management will appear in your preference selection.',
                                      style: TextStyle(fontSize: 13),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if ((_facultyDept ?? '').trim().isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: Text(
                                  'Your branch: ${_facultyDept!.trim()} (you will see branch-specific subjects and All Branches subjects)',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.blue.shade700,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Text('Show'),
                                    const SizedBox(width: 8),
                                    _buildEntriesDropdown(),
                                    const SizedBox(width: 8),
                                    const Text('entries'),
                                  ],
                                ),
                                Row(
                                  children: [
                                    const Text('Search:'),
                                    const SizedBox(width: 8),
                                    SizedBox(
                                      width: 200,
                                      child: TextField(
                                        controller: _searchController,
                                        decoration: const InputDecoration(
                                          isDense: true,
                                          border: OutlineInputBorder(),
                                        ),
                                        onChanged: (v) {
                                          setState(() {
                                            _searchQuery = v.trim();
                                            _currentPage = 1;
                                          });
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            _buildTable(),
                            const SizedBox(height: 8),
                            Text(
                              _buildEntriesLabel(),
                              style: const TextStyle(fontSize: 12),
                            ),
                            const SizedBox(height: 8),
                            _buildPagination(),
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

  Widget _buildEntriesDropdown() {
    return DropdownButton<int>(
      value: _entriesPerPage,
      items: const [
        DropdownMenuItem(value: 10, child: Text('10')),
        DropdownMenuItem(value: 25, child: Text('25')),
        DropdownMenuItem(value: 50, child: Text('50')),
      ],
      onChanged: (v) {
        if (v == null) return;
        setState(() {
          _entriesPerPage = v;
          _currentPage = 1;
        });
      },
    );
  }

  Widget _buildTable() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(4),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(Colors.grey[100]),
          columns: const [
            DataColumn(label: Text('S.No')),
            DataColumn(label: Text('AC Year')),
            DataColumn(label: Text('Class')),
            DataColumn(label: Text('Dept')),
            DataColumn(label: Text('From Date')),
            DataColumn(label: Text('To Date')),
            DataColumn(label: Text('Action')),
          ],
          rows: _pagedItems.asMap().entries.map((entry) {
            final idx = entry.key;
            final round = entry.value;
            final effectiveDept = _effectiveDeptForRound(round);
            final globalIdx = (_currentPage - 1) * _entriesPerPage + idx + 1;
            return DataRow(cells: [
              DataCell(Text('$globalIdx')),
              DataCell(Text(round.acYear)),
              DataCell(Text(round.className)),
              DataCell(Text(effectiveDept)),
              DataCell(Text(round.fromDate)),
              DataCell(Text(round.toDate)),
              DataCell(
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => CoursePreferenceDetailScreen(
                        roundId: round.id,
                        title:
                            '${round.className} Select Course Preference Order (${round.acYear})',
                        dept: effectiveDept,
                        acYear: round.acYear,
                      ),
                    ));
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1976D2),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                  ),
                  child: const Text('Goto Course Preference'),
                ),
              ),
            ]);
          }).toList(),
        ),
      ),
    );
  }

  String _buildEntriesLabel() {
    final total = _filteredItems.length;
    if (total == 0) return 'Showing 0 to 0 of 0 entries';
    final start = (_currentPage - 1) * _entriesPerPage + 1;
    final end = start + _pagedItems.length - 1;
    return 'Showing $start to $end of $total entries';
  }

  Widget _buildPagination() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        OutlinedButton(
          onPressed:
              _currentPage > 1 ? () => setState(() => _currentPage--) : null,
          child: const Text('Previous'),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF1976D2),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            '$_currentPage',
            style: const TextStyle(color: Colors.white),
          ),
        ),
        const SizedBox(width: 8),
        OutlinedButton(
          onPressed: _currentPage < _totalPages
              ? () => setState(() => _currentPage++)
              : null,
          child: const Text('Next'),
        ),
      ],
    );
  }
}
