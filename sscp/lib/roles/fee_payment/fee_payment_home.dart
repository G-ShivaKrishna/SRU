import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../screens/role_selection_screen.dart';
import '../../services/audit_log_service.dart';
import '../../services/user_service.dart';

class FeePaymentHome extends StatefulWidget {
  const FeePaymentHome({super.key});

  static const String routeName = '/feePaymentHome';

  @override
  State<FeePaymentHome> createState() => _FeePaymentHomeState();
}

class _FeePaymentHomeState extends State<FeePaymentHome>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fee Payment Portal'),
        backgroundColor: const Color(0xFF1e3a5f),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                  builder: (context) => const RoleSelectionScreen()),
            );
          },
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Supply Fees'),
            Tab(text: 'Makeup Mid Fees'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _FeeUpdateTab(
            paymentType: 'supply',
            windowsCollection: 'supplyWindows',
            windowIdField: 'supplyWindowId',
            title: 'Supply Exam Fee Confirmation',
          ),
          _FeeUpdateTab(
            paymentType: 'makeup_mid',
            windowsCollection: 'makeupMidWindows',
            windowIdField: 'makeupWindowId',
            title: 'Makeup Mid Fee Confirmation',
          ),
        ],
      ),
    );
  }
}

class _FeeUpdateTab extends StatefulWidget {
  final String paymentType;
  final String windowsCollection;
  final String windowIdField;
  final String title;

  const _FeeUpdateTab({
    required this.paymentType,
    required this.windowsCollection,
    required this.windowIdField,
    required this.title,
  });

  @override
  State<_FeeUpdateTab> createState() => _FeeUpdateTabState();
}

class _FeeUpdateTabState extends State<_FeeUpdateTab> {
  final _db = FirebaseFirestore.instance;
  final _rollCtrl = TextEditingController();
  bool _saving = false;
  String? _selectedWindowId;

  @override
  void dispose() {
    _rollCtrl.dispose();
    super.dispose();
  }

