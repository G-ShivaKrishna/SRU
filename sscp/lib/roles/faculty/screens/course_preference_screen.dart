import 'package:flutter/material.dart';
import '../../../widgets/app_header.dart';
import 'course_preference_detail_screen.dart';

class CoursePreferenceScreen extends StatefulWidget {
  const CoursePreferenceScreen({super.key});

  @override
  State<CoursePreferenceScreen> createState() => _CoursePreferenceScreenState();
}

class _CoursePreferenceScreenState extends State<CoursePreferenceScreen> {
  final TextEditingController _searchController = TextEditingController();

  int _entriesPerPage = 10;
  int _currentPage = 1;
  String _searchQuery = '';

  final List<CoursePreferenceItem> _items = [
    CoursePreferenceItem(
      sNo: 1,
      acYear: '2025-26',
      className: 'UG List 1',
      dept: 'CSE',
      fromDate: '2025-11-18',
      toDate: '2025-11-18',
    ),
    CoursePreferenceItem(
      sNo: 2,
      acYear: '2025-26',
      className: 'UG List 2',
      dept: 'CSE',
      fromDate: '2025-11-18',
      toDate: '2025-11-18',
    ),
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<CoursePreferenceItem> get _filteredItems {
    if (_searchQuery.isEmpty) {
      return _items;
    }

    final query = _searchQuery.toLowerCase();
    return _items.where((item) {
      return item.acYear.toLowerCase().contains(query) ||
          item.className.toLowerCase().contains(query) ||
          item.dept.toLowerCase().contains(query) ||
          item.fromDate.toLowerCase().contains(query) ||
          item.toDate.toLowerCase().contains(query);
    }).toList();
  }

  List<CoursePreferenceItem> get _pagedItems {
    final start = (_currentPage - 1) * _entriesPerPage;
    final end = start + _entriesPerPage;
    final items = _filteredItems;

    if (start >= items.length) {
      return [];
    }

    return items.sublist(start, end > items.length ? items.length : end);
  }

  int get _totalPages {
    final total = _filteredItems.length;
    if (total == 0) {
      return 1;
    }
    return (total / _entriesPerPage).ceil();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Column(
        children: [
          const AppHeader(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1200),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
                                  onChanged: (value) {
                                    setState(() {
                                      _searchQuery = value.trim();
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
      onChanged: (value) {
        if (value == null) {
          return;
        }
        setState(() {
          _entriesPerPage = value;
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
          headingRowColor: MaterialStateProperty.all(Colors.grey[100]),
          columns: const [
            DataColumn(label: Text('S.No')),
            DataColumn(label: Text('AC Year')),
            DataColumn(label: Text('Class')),
            DataColumn(label: Text('Dept')),
            DataColumn(label: Text('From Date')),
            DataColumn(label: Text('To Date')),
            DataColumn(label: Text('Reg')),
          ],
          rows: _pagedItems.map((item) {
            return DataRow(
              cells: [
                DataCell(Text(item.sNo.toString())),
                DataCell(Text(item.acYear)),
                DataCell(Text(item.className)),
                DataCell(Text(item.dept)),
                DataCell(Text(item.fromDate)),
                DataCell(Text(item.toDate)),
                DataCell(
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => CoursePreferenceDetailScreen(
                            title:
                                '${item.className} Select Course Preference Order (${item.acYear})',
                          ),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1976D2),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                    child: const Text('Goto Course Preference'),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  String _buildEntriesLabel() {
    final total = _filteredItems.length;
    if (total == 0) {
      return 'Showing 0 to 0 of 0 entries';
    }
    final start = (_currentPage - 1) * _entriesPerPage + 1;
    final end = start + _pagedItems.length - 1;
    return 'Showing $start to $end of $total entries';
  }

  Widget _buildPagination() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        OutlinedButton(
          onPressed: _currentPage > 1
              ? () {
                  setState(() {
                    _currentPage--;
                  });
                }
              : null,
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
            _currentPage.toString(),
            style: const TextStyle(color: Colors.white),
          ),
        ),
        const SizedBox(width: 8),
        OutlinedButton(
          onPressed: _currentPage < _totalPages
              ? () {
                  setState(() {
                    _currentPage++;
                  });
                }
              : null,
          child: const Text('Next'),
        ),
      ],
    );
  }
}

class CoursePreferenceItem {
  final int sNo;
  final String acYear;
  final String className;
  final String dept;
  final String fromDate;
  final String toDate;

  CoursePreferenceItem({
    required this.sNo,
    required this.acYear,
    required this.className,
    required this.dept,
    required this.fromDate,
    required this.toDate,
  });
}
