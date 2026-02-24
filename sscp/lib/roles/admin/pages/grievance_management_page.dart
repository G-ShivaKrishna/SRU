import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../widgets/app_header.dart';

class GrievanceManagementPage extends StatefulWidget {
  const GrievanceManagementPage({super.key});

  @override
  State<GrievanceManagementPage> createState() =>
      _GrievanceManagementPageState();
}

class _GrievanceManagementPageState extends State<GrievanceManagementPage> {
  final _firestore = FirebaseFirestore.instance;

  String _filterStatus = 'All';
  String _filterType = 'All';

  static const _statuses = [
    'All',
    'Pending',
    'Under Review',
    'Resolved',
    'Rejected',
  ];

  static const _types = [
    'All',
    'Academics',
    'Accounts',
    'Administrative Office',
    'Bus',
    'Examinations',
    'Hostel',
    'Library',
    'Other',
    'Ragging',
  ];

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'resolved':
        return Colors.green;
      case 'under review':
        return Colors.orange;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey.shade600;
    }
  }

  Future<void> _showUpdateDialog(DocumentSnapshot doc) async {
    final d = doc.data() as Map<String, dynamic>;
    String selectedStatus = d['status'] ?? 'Pending';
    final responseCtrl = TextEditingController(text: d['adminResponse'] ?? '');
    bool saving = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: Text(
            'Update Grievance — ${d['grievanceType']}',
            style: const TextStyle(
                color: Color(0xFF1e3a5f), fontWeight: FontWeight.bold),
          ),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Student info
                RichText(
                  text: TextSpan(
                    style: const TextStyle(fontSize: 13, color: Colors.black87),
                    children: [
                      const TextSpan(
                          text: 'Student: ',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      TextSpan(
                          text: '${d['studentName']} (${d['rollNumber']})'),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                // Description preview
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Text(
                    d['description'] ?? '',
                    style: const TextStyle(fontSize: 12),
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 16),
                // Status dropdown
                const Text('Status',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: selectedStatus,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                  ),
                  items: _statuses
                      .where((s) => s != 'All')
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setDlg(() => selectedStatus = v);
                  },
                ),
                const SizedBox(height: 16),
                // Admin response
                const Text('Response to Student (optional)',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                TextFormField(
                  controller: responseCtrl,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Enter a message for the student...',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.all(10),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1e3a5f),
                foregroundColor: Colors.white,
              ),
              onPressed: saving
                  ? null
                  : () async {
                      setDlg(() => saving = true);
                      try {
                        await _firestore
                            .collection('grievances')
                            .doc(doc.id)
                            .update({
                          'status': selectedStatus,
                          'adminResponse': responseCtrl.text.trim(),
                          'updatedAt': FieldValue.serverTimestamp(),
                        });
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Grievance updated.'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      } catch (e) {
                        setDlg(() => saving = false);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
              child: saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                  : const Text('Update'),
            ),
          ],
        ),
      ),
    );

    responseCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Column(
        children: [
          const AppHeader(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    Query query = _firestore
        .collection('grievances')
        .orderBy('createdAt', descending: true);

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        // Client-side filter
        var docs = snapshot.data?.docs ?? [];
        if (_filterStatus != 'All') {
          docs = docs
              .where((d) => (d.data() as Map)['status'] == _filterStatus)
              .toList();
        }
        if (_filterType != 'All') {
          docs = docs
              .where((d) => (d.data() as Map)['grievanceType'] == _filterType)
              .toList();
        }

        // Status counts for header chips
        final all = snapshot.data?.docs ?? [];
        int pending =
            all.where((d) => (d.data() as Map)['status'] == 'Pending').length;
        int underReview = all
            .where((d) => (d.data() as Map)['status'] == 'Under Review')
            .length;
        int resolved =
            all.where((d) => (d.data() as Map)['status'] == 'Resolved').length;

        return Column(
          children: [
            // ── Header ──────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Grievance Management',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1e3a5f),
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Summary chips
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _SummaryChip(
                          label: 'Total',
                          count: all.length,
                          color: Colors.blue),
                      _SummaryChip(
                          label: 'Pending',
                          count: pending,
                          color: Colors.grey.shade600),
                      _SummaryChip(
                          label: 'Under Review',
                          count: underReview,
                          color: Colors.orange),
                      _SummaryChip(
                          label: 'Resolved',
                          count: resolved,
                          color: Colors.green),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Filters
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      SizedBox(
                        width: 160,
                        child: DropdownButtonFormField<String>(
                          value: _filterStatus,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: 'Status',
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8)),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 12),
                          ),
                          items: _statuses
                              .map((s) =>
                                  DropdownMenuItem(value: s, child: Text(s)))
                              .toList(),
                          onChanged: (v) =>
                              setState(() => _filterStatus = v ?? 'All'),
                        ),
                      ),
                      SizedBox(
                        width: 200,
                        child: DropdownButtonFormField<String>(
                          value: _filterType,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: 'Type',
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8)),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 12),
                          ),
                          items: _types
                              .map((t) =>
                                  DropdownMenuItem(value: t, child: Text(t)))
                              .toList(),
                          onChanged: (v) =>
                              setState(() => _filterType = v ?? 'All'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // ── List ────────────────────────────────────────────
            Expanded(
              child: docs.isEmpty
                  ? const Center(
                      child: Text('No grievances found.',
                          style: TextStyle(color: Colors.grey, fontSize: 14)),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        final doc = docs[index];
                        final d = doc.data() as Map<String, dynamic>;
                        final status = d['status'] ?? 'Pending';
                        final createdAt = d['createdAt'] as Timestamp?;
                        final dateStr = createdAt != null
                            ? '${createdAt.toDate().day}/${createdAt.toDate().month}/${createdAt.toDate().year}'
                            : '–';

                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                          elevation: 2,
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    // Type badge
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF1e3a5f)
                                            .withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        d['grievanceType'] ?? '',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF1e3a5f),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    // Status badge
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: _statusColor(status)
                                            .withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                            color: _statusColor(status)),
                                      ),
                                      child: Text(
                                        status,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: _statusColor(status),
                                        ),
                                      ),
                                    ),
                                    const Spacer(),
                                    // Update button
                                    TextButton.icon(
                                      onPressed: () => _showUpdateDialog(doc),
                                      icon: const Icon(Icons.edit, size: 14),
                                      label: const Text('Update',
                                          style: TextStyle(fontSize: 12)),
                                      style: TextButton.styleFrom(
                                        foregroundColor:
                                            const Color(0xFF1e3a5f),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                // Student info
                                Text(
                                  '${d['studentName'] ?? ''} — ${d['rollNumber'] ?? ''}',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                // Description
                                Text(
                                  d['description'] ?? '',
                                  style: const TextStyle(
                                      fontSize: 13, color: Colors.black87),
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Submitted: $dateStr',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade600),
                                ),
                                // Admin response
                                if ((d['adminResponse'] ?? '').isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.shade50,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                          color: Colors.blue.shade200),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(Icons.admin_panel_settings,
                                            size: 14,
                                            color: Colors.blue.shade700),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            d['adminResponse'],
                                            style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.blue.shade900),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _SummaryChip(
      {required this.label, required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        '$label: $count',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
