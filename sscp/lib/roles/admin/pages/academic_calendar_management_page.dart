import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AcademicCalendarManagementPage extends StatefulWidget {
  const AcademicCalendarManagementPage({super.key});

  @override
  State<AcademicCalendarManagementPage> createState() =>
      _AcademicCalendarManagementPageState();
}

class _AcademicCalendarManagementPageState
    extends State<AcademicCalendarManagementPage> {
  final _formKey = GlobalKey<FormState>();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _pdfUrlController = TextEditingController();

  // Form fields
  String? selectedYear;
  String? selectedDegree;
  int? selectedAcademicYear;
  int? selectedSemester;
  DateTime? startDate;
  DateTime? endDate;
  bool isSubmitting = false;

  final academicYears = ['2025-26'];
  final degrees = ['BTECH', 'MTECH', 'MBA', 'MCA'];
  final years = [1, 2, 3, 4];
  final semesters = [1, 2];

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Academic Calendar Management'),
        backgroundColor: const Color(0xFF1e3a5f),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(isMobile ? 16 : 24),
        child: Column(
          children: [
            _buildFormCard(isMobile),
            const SizedBox(height: 32),
            _buildExistingCalendarsSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildFormCard(bool isMobile) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Add New Academic Calendar',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1e3a5f),
                    ),
              ),
              const SizedBox(height: 24),
              if (isMobile)
                Column(
                  children: _buildFormFields(isMobile),
                )
              else
                Column(
                  children: _buildFormFields(isMobile),
                ),
              const SizedBox(height: 24),
              _buildSubmitButton(),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildFormFields(bool isMobile) {
    return [
      Row(
        children: [
          Expanded(
            child: _buildDropdownField(
              'Academic Year',
              selectedYear,
              academicYears,
              (value) => setState(() => selectedYear = value),
            ),
          ),
          if (!isMobile) const SizedBox(width: 16),
          if (!isMobile)
            Expanded(
              child: _buildDropdownField(
                'Degree',
                selectedDegree,
                degrees,
                (value) => setState(() => selectedDegree = value),
              ),
            ),
        ],
      ),
      if (isMobile) const SizedBox(height: 16),
      if (isMobile)
        _buildDropdownField(
          'Degree',
          selectedDegree,
          degrees,
          (value) => setState(() => selectedDegree = value),
        ),
      const SizedBox(height: 16),
      Row(
        children: [
          Expanded(
            child: _buildDropdownField(
              'Year',
              selectedAcademicYear?.toString(),
              years.map((y) => y.toString()).toList(),
              (value) =>
                  setState(() => selectedAcademicYear = int.tryParse(value!)),
            ),
          ),
          if (!isMobile) const SizedBox(width: 16),
          if (!isMobile)
            Expanded(
              child: _buildDropdownField(
                'Semester',
                selectedSemester?.toString(),
                semesters.map((s) => s.toString()).toList(),
                (value) =>
                    setState(() => selectedSemester = int.tryParse(value!)),
              ),
            ),
        ],
      ),
      if (isMobile) const SizedBox(height: 16),
      if (isMobile)
        _buildDropdownField(
          'Semester',
          selectedSemester?.toString(),
          semesters.map((s) => s.toString()).toList(),
          (value) => setState(() => selectedSemester = int.tryParse(value!)),
        ),
      const SizedBox(height: 16),
      Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => _selectDate(true),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[400]!),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today, size: 20, color: Colors.grey),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        startDate != null
                            ? DateFormat('yyyy-MM-dd').format(startDate!)
                            : 'Select Start Date',
                        style: TextStyle(
                          color: startDate != null ? Colors.black : Colors.grey[600],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (!isMobile) const SizedBox(width: 16),
          if (!isMobile)
            Expanded(
              child: GestureDetector(
                onTap: () => _selectDate(false),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[400]!),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 20, color: Colors.grey),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          endDate != null
                              ? DateFormat('yyyy-MM-dd').format(endDate!)
                              : 'Select End Date',
                          style: TextStyle(
                            color: endDate != null ? Colors.black : Colors.grey[600],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      if (isMobile) const SizedBox(height: 16),
      if (isMobile)
        GestureDetector(
          onTap: () => _selectDate(false),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[400]!),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today, size: 20, color: Colors.grey),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    endDate != null
                        ? DateFormat('yyyy-MM-dd').format(endDate!)
                        : 'Select End Date',
                    style: TextStyle(
                      color: endDate != null ? Colors.black : Colors.grey[600],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      const SizedBox(height: 16),
      _buildPdfUploadSection(),
    ];
  }

  Widget _buildDropdownField(
    String label,
    String? value,
    List<String> items,
    Function(String?) onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1e3a5f),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[400]!),
            borderRadius: BorderRadius.circular(4),
          ),
          child: DropdownButton<String>(
            value: value,
            isExpanded: true,
            underline: const SizedBox(),
            hint: Text('Select $label'),
            items: items.map((String item) {
              return DropdownMenuItem<String>(
                value: item,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(item),
                ),
              );
            }).toList(),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildPdfUploadSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'PDF URL',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1e3a5f),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[400]!),
            borderRadius: BorderRadius.circular(4),
          ),
          child: TextField(
            controller: _pdfUrlController,
            decoration: const InputDecoration(
              hintText: 'https://github.com/username/repo/blob/main/pdfs/file.pdf',
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            maxLines: 2,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Recommended: Use GitHub links. Upload PDFs to your GitHub repo, get the file link from GitHub web interface (e.g., github.com/.../blob/main/pdfs/file.pdf), and paste it here. The app will automatically convert it to a direct download link.',
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey[600],
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1e3a5f),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        onPressed: isSubmitting ? null : _submitForm,
        child: isSubmitting
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Text(
                'Add Academic Calendar',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }

  Widget _buildExistingCalendarsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Existing Academic Calendars',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1e3a5f),
              ),
        ),
        const SizedBox(height: 16),
        StreamBuilder<QuerySnapshot>(
          stream: _firestore.collection('academic_calendars').snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(
                child: Text('Error: ${snapshot.error}'),
              );
            }

            final docs = snapshot.data?.docs ?? [];

            if (docs.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      Icon(Icons.calendar_today_outlined,
                          size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'No academic calendars added yet',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: docs.length,
              itemBuilder: (context, index) {
                final doc = docs[index];
                final data = doc.data() as Map<String, dynamic>;

                return _buildCalendarTile(doc.id, data);
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildCalendarTile(String docId, Map<String, dynamic> data) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${data['academicYear']} | ${data['degree']} | Year ${data['year']} | Sem ${data['semester']}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Dates: ${DateFormat('yyyy-MM-dd').format((data['startDate'] as Timestamp).toDate())} to ${DateFormat('yyyy-MM-dd').format((data['endDate'] as Timestamp).toDate())}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  children: [
                    PopupMenuButton(
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          child: const Text('Edit'),
                          onTap: () => _editCalendar(docId, data),
                        ),
                        PopupMenuItem(
                          child: const Text('Delete'),
                          onTap: () => _deleteCalendar(docId),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectDate(bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStartDate ? (startDate ?? DateTime.now()) : (endDate ?? DateTime.now()),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );

    if (picked != null) {
      setState(() {
        if (isStartDate) {
          startDate = picked;
        } else {
          endDate = picked;
        }
      });
    }
  }

  Future<void> _editCalendar(String docId, Map<String, dynamic> data) async {
    // Pre-fill form with existing data
    String? editYear = data['academicYear'];
    String? editDegree = data['degree'];
    int? editAcademicYear = data['year'];
    int? editSemester = data['semester'];
    DateTime? editStartDate = (data['startDate'] as Timestamp).toDate();
    DateTime? editEndDate = (data['endDate'] as Timestamp).toDate();
    final TextEditingController editPdfUrlController =
        TextEditingController(text: data['pdfUrl']);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Academic Calendar'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Academic Year
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Academic Year',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  DropdownButton<String>(
                    value: editYear,
                    isExpanded: true,
                    items: academicYears
                        .map((year) => DropdownMenuItem(
                              value: year,
                              child: Text(year),
                            ))
                        .toList(),
                    onChanged: (value) {
                      editYear = value;
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Degree
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Degree',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  DropdownButton<String>(
                    value: editDegree,
                    isExpanded: true,
                    items: degrees
                        .map((degree) => DropdownMenuItem(
                              value: degree,
                              child: Text(degree),
                            ))
                        .toList(),
                    onChanged: (value) {
                      editDegree = value;
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Year
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Year',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  DropdownButton<int>(
                    value: editAcademicYear,
                    isExpanded: true,
                    items: years
                        .map((year) => DropdownMenuItem(
                              value: year,
                              child: Text(year.toString()),
                            ))
                        .toList(),
                    onChanged: (value) {
                      editAcademicYear = value;
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Semester
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Semester',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  DropdownButton<int>(
                    value: editSemester,
                    isExpanded: true,
                    items: semesters
                        .map((sem) => DropdownMenuItem(
                              value: sem,
                              child: Text(sem.toString()),
                            ))
                        .toList(),
                    onChanged: (value) {
                      editSemester = value;
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Start Date
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Start Date',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: editStartDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                      );
                      if (picked != null) {
                        editStartDate = picked;
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[400]!),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today,
                              size: 18, color: Colors.grey),
                          const SizedBox(width: 8),
                          Text(DateFormat('yyyy-MM-dd').format(editStartDate!)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // End Date
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('End Date',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: editEndDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                      );
                      if (picked != null) {
                        editEndDate = picked;
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[400]!),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today,
                              size: 18, color: Colors.grey),
                          const SizedBox(width: 8),
                          Text(DateFormat('yyyy-MM-dd').format(editEndDate!)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // PDF URL
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('PDF URL',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: editPdfUrlController,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                      hintText: 'https://github.com/username/repo/blob/main/pdfs/file.pdf',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    maxLines: 2,
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1e3a5f),
            ),
            onPressed: () async {
              if (editYear != null &&
                  editDegree != null &&
                  editAcademicYear != null &&
                  editSemester != null &&
                  editStartDate != null &&
                  editEndDate != null &&
                  editPdfUrlController.text.isNotEmpty) {
                try {
                  await _firestore
                      .collection('academic_calendars')
                      .doc(docId)
                      .update({
                    'academicYear': editYear,
                    'degree': editDegree,
                    'year': editAcademicYear,
                    'semester': editSemester,
                    'startDate': Timestamp.fromDate(editStartDate!),
                    'endDate': Timestamp.fromDate(editEndDate!),
                    'pdfUrl': editPdfUrlController.text,
                  });

                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Academic calendar updated successfully!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please fill all fields'),
                    backgroundColor: Colors.orange,
                  ),
                );
              }
            },
            child: const Text('Update',
                style: TextStyle(color: Colors.white, fontSize: 16)),
          ),
        ],
      ),
    );
  }



  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill all fields'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (selectedYear == null ||
        selectedDegree == null ||
        selectedAcademicYear == null ||
        selectedSemester == null ||
        startDate == null ||
        endDate == null ||
        _pdfUrlController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill all fields including PDF URL'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => isSubmitting = true);

    try {
      await _firestore.collection('academic_calendars').add({
        'academicYear': selectedYear,
        'degree': selectedDegree,
        'year': selectedAcademicYear,
        'semester': selectedSemester,
        'startDate': Timestamp.fromDate(startDate!),
        'endDate': Timestamp.fromDate(endDate!),
        'pdfUrl': _pdfUrlController.text,
        'createdAt': Timestamp.now(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Academic calendar added successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }

      // Reset form
      _formKey.currentState!.reset();
      setState(() {
        selectedYear = null;
        selectedDegree = null;
        selectedAcademicYear = null;
        selectedSemester = null;
        startDate = null;
        endDate = null;
        _pdfUrlController.clear();
        isSubmitting = false;
      });
    } catch (e) {
      setState(() => isSubmitting = false);
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

  Future<void> _deleteCalendar(String docId) async {
    try {
      await _firestore.collection('academic_calendars').doc(docId).delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Academic calendar deleted'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
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
}
