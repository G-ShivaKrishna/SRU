import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class RegularFeeWindowManagementPage extends StatefulWidget {
  const RegularFeeWindowManagementPage({super.key});

  @override
  State<RegularFeeWindowManagementPage> createState() =>
      _RegularFeeWindowManagementPageState();
}

class _RegularFeeWindowManagementPageState
    extends State<RegularFeeWindowManagementPage> {
  final _firestore = FirebaseFirestore.instance;

  Future<void> _showWindowDialog({QueryDocumentSnapshot? existing}) async {
    final data = existing?.data() as Map<String, dynamic>?;
    final titleCtrl = TextEditingController(text: data?['title']?.toString() ?? '');
    final sessionCtrl =
        TextEditingController(text: data?['examSession']?.toString() ?? '');
    final feeCtrl = TextEditingController(
      text: data?['fee'] != null ? data!['fee'].toString() : '',
    );

    DateTime? startDate = (data?['startDate'] as Timestamp?)?.toDate();
    DateTime? endDate = (data?['endDate'] as Timestamp?)?.toDate();
    bool isActive = data?['isActive'] as bool? ?? true;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: Text(existing == null
              ? 'Create Regular Fee Window'
              : 'Edit Regular Fee Window'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(labelText: 'Window Title *'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: sessionCtrl,
                  decoration: const InputDecoration(labelText: 'Exam Session *'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: feeCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Fee Amount (INR) *',
                    prefixIcon: Icon(Icons.currency_rupee, size: 16),
                  ),
                ),
                const SizedBox(height: 10),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(startDate == null
                      ? 'Start Date *'
                      : 'Start: ${DateFormat('dd MMM yyyy').format(startDate!)}'),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: startDate ?? DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2035),
                    );
                    if (picked != null) {
                      setSt(() => startDate = picked);
                    }
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(endDate == null
                      ? 'End Date *'
                      : 'End: ${DateFormat('dd MMM yyyy').format(endDate!)}'),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: endDate ?? (startDate ?? DateTime.now()),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2035),
                    );
                    if (picked != null) {
                      setSt(() => endDate = picked);
                    }
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Window Active'),
                  value: isActive,
                  onChanged: (value) => setSt(() => isActive = value),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1e3a5f),
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                final title = titleCtrl.text.trim();
                final examSession = sessionCtrl.text.trim();
                final fee = double.tryParse(feeCtrl.text.trim());

                if (title.isEmpty ||
                    examSession.isEmpty ||
                    fee == null ||
                    startDate == null ||
                    endDate == null) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(
                      content: Text('Please fill all required fields.'),
                    ),
                  );
                  return;
                }

                if (endDate!.isBefore(startDate!)) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(
                      content: Text('End date must be on or after start date.'),
                    ),
                  );
                  return;
                }

                final payload = <String, dynamic>{
                  'title': title,
                  'examSession': examSession,
                  'fee': fee,
                  'startDate': Timestamp.fromDate(startDate!),
                  'endDate': Timestamp.fromDate(endDate!),
                  'isActive': isActive,
                };

                if (existing == null) {
                  payload['createdAt'] = FieldValue.serverTimestamp();
                  await _firestore.collection('regularExamWindows').add(payload);
                } else {
                  payload['updatedAt'] = FieldValue.serverTimestamp();
                  await _firestore
                      .collection('regularExamWindows')
                      .doc(existing.id)
                      .update(payload);
                }

                if (ctx.mounted) {
                  Navigator.pop(ctx);
                }
              },
              child: Text(existing == null ? 'Create' : 'Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleWindow(String id, bool currentValue) async {
    await _firestore.collection('regularExamWindows').doc(id).update({
      'isActive': !currentValue,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _deleteWindow(String id) async {
    await _firestore.collection('regularExamWindows').doc(id).delete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Regular Fee Window Management'),
        backgroundColor: const Color(0xFF1e3a5f),
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('regularExamWindows')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Failed to load windows: ${snapshot.error}'),
            );
          }

          final docs = snapshot.data?.docs ?? [];

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Manage the Regular Exam Fee windows shown in Fee Payment.',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _showWindowDialog(),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('New Window'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1e3a5f),
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              if (docs.isEmpty)
                const Expanded(
                  child: Center(
                    child: Text(
                      'No regular fee windows found.\nCreate one to enable Regular Exam Fee payments.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final doc = docs[index];
                      final data = doc.data() as Map<String, dynamic>;
                      final isActive = (data['isActive'] as bool?) ?? false;
                      final fee = (data['fee'] as num?)?.toDouble() ?? 0;
                      final startDate = (data['startDate'] as Timestamp?)?.toDate();
                      final endDate = (data['endDate'] as Timestamp?)?.toDate();

                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      data['title']?.toString() ?? 'Untitled Window',
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: isActive ? Colors.green : Colors.grey,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      isActive ? 'ACTIVE' : 'INACTIVE',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Session: ${data['examSession']?.toString() ?? '-'}',
                              ),
                              Text('Fee: INR ${fee.toStringAsFixed(2)}'),
                              if (startDate != null && endDate != null)
                                Text(
                                  'Window: ${DateFormat('dd MMM yyyy').format(startDate)} - ${DateFormat('dd MMM yyyy').format(endDate)}',
                                ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Switch(
                                    value: isActive,
                                    onChanged: (_) => _toggleWindow(doc.id, isActive),
                                  ),
                                  const Text('Enable in Fee Payment'),
                                  const Spacer(),
                                  IconButton(
                                    tooltip: 'Edit',
                                    icon: const Icon(Icons.edit_outlined),
                                    onPressed: () => _showWindowDialog(existing: doc),
                                  ),
                                  IconButton(
                                    tooltip: 'Delete',
                                    icon: const Icon(Icons.delete_outline,
                                        color: Colors.red),
                                    onPressed: () async {
                                      final shouldDelete = await showDialog<bool>(
                                        context: context,
                                        builder: (ctx) => AlertDialog(
                                          title: const Text('Delete Window'),
                                          content: const Text(
                                            'Are you sure you want to delete this regular fee window?',
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(ctx, false),
                                              child: const Text('Cancel'),
                                            ),
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(ctx, true),
                                              child: const Text('Delete'),
                                            ),
                                          ],
                                        ),
                                      );

                                      if (shouldDelete == true) {
                                        await _deleteWindow(doc.id);
                                      }
                                    },
                                  ),
                                ],
                              ),
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
      ),
    );
  }
}