  Future<void> _markPaid() async {
    final rollNo = _rollCtrl.text.trim().toUpperCase();
    if (rollNo.isEmpty) {
      _showSnack('Enter roll number', isError: true);
      return;
    }
    if (_selectedWindowId == null) {
      _showSnack('Select a registration window', isError: true);
      return;
    }

    setState(() => _saving = true);
    try {
      final windowDoc = await _db
          .collection(widget.windowsCollection)
          .doc(_selectedWindowId)
          .get();
      if (!windowDoc.exists) {
        _showSnack('Selected window not found', isError: true);
        return;
      }

      final studentDoc = await _db.collection('students').doc(rollNo).get();
      final studentName = studentDoc.data()?['name']?.toString() ?? '';

      final winData = windowDoc.data() ?? <String, dynamic>{};
      final windowTitle = winData['title']?.toString() ?? _selectedWindowId!;
      final examSession = winData['examSession']?.toString() ?? '';
      final amount = (winData['fee'] as num?)?.toDouble() ?? 0;

      final staffEmail = FirebaseAuth.instance.currentUser?.email ?? '';
      final staffId = UserService.getCurrentUserId() ??
          staffEmail.split('@').first.toUpperCase();
      final paymentDocId =
          '${widget.paymentType}_${_selectedWindowId!}_$rollNo';

      await _db.collection('feePayments').doc(paymentDocId).set({
        'paymentType': widget.paymentType,
        'windowId': _selectedWindowId,
        'windowTitle': windowTitle,
        'windowIdField': widget.windowIdField,
        'rollNo': rollNo,
        'studentName': studentName,
        'examSession': examSession,
        'amount': amount,
        'status': 'paid',
        'updatedBy': staffId,
        'updatedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Log audit trail
      AuditLogService().logFeePayment(
        staffId: staffId,
        paymentType: widget.paymentType,
        windowId: _selectedWindowId!,
        studentRollNo: rollNo,
        status: 'paid',
        amount: amount,
        additionalDetails: {
          'windowTitle': windowTitle,
          'examSession': examSession,
          'studentName': studentName,
        },
      );

      _showSnack('Payment marked as PAID for $rollNo');
    } catch (e) {
      _showSnack('Failed to update payment: $e', isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _markUnpaid() async {
    final rollNo = _rollCtrl.text.trim().toUpperCase();
    if (rollNo.isEmpty || _selectedWindowId == null) {
      _showSnack('Enter roll number and select a window', isError: true);
      return;
    }

    setState(() => _saving = true);
    try {
      final staffEmail = FirebaseAuth.instance.currentUser?.email ?? '';
      final staffId = UserService.getCurrentUserId() ??
          staffEmail.split('@').first.toUpperCase();
      final paymentDocId =
          '${widget.paymentType}_${_selectedWindowId!}_$rollNo';

      await _db.collection('feePayments').doc(paymentDocId).set({
        'paymentType': widget.paymentType,
        'windowId': _selectedWindowId,
        'windowIdField': widget.windowIdField,
        'rollNo': rollNo,
        'status': 'unpaid',
        'updatedBy': staffId,
        'updatedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Log audit trail
      AuditLogService().logFeePayment(
        staffId: staffId,
        paymentType: widget.paymentType,
        windowId: _selectedWindowId!,
        studentRollNo: rollNo,
        status: 'unpaid',
        amount: 0,
        additionalDetails: {},
      );

      _showSnack('Payment set to UNPAID for $rollNo');
    } catch (e) {
      _showSnack('Failed to update payment: $e', isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _db
          .collection(widget.windowsCollection)
          .where('isActive', isEqualTo: true)
          .snapshots(),
      builder: (context, snap) {
        final windows = (snap.data?.docs ?? []).where((doc) {
          final d = doc.data() as Map<String, dynamic>;
          final start = (d['startDate'] as Timestamp?)?.toDate();
          final end = (d['endDate'] as Timestamp?)?.toDate();
          final now = DateTime.now();
          if (start == null || end == null) return false;
          return now.isAfter(start) && now.isBefore(end);
        }).toList();

        if (windows.isNotEmpty &&
            _selectedWindowId != null &&
            !windows.any((w) => w.id == _selectedWindowId)) {
          _selectedWindowId = null;
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.title,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    if (windows.isEmpty)
                      const Text(
                        'No active registration windows right now.',
                        style: TextStyle(color: Colors.grey),
                      )
                    else
                      DropdownButtonFormField<String>(
                        initialValue: _selectedWindowId,
                        decoration: const InputDecoration(
                          labelText: 'Registration Window',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: windows.map((doc) {
                          final d = doc.data() as Map<String, dynamic>;
                          final title = d['title']?.toString() ?? doc.id;
                          final session = d['examSession']?.toString() ?? '';
                          return DropdownMenuItem(
                            value: doc.id,
                            child: Text(
                              '$title (${session.isEmpty ? '-' : session})',
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: (v) => setState(() => _selectedWindowId = v),
                      ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _rollCtrl,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                        labelText: 'Student Roll No',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _saving ? null : _markPaid,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1e3a5f),
                              foregroundColor: Colors.white,
                            ),
                            icon: const Icon(Icons.check_circle_outline),
                            label: const Text('Mark Paid'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _saving ? null : _markUnpaid,
                            icon: const Icon(Icons.cancel_outlined),
                            label: const Text('Mark Unpaid'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Student registration is allowed only when payment status is PAID for the selected window.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
            if (_selectedWindowId != null) ...[
              const SizedBox(height: 10),
              const Text('Recent Payment Updates',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              StreamBuilder<QuerySnapshot>(
                stream: _db
                    .collection('feePayments')
                    .where('paymentType', isEqualTo: widget.paymentType)
                    .where('windowId', isEqualTo: _selectedWindowId)
                    .snapshots(),
                builder: (context, listSnap) {
                  if (listSnap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  var docs = listSnap.data?.docs ?? [];
                  // Sort client-side by updatedAt descending, limit to 25
                  docs.sort((a, b) {
                    final timeA = (a.data()
                        as Map<String, dynamic>)['updatedAt'] as Timestamp?;
                    final timeB = (b.data()
                        as Map<String, dynamic>)['updatedAt'] as Timestamp?;
                    return (timeB?.toDate() ?? DateTime(2000))
                        .compareTo(timeA?.toDate() ?? DateTime(2000));
                  });
                  if (docs.length > 25) {
                    docs = docs.sublist(0, 25);
                  }
                  if (docs.isEmpty) {
                    return const Card(
                      child: Padding(
                        padding: EdgeInsets.all(14),
                        child: Text('No payment updates yet.'),
                      ),
                    );
                  }
                  return Card(
                    child: Column(
                      children: docs.map((doc) {
                        final d = doc.data() as Map<String, dynamic>;
                        final paid =
                            (d['status']?.toString().toLowerCase() ?? '') ==
                                'paid';
                        return ListTile(
                          dense: true,
                          leading: Icon(
                            paid ? Icons.check_circle : Icons.cancel,
                            color: paid ? Colors.green : Colors.orange,
                            size: 18,
                          ),
                          title: Text((d['rollNo'] ?? '').toString()),
                          subtitle:
                              Text('Updated by: ${d['updatedBy'] ?? '-'}'),
                          trailing: Text(
                            paid ? 'PAID' : 'UNPAID',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: paid ? Colors.green : Colors.orange,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  );
                },
              )
            ],
          ],
        );
      },
    );
  }
}
