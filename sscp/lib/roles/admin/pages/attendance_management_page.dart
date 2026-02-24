import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

/// Admin page to review faculty requests to edit past attendance records.
/// Reads the `attendanceEditRequests` collection and lets admin approve/reject.
class AttendanceManagementPage extends StatefulWidget {
  const AttendanceManagementPage({super.key});

  @override
  State<AttendanceManagementPage> createState() =>
      _AttendanceManagementPageState();
}

class _AttendanceManagementPageState extends State<AttendanceManagementPage>
    with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
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

  // ── build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance Management'),
        backgroundColor: const Color(0xFF1e3a5f),
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(icon: Icon(Icons.pending_actions), text: 'Pending'),
            Tab(icon: Icon(Icons.history), text: 'History'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _RequestList(
            firestore: _firestore,
            statusFilter: 'pending',
            emptyMessage: 'No pending edit requests.',
            showActions: true,
          ),
          _RequestList(
            firestore: _firestore,
            statusFilter: null, // all non-pending
            emptyMessage: 'No past requests.',
            showActions: false,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Inner widget that renders either the pending list or the history list
// ─────────────────────────────────────────────────────────────────────────────

class _RequestList extends StatelessWidget {
  const _RequestList({
    required this.firestore,
    required this.statusFilter,
    required this.emptyMessage,
    required this.showActions,
  });

  final FirebaseFirestore firestore;

  /// 'pending' for pending tab; null for history tab (approved + rejected)
  final String? statusFilter;
  final String emptyMessage;
  final bool showActions;

  /// No orderBy on the Firestore side to avoid composite-index requirement.
  /// Sorting is done client-side after the snapshot arrives.
  Stream<QuerySnapshot> get _stream {
    final col = firestore.collection('attendanceEditRequests');
    if (statusFilter != null) {
      return col.where('status', isEqualTo: statusFilter).snapshots();
    }
    // history: approved or rejected
    return col.where('status', whereIn: ['approved', 'rejected']).snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _stream,
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(child: Text('Error: ${snap.error}'));
        }
        // Sort newest-first client-side (avoids composite Firestore index)
        final docs = List<QueryDocumentSnapshot>.from(snap.data?.docs ?? []);
        docs.sort((a, b) {
          final aTs = (a.data() as Map<String, dynamic>)['requestedAt'];
          final bTs = (b.data() as Map<String, dynamic>)['requestedAt'];
          if (aTs == null && bTs == null) return 0;
          if (aTs == null) return 1;
          if (bTs == null) return -1;
          return (bTs as Timestamp).compareTo(aTs as Timestamp);
        });
        if (docs.isEmpty) {
          return _emptyState();
        }
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          itemBuilder: (ctx, i) => _RequestCard(
            doc: docs[i],
            showActions: showActions,
            firestore: firestore,
          ),
        );
      },
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.assignment_outlined,
              size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(emptyMessage,
              style: TextStyle(fontSize: 15, color: Colors.grey.shade600)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Card for a single request
// ─────────────────────────────────────────────────────────────────────────────

class _RequestCard extends StatelessWidget {
  const _RequestCard({
    required this.doc,
    required this.showActions,
    required this.firestore,
  });

  final QueryDocumentSnapshot doc;
  final bool showActions;
  final FirebaseFirestore firestore;

  Map<String, dynamic> get _data => doc.data() as Map<String, dynamic>;

  String get _facultyId => _data['facultyId'] as String? ?? '—';
  String get _subjectCode => _data['subjectCode'] as String? ?? '—';
  String get _subjectName => _data['subjectName'] as String? ?? '';
  String get _fromDateStr => _data['fromDateStr'] as String? ?? '—';
  String get _toDateStr => _data['toDateStr'] as String? ?? '—';
  String get _reason => _data['reason'] as String? ?? '—';
  String get _status => _data['status'] as String? ?? 'pending';
  String get _adminNote => _data['adminNote'] as String? ?? '';

  Timestamp? get _requestedAt => _data['requestedAt'] as Timestamp?;

  Color get _statusColor {
    switch (_status) {
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  String get _statusLabel {
    switch (_status) {
      case 'approved':
        return 'Approved';
      case 'rejected':
        return 'Rejected';
      default:
        return 'Pending';
    }
  }

  @override
  Widget build(BuildContext context) {
    final submittedAt = _requestedAt != null
        ? DateFormat('dd-MM-yyyy HH:mm').format(_requestedAt!.toDate())
        : '—';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── header row ─────────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$_subjectCode${_subjectName.isNotEmpty ? ' — $_subjectName' : ''}',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 2),
                      Text('Faculty: $_facultyId',
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey.shade700)),
                    ],
                  ),
                ),
                _statusChip(_statusLabel, _statusColor),
              ],
            ),
            const SizedBox(height: 10),
            // ── date range ─────────────────────────────────────────────
            _infoRow(
                Icons.date_range, 'Date range: $_fromDateStr  →  $_toDateStr'),
            _infoRow(Icons.access_time, 'Requested: $submittedAt'),
            const SizedBox(height: 8),
            // ── reason ─────────────────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'Reason: $_reason',
                style: const TextStyle(fontSize: 13),
              ),
            ),
            // ── admin note (if any) ────────────────────────────────────
            if (_adminNote.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _statusColor.withOpacity(0.08),
                  border: Border.all(color: _statusColor.withOpacity(0.3)),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Admin note: $_adminNote',
                  style: TextStyle(
                      fontSize: 13, color: _statusColor.withOpacity(0.9)),
                ),
              ),
            ],
            // ── action buttons (pending only) ──────────────────────────
            if (showActions) ...[
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _showActionDialog(context, false),
                    icon: const Icon(Icons.close, size: 16),
                    label: const Text('Reject'),
                    style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red)),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    onPressed: () => _showActionDialog(context, true),
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text('Approve'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _showActionDialog(BuildContext context, bool approve) async {
    final noteCtrl = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(approve ? 'Approve Request' : 'Reject Request'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              approve
                  ? 'Allow $_facultyId to edit $_subjectCode attendance from $_fromDateStr to $_toDateStr?'
                  : 'Reject edit request from $_facultyId for $_subjectCode?',
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: noteCtrl,
              maxLines: 2,
              decoration: InputDecoration(
                labelText:
                    approve ? 'Note (optional)' : 'Reason for rejection *',
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: approve ? Colors.green : Colors.red),
            child: Text(approve ? 'Approve' : 'Reject',
                style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _updateStatus(
        approve: approve,
        adminNote: noteCtrl.text.trim(),
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(approve ? 'Request approved.' : 'Request rejected.'),
          backgroundColor: approve ? Colors.green : Colors.red,
        ));
      }
    }
  }

  Future<void> _updateStatus(
      {required bool approve, required String adminNote}) async {
    await firestore.collection('attendanceEditRequests').doc(doc.id).update({
      'status': approve ? 'approved' : 'rejected',
      'adminNote': adminNote,
      'resolvedAt': FieldValue.serverTimestamp(),
    });
  }

  // ── helpers ───────────────────────────────────────────────────────────────

  Widget _statusChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        border: Border.all(color: color.withOpacity(0.5)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 12, fontWeight: FontWeight.bold)),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(children: [
        Icon(icon, size: 14, color: Colors.grey),
        const SizedBox(width: 6),
        Expanded(
            child: Text(text,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700))),
      ]),
    );
  }
}
