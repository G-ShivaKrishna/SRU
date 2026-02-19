import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ViewOnlyPage extends StatefulWidget {
  const ViewOnlyPage({super.key});

  @override
  State<ViewOnlyPage> createState() => _ViewOnlyPageState();
}

class _ViewOnlyPageState extends State<ViewOnlyPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  List<Map<String, dynamic>> _filteredStudents = [];
  List<Map<String, dynamic>> _filteredFaculty = [];
  List<Map<String, dynamic>> _allStudents = [];
  List<Map<String, dynamic>> _allFaculty = [];
  
  bool _isLoadingStudents = false;
  bool _isLoadingFaculty = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _searchController.addListener(_onSearchChanged);
    _loadAllData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    await Future.wait([_loadStudents(), _loadFaculty()]);
  }

  Future<void> _loadStudents() async {
    setState(() => _isLoadingStudents = true);
    try {
      final snapshot = await _firestore.collection('students').get();
      setState(() {
        _allStudents = snapshot.docs
            .map((doc) => {'id': doc.id, 'rollNumber': doc.id, ...doc.data()})
            .toList();
        _filteredStudents = _allStudents;
      });
    } catch (e) {
      print('Error loading students: $e');
    } finally {
      setState(() => _isLoadingStudents = false);
    }
  }

  Future<void> _loadFaculty() async {
    setState(() => _isLoadingFaculty = true);
    try {
      final snapshot = await _firestore.collection('faculty').get();
      setState(() {
        _allFaculty = snapshot.docs
            .map((doc) => {'id': doc.id, ...doc.data()})
            .toList();
        _filteredFaculty = _allFaculty;
      });
    } catch (e) {
      print('Error loading faculty: $e');
    } finally {
      setState(() => _isLoadingFaculty = false);
    }
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase().trim();
    
    setState(() {
      if (query.isEmpty) {
        _filteredStudents = _allStudents;
        _filteredFaculty = _allFaculty;
      } else {
        _filteredStudents = _allStudents.where((student) {
          final rollNumber = (student['rollNumber'] ?? '').toString().toLowerCase();
          final name = (student['name'] ?? '').toString().toLowerCase();
          final email = (student['email'] ?? '').toString().toLowerCase();
          return rollNumber.contains(query) || name.contains(query) || email.contains(query);
        }).toList();
        
        _filteredFaculty = _allFaculty.where((faculty) {
          final facultyId = (faculty['facultyId'] ?? '').toString().toLowerCase();
          final name = (faculty['name'] ?? '').toString().toLowerCase();
          final email = (faculty['email'] ?? '').toString().toLowerCase();
          return facultyId.contains(query) || name.contains(query) || email.contains(query);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      appBar: AppBar(
        title: const Text('View Data (Read-Only)'),
        backgroundColor: const Color(0xFF1e3a5f),
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Students'),
            Tab(text: 'Faculty'),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(isMobile ? 12 : 16),
            child: ValueListenableBuilder<TextEditingValue>(
              valueListenable: _searchController,
              builder: (context, value, child) {
                return TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search by ID, name, or email...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: value.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                  ),
                );
              },
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildStudentView(isMobile),
                _buildFacultyView(isMobile),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentView(bool isMobile) {
    if (_isLoadingStudents) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_filteredStudents.isEmpty) {
      return Center(
        child: Text(
          _searchController.text.isEmpty
              ? 'No students found'
              : 'No students match your search',
          style: const TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      itemCount: _filteredStudents.length,
      itemBuilder: (context, index) {
        final student = _filteredStudents[index];
        return _buildDataCard(
          student['name'] ?? 'Student',
          {
            'Roll Number': student['rollNumber'] ?? 'N/A',
            'Name': student['name'] ?? 'N/A',
            'Department': student['department'] ?? 'N/A',
            'Year': student['year']?.toString() ?? 'N/A',
            'Email': student['email'] ?? 'N/A',
            'Phone': student['phoneNumber'] ?? 'N/A',
            'Status': student['status'] ?? 'Active',
          },
          index,
          isMobile,
          Colors.blue,
        );
      },
    );
  }

  Widget _buildFacultyView(bool isMobile) {
    if (_isLoadingFaculty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_filteredFaculty.isEmpty) {
      return Center(
        child: Text(
          _searchController.text.isEmpty
              ? 'No faculty found'
              : 'No faculty match your search',
          style: const TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      itemCount: _filteredFaculty.length,
      itemBuilder: (context, index) {
        final faculty = _filteredFaculty[index];
        return _buildDataCard(
          faculty['name'] ?? 'Faculty',
          {
            'Faculty ID': faculty['facultyId'] ?? 'N/A',
            'Name': faculty['name'] ?? 'N/A',
            'Department': faculty['department'] ?? 'N/A',
            'Designation': faculty['designation'] ?? 'N/A',
            'Email': faculty['email'] ?? 'N/A',
            'Phone': faculty['phone'] ?? 'N/A',
            'Status': faculty['status'] ?? 'Active',
          },
          index,
          isMobile,
          Colors.green,
        );
      },
    );
  }

  Widget _buildDataCard(
    String title,
    Map<String, String> data,
    int index,
    bool isMobile,
    Color statusColor,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: isMobile ? 13 : 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  data['Status'] ?? 'Active',
                  style: TextStyle(
                    fontSize: 10,
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...data.entries
              .where((e) => e.key != 'Status')
              .map((e) => _buildInfoRow(e.key, e.value, isMobile))
              .toList(),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, bool isMobile) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: isMobile ? 10 : 11,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: isMobile ? 11 : 12,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}
