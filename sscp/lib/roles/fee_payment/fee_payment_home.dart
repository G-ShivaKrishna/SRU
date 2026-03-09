import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../screens/role_selection_screen.dart';
import '../../services/audit_log_service.dart';
import '../../services/user_service.dart';

// ─── Fee type configuration ───────────────────────────────────────────────────
class _FeeTypeConfig {
  final String label;
  final String paymentType;
  final String windowsCollection;
  final String windowIdField;
  const _FeeTypeConfig({
    required this.label,
    required this.paymentType,
    required this.windowsCollection,
    required this.windowIdField,
  });
}

const _feeTypes = <_FeeTypeConfig>[
  _FeeTypeConfig(
    label: 'Regular Fee',
    paymentType: 'regular_fee',
    windowsCollection: 'regularFeeWindows',
    windowIdField: 'regularFeeWindowId',
  ),
  _FeeTypeConfig(
    label: 'Supply Exam Fee',
    paymentType: 'supply',
    windowsCollection: 'supplyWindows',
    windowIdField: 'supplyWindowId',
  ),
  _FeeTypeConfig(
    label: 'Makeup Mid Fee',
    paymentType: 'makeup_mid',
    windowsCollection: 'makeupMidWindows',
    windowIdField: 'makeupWindowId',
  ),
  _FeeTypeConfig(
    label: 'Regular Exam Fee',
    paymentType: 'regular_exam',
    windowsCollection: 'regularExamWindows',
    windowIdField: 'regularExamWindowId',
  ),
];

class FeePaymentHome extends StatefulWidget {
  const FeePaymentHome({super.key});

  static const String routeName = '/feePaymentHome';

  @override
  State<FeePaymentHome> createState() => _FeePaymentHomeState();
}

