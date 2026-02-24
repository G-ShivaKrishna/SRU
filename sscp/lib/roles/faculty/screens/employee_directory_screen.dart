import 'package:flutter/material.dart';
import '../../../widgets/app_header.dart';
import '../../../services/faculty_assignment_service.dart';

class EmployeeDirectoryScreen extends StatefulWidget {
  const EmployeeDirectoryScreen({super.key});

  @override
  State<EmployeeDirectoryScreen> createState() =>
      _EmployeeDirectoryScreenState();
}

class _EmployeeDirectoryScreenState extends State<EmployeeDirectoryScreen> {
  final FacultyAssignmentService _facultyService = FacultyAssignmentService();
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _allFaculty = [];
  List<Map<String, dynamic>> _filteredFaculty = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadFacultyData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadFacultyData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final faculty = await _facultyService.getAllFaculty();
      setState(() {
        _allFaculty = faculty;
        _filteredFaculty = faculty;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _filterFaculty(String query) {
    if (query.isEmpty) {
      setState(() {
        _filteredFaculty = _allFaculty;
      });
      return;
    }

    final lowerQuery = query.toLowerCase();
    setState(() {
      _filteredFaculty = _allFaculty.where((faculty) {
        final name = (faculty['name'] ?? '').toString().toLowerCase();
        final employeeId =
            (faculty['employeeId'] ?? '').toString().toLowerCase();
        final department =
            (faculty['department'] ?? '').toString().toLowerCase();
        final designation =
            (faculty['designation'] ?? '').toString().toLowerCase();
        final email = (faculty['email'] ?? '').toString().toLowerCase();
        final mobile = (faculty['mobileNo1'] ?? '').toString().toLowerCase();

        return name.contains(lowerQuery) ||
            employeeId.contains(lowerQuery) ||
            department.contains(lowerQuery) ||
            designation.contains(lowerQuery) ||
            email.contains(lowerQuery) ||
            mobile.contains(lowerQuery);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Employee Directory'),
        backgroundColor: const Color(0xFF1e3a5f),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          const AppHeader(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? _buildErrorView()
                    : _buildContent(isMobile),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'Failed to load employee data:\n$_error',
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _loadFacultyData,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(bool isMobile) {
    return Padding(
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title and Search Row
          _buildHeaderRow(isMobile),
          const SizedBox(height: 16),
          // Faculty List
          Expanded(
            child: _filteredFaculty.isEmpty
                ? const Center(
                    child: Text(
                      'No employees found',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  )
                : isMobile
                    ? _buildMobileView()
                    : _buildDesktopTable(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderRow(bool isMobile) {
    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Employee Details',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1e3a5f),
            ),
          ),
          const SizedBox(height: 12),
          _buildSearchField(),
        ],
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Employee Details',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1e3a5f),
          ),
        ),
        SizedBox(
          width: 300,
          child: _buildSearchField(),
        ),
      ],
    );
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      onChanged: _filterFaculty,
      decoration: InputDecoration(
        hintText: 'Search...',
        prefixIcon: const Icon(Icons.search),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    );
  }

  Widget _buildDesktopTable() {
    return SingleChildScrollView(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(const Color(0xFF1e3a5f)),
          headingTextStyle: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
          columns: const [
            DataColumn(label: Text('S.No')),
            DataColumn(label: Text('Employee ID')),
            DataColumn(label: Text('Name')),
            DataColumn(label: Text('Department')),
            DataColumn(label: Text('Designation')),
            DataColumn(label: Text('Mobile No')),
            DataColumn(label: Text('Cabin No')),
            DataColumn(label: Text('Email')),
          ],
          rows: _filteredFaculty.asMap().entries.map((entry) {
            final index = entry.key;
            final faculty = entry.value;
            return DataRow(
              color: WidgetStateProperty.resolveWith<Color?>(
                (states) => index.isEven ? Colors.grey[50] : Colors.white,
              ),
              cells: [
                DataCell(Text('${index + 1}')),
                DataCell(Text(_getValue(faculty, 'employeeId'))),
                DataCell(Text(_getFullName(faculty))),
                DataCell(Text(_getValue(faculty, 'department'))),
                DataCell(Text(_getValue(faculty, 'designation'))),
                DataCell(Text(_getValue(faculty, 'mobileNo1'))),
                DataCell(Text(_getValue(faculty, 'cabinNumber'))),
                DataCell(Text(_getValue(faculty, 'email'))),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildMobileView() {
    return ListView.builder(
      itemCount: _filteredFaculty.length,
      itemBuilder: (context, index) {
        return _buildMobileCard(index, _filteredFaculty[index]);
      },
    );
  }

  Widget _buildMobileCard(int index, Map<String, dynamic> faculty) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!, width: 1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          // Header with name
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: Color(0xFF1e3a5f),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(7),
                topRight: Radius.circular(7),
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.white24,
                  child: Text(
                    _getInitial(faculty),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getFullName(faculty),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        _getValue(faculty, 'designation'),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Details
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                _buildMobileRow('S.No', '${index + 1}'),
                _buildMobileRow('Employee ID', _getValue(faculty, 'employeeId')),
                _buildMobileRow('Department', _getValue(faculty, 'department')),
                _buildMobileRow('Mobile No', _getValue(faculty, 'mobileNo1')),
                _buildMobileRow('Cabin No', _getValue(faculty, 'cabinNumber')),
                _buildMobileRow('Email', _getValue(faculty, 'email')),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.black87,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  String _getValue(Map<String, dynamic> faculty, String key) {
    final value = faculty[key]?.toString().trim() ?? '';
    return value.isEmpty ? '-' : value;
  }

  String _getFullName(Map<String, dynamic> faculty) {
    final title = (faculty['title'] ?? '').toString().trim();
    final name = (faculty['name'] ?? '').toString().trim();
    if (title.isNotEmpty && name.isNotEmpty) {
      return '$title $name';
    }
    return name.isEmpty ? '-' : name;
  }

  String _getInitial(Map<String, dynamic> faculty) {
    final name = (faculty['name'] ?? '').toString().trim();
    return name.isNotEmpty ? name[0].toUpperCase() : 'E';
  }
}
