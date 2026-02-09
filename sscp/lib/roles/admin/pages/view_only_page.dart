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
      itemBuilder: (context, index) => _buildStudentCard(index, isMobile),
    );
  }

  Widget _buildStudentCard(int index, bool isMobile) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 12 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Student ${index + 1}',
                  style: TextStyle(
                    fontSize: isMobile ? 13 : 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green[100],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Active',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.green[800],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildInfoRow('Hall Ticket', 'HT2022${1001 + index}', isMobile),
            _buildInfoRow('Name', 'Student Name ${index + 1}', isMobile),
            _buildInfoRow('Department', 'CSE', isMobile),
            _buildInfoRow('Batch', '2022-2026', isMobile),
            _buildInfoRow('Year', '2', isMobile),
            _buildInfoRow('Email', 'student${index + 1}@email.com', isMobile),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildViewButton('Profile', Colors.blue, isMobile),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildViewButton('Marks', Colors.green, isMobile),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child:
                      _buildViewButton('Attendance', Colors.orange, isMobile),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFacultyView(bool isMobile) {
    return ListView.builder(
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      itemCount: 10,
      itemBuilder: (context, index) => _buildFacultyCard(index, isMobile),
    );
  }

  Widget _buildFacultyCard(int index, bool isMobile) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 12 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Faculty ${index + 1}',
                  style: TextStyle(
                    fontSize: isMobile ? 13 : 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green[100],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Active',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.green[800],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildInfoRow('Faculty ID', 'FAC${2000 + index}', isMobile),
            _buildInfoRow('Name', 'Faculty Name ${index + 1}', isMobile),
            _buildInfoRow('Department', 'CSE', isMobile),
            _buildInfoRow('Designation', 'Assistant Professor', isMobile),
            _buildInfoRow('Email', 'faculty${index + 1}@email.com', isMobile),
            _buildInfoRow('Subjects', 'DBMS, OS, DSA', isMobile),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildViewButton('Profile', Colors.blue, isMobile),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildViewButton('Marks', Colors.green, isMobile),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildViewButton('Records', Colors.purple, isMobile),
                ),
              ],
            ),
          ],
        ),
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
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildViewButton(String label, Color color, bool isMobile) {
    return OutlinedButton(
      onPressed: () {},
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: color),
        padding: EdgeInsets.symmetric(vertical: isMobile ? 6 : 8),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: isMobile ? 9 : 10),
      ),
    );
  }
}
