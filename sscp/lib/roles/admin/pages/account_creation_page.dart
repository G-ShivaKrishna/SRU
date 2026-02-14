import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import '../../../services/excel_upload_service.dart';

class AccountCreationPage extends StatefulWidget {
  const AccountCreationPage({super.key});

  @override
  State<AccountCreationPage> createState() => _AccountCreationPageState();
}

class _AccountCreationPageState extends State<AccountCreationPage>
    with TickerProviderStateMixin {
  late TabController _methodTabController;
  late TabController _typeTabController;
  bool _isLoading = false;
  Map<String, dynamic>? _uploadResult;
  File? _selectedFile;
  FilePickerResult? _selectedFilePickerResult;
  String? _selectedFileName;

  final List<String> _methods = ['Excel Upload', 'Manual Entry'];
  final List<String> _types = ['Students', 'Faculty'];
  final Map<String, List<String>> _requiredColumns = {
    'Students': [
      'HallTicketNumber',
      'StudentName',
      'Department',
      'BatchNumber',
      'Year',
      'Email',
      'AdmissionYear',
      'AdmissionType',
      'DateOfAdmission'
    ],
    'Faculty': [
      'FacultyID',
      'FacultyName',
      'Department',
      'Designation',
      'Email',
      'Subjects'
    ],
  };

  // Form controllers for manual entry
  final Map<String, TextEditingController> _studentControllers = {
    'hallTicketNumber': TextEditingController(),
    'studentName': TextEditingController(),
    'department': TextEditingController(),
    'batchNumber': TextEditingController(),
    'year': TextEditingController(),
    'email': TextEditingController(),
    'admissionYear': TextEditingController(),
    'admissionType': TextEditingController(),
    'dateOfAdmission': TextEditingController(),
  };

  final Map<String, TextEditingController> _facultyControllers = {
    'facultyId': TextEditingController(),
    'facultyName': TextEditingController(),
    'department': TextEditingController(),
    'designation': TextEditingController(),
    'email': TextEditingController(),
    'subjects': TextEditingController(),
  };

  @override
  void initState() {
    super.initState();
    _methodTabController = TabController(length: _methods.length, vsync: this);
    _typeTabController = TabController(length: _types.length, vsync: this);
    _methodTabController.addListener(_resetUploadState);
  }

  @override
  void dispose() {
    _methodTabController.removeListener(_resetUploadState);
    _methodTabController.dispose();
    _typeTabController.dispose();
    _studentControllers.forEach((_, controller) => controller.dispose());
    _facultyControllers.forEach((_, controller) => controller.dispose());
    super.dispose();
  }

  void _resetUploadState() {
    setState(() {
      _selectedFile = null;
      _selectedFilePickerResult = null;
      _selectedFileName = null;
      _uploadResult = null;
      _clearFormControllers();
    });
  }

  void _clearFormControllers() {
    _studentControllers.forEach((_, controller) => controller.clear());
    _facultyControllers.forEach((_, controller) => controller.clear());
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Upload Accounts'),
        backgroundColor: const Color(0xFF1e3a5f),
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _methodTabController,
          tabs: _methods.map((method) => Tab(text: method)).toList(),
        ),
      ),
      body: TabBarView(
        controller: _methodTabController,
        children: [
          _buildExcelUploadSection(isMobile),
          _buildManualEntrySection(isMobile),
        ],
      ),
    );
  }

  // ============ EXCEL UPLOAD SECTION ============
  Widget _buildExcelUploadSection(bool isMobile) {
    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 12 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),
            _buildTypeSelector(isMobile),
            const SizedBox(height: 24),
            _buildRequiredColumnsCard(
                _typeTabController.index == 0 ? 'Students' : 'Faculty',
                isMobile),
            const SizedBox(height: 24),
            _buildFileSelectionCard(isMobile),
            const SizedBox(height: 24),
            if (_selectedFile != null || _selectedFilePickerResult != null)
              _buildSelectedFileCard(isMobile),
            const SizedBox(height: 24),
            _buildUploadButton(
                _typeTabController.index == 0 ? 'Students' : 'Faculty',
                isMobile),
            if (_uploadResult != null) ...[
              const SizedBox(height: 24),
              _buildResultCard(isMobile),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTypeSelector(bool isMobile) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: TabBar(
        controller: _typeTabController,
        tabs: _types.map((type) => Tab(text: type)).toList(),
      ),
    );
  }

  // ============ MANUAL ENTRY SECTION ============
  Widget _buildManualEntrySection(bool isMobile) {
    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 12 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),
            _buildManualTypeSelector(isMobile),
            const SizedBox(height: 24),
            if (_typeTabController.index == 0)
              _buildStudentManualForm(isMobile)
            else
              _buildFacultyManualForm(isMobile),
            const SizedBox(height: 24),
            _buildManualSubmitButton(isMobile),
            if (_uploadResult != null) ...[
              const SizedBox(height: 24),
              _buildResultCard(isMobile),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildManualTypeSelector(bool isMobile) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: TabBar(
        controller: _typeTabController,
        onTap: (index) => setState(() {}),
        tabs: _types.map((type) => Tab(text: type)).toList(),
      ),
    );
  }

  Widget _buildStudentManualForm(bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Enter Student Details',
          style: TextStyle(
            fontSize: isMobile ? 14 : 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        _buildFormField(
          'Hall Ticket Number',
          'e.g., 2203A51291',
          _studentControllers['hallTicketNumber']!,
          isMobile,
        ),
        const SizedBox(height: 12),
        _buildFormField(
          'Student Name',
          'e.g., John Doe',
          _studentControllers['studentName']!,
          isMobile,
        ),
        const SizedBox(height: 12),
        _buildFormField(
          'Department',
          'e.g., CSE',
          _studentControllers['department']!,
          isMobile,
        ),
        const SizedBox(height: 12),
        _buildFormField(
          'Batch Number',
          'e.g., 22CSBTB09',
          _studentControllers['batchNumber']!,
          isMobile,
        ),
        const SizedBox(height: 12),
        _buildFormField(
          'Year',
          'e.g., 2',
          _studentControllers['year']!,
          isMobile,
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 12),
        _buildFormField(
          'Email',
          'e.g., student@email.com',
          _studentControllers['email']!,
          isMobile,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.blue, width: 1),
          ),
          child: const Text(
            'Admission Information',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.blue,
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(height: 12),
        _buildFormField(
          'Admission Year',
          'e.g., 2022',
          _studentControllers['admissionYear']!,
          isMobile,
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 12),
        _buildFormField(
          'Admission Type',
          'e.g., Regular, Lateral, etc.',
          _studentControllers['admissionType']!,
          isMobile,
        ),
        const SizedBox(height: 12),
        _buildFormField(
          'Date of Admission',
          'e.g., 2022-08-15',
          _studentControllers['dateOfAdmission']!,
          isMobile,
        ),
      ],
    );
  }

  Widget _buildFacultyManualForm(bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Enter Faculty Details',
          style: TextStyle(
            fontSize: isMobile ? 14 : 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        _buildFormField(
          'Faculty ID',
          'e.g., FAC2001',
          _facultyControllers['facultyId']!,
          isMobile,
        ),
        const SizedBox(height: 12),
        _buildFormField(
          'Faculty Name',
          'e.g., Dr. Jane Doe',
          _facultyControllers['facultyName']!,
          isMobile,
        ),
        const SizedBox(height: 12),
        _buildFormField(
          'Department',
          'e.g., CSE',
          _facultyControllers['department']!,
          isMobile,
        ),
        const SizedBox(height: 12),
        _buildFormField(
          'Designation',
          'e.g., Assistant Professor',
          _facultyControllers['designation']!,
          isMobile,
        ),
        const SizedBox(height: 12),
        _buildFormField(
          'Email',
          'e.g., faculty@email.com',
          _facultyControllers['email']!,
          isMobile,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 12),
        _buildFormField(
          'Subjects',
          'e.g., DBMS, OS, DSA',
          _facultyControllers['subjects']!,
          isMobile,
        ),
      ],
    );
  }

  Widget _buildFormField(
    String label,
    String hint,
    TextEditingController controller,
    bool isMobile, {
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        contentPadding: EdgeInsets.symmetric(
          horizontal: 12,
          vertical: isMobile ? 10 : 12,
        ),
        prefixIcon: Icon(_getIconForField(label)),
      ),
    );
  }

  IconData _getIconForField(String label) {
    switch (label.toLowerCase()) {
      case 'hall ticket number':
      case 'faculty id':
        return Icons.badge;
      case 'student name':
      case 'faculty name':
        return Icons.person;
      case 'department':
        return Icons.business;
      case 'email':
        return Icons.email;
      case 'year':
        return Icons.calendar_today;
      default:
        return Icons.edit;
    }
  }

  // ============ SHARED WIDGETS ============
  Widget _buildRequiredColumnsCard(String type, bool isMobile) {
    final columns = _requiredColumns[type]!;
    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Required Excel Columns (Header Row)',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: isMobile ? 12 : 14,
            ),
          ),
          const SizedBox(height: 12),
          ...columns.map((col) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle,
                        color: Colors.green, size: 16),
                    const SizedBox(width: 8),
                    Text(col, style: const TextStyle(fontSize: 12)),
                  ],
                ),
              )),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(8),
            color: Colors.orange[100],
            child: Text(
              '📝 One row = one account | Password auto-generated | Role auto-assigned | Status = active',
              style: TextStyle(
                fontSize: isMobile ? 10 : 11,
                color: Colors.orange[900],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFileSelectionCard(bool isMobile) {
    return GestureDetector(
      onTap: _isLoading ? null : _pickFile,
      child: Container(
        padding: EdgeInsets.all(isMobile ? 16 : 20),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Colors.blue,
            width: 2,
            style: BorderStyle.solid,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.blue.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.cloud_upload,
              size: isMobile ? 40 : 50,
              color: Colors.blue,
            ),
            const SizedBox(height: 12),
            Text(
              'Click or tap to select Excel file',
              style: TextStyle(
                fontSize: isMobile ? 12 : 14,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Supported formats: .xlsx, .xls, .csv',
              style: TextStyle(
                fontSize: isMobile ? 10 : 11,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedFileCard(bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green, width: 1),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle, color: Colors.green, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'File Selected',
                  style: TextStyle(
                    fontSize: isMobile ? 12 : 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.green[800],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _selectedFileName ?? 'Unknown file',
                  style: TextStyle(
                    fontSize: isMobile ? 10 : 11,
                    color: Colors.green[700],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.red),
            onPressed: () {
              setState(() {
                _selectedFile = null;
                _selectedFilePickerResult = null;
                _selectedFileName = null;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildUploadButton(String type, bool isMobile) {
    final isDisabled =
        (_selectedFile == null && _selectedFilePickerResult == null) ||
            _isLoading;

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: isDisabled ? null : () => _handleExcelUpload(type),
        icon: _isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Icon(Icons.cloud_upload),
        label: Text(
          _isLoading
              ? 'Uploading...'
              : (_selectedFile == null && _selectedFilePickerResult == null)
                  ? 'Select File First'
                  : 'Upload Excel File',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          backgroundColor: const Color(0xFF1e3a5f),
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.grey[400],
          disabledForegroundColor: Colors.white,
        ),
      ),
    );
  }

  Widget _buildManualSubmitButton(bool isMobile) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _isLoading ? null : _handleManualSubmit,
        icon: _isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Icon(Icons.person_add),
        label: Text(
          _isLoading ? 'Creating...' : 'Create Account',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          backgroundColor: const Color(0xFF1e3a5f),
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.grey[400],
          disabledForegroundColor: Colors.white,
        ),
      ),
    );
  }

  Widget _buildResultCard(bool isMobile) {
    final result = _uploadResult!;
    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      decoration: BoxDecoration(
        color: result['success'] ? Colors.green[50] : Colors.red[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: result['success'] ? Colors.green : Colors.red,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                result['success'] ? Icons.check_circle : Icons.error,
                color: result['success'] ? Colors.green : Colors.red,
                size: 24,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  result['message'] ?? 'Operation completed',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: isMobile ? 12 : 13,
                    color: result['success'] ? Colors.green : Colors.red,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (result.containsKey('totalRows')) ...[
            _buildResultRow(
                'Total Rows', (result['totalRows'] ?? 0).toString(), isMobile),
          ],
          if (result.containsKey('created')) ...[
            _buildResultRow('Created', (result['created'] ?? 0).toString(),
                isMobile, Colors.green),
          ],
          if (result.containsKey('failed')) ...[
            _buildResultRow('Failed', (result['failed'] ?? 0).toString(),
                isMobile, Colors.red),
          ],
          if ((result['failedReasons'] as List?)?.isNotEmpty ?? false) ...[
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 12),
            Text(
              'Failed Rows:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: isMobile ? 11 : 12,
              ),
            ),
            const SizedBox(height: 8),
            ...((result['failedReasons'] as List).map(
              (reason) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('• $reason', style: const TextStyle(fontSize: 11)),
              ),
            )),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _selectedFile = null;
                  _selectedFilePickerResult = null;
                  _selectedFileName = null;
                  _uploadResult = null;
                  _clearFormControllers();
                });
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Create Another Account'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultRow(String label, String value, bool isMobile,
      [Color? valueColor]) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: isMobile ? 11 : 12)),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: isMobile ? 11 : 12,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }

  // ============ HANDLERS ============
  Future<void> _pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls', 'csv'],
        allowMultiple: false,
      );

      if (result != null) {
        setState(() {
          _selectedFilePickerResult = result;
          _selectedFileName = result.files.single.name;
          _uploadResult = null;

          // On web, path is not available - only use bytes
          if (!kIsWeb && result.files.single.path != null) {
            _selectedFile = File(result.files.single.path!);
          } else {
            _selectedFile = null; // Web platform - will use bytes instead
          }
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking file: $e')),
      );
    }
  }

  Future<void> _handleExcelUpload(String type) async {
    if (_selectedFile == null && _selectedFilePickerResult == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a file first')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final result = await ExcelUploadService.uploadAccounts(
        type,
        _selectedFile,
        fileBytes: _selectedFilePickerResult?.files.single.bytes,
        fileName: _selectedFileName,
      );
      setState(() => _uploadResult = result);
    } catch (e) {
      setState(() {
        _uploadResult = {
          'success': false,
          'message': 'Upload failed: $e',
        };
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleManualSubmit() async {
    final type = _typeTabController.index == 0 ? 'Students' : 'Faculty';
    final controllers =
        type == 'Students' ? _studentControllers : _facultyControllers;

    // Validate all fields are filled
    if (controllers.values.any((controller) => controller.text.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final result = await ExcelUploadService.createAccountManually(
        type,
        Map.fromEntries(
          controllers.entries.map((e) => MapEntry(e.key, e.value.text)),
        ),
      );
      setState(() => _uploadResult = result);
    } catch (e) {
      setState(() {
        _uploadResult = {
          'success': false,
          'message': 'Account creation failed: $e',
        };
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }
}
