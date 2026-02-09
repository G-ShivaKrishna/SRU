import 'package:flutter/material.dart';

class PermissionManagementPage extends StatefulWidget {
  const PermissionManagementPage({super.key});

  @override
  State<PermissionManagementPage> createState() =>
      _PermissionManagementPageState();
}

class _PermissionManagementPageState extends State<PermissionManagementPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<Map<String, dynamic>> _pendingRequests = [
    {
      'id': '1',
      'name': 'John Student',
      'hallTicket': 'HT202201001',
      'type': 'Profile Edit',
      'fields': ['Mobile Number', 'Address', 'Email'],
      'requestedAt': '2024-01-15 10:30 AM',
    },
    {
      'id': '2',
      'name': 'Dr. Jane Faculty',
      'facultyId': 'FAC2001',
      'type': 'Marks Edit',
      'subject': 'DBMS',
      'requestedAt': '2024-01-14 03:15 PM',
    },
  ];

  final List<Map<String, dynamic>> _activePermissions = [
    {
      'id': '1',
      'name': 'Alice Student',
      'type': 'Profile Edit',
      'grantedAt': '2024-01-10',
      'expiresAt': '2024-02-10',
      'status': 'Active',
    },
    {
      'id': '2',
      'name': 'Prof. Bob Faculty',
      'type': 'Marks Edit',
      'grantedAt': '2024-01-01',
      'expiresAt': 'No Expiry',
      'status': 'Active',
    },
  ];

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
        title: const Text('Manage Permissions'),
        backgroundColor: const Color(0xFF1e3a5f),
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Pending Requests'),
            Tab(text: 'Active Permissions'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPendingRequestsView(isMobile),
          _buildActivePermissionsView(isMobile),
        ],
      ),
    );
  }

  Widget _buildPendingRequestsView(bool isMobile) {
    return ListView.builder(
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      itemCount: _pendingRequests.length,
      itemBuilder: (context, index) =>
          _buildPendingRequestCard(_pendingRequests[index], isMobile),
    );
  }

  Widget _buildPendingRequestCard(Map<String, dynamic> request, bool isMobile) {
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
                  request['name'],
                  style: TextStyle(
                    fontSize: isMobile ? 13 : 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange[100],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    request['type'],
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.orange[900],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildInfoRow(
              'ID',
              request['hallTicket'] ?? request['facultyId'],
              isMobile,
            ),
            if (request['fields'] != null)
              _buildFieldsList(request['fields'], isMobile),
            if (request['subject'] != null)
              _buildInfoRow('Subject', request['subject'], isMobile),
            _buildInfoRow('Requested At', request['requestedAt'], isMobile),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _grantPermission(request),
                    icon: const Icon(Icons.check),
                    label: const Text('Grant'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding:
                          EdgeInsets.symmetric(vertical: isMobile ? 10 : 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _rejectPermission(request),
                    icon: const Icon(Icons.close),
                    label: const Text('Reject'),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.red),
                      padding:
                          EdgeInsets.symmetric(vertical: isMobile ? 10 : 12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFieldsList(List<String> fields, bool isMobile) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Editable Fields:',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: isMobile ? 10 : 11,
            ),
          ),
          const SizedBox(height: 6),
          ...fields.map(
            (field) => Padding(
              padding: const EdgeInsets.only(left: 8, top: 2, bottom: 2),
              child: Row(
                children: [
                  const Icon(Icons.circle, size: 6),
                  const SizedBox(width: 8),
                  Text(field, style: TextStyle(fontSize: isMobile ? 10 : 11)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivePermissionsView(bool isMobile) {
    return ListView.builder(
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      itemCount: _activePermissions.length,
      itemBuilder: (context, index) =>
          _buildActivePermissionCard(_activePermissions[index], isMobile),
    );
  }

  Widget _buildActivePermissionCard(
      Map<String, dynamic> permission, bool isMobile) {
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
                  permission['name'],
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
                    permission['status'],
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
            _buildInfoRow('Permission Type', permission['type'], isMobile),
            _buildInfoRow('Granted At', permission['grantedAt'], isMobile),
            _buildInfoRow('Expires At', permission['expiresAt'], isMobile),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _revokePermission(permission),
                icon: const Icon(Icons.block),
                label: const Text('Revoke Permission'),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.red),
                  foregroundColor: Colors.red,
                  padding: EdgeInsets.symmetric(vertical: isMobile ? 10 : 12),
                ),
              ),
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

  void _grantPermission(Map<String, dynamic> request) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Permission granted to ${request['name']}')),
    );
    setState(() => _pendingRequests.remove(request));
  }

  void _rejectPermission(Map<String, dynamic> request) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text('Permission request rejected for ${request['name']}')),
    );
    setState(() => _pendingRequests.remove(request));
  }

  void _revokePermission(Map<String, dynamic> permission) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Revoke Permission?'),
        content: Text(
          'Are you sure you want to revoke ${permission['type']} permission from ${permission['name']}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Permission revoked from ${permission['name']}',
                  ),
                ),
              );
              setState(() => _activePermissions.remove(permission));
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Revoke'),
          ),
        ],
      ),
    );
  }
}
