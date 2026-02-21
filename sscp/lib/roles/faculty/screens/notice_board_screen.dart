import 'package:flutter/material.dart';
import '../../../widgets/app_header.dart';

// Model for Notice Board Entry
class NoticeBoardItem {
  final String academicYear;
  final String examId;
  final String examDate;
  final String session;
  final int studentsCount;

  NoticeBoardItem({
    required this.academicYear,
    required this.examId,
    required this.examDate,
    required this.session,
    required this.studentsCount,
  });
}

class NoticeBoardScreen extends StatefulWidget {
  const NoticeBoardScreen({super.key});

  @override
  State<NoticeBoardScreen> createState() => _NoticeBoardScreenState();
}

class _NoticeBoardScreenState extends State<NoticeBoardScreen> {
  List<NoticeBoardItem> noticeBoardData = [];
  int entriesPerPage = 100;
  int currentPage = 1;
  String searchQuery = '';
  String sortColumn = 'examDate';
  bool sortAscending = true;

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initializeNoticeBoardData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _initializeNoticeBoardData() {
    noticeBoardData = [
      NoticeBoardItem(
        academicYear: '2025-26/1',
        examId: '2026_JAN_SUP',
        examDate: '2026-01-23',
        session: '10:00AM - 12:30PM',
        studentsCount: 2,
      ),
      NoticeBoardItem(
        academicYear: '2025-26/1',
        examId: '2026_JAN_SUP',
        examDate: '2026-01-22',
        session: '10:00AM - 12:30PM',
        studentsCount: 10,
      ),
      NoticeBoardItem(
        academicYear: '2025-26/1',
        examId: '2026_JAN_SUP',
        examDate: '2026-01-21',
        session: '10:00AM - 12:30PM',
        studentsCount: 15,
      ),
      NoticeBoardItem(
        academicYear: '2025-26/1',
        examId: '2026_JAN_SUP',
        examDate: '2026-01-20',
        session: '10:00AM - 12:30PM',
        studentsCount: 6,
      ),
      NoticeBoardItem(
        academicYear: '2025-26/1',
        examId: '2026_JAN_SUP',
        examDate: '2026-01-19',
        session: '10:00AM - 12:30PM',
        studentsCount: 15,
      ),
      NoticeBoardItem(
        academicYear: '2025-26/1',
        examId: '2026_JAN_SUP',
        examDate: '2026-01-17',
        session: '10:00AM - 12:30PM',
        studentsCount: 3,
      ),
      NoticeBoardItem(
        academicYear: '2025-26/1',
        examId: '2026_JAN_SUP',
        examDate: '2026-01-16',
        session: '10:00AM - 12:30PM',
        studentsCount: 8,
      ),
      NoticeBoardItem(
        academicYear: '2025-26/1',
        examId: '2025_DEC_REG',
        examDate: '2025-12-15',
        session: '02:00PM - 04:30PM',
        studentsCount: 25,
      ),
      NoticeBoardItem(
        academicYear: '2025-26/1',
        examId: '2025_DEC_REG',
        examDate: '2025-12-14',
        session: '10:00AM - 12:30PM',
        studentsCount: 30,
      ),
      NoticeBoardItem(
        academicYear: '2025-26/1',
        examId: '2025_NOV_MID',
        examDate: '2025-11-20',
        session: '10:00AM - 12:30PM',
        studentsCount: 20,
      ),
    ];
  }

  List<NoticeBoardItem> get _filteredData {
    if (searchQuery.isEmpty) {
      return noticeBoardData;
    }
    return noticeBoardData
        .where((item) =>
            item.academicYear
                .toLowerCase()
                .contains(searchQuery.toLowerCase()) ||
            item.examId.toLowerCase().contains(searchQuery.toLowerCase()) ||
            item.examDate.toLowerCase().contains(searchQuery.toLowerCase()))
        .toList();
  }

