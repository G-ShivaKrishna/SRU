import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../widgets/app_header.dart';
import '../../../services/user_service.dart';
import '../../../services/audit_log_service.dart';

class GrievanceScreen extends StatefulWidget {
  final int initialIndex;
  const GrievanceScreen({super.key, this.initialIndex = 0});

  @override
  State<GrievanceScreen> createState() => _GrievanceScreenState();
}

class _GrievanceScreenState extends State<GrievanceScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
        length: 2, vsync: this, initialIndex: widget.initialIndex);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Column(
        children: [
          const AppHeader(),
          // Tab bar
          Container(
            color: const Color(0xFF1e3a5f),
            child: TabBar(
              controller: _tabController,
              indicatorColor: Colors.yellow,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              labelStyle:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              tabs: const [
                Tab(text: 'Submit Grievance'),
                Tab(text: 'Grievance Status'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: const [
                _SubmitGrievanceTab(),
                _GrievanceStatusTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Submit Tab ──────────────────────────────────────────────────────────────

class _SubmitGrievanceTab extends StatefulWidget {
  const _SubmitGrievanceTab();

  @override
  State<_SubmitGrievanceTab> createState() => _SubmitGrievanceTabState();
}

class _SubmitGrievanceTabState extends State<_SubmitGrievanceTab> {
  static const _types = [
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

  String? _selectedType;
  final _descCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _submitting = false;

  // No special characters: & ' " @ # $ ...
  static final _specialCharRegex = RegExp(r'''[&'"@#$%^*<>{}|\\]''');

  @override
  void dispose() {
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);

    try {
      final user = FirebaseAuth.instance.currentUser!;
      var rollNumber = UserService.getCurrentUserId();

      // Fallback to email extraction if UserService hasn't cached yet
      if (rollNumber == null || rollNumber.isEmpty) {
        final email = user.email ?? '';
        rollNumber = email.split('@')[0].toUpperCase();
      }

      if (rollNumber.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('User information not found'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _submitting = false);
        return;
      }

      // Fetch student name
      final studentDoc = await FirebaseFirestore.instance
          .collection('students')
          .doc(rollNumber)
          .get();
      final studentName = studentDoc.data()?['name'] ?? rollNumber;

      final docRef =
          await FirebaseFirestore.instance.collection('grievances').add({
        'rollNumber': rollNumber,
        'studentName': studentName,
        'studentEmail': user.email,
        'grievanceType': _selectedType,
        'description': _descCtrl.text.trim(),
        'status': 'Pending',
        'adminResponse': '',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Log audit trail
      AuditLogService().logGrievanceSubmission(
        studentRollNo: rollNumber,
        grievanceId: docRef.id,
        grievanceType: _selectedType!,
        subject: _descCtrl.text.trim().substring(
            0,
            _descCtrl.text.trim().length > 50
                ? 50
                : _descCtrl.text.trim().length),
      );

      _descCtrl.clear();
      setState(() {
        _selectedType = null;
        _submitting = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Grievance submitted successfully.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() => _submitting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 16),
                const Text(
                  'Grievance Entry',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 32),

                // Grievance Type
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Grievance Type',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _selectedType,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6)),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                  ),
                  hint: const Text(''),
                  items: _types
                      .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedType = v),
                  validator: (v) =>
                      v == null ? 'Please select a grievance type' : null,
                ),
                const SizedBox(height: 24),

                // Description
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Describe Your Grievance',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _descCtrl,
                  maxLines: 7,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6)),
                    contentPadding: const EdgeInsets.all(12),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Please describe your grievance';
                    }
                    if (_specialCharRegex.hasMatch(v)) {
                      return 'Special characters are not allowed';
                    }
                    return null;
                  },
                ),

                // Note
                const SizedBox(height: 8),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: 'Note : ',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        TextSpan(
                          text:
                              "Special Characters are not allowed (Ex : &, ' \",@ # \$ ...)",
                          style: TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                              fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Submit button
                SizedBox(
                  width: 140,
                  height: 44,
                  child: ElevatedButton(
                    onPressed: _submitting ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2e7d32),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6)),
                    ),
                    child: _submitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2),
                          )
                        : const Text(
                            'Submit',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Status Tab ──────────────────────────────────────────────────────────────

class _GrievanceStatusTab extends StatefulWidget {
  const _GrievanceStatusTab();

  @override
  State<_GrievanceStatusTab> createState() => _GrievanceStatusTabState();
}

class _GrievanceStatusTabState extends State<_GrievanceStatusTab> {
  Stream<QuerySnapshot>? _stream;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      var rollNumber = UserService.getCurrentUserId();

      // Fallback to email extraction if UserService hasn't cached yet
      if (rollNumber == null || rollNumber.isEmpty) {
        final email = user.email ?? '';
        rollNumber = email.split('@')[0].toUpperCase();
      }

      if (rollNumber.isNotEmpty) {
        _stream = FirebaseFirestore.instance
            .collection('grievances')
            .where('rollNumber', isEqualTo: rollNumber)
            .snapshots();
      }
    }
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'resolved':
        return Colors.green;
      case 'under review':
        return Colors.orange;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey.shade600; // Pending
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_stream == null) {
      return const Center(child: Text('Not logged in.'));
    }

    return StreamBuilder<QuerySnapshot>(
      stream: _stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final docs = (snapshot.data?.docs ?? [])
          ..sort((a, b) {
            final aTime = (a.data() as Map)['createdAt'] as Timestamp?;
            final bTime = (b.data() as Map)['createdAt'] as Timestamp?;
            if (aTime == null || bTime == null) return 0;
            return bTime.compareTo(aTime); // newest first
          });

        if (docs.isEmpty) {
          return const Center(
            child: Text(
              'No grievances submitted yet.',
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final d = docs[index].data() as Map<String, dynamic>;
            final status = d['status'] ?? 'Pending';
            final createdAt = d['createdAt'] as Timestamp?;
            final dateStr = createdAt != null
                ? '${createdAt.toDate().day}/${createdAt.toDate().month}/${createdAt.toDate().year}'
                : '–';

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            d['grievanceType'] ?? '',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1e3a5f),
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: _statusColor(status).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: _statusColor(status), width: 1),
                          ),
                          child: Text(
                            status,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _statusColor(status),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      d['description'] ?? '',
                      style:
                          const TextStyle(fontSize: 13, color: Colors.black87),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Submitted: $dateStr',
                      style:
                          TextStyle(fontSize: 11, color: Colors.grey.shade600),
                    ),
                    if ((d['adminResponse'] ?? '').isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.admin_panel_settings,
                                size: 16, color: Colors.blue.shade700),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                d['adminResponse'],
                                style: TextStyle(
                                    fontSize: 12, color: Colors.blue.shade900),
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
        );
      },
    );
  }
}
