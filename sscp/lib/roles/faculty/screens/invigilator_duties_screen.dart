import 'package:flutter/material.dart';
import '../../../widgets/app_header.dart';

// Model for Invigilation Duty
class InvigilationDuty {
  final int sNo;
  final String academicYear;
  final String examType;
  final String date;
  final String session;
  final String room;
  final String remarks;

  InvigilationDuty({
    required this.sNo,
    required this.academicYear,
    required this.examType,
    required this.date,
    required this.session,
    required this.room,
    required this.remarks,
  });
}

class InvigilatorDutiesScreen extends StatefulWidget {
  const InvigilatorDutiesScreen({super.key});

  @override
  State<InvigilatorDutiesScreen> createState() =>
      _InvigilatorDutiesScreenState();
}

class _InvigilatorDutiesScreenState extends State<InvigilatorDutiesScreen> {
  List<InvigilationDuty> dutyData = [];
  int entriesPerPage = 10;
  int currentPage = 1;
  String searchQuery = '';
  String sortColumn = 'sNo';
  bool sortAscending = true;

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initializeDutyData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _initializeDutyData() {
    dutyData = [
      InvigilationDuty(
        sNo: 1,
        academicYear: '2025-2026',
        examType: '2025_DEC_SUP',
        date: '22-12-2025',
        session: '10:00AM -12:00PM (FN)',
        room: '1109',
        remarks: 'YES',
      ),
      InvigilationDuty(
        sNo: 2,
        academicYear: '2025-26',
        examType: '2025_NOV_REG',
        date: '04-12-2025',
        session: '02:00PM -04:00PM (AN)',
        room: '1101',
        remarks: 'yes',
      ),
      InvigilationDuty(
        sNo: 3,
        academicYear: '2025-26',
        examType: '2025_NOV_REG',
        date: '04-12-2025',
        session: '10:00AM -12:00PM (FN)',
        room: '3014',
        remarks: 'yes',
      ),
      InvigilationDuty(
        sNo: 4,
        academicYear: '2025-26',
        examType: '2025_NOV_REG',
        date: '03-12-2025',
        session: '02:00PM -04:00PM (AN)',
        room: '1016',
        remarks: 'yes',
      ),
      InvigilationDuty(
        sNo: 5,
        academicYear: '2025-26',
        examType: '2025_NOV_REG',
        date: '03-12-2025',
        session: '10:00AM -12:00PM (FN)',
        room: '3206',
        remarks: 'yes',
      ),
      InvigilationDuty(
        sNo: 6,
        academicYear: '2025-26',
        examType: '2025_NOV_REG',
        date: '02-12-2025',
        session: '02:00PM -04:00PM (AN)',
        room: '3014',
        remarks: 'yes',
      ),
      InvigilationDuty(
        sNo: 7,
        academicYear: '2025-26',
        examType: '2025_NOV_REG',
        date: '02-12-2025',
        session: '10:00AM -12:00PM (FN)',
        room: '2017',
        remarks: 'yes',
      ),
      InvigilationDuty(
        sNo: 8,
        academicYear: '2025-26',
        examType: '2025_NOV_REG',
        date: '01-12-2025',
        session: '02:00PM -04:00PM (AN)',
        room: '1016',
        remarks: 'yes',
      ),
      InvigilationDuty(
        sNo: 9,
        academicYear: '2025-26',
        examType: '2025_NOV_REG',
        date: '01-12-2025',
        session: '10:00AM -12:00PM (FN)',
        room: '3015',
        remarks: 'yes',
      ),
      InvigilationDuty(
        sNo: 10,
        academicYear: '2025-26',
        examType: '2025_NOV_MID',
        date: '04-11-2025',
        session: '03:30PM -04:30PM (AN)',
        room: '2003',
        remarks: 'YES',
      ),
      InvigilationDuty(
        sNo: 11,
        academicYear: '2025-26',
        examType: '2025_OCT_REG',
        date: '15-10-2025',
        session: '10:00AM -12:00PM (FN)',
        room: '1105',
        remarks: 'yes',
      ),
      InvigilationDuty(
        sNo: 12,
        academicYear: '2025-26',
        examType: '2025_OCT_REG',
        date: '14-10-2025',
        session: '02:00PM -04:00PM (AN)',
        room: '2008',
        remarks: 'yes',
      ),
      InvigilationDuty(
        sNo: 13,
        academicYear: '2025-26',
        examType: '2025_SEP_SUP',
        date: '25-09-2025',
        session: '10:00AM -12:00PM (FN)',
        room: '1205',
        remarks: 'yes',
      ),
      InvigilationDuty(
        sNo: 14,
        academicYear: '2025-26',
        examType: '2025_SEP_SUP',
        date: '24-09-2025',
        session: '02:00PM -04:00PM (AN)',
        room: '3010',
        remarks: 'yes',
      ),
      InvigilationDuty(
        sNo: 15,
        academicYear: '2025-26',
        examType: '2025_AUG_MID',
        date: '20-08-2025',
        session: '10:00AM -12:00PM (FN)',
        room: '1102',
        remarks: 'YES',
      ),
      InvigilationDuty(
        sNo: 16,
        academicYear: '2025-26',
        examType: '2025_AUG_MID',
        date: '19-08-2025',
        session: '02:00PM -04:00PM (AN)',
        room: '2015',
        remarks: 'yes',
      ),
    ];
  }