  List<NoticeBoardItem> get _sortedData {
    final filtered = _filteredData;
    filtered.sort((a, b) {
      dynamic aValue, bValue;

      switch (sortColumn) {
        case 'academicYear':
          aValue = a.academicYear;
          bValue = b.academicYear;
          break;
        case 'examId':
          aValue = a.examId;
          bValue = b.examId;
          break;
        case 'examDate':
          aValue = a.examDate;
          bValue = b.examDate;
          break;
        case 'session':
          aValue = a.session;
          bValue = b.session;
          break;
        case 'studentsCount':
          aValue = a.studentsCount;
          bValue = b.studentsCount;
          break;
        default:
          return 0;
      }

      if (sortAscending) {
        return aValue.toString().compareTo(bValue.toString());
      } else {
        return bValue.toString().compareTo(aValue.toString());
      }
    });

    return filtered;
  }

  List<NoticeBoardItem> get _paginatedData {
    final sorted = _sortedData;
    final startIndex = (currentPage - 1) * entriesPerPage;
    final endIndex = startIndex + entriesPerPage;

    if (startIndex >= sorted.length) return [];
    if (endIndex <= sorted.length) {
      return sorted.sublist(startIndex, endIndex);
    }
    return sorted.sublist(startIndex);
  }

  int get _totalPages {
    final sorted = _sortedData;
    return (sorted.length / entriesPerPage).ceil();
  }

  void _onSortColumn(String column) {
    setState(() {
      if (sortColumn == column) {
        sortAscending = !sortAscending;
      } else {
        sortColumn = column;
        sortAscending = true;
      }
      currentPage = 1;
    });
  }

