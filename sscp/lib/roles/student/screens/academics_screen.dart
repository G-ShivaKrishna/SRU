import 'package:flutter/material.dart';
import '../../../widgets/app_header.dart';

class AcademicsScreen extends StatefulWidget {
  const AcademicsScreen({super.key});

  @override
  State<AcademicsScreen> createState() => _AcademicsScreenState();
}

class _AcademicsScreenState extends State<AcademicsScreen> {
  String? selectedYear;
  String? selectedDegree;
  String? selectedSem;
  bool isCalendarFetched = false;

  final academicYears = ['2022-23', '2023-24', '2024-25', '2025-26'];
  final degrees = ['BTECH', 'MTECH', 'MBA', 'MCA'];
  final semesters = ['1', '2', '3', '4', '5', '6', '7', '8'];

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Academic Calendar'),
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
                  _buildFilterCard(context),
                  const SizedBox(height: 24),
                  if (isCalendarFetched)
                    _buildCalendarContent(context)
                  else
                    _buildNoDataMessage(context),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderSection(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Container(
      color: const Color(0xFF1e3a5f),
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      child: Text(
        'Academic Calendar',
        style: TextStyle(
          color: Colors.yellow,
          fontSize: isMobile ? 14 : 16,
          fontWeight: FontWeight.bold,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildFilterCard(BuildContext context) {
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
            'Select Filters',
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
                _buildDropdownField(
                    'Academic Year', selectedYear, academicYears, (value) {
                  setState(() => selectedYear = value);
                }),
                const SizedBox(height: 12),
                _buildDropdownField('Degree', selectedDegree, degrees, (value) {
                  setState(() => selectedDegree = value);
                }),
                const SizedBox(height: 12),
                _buildDropdownField('Semester', selectedSem, semesters,
                    (value) {
                  setState(() => selectedSem = value);
                }),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: _onSearchPressed,
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
            )
          else
            Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildDropdownField(
                          'Academic Year', selectedYear, academicYears,
                          (value) {
                        setState(() => selectedYear = value);
                      }),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildDropdownField(
                          'Degree', selectedDegree, degrees, (value) {
                        setState(() => selectedDegree = value);
                      }),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildDropdownField(
                          'Semester', selectedSem, semesters, (value) {
                        setState(() => selectedSem = value);
                      }),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: _onSearchPressed,
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
        ],
      ),
    );
  }

  Widget _buildDropdownField(String label, String? value, List<String> items,
      Function(String?) onChanged) {
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
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[400]!),
            borderRadius: BorderRadius.circular(4),
          ),
          child: DropdownButton<String>(
            value: value,
            isExpanded: true,
            underline: const SizedBox(),
            hint: Text('Select $label'),
            items: items.map((String item) {
              return DropdownMenuItem<String>(
                value: item,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(item),
                ),
              );
            }).toList(),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  void _onSearchPressed() {
    if (selectedYear != null && selectedDegree != null && selectedSem != null) {
      setState(() => isCalendarFetched = true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select all filters'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildNoDataMessage(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Center(
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 16 : 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 40),
            Icon(
              Icons.calendar_today,
              size: isMobile ? 80 : 120,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 20),
            Text(
              'Select filters and click Search',
              style: TextStyle(
                fontSize: isMobile ? 16 : 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'to view the academic calendar',
              style: TextStyle(
                fontSize: isMobile ? 12 : 14,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendarContent(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    final calendarEvents = [
      {'event': 'Semester Starts', 'date': '15-Jul-2025', 'type': 'start'},
      {'event': 'Add/Drop Courses', 'date': '22-Jul-2025', 'type': 'important'},
      {'event': 'Mid Sem Exams', 'date': '15-Sep-2025', 'type': 'exam'},
      {
        'event': 'Project Submission',
        'date': '10-Oct-2025',
        'type': 'deadline'
      },
      {'event': 'End Sem Exams', 'date': '20-Nov-2025', 'type': 'exam'},
      {
        'event': 'Results Declaration',
        'date': '05-Dec-2025',
        'type': 'important'
      },
      {'event': 'Semester Ends', 'date': '10-Dec-2025', 'type': 'end'},
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
              'Academic Calendar - $selectedYear | $selectedDegree | Semester $selectedSem',
              style: TextStyle(
                color: Colors.white,
                fontSize: isMobile ? 12 : 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(isMobile ? 12 : 14),
            child: Column(
              children: calendarEvents.asMap().entries.map((entry) {
                int index = entry.key;
                Map<String, String> event = entry.value;
                return Column(
                  children: [
                    if (index > 0) Divider(color: Colors.grey[300], height: 16),
                    _buildCalendarEventRow(event, isMobile),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarEventRow(Map<String, String> event, bool isMobile) {
    Color eventColor;
    IconData eventIcon;

    switch (event['type']) {
      case 'exam':
        eventColor = Colors.red[100]!;
        eventIcon = Icons.event_available;
        break;
      case 'important':
        eventColor = Colors.orange[100]!;
        eventIcon = Icons.flag;
        break;
      case 'deadline':
        eventColor = Colors.purple[100]!;
        eventIcon = Icons.assignment_turned_in;
        break;
      case 'start':
        eventColor = Colors.green[100]!;
        eventIcon = Icons.play_circle;
        break;
      case 'end':
        eventColor = Colors.blue[100]!;
        eventIcon = Icons.stop_circle;
        break;
      default:
        eventColor = Colors.grey[100]!;
        eventIcon = Icons.event;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: eventColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(eventIcon, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event['event']!,
                  style: TextStyle(
                    fontSize: isMobile ? 12 : 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  event['date']!,
                  style: TextStyle(
                    fontSize: isMobile ? 11 : 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