  List<InvigilationDuty> get _filteredData {
    if (searchQuery.isEmpty) {
      return dutyData;
    }
    return dutyData
        .where((item) =>
            item.academicYear
                .toLowerCase()
                .contains(searchQuery.toLowerCase()) ||
            item.examType.toLowerCase().contains(searchQuery.toLowerCase()) ||
            item.room.toLowerCase().contains(searchQuery.toLowerCase()) ||
            item.date.toLowerCase().contains(searchQuery.toLowerCase()))
        .toList();
  }

  List<InvigilationDuty> get _sortedData {
    final filtered = _filteredData;
    filtered.sort((a, b) {
      dynamic aValue, bValue;

      switch (sortColumn) {
        case 'sNo':
          aValue = a.sNo;
          bValue = b.sNo;
          break;
        case 'academicYear':
          aValue = a.academicYear;
          bValue = b.academicYear;
          break;
        case 'examType':
          aValue = a.examType;
          bValue = b.examType;
          break;
        case 'date':
          aValue = a.date;
          bValue = b.date;
          break;
        case 'session':
          aValue = a.session;
          bValue = b.session;
          break;
        case 'room':
          aValue = a.room;
          bValue = b.room;
          break;
        case 'remarks':
          aValue = a.remarks;
          bValue = b.remarks;
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

  List<InvigilationDuty> get _paginatedData {
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
                        'Emp Exams Invigilation Duties',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1976D2),
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
                                  items: [10, 25, 50].map((int value) {
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
                                      entriesPerPage = value ?? 10;
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
                    _buildDutiesTable(),

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

  Widget _buildDutiesTable() {
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
                  _buildHeaderCell('S.No'),
                  _buildHeaderCell('AC Year/Sem'),
                  _buildHeaderCell('Exam Type'),
                  _buildHeaderCell('Date'),
                  _buildHeaderCell('Session'),
                  _buildHeaderCell('Room'),
                  _buildHeaderCell('Remarks'),
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
                    _buildDataCell(item.sNo.toString(), 80),
                    _buildDataCell(item.academicYear, 120),
                    _buildDataCell(item.examType, 130),
                    _buildDataCell(item.date, 110),
                    _buildDataCell(item.session, 180),
                    _buildDataCell(item.room, 80),
                    _buildDataCell(item.remarks, 100),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCell(String text) {
    final isSortable = [
      'sNo',
      'academicYear',
      'examType',
      'date',
      'session',
      'room',
      'remarks'
    ].contains(text.replaceAll(' ', ''));
    final columnKey = text.replaceAll(' ', '').replaceAll('/', '');

    Widget headerContent = Text(
      text,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
      ),
    );

    double width = 80;
    switch (text) {
      case 'S.No':
        width = 80;
        break;
      case 'AC Year/Sem':
        width = 120;
        break;
      case 'Exam Type':
        width = 130;
        break;
      case 'Date':
        width = 110;
        break;
      case 'Session':
        width = 180;
        break;
      case 'Room':
        width = 80;
        break;
      case 'Remarks':
        width = 100;
        break;
    }

    return GestureDetector(
      onTap: isSortable
          ? () {
              _onSortColumn(text.replaceAll(' ', '').replaceAll('/', ''));
            }
          : null,
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
