import 'package:flutter/material.dart';
import '../../../widgets/app_header.dart';

// Model for Exam Timetable Entry
class ExamTimetableItem {
  final int sNo;
  final String classInfo;
  final String code;
  final String course;
  final String date;
  final String session;

  ExamTimetableItem({
    required this.sNo,
    required this.classInfo,
    required this.code,
    required this.course,
    required this.date,
    required this.session,
  });
}

class ExamTimetableScreen extends StatefulWidget {
  const ExamTimetableScreen({super.key});

  @override
  State<ExamTimetableScreen> createState() => _ExamTimetableScreenState();
}

class _ExamTimetableScreenState extends State<ExamTimetableScreen> {
  final List<String> examIds = [
    '2026_FEB_SUP',
    '2026_FEB_REG',
    '2026_JAN_SUP',
    '2025_OCT_REG',
    '2025_SEP_SUP',
    '2025_DEC_SUP',
    '2025_DEC_REG',
    '2025_NOV_MID',
  ];

  String? selectedExamId;
  List<ExamTimetableItem> timetableData = [];
  bool isLoading = false;
  int entriesPerPage = 10;
  int currentPage = 1;
  String searchQuery = '';

  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchPressed() {
    if (selectedExamId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select an Exam ID first'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      isLoading = true;
      currentPage = 1;
    });

