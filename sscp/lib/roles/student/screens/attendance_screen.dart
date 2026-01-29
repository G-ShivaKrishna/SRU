import 'package:flutter/material.dart';
import '../../../widgets/app_header.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  DateTime? fromDate;
  DateTime? toDate;

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance Report'),
        backgroundColor: const Color(0xFF1e3a5f),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const AppHeader(),
            Padding(
              padding: EdgeInsets.all(isMobile ? 12 : 16),
              child: Column(
                children: [
                  _buildDateRangeSelector(context),
                  const SizedBox(height: 24),
                  _buildAttendanceReport(context),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateRangeSelector(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!, width: 1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Select Date Range',
            style: TextStyle(
              fontSize: isMobile ? 13 : 14,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1e3a5f),
            ),
          ),
          const SizedBox(height: 16),
          if (isMobile)
            Column(
              children: [
                _buildDateField('From Date', fromDate, (date) {
                  setState(() => fromDate = date);
                }),
                const SizedBox(height: 12),
                _buildDateField('To Date', toDate, (date) {
                  setState(() => toDate = date);
                }),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () {},
                    child: const Text(
                      'Submit',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            )
          else
            Row(
              children: [
                Expanded(
                  child: _buildDateField('From Date', fromDate, (date) {
                    setState(() => fromDate = date);
                  }),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildDateField('To Date', toDate, (date) {
                    setState(() => toDate = date);
                  }),
                ),
                const SizedBox(width: 16),
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                    ),
                    onPressed: () {},
                    child: const Text(
                      'Submit',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildDateField(
    String label,
    DateTime? selectedDate,
    Function(DateTime) onDateSelected,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1e3a5f),
          ),
        ),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: () async {
            final pickedDate = await showDatePicker(
              context: context,
              initialDate: selectedDate ?? DateTime.now(),
              firstDate: DateTime(2020),
              lastDate: DateTime.now(),
            );
            if (pickedDate != null) {
              onDateSelected(pickedDate);
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[400]!),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  selectedDate != null
                      ? '${selectedDate.day.toString().padLeft(2, '0')}/${selectedDate.month.toString().padLeft(2, '0')}/${selectedDate.year}'
                      : 'mm/dd/yyyy',
                  style: TextStyle(
                    fontSize: 12,
                    color: selectedDate != null ? Colors.black : Colors.grey,
                  ),
                ),
                Icon(Icons.calendar_today, size: 18, color: Colors.grey[600]),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAttendanceReport(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    final attendanceData = [
      {
        'courseCode': '22CS301',
        'courseName': 'Design and Analysis of Algorithms',
        'classesHeld': '25',
        'classesAttended': '24',
        'percentage': '96.00%'
      },
      {
        'courseCode': '22CS302',
        'courseName': 'Operating Systems',
        'classesHeld': '24',
        'classesAttended': '23',
        'percentage': '95.83%'
      },
      {
        'courseCode': '22CS303',
        'courseName': 'DBMS',
        'classesHeld': '26',
        'classesAttended': '25',
        'percentage': '96.15%'
      },
      {
        'courseCode': '22CS304',
        'courseName': 'Python Programming',
        'classesHeld': '23',
        'classesAttended': '22',
        'percentage': '95.65%'
      },
    ];

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!, width: 1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(isMobile ? 12 : 14),
            decoration: BoxDecoration(
              color: const Color(0xFF1e3a5f),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(7),
                topRight: Radius.circular(7),
              ),
            ),
            child: Text(
              'Attendance Summary',
              style: TextStyle(
                color: Colors.white,
                fontSize: isMobile ? 13 : 15,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(isMobile ? 12 : 14),
            child: isMobile
                ? _buildMobileAttendanceList(attendanceData)
                : _buildDesktopAttendanceTable(attendanceData),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopAttendanceTable(List<Map<String, String>> data) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(
              label: Text('Course Code',
                  style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(
              label: Text('Course Name',
                  style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(
              label: Text('Classes Held',
                  style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(
              label: Text('Classes Attended',
                  style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(
              label: Text('Percentage',
                  style: TextStyle(fontWeight: FontWeight.bold))),
        ],
        rows: data.map((item) {
          return DataRow(
            cells: [
              DataCell(Text(item['courseCode']!)),
              DataCell(
                SizedBox(
                  width: 250,
                  child: Text(
                    item['courseName']!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              DataCell(Text(item['classesHeld']!)),
              DataCell(Text(item['classesAttended']!)),
              DataCell(
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getPercentageColor(item['percentage']!),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    item['percentage']!,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMobileAttendanceList(List<Map<String, String>> data) {
    return Column(
      children: data.asMap().entries.map((entry) {
        int index = entry.key;
        Map<String, String> item = entry.value;

        return Column(
          children: [
            if (index > 0) Divider(color: Colors.grey[300], height: 16),
            _buildMobileAttendanceRow('Course Code', item['courseCode']!),
            _buildMobileAttendanceRow('Course Name', item['courseName']!),
            _buildMobileAttendanceRow('Classes Held', item['classesHeld']!),
            _buildMobileAttendanceRow(
                'Classes Attended', item['classesAttended']!),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Percentage',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1e3a5f),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getPercentageColor(item['percentage']!),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      item['percentage']!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildMobileAttendanceRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1e3a5f),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 11,
                color: Colors.black87,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Color _getPercentageColor(String percentage) {
    final percent = double.parse(percentage.replaceAll('%', ''));
    if (percent >= 90) {
      return Colors.green;
    } else if (percent >= 75) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }
}
