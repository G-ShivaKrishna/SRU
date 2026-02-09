import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import '../../../services/excel_upload_service.dart';

class AccountCreationPage extends StatefulWidget {
  const AccountCreationPage({super.key});

  @override
  State<AccountCreationPage> createState() => _AccountCreationPageState();
}

class _AccountCreationPageState extends State<AccountCreationPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = false;
  Map<String, dynamic>? _uploadResult;
  File? _selectedFile;
  String? _selectedFileName;

  final List<String> _tabs = ['Students', 'Faculty'];
  final Map<String, List<String>> _requiredColumns = {
    'Students': [
      'HallTicketNumber',
      'StudentName',
      'Department',
      'BatchNumber',
      'Year',
      'Email'
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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(_resetUploadState);
  }

  @override
  void dispose() {
    _tabController.removeListener(_resetUploadState);
    _tabController.dispose();
    super.dispose();
  }

  void _resetUploadState() {
    setState(() {
      _selectedFile = null;
      _selectedFileName = null;
      _uploadResult = null;
    });
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
          controller: _tabController,
          tabs: _tabs.map((tab) => Tab(text: tab)).toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: _tabs
            .map((type) => _buildUploadSection(type, isMobile))
            .toList(),
      ),
    );
  }

  Widget _buildUploadSection(String type, bool isMobile) {
    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 12 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),
            _buildRequiredColumnsCard(type, isMobile),
            const SizedBox(height: 24),
            _buildFileSelectionCard(isMobile),
            const SizedBox(height: 24),
            if (_selectedFile != null)
              _buildSelectedFileCard(isMobile),
            const SizedBox(height: 24),
            _buildUploadButton(type, isMobile),
            if (_uploadResult != null) ...[
              const SizedBox(height: 24),
              _buildResultCard(isMobile),
            ],
          ],
        ),
      ),
    );
  }

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
                const Icon(Icons.check_circle, color: Colors.green, size: 16),
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
                _selectedFileName = null;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildUploadButton(String type, bool isMobile) {
    final isDisabled = _selectedFile == null || _isLoading;

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: isDisabled ? null : () => _handleUpload(type),
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
              : _selectedFile == null
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
                  result['message'] ?? 'Upload completed',
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
          _buildResultRow('Total Rows', result['totalRows'].toString(), isMobile),
          _buildResultRow('Created', result['created'].toString(), isMobile, Colors.green),
          _buildResultRow('Failed', result['failed'].toString(), isMobile, Colors.red),
          if (result['failedReasons'] != null &&
              (result['failedReasons'] as List).isNotEmpty) ...[
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
                  _selectedFileName = null;
                  _uploadResult = null;
                });
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Upload Another File'),
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

  Widget _buildResultRow(String label, String value, bool isMobile, [Color? valueColor]) {
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

  Future<void> _pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls', 'csv'],
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        setState(() {
          _selectedFile = File(result.files.single.path!);
          _selectedFileName = result.files.single.name;
          _uploadResult = null;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking file: $e')),
      );
    }
  }

  Future<void> _handleUpload(String type) async {
    if (_selectedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a file first')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final result = await ExcelUploadService.uploadAccounts(
        type,
        _selectedFile!,
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
}
