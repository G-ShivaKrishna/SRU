import 'package:flutter/material.dart';

class ViewOnlyPage extends StatefulWidget {
  const ViewOnlyPage({super.key});

  @override
  State<ViewOnlyPage> createState() => _ViewOnlyPageState();
}

class _ViewOnlyPageState extends State<ViewOnlyPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      appBar: AppBar(
        title: const Text('View Data (Read-Only)'),
        backgroundColor: const Color(0xFF1e3a5f),
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Students'),
            Tab(text: 'Faculty'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildStudentView(isMobile),
          _buildFacultyView(isMobile),
        ],
      ),
    );
  }

  Widget _buildStudentView(bool isMobile) {
    return ListView.builder(
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      itemCount: 10,
      itemBuilder: (context, index) => _buildDataCard(
        'Student ${index + 1}',
        {
          'Hall Ticket': 'HT202201${1001 + index}',
          'Name': 'Student Name ${index + 1}',
          'Department': 'CSE',
          'Batch': '2022-2026',
          'Year': '2',
          'Email': 'student${index + 1}@email.com',
          'Status': 'Active',
        },
        index,
        isMobile,
        Colors.blue,
      ),
    );
  }

  Widget _buildFacultyView(bool isMobile) {
    return ListView.builder(
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      itemCount: 10,
      itemBuilder: (context, index) => _buildDataCard(
        'Faculty ${index + 1}',
        {
          'Faculty ID': 'FAC${2000 + index}',
          'Name': 'Faculty Name ${index + 1}',
          'Department': 'CSE',
          'Designation': 'Assistant Professor',
          'Email': 'faculty${index + 1}@email.com',
          'Subjects': 'DBMS, OS, DSA',
          'Status': 'Active',
        },
        index,
        isMobile,
        Colors.green,
      ),
    );
  }

  Widget _buildDataCard(
    String title,
    Map<String, String> data,
    int index,
    bool isMobile,
    Color statusColor,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: isMobile ? 13 : 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  data['Status'] ?? 'Active',
                  style: TextStyle(
                    fontSize: 10,
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...data.entries.where((e) => e.key != 'Status').map((e) =>
              _buildInfoRow(e.key, e.value, isMobile)).toList(),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, bool isMobile) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: isMobile ? 10 : 11,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: isMobile ? 11 : 12,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}
