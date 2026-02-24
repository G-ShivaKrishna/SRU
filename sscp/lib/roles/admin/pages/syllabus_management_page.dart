import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../widgets/app_header.dart';

class SyllabusManagementPage extends StatefulWidget {
  const SyllabusManagementPage({super.key});

  @override
  State<SyllabusManagementPage> createState() => _SyllabusManagementPageState();
}

class _SyllabusManagementPageState extends State<SyllabusManagementPage> {
  final _firestore = FirebaseFirestore.instance;
  final _collection = 'syllabusItems';

  // ─── Add / Edit Dialog ─────────────────────────────────────────────────────

  Future<void> _showDialog({DocumentSnapshot? doc}) async {
    final isEdit = doc != null;
    final data = isEdit ? doc.data() as Map<String, dynamic> : {};

    final classInfoCtrl =
        TextEditingController(text: isEdit ? data['classInfo'] ?? '' : '');
    final regulationCtrl =
        TextEditingController(text: isEdit ? data['regulation'] ?? '' : '');
    final urlCtrl =
        TextEditingController(text: isEdit ? data['pdfUrl'] ?? '' : '');

    final formKey = GlobalKey<FormState>();
    bool saving = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setDlg) {
          return AlertDialog(
            title: Text(
              isEdit ? 'Edit Syllabus Entry' : 'Add Syllabus Entry',
              style: const TextStyle(
                color: Color(0xFF1e3a5f),
                fontWeight: FontWeight.bold,
              ),
            ),
            content: SizedBox(
              width: 440,
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Class Info
                    TextFormField(
                      controller: classInfoCtrl,
                      decoration: _inputDecoration(
                        'Class Info',
                        'e.g. 1-1-BTECH-CSE(CSE)',
                        hint2: 'Format: Year-Sem-Degree-Branch(Branch)',
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    // Regulation
                    TextFormField(
                      controller: regulationCtrl,
                      decoration:
                          _inputDecoration('Regulation Code', 'e.g. RA20, R25'),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                      textCapitalization: TextCapitalization.characters,
                    ),
                    const SizedBox(height: 16),
                    // PDF URL
                    TextFormField(
                      controller: urlCtrl,
                      decoration: _inputDecoration(
                        'PDF Link (URL)',
                        'https://...',
                        hint2:
                            'GitHub raw link, Google Drive share link, or direct PDF URL',
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Required';
                        final uri = Uri.tryParse(v.trim());
                        if (uri == null || !uri.hasAbsolutePath) {
                          return 'Enter a valid URL';
                        }
                        return null;
                      },
                      maxLines: 2,
                      keyboardType: TextInputType.url,
                    ),
                  ],
                ),
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
                        if (!formKey.currentState!.validate()) return;
                        setDlg(() => saving = true);

                        try {
                          if (isEdit) {
                            await _firestore
                                .collection(_collection)
                                .doc(doc.id)
                                .update({
                              'classInfo': classInfoCtrl.text.trim(),
                              'regulation':
                                  regulationCtrl.text.trim().toUpperCase(),
                              'pdfUrl': urlCtrl.text.trim(),
                              'updatedAt': FieldValue.serverTimestamp(),
                            });
                          } else {
                            final snap = await _firestore
                                .collection(_collection)
                                .orderBy('sNo', descending: true)
                                .limit(1)
                                .get();
                            final nextSNo = snap.docs.isEmpty
                                ? 1
                                : ((snap.docs.first.data()['sNo'] as num?)
                                            ?.toInt() ??
                                        0) +
                                    1;

                            await _firestore.collection(_collection).add({
                              'sNo': nextSNo,
                              'classInfo': classInfoCtrl.text.trim(),
                              'regulation':
                                  regulationCtrl.text.trim().toUpperCase(),
                              'pdfUrl': urlCtrl.text.trim(),
                              'createdAt': FieldValue.serverTimestamp(),
                            });
                          }

                          if (ctx.mounted) Navigator.pop(ctx);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(isEdit
                                    ? 'Syllabus entry updated.'
                                    : 'Syllabus entry added.'),
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
                    : Text(isEdit ? 'Save' : 'Add'),
              ),
            ],
          );
        });
      },
    );

    classInfoCtrl.dispose();
    regulationCtrl.dispose();
    urlCtrl.dispose();
  }

  Future<void> _delete(DocumentSnapshot doc) async {
    final data = doc.data() as Map<String, dynamic>;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Syllabus Entry'),
        content: Text(
          'Delete "${data['classInfo']} – ${data['regulation']}"?\nThis cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _firestore.collection(_collection).doc(doc.id).delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Syllabus entry deleted.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  InputDecoration _inputDecoration(String label, String hint, {String? hint2}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      helperText: hint2,
      helperMaxLines: 2,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    );
  }

  // ─── Build ──────────────────────────────────────────────────────────────────

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
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection(_collection).orderBy('sNo').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final docs = snapshot.data?.docs ?? [];

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title row
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Syllabus Management',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1e3a5f),
                      ),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _showDialog(),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Syllabus'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1e3a5f),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Info box
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  border: Border.all(color: Colors.blue.shade200),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline,
                        color: Colors.blue.shade700, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'How to add PDF links:\n'
                        '• GitHub: Use RAW link — replace "github.com" → "raw.githubusercontent.com" and remove "/blob"\n'
                        '  e.g. https://raw.githubusercontent.com/SumithReddy007/DOCS/main/file.pdf\n'
                        '• Google Drive: Upload PDF → Share → "Anyone with link can view" → copy link\n'
                        '• Direct URL: Any direct .pdf URL (e.g. from university website)\n'
                        '• Firebase Storage: Upload PDF → copy download URL',
                        style: TextStyle(
                            fontSize: 12, color: Colors.blue.shade900),
                      ),
                    ),
                  ],
                ),
              ),
              // Table
              if (docs.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Text(
                      'No syllabus entries yet. Click "Add Syllabus" to get started.',
                      style: TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                  ),
                )
              else
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!, width: 1),
                    borderRadius: BorderRadius.circular(4),
                    color: Colors.white,
                  ),
                  child: Column(
                    children: [
                      // Header
                      Container(
                        decoration: const BoxDecoration(
                          color: Color(0xFF1e3a5f),
                          borderRadius:
                              BorderRadius.vertical(top: Radius.circular(4)),
                        ),
                        child: Row(
                          children: [
                            _hCell('S.No', flex: 1),
                            _hCell('Class Info', flex: 3),
                            _hCell('Regulation', flex: 2),
                            _hCell('PDF Link', flex: 5),
                            _hCell('Actions', flex: 2),
                          ],
                        ),
                      ),
                      // Rows
                      ...docs.asMap().entries.map((entry) {
                        final index = entry.key;
                        final doc = entry.value;
                        final d = doc.data() as Map<String, dynamic>;
                        final isEven = index % 2 == 0;

                        return Container(
                          color:
                              isEven ? Colors.white : const Color(0xFFF5F8FF),
                          child: Row(
                            children: [
                              _dCell((d['sNo'] ?? index + 1).toString(),
                                  flex: 1),
                              _dCell(d['classInfo'] ?? '', flex: 3),
                              _dCell(d['regulation'] ?? '', flex: 2),
                              Expanded(
                                flex: 5,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 10),
                                  child: Text(
                                    d['pdfUrl'] ?? '',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF1976D2),
                                      decoration: TextDecoration.underline,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 2,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Padding(
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 8),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit,
                                            size: 18, color: Color(0xFF1e3a5f)),
                                        tooltip: 'Edit',
                                        onPressed: () => _showDialog(doc: doc),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete,
                                            size: 18, color: Colors.red),
                                        tooltip: 'Delete',
                                        onPressed: () => _delete(doc),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _hCell(String text, {int flex = 1}) {
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _dCell(String text, {int flex = 1}) {
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Text(
          text,
          style: const TextStyle(fontSize: 13, color: Colors.black87),
        ),
      ),
    );
  }
}