    // Simulate loading data
    Future.delayed(const Duration(milliseconds: 500), () {
      _loadTimetableData(selectedExamId!);
      setState(() {
        isLoading = false;
      });
    });
  }

  void _loadTimetableData(String examId) {
    // Sample data based on selected exam ID
    final sampleData = {
      '2026_FEB_SUP': [
        ExamTimetableItem(
          sNo: 1,
          classInfo: '3-1-BBA-BM-BBA',
          code: '23HS300OE304',
          course: 'CRITICAL THINKING',
          date: '02-02-2026',
          session: '10:00AM - 12:00PM',
        ),
        ExamTimetableItem(
          sNo: 2,
          classInfo: '3-1-BBA-BM-BBAL',
          code: '23HS300OE304',
          course: 'CRITICAL THINKING',
          date: '02-02-2026',
          session: '10:00AM - 12:00PM',
        ),
        ExamTimetableItem(
          sNo: 3,
          classInfo: '3-1-BBA-BM-BBA',
          code: '23SB201PE106',
          course: 'DIGITAL MARKETING',
          date: '03-02-2026',
          session: '10:00AM - 12:00PM',
        ),
        ExamTimetableItem(
          sNo: 4,
          classInfo: '3-1-BBA-BM-BBAL',
          code: '23SB201PE106',
          course: 'DIGITAL MARKETING',
          date: '03-02-2026',
          session: '10:00AM - 12:00PM',
        ),
        ExamTimetableItem(
          sNo: 5,
          classInfo: '2-1-BBA-BM-BBA',
          code: '23HS200OE205',
          course: 'ETHICS',
          date: '04-02-2026',
          session: '02:00PM - 04:00PM',
        ),
        ExamTimetableItem(
          sNo: 6,
          classInfo: '2-1-BBA-BM-BBAL',
          code: '23HS200OE205',
          course: 'ETHICS',
          date: '04-02-2026',
          session: '02:00PM - 04:00PM',
        ),
        ExamTimetableItem(
          sNo: 7,
          classInfo: '1-1-BBA-BM-BBA',
          code: '23HS100OE106',
          course: 'COMMUNICATION',
          date: '05-02-2026',
          session: '10:00AM - 12:00PM',
        ),
        ExamTimetableItem(
          sNo: 8,
          classInfo: '1-1-BBA-BM-BBAL',
          code: '23HS100OE106',
          course: 'COMMUNICATION',
          date: '05-02-2026',
          session: '10:00AM - 12:00PM',
        ),
      ],
      '2026_FEB_REG': [
        ExamTimetableItem(
          sNo: 1,
          classInfo: '3-1-BTECH-ECE',
          code: '23EC301',
          course: 'DIGITAL ELECTRONICS',
          date: '10-02-2026',
          session: '09:00AM - 11:00AM',
        ),
        ExamTimetableItem(
          sNo: 2,
          classInfo: '3-1-BTECH-MECH',
          code: '23ME301',
          course: 'THERMODYNAMICS',
          date: '11-02-2026',
          session: '09:00AM - 11:00AM',
        ),
      ],
    };

    if (sampleData.containsKey(examId)) {
      timetableData = sampleData[examId]!;
    } else {
      timetableData = [];
    }
  }

  List<ExamTimetableItem> get _filteredData {
    if (searchQuery.isEmpty) {
      return timetableData;
    }
    return timetableData
        .where((item) =>
            item.classInfo.toLowerCase().contains(searchQuery.toLowerCase()) ||
            item.course.toLowerCase().contains(searchQuery.toLowerCase()) ||
            item.code.toLowerCase().contains(searchQuery.toLowerCase()))
        .toList();
  }

  List<ExamTimetableItem> get _paginatedData {
    final filtered = _filteredData;
    final startIndex = (currentPage - 1) * entriesPerPage;
    final endIndex = startIndex + entriesPerPage;

    if (startIndex >= filtered.length) return [];
    if (endIndex <= filtered.length) {
      return filtered.sublist(startIndex, endIndex);
    }
    return filtered.sublist(startIndex);
  }

  int get _totalPages {
    final filtered = _filteredData;
    return (filtered.length / entriesPerPage).ceil();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Column(
        children: [
          const AppHeader(),
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.all(isMobile ? 12 : 16),
                child: Column(
                  children: [
                    // Title
                    Padding(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: Text(
                        'Exam Time Table / Date Sheet',
                        style: TextStyle(
                          fontSize: isMobile ? 22 : 28,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1e3a5f),
                        ),
                      ),
                    ),

                    // Filter Card
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Exam ID:',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF1e3a5f),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                        color: Colors.grey[400]!, width: 1),
                                    borderRadius: BorderRadius.circular(4),
                                    color: Colors.white,
                                  ),
                                  child: DropdownButton<String>(
                                    value: selectedExamId,
                                    isExpanded: true,
                                    underline: const SizedBox(),
                                    hint: const Padding(
                                      padding:
                                          EdgeInsets.symmetric(horizontal: 12),
                                      child: Text('-- Select Exam ID --'),
                                    ),
                                    items: examIds.map((String item) {
                                      return DropdownMenuItem<String>(
                                        value: item,
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 12),
                                          child: Text(item),
                                        ),
                                      );
                                    }).toList(),
                                    onChanged: (value) {
                                      setState(() {
                                        selectedExamId = value;
                                      });
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Padding(
                            padding: const EdgeInsets.only(top: 24),
                            child: ElevatedButton(
                              onPressed: _onSearchPressed,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1976D2),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 32, vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              child: const Text(
                                'Search',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Results Section
                    if (selectedExamId != null && timetableData.isNotEmpty)
                      Column(
                        children: [
                          // Exam ID Display and Controls
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.withOpacity(0.1),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Exam ID: $selectedExamId',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF2D7D2D),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    // PDF Export Button
                                    Tooltip(
                                      message: 'Export as PDF',
                                      child: Container(
                                        decoration: BoxDecoration(
                                          border: Border.all(
                                              color: Colors.grey[400]!),
                                          borderRadius:
                                              BorderRadius.circular(4),
                                        ),
                                        child: IconButton(
                                          icon: const Icon(
                                            Icons.picture_as_pdf,
                                            color: Colors.red,
                                          ),
                                          onPressed: () {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                    'PDF export coming soon'),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    // Excel Export Button
                                    Tooltip(
                                      message: 'Export as Excel',
                                      child: Container(
                                        decoration: BoxDecoration(
                                          border: Border.all(
                                              color: Colors.grey[400]!),
                                          borderRadius:
                                              BorderRadius.circular(4),
                                        ),
                                        child: IconButton(
                                          icon: const Icon(
                                            Icons.table_chart,
                                            color: Colors.green,
                                          ),
                                          onPressed: () {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                    'Excel export coming soon'),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                    const Spacer(),
                                    // Entries Per Page
                                    Row(
                                      children: [
                                        const Text('Show'),
                                        const SizedBox(width: 8),
                                        Container(
                                          decoration: BoxDecoration(
                                            border: Border.all(
                                                color: Colors.grey[400]!),
                                            borderRadius:
                                                BorderRadius.circular(4),
                                          ),
                                          child: DropdownButton<int>(
                                            value: entriesPerPage,
                                            underline: const SizedBox(),
                                            items:
                                                [10, 25, 50].map((int value) {
                                              return DropdownMenuItem<int>(
                                                value: value,
                                                child: Padding(
                                                  padding: const EdgeInsets
                                                      .symmetric(horizontal: 8),
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
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Search Box
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.grey[400]!),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _searchController,
                                    decoration: const InputDecoration(
                                      hintText: 'Search...',
                                      border: InputBorder.none,
                                      contentPadding:
                                          EdgeInsets.symmetric(horizontal: 16),
                                    ),
                                    onChanged: (value) {
                                      setState(() {
                                        searchQuery = value;
                                        currentPage = 1;
                                      });
                                    },
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: Icon(Icons.search,
                                      color: Colors.grey[600]),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Timetable
                          _buildTimetableTable(context),
                          const SizedBox(height: 16),

                          // Pagination Controls
                          _buildPaginationControls(),
                        ],
                      )
                    else if (isLoading)
                      const Center(child: CircularProgressIndicator())
                    else if (selectedExamId != null && timetableData.isEmpty)
                      _buildNoDataMessage(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimetableTable(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!, width: 1),
        borderRadius: BorderRadius.circular(8),
        color: Colors.white,
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header Row
            Container(
              color: const Color(0xFF202124),
              child: Row(
                children: [
                  _buildTableCell('S.No', 70, isHeader: true, isDark: true),
                  _buildTableCell('Class Info', 150,
                      isHeader: true, isDark: true),
                  _buildTableCell('Code', 130, isHeader: true, isDark: true),
                  _buildTableCell('Course', 180, isHeader: true, isDark: true),
                  _buildTableCell('Date', 120, isHeader: true, isDark: true),
                  _buildTableCell('Session', 150, isHeader: true, isDark: true),
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
                    _buildTableCell(item.sNo.toString(), 70, isHeader: false),
                    _buildTableCell(item.classInfo, 150, isHeader: false),
                    _buildTableCell(item.code, 130, isHeader: false),
                    _buildTableCell(item.course, 180, isHeader: false),
                    _buildTableCell(item.date, 120, isHeader: false),
                    _buildTableCell(item.session, 150, isHeader: false),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildTableCell(String text, double width,
      {required bool isHeader, bool isDark = false}) {
    return Container(
      width: width,
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(
              color: isDark ? Colors.grey[700]! : Colors.grey[300]!, width: 1),
          bottom: BorderSide(color: Colors.grey[300]!, width: 1),
        ),
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          text,
          style: TextStyle(
            fontSize: isHeader ? 12 : 12,
            fontWeight: isHeader ? FontWeight.bold : FontWeight.w500,
            color: isHeader ? Colors.white : Colors.black87,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Widget _buildPaginationControls() {
    final totalPages = _totalPages;
    final filteredLength = _filteredData.length;
    final startIndex = (currentPage - 1) * entriesPerPage + 1;
    final endIndex = (startIndex + entriesPerPage - 1 > filteredLength)
        ? filteredLength
        : startIndex + entriesPerPage - 1;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
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

  Widget _buildNoDataMessage() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.calendar_today,
              size: 100,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 20),
            Text(
              'No exam timetable found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Try selecting a different exam ID',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
