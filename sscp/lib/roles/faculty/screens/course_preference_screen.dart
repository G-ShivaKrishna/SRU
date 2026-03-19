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
    final isMobile = MediaQuery.of(context).size.width < 700;
    final titleColor = const Color(0xFF1E3A5F);

    return Scaffold(
      backgroundColor: const Color(0xFFF3F6FB),
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
                            Row(
                              children: [
                                Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1976D2)
                                        .withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.assignment_outlined,
                                    color: Color(0xFF1976D2),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Course Preference Rounds',
                                        style: TextStyle(
                                          fontSize: isMobile ? 20 : 24,
                                          fontWeight: FontWeight.w800,
                                          color: titleColor,
                                          letterSpacing: 0.2,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Select and submit your subject preference order by round.',
                                        style: TextStyle(
                                          fontSize: isMobile ? 12 : 13,
                                          color: Colors.grey.shade700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            // Info banner
                            Container(
                              padding: const EdgeInsets.all(12),
                              margin: const EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(12),
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
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 10),
                                margin: const EdgeInsets.only(bottom: 16),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE8F2FF),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                      color: const Color(0xFFBFD8FF)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.account_tree_outlined,
                                        size: 16, color: Color(0xFF1565C0)),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Your branch: ${_facultyDept!.trim()} (includes branch-specific + all-branches subjects)',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.blue.shade700,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            Container(
                              width: double.infinity,
                              padding: EdgeInsets.all(isMobile ? 12 : 14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey.shade300),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.04),
                                    blurRadius: 10,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Wrap(
                                spacing: 16,
                                runSpacing: 12,
                                alignment: WrapAlignment.spaceBetween,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text('Show',
                                          style: TextStyle(
                                            color: Colors.grey.shade800,
                                            fontWeight: FontWeight.w600,
                                          )),
                                      const SizedBox(width: 8),
                                      _buildEntriesDropdown(),
                                      const SizedBox(width: 8),
                                      Text('entries',
                                          style: TextStyle(
                                            color: Colors.grey.shade800,
                                            fontWeight: FontWeight.w600,
                                          )),
                                    ],
                                  ),
                                  ConstrainedBox(
                                    constraints: BoxConstraints(
                                      maxWidth: isMobile ? 360 : 290,
                                      minWidth: isMobile ? 240 : 260,
                                    ),
                                    child: TextField(
                                      controller: _searchController,
                                      decoration: InputDecoration(
                                        isDense: true,
                                        hintText: 'Search rounds',
                                        prefixIcon:
                                            const Icon(Icons.search, size: 20),
                                        border: const OutlineInputBorder(),
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                                horizontal: 12, vertical: 10),
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
                            ),
                            const SizedBox(height: 16),
                            _pagedItems.isEmpty
                                ? Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 36, horizontal: 16),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                          color: Colors.grey.shade300),
                                    ),
                                    child: Column(
                                      children: [
                                        Icon(Icons.search_off,
                                            size: 34,
                                            color: Colors.grey.shade400),
                                        const SizedBox(height: 10),
                                        Text(
                                          'No rounds found for your search.',
                                          style: TextStyle(
                                            color: Colors.grey.shade700,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                : _buildTable(context),
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: Text(
                                _buildEntriesLabel(),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade700,
                                ),
                              ),
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
      borderRadius: BorderRadius.circular(8),
      underline: Container(
        height: 1,
        color: Colors.transparent,
      ),
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

  Widget _buildTable(BuildContext context) {
    final isCompact = MediaQuery.of(context).size.width < 900;

    if (isCompact) {
      return Column(
        children: _pagedItems.asMap().entries.map((entry) {
          final idx = entry.key;
          final round = entry.value;
          final effectiveDept = _effectiveDeptForRound(round);
          final globalIdx = (_currentPage - 1) * _entriesPerPage + idx + 1;

          return Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$globalIdx. ${round.className}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E3A5F),
                  ),
                ),
                const SizedBox(height: 8),
                _mRow('AC Year', round.acYear),
                _mRow('Department', effectiveDept),
                _mRow('From', round.fromDate),
                _mRow('To', round.toDate),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
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
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Open Preference'),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: DataTable(
        columnSpacing: 22,
        horizontalMargin: 14,
        headingRowHeight: 50,
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
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                child: const Text('Open Preference'),
              ),
            ),
          ]);
        }).toList(),
      ),
    );
  }

  Widget _mRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const Text(': ', style: TextStyle(fontSize: 12)),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
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
    final isMobile = MediaQuery.of(context).size.width < 700;

    return Wrap(
      alignment: isMobile ? WrapAlignment.center : WrapAlignment.end,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: [
        OutlinedButton(
          style: OutlinedButton.styleFrom(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed:
              _currentPage > 1 ? () => setState(() => _currentPage--) : null,
          child: const Text('Previous'),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF1976D2),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            '$_currentPage / $_totalPages',
            style: const TextStyle(color: Colors.white),
          ),
        ),
        OutlinedButton(
          style: OutlinedButton.styleFrom(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: _currentPage < _totalPages
              ? () => setState(() => _currentPage++)
              : null,
          child: const Text('Next'),
        ),
      ],
    );
  }
}
