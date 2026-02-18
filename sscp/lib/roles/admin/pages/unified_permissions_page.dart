import 'package:flutter/material.dart';
import '../../../services/student_access_service.dart';

class UnifiedPermissionsPage extends StatefulWidget {
  const UnifiedPermissionsPage({super.key});

  @override
  State<UnifiedPermissionsPage> createState() => _UnifiedPermissionsPageState();
}

class _UnifiedPermissionsPageState extends State<UnifiedPermissionsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _studentPendingRequests = [];
  List<Map<String, dynamic>> _studentApprovedRequests = [];
  List<Map<String, dynamic>> _studentRejectedRequests = [];
  List<Map<String, dynamic>> _facultyPendingRequests = [];
  List<Map<String, dynamic>> _facultyApprovedRequests = [];
  List<Map<String, dynamic>> _facultyRejectedRequests = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 7, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final allRequests = await StudentAccessService.getAllEditAccessRequests();

      // Separate by user type (student or faculty)
      final studentRequests = allRequests.where((req) {
        final hallTicket = req['hallTicketNumber'] ?? '';
        // Students have format like 2203A51291, Faculty have format like FAC001
        return !hallTicket.startsWith('FAC');
      }).toList();

      final facultyRequests = allRequests.where((req) {
        final hallTicket = req['hallTicketNumber'] ?? '';
        return hallTicket.startsWith('FAC');
      }).toList();

      final studentPending =
          studentRequests.where((req) => req['status'] == 'pending').toList();
      final studentApproved =
          studentRequests.where((req) => req['status'] == 'approved').toList();
      final studentRejected =
          studentRequests.where((req) => req['status'] == 'rejected').toList();

      final facultyPending =
          facultyRequests.where((req) => req['status'] == 'pending').toList();
      final facultyApproved =
          facultyRequests.where((req) => req['status'] == 'approved').toList();
      final facultyRejected =
          facultyRequests.where((req) => req['status'] == 'rejected').toList();

      setState(() {
        _studentPendingRequests = studentPending;
        _studentApprovedRequests = studentApproved;
        _studentRejectedRequests = studentRejected;
        _facultyPendingRequests = facultyPending;
        _facultyApprovedRequests = facultyApproved;
        _facultyRejectedRequests = facultyRejected;
        _isLoading = false;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading data: $e')),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _approveRequest(Map<String, dynamic> request) async {
    final confirmApprove = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Approve Edit Access?'),
        content: Text(
          'Allow ${request['studentName']} (${request['hallTicketNumber']}) to edit their profile?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Approve', style: TextStyle(color: Colors.green)),
          ),
        ],
      ),
    );

    if (confirmApprove == true) {
      final result = await StudentAccessService.approveEditAccessRequest(
        request['requestId'],
        request['hallTicketNumber'],
      );

      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Edit access approved successfully'),
            backgroundColor: Colors.green,
          ),
        );
        _loadData();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'])),
        );
      }
    }
  }

  Future<void> _rejectRequest(Map<String, dynamic> request) async {
    final reasonController = TextEditingController();

    final confirmReject = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Request?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Reject edit access request from ${request['studentName']} (${request['hallTicketNumber']})?',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                hintText: 'Optional rejection reason',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reject', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmReject == true) {
      final result = await StudentAccessService.rejectEditAccessRequest(
        request['requestId'],
        reasonController.text.isNotEmpty ? reasonController.text : null,
      );

      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Request rejected'),
            backgroundColor: Colors.orange,
          ),
        );
        _loadData();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'])),
        );
      }
    }
    reasonController.dispose();
  }

  Future<void> _revokeAccess(String hallTicketNumber) async {
    final confirmRevoke = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Revoke Edit Access?'),
        content: Text(
          'Remove edit access from $hallTicketNumber?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Revoke', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmRevoke == true) {
      final result =
          await StudentAccessService.revokeEditAccess(hallTicketNumber);

      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Edit access revoked'),
            backgroundColor: Colors.red,
          ),
        );
        _loadData();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'])),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Manage Access & Permissions'),
          backgroundColor: const Color(0xFF1e3a5f),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Access & Permissions'),
        backgroundColor: const Color(0xFF1e3a5f),
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: isMobile,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            Tab(
              text: 'Students - Pending (${_studentPendingRequests.length})',
              icon: const Icon(Icons.pending_actions),
            ),
            Tab(
              text: 'Students - Approved (${_studentApprovedRequests.length})',
              icon: const Icon(Icons.check_circle),
            ),
            Tab(
              text: 'Students - Rejected (${_studentRejectedRequests.length})',
              icon: const Icon(Icons.cancel),
            ),
            Tab(
              text: 'Faculty - Pending (${_facultyPendingRequests.length})',
              icon: const Icon(Icons.pending_actions),
            ),
            Tab(
              text: 'Faculty - Approved (${_facultyApprovedRequests.length})',
              icon: const Icon(Icons.check_circle),
            ),
            Tab(
              text: 'Faculty - Rejected (${_facultyRejectedRequests.length})',
              icon: const Icon(Icons.cancel),
            ),
            const Tab(
              text: 'Refresh',
              icon: Icon(Icons.refresh),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPendingRequestsTab(_studentPendingRequests, isMobile),
          _buildApprovedRequestsTab(_studentApprovedRequests, isMobile),
          _buildRejectedRequestsTab(_studentRejectedRequests, isMobile),
          _buildPendingRequestsTab(_facultyPendingRequests, isMobile),
          _buildApprovedRequestsTab(_facultyApprovedRequests, isMobile),
          _buildRejectedRequestsTab(_facultyRejectedRequests, isMobile),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.refresh, size: 48, color: Colors.grey),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _loadData,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh Data'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1e3a5f),
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingRequestsTab(
      List<Map<String, dynamic>> requests, bool isMobile) {
    if (requests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              'No pending requests',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      itemCount: requests.length,
      itemBuilder: (context, index) {
        final request = requests[index];
        return _buildRequestCard(request, 'pending', isMobile);
      },
    );
  }

  Widget _buildApprovedRequestsTab(
      List<Map<String, dynamic>> requests, bool isMobile) {
    if (requests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              'No approved requests',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      itemCount: requests.length,
      itemBuilder: (context, index) {
        final request = requests[index];
        return _buildRequestCard(request, 'approved', isMobile);
      },
    );
  }

  Widget _buildRejectedRequestsTab(
      List<Map<String, dynamic>> requests, bool isMobile) {
    if (requests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cancel, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              'No rejected requests',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      itemCount: requests.length,
      itemBuilder: (context, index) {
        final request = requests[index];
        return _buildRequestCard(request, 'rejected', isMobile);
      },
    );
  }

  Widget _buildRequestCard(
      Map<String, dynamic> request, String status, bool isMobile) {
    final DateTime requestedAt =
        (request['requestedAt'] as dynamic).toDate() ?? DateTime.now();
    final formattedDate =
        '${requestedAt.day}/${requestedAt.month}/${requestedAt.year} ${requestedAt.hour}:${requestedAt.minute.toString().padLeft(2, '0')}';

    Color statusColor;
    IconData statusIcon;

    if (status == 'pending') {
      statusColor = Colors.orange;
      statusIcon = Icons.pending_actions;
    } else if (status == 'approved') {
      statusColor = Colors.green;
      statusIcon = Icons.check_circle;
    } else {
      statusColor = Colors.red;
      statusIcon = Icons.cancel;
    }

    return Card(
      margin: EdgeInsets.only(bottom: isMobile ? 12 : 16),
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 12 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(statusIcon, color: statusColor, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        request['studentName'] ?? 'Unknown',
                        style: TextStyle(
                          fontSize: isMobile ? 14 : 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        request['hallTicketNumber'] ?? 'N/A',
                        style: TextStyle(
                          fontSize: isMobile ? 11 : 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: statusColor.withOpacity(0.5)),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildFieldsChip(request['fieldsToEdit'] ?? [], isMobile),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.schedule, size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 6),
                Text(
                  formattedDate,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
            if (request['rejectionReason'] != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  border: Border.all(color: Colors.red.shade200),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Rejection Reason:',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.red.shade700,
                      ),
                    ),
                    Text(
                      request['rejectionReason'],
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.red.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (status == 'pending') ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _rejectRequest(request),
                      icon: const Icon(Icons.close),
                      label: const Text('Reject'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _approveRequest(request),
                      icon: const Icon(Icons.check),
                      label: const Text('Approve'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ] else if (status == 'approved') ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _revokeAccess(request['hallTicketNumber']),
                  icon: const Icon(Icons.block),
                  label: const Text('Revoke Access'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.orange,
                    side: const BorderSide(color: Colors.orange),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFieldsChip(List<dynamic> fields, bool isMobile) {
    if (fields.isEmpty) {
      return const SizedBox.shrink();
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: fields
          .map((field) => Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  border: Border.all(color: Colors.blue.shade200),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  field.toString(),
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.blue.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ))
          .toList(),
    );
  }
}
