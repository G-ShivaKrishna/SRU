import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../services/audit_log_service.dart';
import '../../../models/audit_log_model.dart';
import '../../../widgets/app_header.dart';

class AuditLogViewerPage extends StatefulWidget {
  const AuditLogViewerPage({super.key});

  @override
  State<AuditLogViewerPage> createState() => _AuditLogViewerPageState();
}

class _AuditLogViewerPageState extends State<AuditLogViewerPage> {
  final _auditService = AuditLogService();
  
  final _dateFormat = DateFormat('MMM dd, yyyy HH:mm');
  
  @override
  void dispose() {
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Activity Log & Audit Trail'),
        backgroundColor: const Color(0xFF1e3a5f),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            tooltip: 'Create Test Log',
            onPressed: _createTestLog,
          ),
        ],
      ),
      body: Column(
        children: [
          const AppHeader(),
          _buildStatistics(),
          Expanded(child: _buildLogList()),
        ],
      ),
    );
  }
  
  Widget _buildStatistics() {
    return FutureBuilder<Map<String, int>>(
      future: _auditService.getLogStatistics(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        
        final stats = snapshot.data!;
        
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            border: Border.all(color: Colors.blue.shade200),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Statistics',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1e3a5f),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 16,
                runSpacing: 8,
                children: [
                  _buildStatChip('Total', stats['total'] ?? 0, Colors.blue),
                  _buildStatChip('Marks', stats['marks'] ?? 0, Colors.orange),
                  _buildStatChip('Fees', stats['fees'] ?? 0, Colors.green),
                  _buildStatChip('Grievances', stats['grievance'] ?? 0, Colors.red),
                  _buildStatChip('Feedback', stats['feedback'] ?? 0, Colors.purple),
                  _buildStatChip('Profile', stats['profile'] ?? 0, Colors.teal),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
  
  Widget _buildStatChip(String label, int count, Color color) {
    return Chip(
      label: Text('$label: $count'),
      backgroundColor: color.withOpacity(0.2),
      labelStyle: TextStyle(
        color: color,
        fontWeight: FontWeight.bold,
        fontSize: 12,
      ),
    );
  }
  
  Widget _buildLogList() {
    print('🔷 Building log list widget...');
    return StreamBuilder<List<AuditLogEntry>>(
      stream: _auditService.getAuditLogs(
        limit: 100,
      ),
      builder: (context, snapshot) {
        print('🔷 StreamBuilder state: ${snapshot.connectionState}');
        print('🔷 Has error: ${snapshot.hasError}');
        print('🔷 Error: ${snapshot.error}');
        print('🔷 Has data: ${snapshot.hasData}');
        print('🔷 Data length: ${snapshot.data?.length ?? 0}');
        
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        if (snapshot.hasError) {
          print('❌ StreamBuilder error: ${snapshot.error}');
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, color: Colors.red, size: 48),
                const SizedBox(height: 16),
                Text('Error: ${snapshot.error}'),
                const SizedBox(height: 8),
                Text('Stack: ${snapshot.stackTrace}', 
                  style: const TextStyle(fontSize: 10)),
              ],
            ),
          );
        }
        
        final logs = snapshot.data ?? [];
        
        if (logs.isEmpty) {
          return const Center(
            child: Text('No activity logs found'),
          );
        }
        
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: logs.length,
          itemBuilder: (context, index) {
            return _buildLogCard(logs[index]);
          },
        );
      },
    );
  }
  
  Widget _buildLogCard(AuditLogEntry log) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: _getModuleIcon(log.module),
        title: Text(
          log.getDescription(),
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          _dateFormat.format(log.timestamp),
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailRow('User ID', log.userId),
                _buildDetailRow('Role', _formatRole(log.userRole)),
                _buildDetailRow('Operation', log.operation.toUpperCase()),
                _buildDetailRow('Module', _formatModule(log.module)),
                if (log.targetId != null)
                  _buildDetailRow('Target', log.targetId!),
                if (log.affectedUsers.isNotEmpty)
                  _buildDetailRow(
                    'Affected Users',
                    log.affectedUsers.take(5).join(', ') +
                        (log.affectedUsers.length > 5
                            ? ' +${log.affectedUsers.length - 5} more'
                            : ''),
                  ),
                const Divider(height: 24),
                const Text(
                  'Details:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
                const SizedBox(height: 8),
                ...log.details.entries.map((e) =>
                    _buildDetailRow(e.key, e.value.toString())),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade900,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _getModuleIcon(String module) {
    IconData icon;
    Color color;
    
    switch (module) {
      case 'marks':
        icon = Icons.grade;
        color = Colors.orange;
        break;
      case 'fees':
        icon = Icons.payment;
        color = Colors.green;
        break;
      case 'grievance':
        icon = Icons.report_problem;
        color = Colors.red;
        break;
      case 'feedback':
        icon = Icons.feedback;
        color = Colors.purple;
        break;
      case 'profile':
        icon = Icons.person;
        color = Colors.teal;
        break;
      default:
        icon = Icons.description;
        color = Colors.blue;
    }
    
    return CircleAvatar(
      backgroundColor: color.withOpacity(0.2),
      child: Icon(icon, color: color, size: 20),
    );
  }
  
  String _formatRole(String role) {
    switch (role) {
      case 'faculty':
        return 'Faculty';
      case 'fee_payment':
        return 'Fee Payment Staff';
      case 'student':
        return 'Student';
      default:
        return role;
    }
  }
  
  String _formatModule(String module) {
    switch (module) {
      case 'marks':
        return 'Marks Entry';
      case 'fees':
        return 'Fee Payments';
      case 'grievance':
        return 'Grievances';
      case 'feedback':
        return 'Feedback';
      case 'profile':
        return 'Profile Updates';
      default:
        return module;
    }
  }
  
  Future<void> _createTestLog() async {
    print('🧪 Creating test audit log...');
    try {
      await _auditService.logActivity(
        userId: 'TEST001',
        userRole: 'faculty',
        operation: 'test',
        module: 'marks',
        subModule: 'test_marks',
        targetEntity: 'testEntity',
        targetId: 'test_${DateTime.now().millisecondsSinceEpoch}',
        affectedUsers: ['STUDENT001', 'STUDENT002'],
        details: {
          'testField': 'Test Value',
          'timestamp': DateTime.now().toString(),
          'description': 'This is a test audit log entry',
        },
      );
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✓ Test audit log created successfully!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
    } catch (e) {
      print('❌ Failed to create test log: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to create test log: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }
}