class _FeePaymentHomeState extends State<FeePaymentHome> {
  _FeeTypeConfig _selectedType = _feeTypes[0];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fee Payment Portal'),
        backgroundColor: const Color(0xFF1e3a5f),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const RoleSelectionScreen()),
          ),
        ),
      ),
      body: Column(
        children: [
          // ── Fee type selector ──────────────────────────────────────────
          Container(
            color: const Color(0xFF1e3a5f).withValues(alpha: 0.06),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: DropdownButtonFormField<_FeeTypeConfig>(
              initialValue: _selectedType,
              decoration: const InputDecoration(
                labelText: 'Select Fee Type',
                border: OutlineInputBorder(),
                isDense: true,
                filled: true,
                fillColor: Colors.white,
                prefixIcon: Icon(Icons.category_outlined),
              ),
              items: _feeTypes
                  .map((t) => DropdownMenuItem(
                        value: t,
                        child: Text(t.label),
                      ))
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _selectedType = v);
              },
            ),
          ),
          // ── Fee update panel (recreated on type change) ────────────────
          Expanded(
            child: _FeeUpdatePanel(
              key: ValueKey(_selectedType.paymentType),
              config: _selectedType,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Panel: windows dropdown + roll number input + paid/unpaid buttons + records
// ─────────────────────────────────────────────────────────────────────────────

class _FeeUpdatePanel extends StatefulWidget {
  final _FeeTypeConfig config;
  const _FeeUpdatePanel({super.key, required this.config});

  @override
  State<_FeeUpdatePanel> createState() => _FeeUpdatePanelState();
}

class _FeeUpdatePanelState extends State<_FeeUpdatePanel> {
  final _db = FirebaseFirestore.instance;
  final _rollCtrl = TextEditingController();
  bool _saving = false;
  String? _selectedWindowId;

  @override
  void dispose() {
    _rollCtrl.dispose();
    super.dispose();
  }

  Future<void> _update(String status) async {
    final rollNo = _rollCtrl.text.trim().toUpperCase();
    if (rollNo.isEmpty) {
      _snack('Enter roll number', error: true);
      return;
    }
    if (_selectedWindowId == null) {
      _snack('Select a window / session', error: true);
      return;
    }

    setState(() => _saving = true);
    try {
      final windowDoc = await _db
          .collection(widget.config.windowsCollection)
          .doc(_selectedWindowId)
          .get();
      if (!windowDoc.exists) {
        _snack('Selected window not found', error: true);
        return;
      }

      final winData = windowDoc.data() ?? {};
      final windowTitle = winData['title']?.toString() ?? _selectedWindowId!;
      final examSession = winData['examSession']?.toString() ?? '';
      final amount =
          status == 'paid' ? (winData['fee'] as num?)?.toDouble() ?? 0 : 0.0;

      String studentName = '';
      if (status == 'paid') {
        final studentDoc = await _db.collection('students').doc(rollNo).get();
        studentName = studentDoc.data()?['name']?.toString() ?? '';
      }

      final staffEmail = FirebaseAuth.instance.currentUser?.email ?? '';
      final staffId = UserService.getCurrentUserId() ??
          staffEmail.split('@').first.toUpperCase();
      final docId =
          '${widget.config.paymentType}_${_selectedWindowId!}_$rollNo';

      await _db.collection('feePayments').doc(docId).set({
        'paymentType': widget.config.paymentType,
        'feeTypeLabel': widget.config.label,
        'windowId': _selectedWindowId,
        'windowTitle': windowTitle,
        'windowIdField': widget.config.windowIdField,
        'rollNo': rollNo,
        if (studentName.isNotEmpty) 'studentName': studentName,
        'examSession': examSession,
        'amount': amount,
        'status': status,
        'updatedBy': staffId,
        'updatedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      AuditLogService().logFeePayment(
        staffId: staffId,
        paymentType: widget.config.paymentType,
        windowId: _selectedWindowId!,
        studentRollNo: rollNo,
        status: status,
        amount: amount,
        additionalDetails: {
          'windowTitle': windowTitle,
          'examSession': examSession,
          'studentName': studentName,
          'feeType': widget.config.label,
        },
      );

      _snack('$rollNo marked as ${status.toUpperCase()}');
      _rollCtrl.clear();
    } catch (e) {
      _snack('Failed: $e', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? Colors.red : Colors.green,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _db
          .collection(widget.config.windowsCollection)
          .where('isActive', isEqualTo: true)
          .snapshots(),
      builder: (context, snap) {
        // Show all windows that admin has marked active — trust isActive flag
        final windows = (snap.data?.docs ?? []).toList();

        // Reset window selection if it's no longer in the list
        if (_selectedWindowId != null &&
            windows.isNotEmpty &&
            !windows.any((w) => w.id == _selectedWindowId)) {
          _selectedWindowId = null;
        }

        final rollFilled = _rollCtrl.text.trim().isNotEmpty;
        final canAct = !_saving && rollFilled && _selectedWindowId != null;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Input card ──────────────────────────────────────────────
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.payment,
                            color: Color(0xFF1e3a5f), size: 20),
                        const SizedBox(width: 8),
                        Text(
                          widget.config.label,
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Window selector
                    if (snap.connectionState == ConnectionState.waiting)
                      const Center(
                          child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: CircularProgressIndicator(),
                      ))
                    else if (windows.isEmpty)
                      _InfoBox(
                        icon: Icons.info_outline,
                        color: Colors.orange,
                        text:
                            'No active windows declared by admin for "${widget.config.label}". Ask admin to create one.',
                      )
                    else
                      DropdownButtonFormField<String>(
                        initialValue: _selectedWindowId,
                        decoration: const InputDecoration(
                          labelText: 'Window / Session',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: windows.map((doc) {
                          final d = doc.data() as Map<String, dynamic>;
                          final title = d['title']?.toString() ?? doc.id;
                          final session = d['examSession']?.toString() ?? '';
                          final fee = d['fee'];
                          return DropdownMenuItem(
                            value: doc.id,
                            child: Text(
                              [
                                title,
                                if (session.isNotEmpty) session,
                                if (fee != null) '₹$fee',
                              ].join(' · '),
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: (v) => setState(() => _selectedWindowId = v),
                      ),

                    const SizedBox(height: 12),
                    // Roll number
                    TextField(
                      controller: _rollCtrl,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                        labelText: 'Student Roll Number',
                        hintText: 'e.g. 2203A51001',
                        border: OutlineInputBorder(),
                        isDense: true,
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 14),

                    // Buttons
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: canAct ? () => _update('paid') : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green.shade700,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: Colors.green.shade200,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            icon: _saving
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        color: Colors.white, strokeWidth: 2),
                                  )
                                : const Icon(Icons.check_circle_outline),
                            label: const Text('Mark PAID'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: canAct ? () => _update('unpaid') : null,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.orange.shade800,
                              side: BorderSide(color: Colors.orange.shade400),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            icon: const Icon(Icons.cancel_outlined),
                            label: const Text('Mark UNPAID'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Students can register only when their fee status is PAID for the selected window.',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),

            // ── Payment records ─────────────────────────────────────────
            if (_selectedWindowId != null &&
                _rollCtrl.text.trim().isNotEmpty) ...[
              const SizedBox(height: 14),
              _PaymentRecords(
                db: _db,
                paymentType: widget.config.paymentType,
                windowId: _selectedWindowId!,
                rollNo: _rollCtrl.text.trim().toUpperCase(),
              ),
            ],
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Payment records list with paid/unpaid summary counts
// ─────────────────────────────────────────────────────────────────────────────

class _PaymentRecords extends StatelessWidget {
  final FirebaseFirestore db;
  final String paymentType;
  final String windowId;
  final String rollNo;

  const _PaymentRecords({
    required this.db,
    required this.paymentType,
    required this.windowId,
    required this.rollNo,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: db
          .collection('feePayments')
          .where('paymentType', isEqualTo: paymentType)
          .where('windowId', isEqualTo: windowId)
          .where('rollNo', isEqualTo: rollNo)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        var docs = List.of(snap.data?.docs ?? []);
        docs.sort((a, b) {
          final ta = (a.data() as Map)['updatedAt'] as Timestamp?;
          final tb = (b.data() as Map)['updatedAt'] as Timestamp?;
          return (tb?.toDate() ?? DateTime(2000))
              .compareTo(ta?.toDate() ?? DateTime(2000));
        });
        if (docs.length > 50) docs = docs.sublist(0, 50);

        final paidCount =
            docs.where((d) => (d.data() as Map)['status'] == 'paid').length;
        final unpaidCount = docs.length - paidCount;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('Payment Records',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const Spacer(),
                _Badge(label: 'Paid: $paidCount', color: Colors.green),
                const SizedBox(width: 6),
                _Badge(label: 'Unpaid: $unpaidCount', color: Colors.orange),
              ],
            ),
            const SizedBox(height: 8),
            if (docs.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(14),
                  child: Text('No payment records yet.',
                      style: TextStyle(color: Colors.grey)),
                ),
              )
            else
              Card(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                child: Column(
                  children: docs.map((doc) {
                    final d = doc.data() as Map<String, dynamic>;
                    final isPaid = d['status'] == 'paid';
                    final name = d['studentName']?.toString() ?? '';
                    return ListTile(
                      dense: true,
                      leading: CircleAvatar(
                        radius: 14,
                        backgroundColor: isPaid
                            ? Colors.green.shade100
                            : Colors.orange.shade100,
                        child: Icon(
                          isPaid ? Icons.check : Icons.close,
                          size: 14,
                          color: isPaid
                              ? Colors.green.shade700
                              : Colors.orange.shade700,
                        ),
                      ),
                      title: Text(
                        d['rollNo']?.toString() ?? '',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        name.isNotEmpty
                            ? '$name · by ${d['updatedBy'] ?? '-'}'
                            : 'Updated by: ${d['updatedBy'] ?? '-'}',
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isPaid
                              ? Colors.green.shade50
                              : Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                              color: isPaid
                                  ? Colors.green.shade300
                                  : Colors.orange.shade300),
                        ),
                        child: Text(
                          isPaid ? 'PAID' : 'UNPAID',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                            color: isPaid
                                ? Colors.green.shade700
                                : Colors.orange.shade700,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _InfoBox extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;
  const _InfoBox({required this.icon, required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
              child: Text(text,
                  style: const TextStyle(fontSize: 13, color: Colors.black87))),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.bold, color: color)),
    );
  }
}