  void _viewNoticeBoard(NoticeBoardItem item) {
    // TODO: Navigate to notice board details or PDF
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Notice Board for ${item.examId} on ${item.examDate}',
        ),
      ),
    );
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
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Title
                    Padding(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: Text(
                        'Day & Session Wise Notice Board Report',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ),

                    // Controls
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          // Export Buttons
                          Tooltip(
                            message: 'Export as Excel',
                            child: Container(
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey[400]!),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: IconButton(
                                icon: const Icon(
                                  Icons.table_chart,
                                  color: Colors.green,
                                  size: 20,
                                ),
                                onPressed: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Excel export coming soon'),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Tooltip(
                            message: 'Export as CSV',
                            child: Container(
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey[400]!),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: IconButton(
                                icon: const Icon(
                                  Icons.description,
                                  color: Colors.green,
                                  size: 20,
                                ),
                                onPressed: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('CSV export coming soon'),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),

                          // Entries Per Page
                          Row(
                            children: [
                              const Text('Show'),
                              const SizedBox(width: 8),
                              Container(
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey[400]!),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: DropdownButton<int>(
                                  value: entriesPerPage,
                                  underline: const SizedBox(),
                                  items: [10, 25, 50, 100].map((int value) {
                                    return DropdownMenuItem<int>(
                                      value: value,
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8),
                                        child: Text('$value'),
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    setState(() {
                                      entriesPerPage = value ?? 100;
                                      currentPage = 1;
                                    });
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Text('entries'),
                            ],
                          ),
                          const Spacer(),

                          // Search Box
                          SizedBox(
                            width: 250,
                            child: TextField(
                              controller: _searchController,
                              decoration: InputDecoration(
                                hintText: 'Search...',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(4),
                                  borderSide:
                                      BorderSide(color: Colors.grey[400]!),
                                ),
                                contentPadding:
                                    const EdgeInsets.symmetric(horizontal: 12),
                              ),
                              onChanged: (value) {
                                setState(() {
                                  searchQuery = value;
                                  currentPage = 1;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Table
                    _buildNoticeBoardTable(),

                    const SizedBox(height: 16),

                    // Pagination
                    _buildPaginationControls(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoticeBoardTable() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!, width: 1),
        borderRadius: BorderRadius.circular(4),
        color: Colors.white,
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header Row
            Container(
              color: Colors.grey[100],
              child: Row(
                children: [
                  _buildHeaderCell('AC Year/Sem', 'academicYear'),
                  _buildHeaderCell('Exam ID', 'examId'),
                  _buildHeaderCell('Exam Date', 'examDate'),
                  _buildHeaderCell('Session', 'session'),
                  _buildHeaderCell('Students Count', 'studentsCount'),
                  _buildHeaderCell('View', ''),
                ],
              ),
            ),
            // Data Rows
            ..._paginatedData.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              final isEvenRow = index % 2 == 0;

              return Container(
                color: isEvenRow ? Colors.white : Colors.grey[50],
                child: Row(
                  children: [
                    _buildDataCell(item.academicYear, 140),
                    _buildDataCell(item.examId, 150),
                    _buildDataCell(item.examDate, 130),
                    _buildDataCell(item.session, 180),
                    _buildDataCell(item.studentsCount.toString(), 150),
                    _buildActionCell(item, 150),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCell(String text, String columnKey) {
    final isSortable = columnKey.isNotEmpty;

    Widget headerContent = Text(
      text,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
      ),
    );

    double width = 140;
    switch (text) {
      case 'AC Year/Sem':
        width = 140;
        break;
      case 'Exam ID':
        width = 150;
        break;
      case 'Exam Date':
        width = 130;
        break;
      case 'Session':
        width = 180;
        break;
      case 'Students Count':
        width = 150;
        break;
      case 'View':
        width = 150;
        break;
    }

    return GestureDetector(
      onTap: isSortable ? () => _onSortColumn(columnKey) : null,
      child: Container(
        width: width,
        height: 50,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          border: Border(
            right: BorderSide(color: Colors.grey[300]!, width: 1),
            bottom: BorderSide(color: Colors.grey[300]!, width: 1),
          ),
        ),
        child: Row(
          children: [
            Expanded(child: headerContent),
            if (isSortable)
              Icon(
                sortColumn == columnKey
                    ? (sortAscending
                        ? Icons.arrow_upward
                        : Icons.arrow_downward)
                    : Icons.unfold_more,
                size: 14,
                color: Colors.grey[600],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataCell(String text, double width) {
    return Container(
      width: width,
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(color: Colors.grey[300]!, width: 1),
          bottom: BorderSide(color: Colors.grey[300]!, width: 1),
        ),
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.black87,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Widget _buildActionCell(NoticeBoardItem item, double width) {
    return Container(
      width: width,
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(color: Colors.grey[300]!, width: 1),
          bottom: BorderSide(color: Colors.grey[300]!, width: 1),
        ),
      ),
      child: Center(
        child: ElevatedButton(
          onPressed: () => _viewNoticeBoard(item),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1976D2),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          child: const Text(
            'Notice Board',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPaginationControls() {
    final totalPages = _totalPages;
    final filteredLength = _sortedData.length;
    final startIndex = (currentPage - 1) * entriesPerPage + 1;
    final endIndex = (startIndex + entriesPerPage - 1 > filteredLength)
        ? filteredLength
        : startIndex + entriesPerPage - 1;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Showing $startIndex to $endIndex of $filteredLength entries',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          Row(
            children: [
              if (currentPage > 1)
                TextButton(
                  onPressed: () {
                    setState(() {
                      currentPage--;
                    });
                  },
                  child: const Text('Previous'),
                )
              else
                TextButton(
                  onPressed: null,
                  child: const Text('Previous'),
                ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[400]!),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text('$currentPage'),
              ),
              const SizedBox(width: 8),
              if (currentPage < totalPages)
                TextButton(
                  onPressed: () {
                    setState(() {
                      currentPage++;
                    });
                  },
                  child: const Text('Next'),
                )
              else
                TextButton(
                  onPressed: null,
                  child: const Text('Next'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
