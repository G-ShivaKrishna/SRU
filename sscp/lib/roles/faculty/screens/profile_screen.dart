import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../widgets/app_header.dart';
import '../../../config/dev_config.dart';

class FacultyProfileScreen extends StatefulWidget {
  const FacultyProfileScreen({super.key});

  @override
  State<FacultyProfileScreen> createState() => _FacultyProfileScreenState();
}

class _FacultyProfileScreenState extends State<FacultyProfileScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Map<String, dynamic>? _facultyData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFacultyData();
  }

  Future<void> _loadFacultyData() async {
    try {
      final user = _auth.currentUser;

      if (DevConfig.bypassLogin && DevConfig.useDemoData) {
        setState(() {
          _facultyData = _getDemoData();
          _isLoading = false;
        });
        return;
      }

      if (user == null) {
        setState(() {
          _facultyData = _getDemoData();
          _isLoading = false;
        });
        return;
      }

      final email = user.email ?? '';
      final facultyId = email.split('@')[0].toUpperCase();

      final doc = await _firestore.collection('faculty').doc(facultyId).get();
      if (doc.exists) {
        setState(() {
          _facultyData = doc.data();
          _isLoading = false;
        });
      } else {
        setState(() {
          _facultyData = _getDemoData();
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _facultyData = _getDemoData();
        _isLoading = false;
      });
    }
  }

  Map<String, dynamic> _getDemoData() {
    return {
      'employeeId': 'FAC001',
      'name': 'DEMO FACULTY',
      'designation': 'Assistant Professor',
      'department': 'Computer Science & Engineering',
      'dateOfBirth': '15/05/1985',
      'gender': 'MALE',
      'bloodGroup': 'B+',
      'dateOfJoining': '10-08-2015',
      'qualification': 'PhD (Computer Science)',
      'specialization': 'Machine Learning, Data Science',
      'experience': '10 Years',
      'nationality': 'Indian',
      'religion': 'Hindu',
      'maritalStatus': 'Married',
      'addressLine1': 'Demo Faculty Address Line 1',
      'addressLine2': 'Demo Faculty Address Line 2',
      'city': 'HYDERABAD',
      'state': 'TELANGANA',
      'country': 'India',
      'postalCode': '500001',
      'phoneNumber': '9876543210',
      'email': 'faculty.demo@sru.edu.in',
      'emergencyContact': '9876543211',
      'aadharNumber': '****1234',
      'panNumber': 'ABCDE1234F',
    };
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Faculty Profile'),
        backgroundColor: const Color(0xFF1e3a5f),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const AppHeader(),
            Padding(
              padding: EdgeInsets.all(isMobile ? 12 : 16),
              child: Column(
                children: [
                  _buildSectionCard(
                      'Faculty Basic Information',
                      [
                        _buildInfoRow('Employee ID',
                            _facultyData?['employeeId'] ?? 'N/A'),
                        _buildInfoRow('Name', _facultyData?['name'] ?? 'N/A'),
                        _buildInfoRow('Designation',
                            _facultyData?['designation'] ?? 'N/A'),
                        _buildInfoRow(
                            'Department', _facultyData?['department'] ?? 'N/A'),
                        _buildInfoRow('Date of Birth',
                            _facultyData?['dateOfBirth'] ?? 'N/A'),
                        _buildInfoRow(
                            'Gender', _facultyData?['gender'] ?? 'N/A'),
                        _buildInfoRow('Blood Group',
                            _facultyData?['bloodGroup'] ?? 'N/A'),
                      ],
                      context),
                  const SizedBox(height: 16),
                  _buildSectionCard(
                      'Employment Information',
                      [
                        _buildInfoRow('Date of Joining',
                            _facultyData?['dateOfJoining'] ?? 'N/A'),
                        _buildInfoRow('Qualification',
                            _facultyData?['qualification'] ?? 'N/A'),
                        _buildInfoRow('Specialization',
                            _facultyData?['specialization'] ?? 'N/A'),
                        _buildInfoRow(
                            'Experience', _facultyData?['experience'] ?? 'N/A'),
                      ],
                      context),
                  const SizedBox(height: 16),
                  _buildSectionCard(
                      'Personal Details',
                      [
                        _buildInfoRow('Nationality',
                            _facultyData?['nationality'] ?? 'N/A'),
                        _buildInfoRow(
                            'Religion', _facultyData?['religion'] ?? 'N/A'),
                        _buildInfoRow('Marital Status',
                            _facultyData?['maritalStatus'] ?? 'N/A'),
                      ],
                      context),
                  const SizedBox(height: 16),
                  _buildSectionCard(
                      'Contact Information',
                      [
                        _buildInfoRow('Address Line 1',
                            _facultyData?['addressLine1'] ?? 'N/A'),
                        _buildInfoRow('Address Line 2',
                            _facultyData?['addressLine2'] ?? 'N/A'),
                        _buildInfoRow('City', _facultyData?['city'] ?? 'N/A'),
                        _buildInfoRow('State', _facultyData?['state'] ?? 'N/A'),
                        _buildInfoRow(
                            'Country', _facultyData?['country'] ?? 'N/A'),
                        _buildInfoRow('Postal Code',
                            _facultyData?['postalCode'] ?? 'N/A'),
                        _buildInfoRow('Phone Number',
                            _facultyData?['phoneNumber'] ?? 'N/A'),
                        _buildInfoRow('Email', _facultyData?['email'] ?? 'N/A'),
                        _buildInfoRow('Emergency Contact',
                            _facultyData?['emergencyContact'] ?? 'N/A'),
                      ],
                      context),
                  const SizedBox(height: 16),
                  _buildSectionCard(
                      'Official Documents',
                      [
                        _buildInfoRow('Aadhar Number',
                            _facultyData?['aadharNumber'] ?? 'N/A'),
                        _buildInfoRow(
                            'PAN Number', _facultyData?['panNumber'] ?? 'N/A'),
                      ],
                      context),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard(
    String title,
    List<Widget> children,
    BuildContext context,
  ) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!, width: 1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(isMobile ? 12 : 14),
            decoration: BoxDecoration(
              color: const Color(0xFF1e3a5f),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(7),
                topRight: Radius.circular(7),
              ),
            ),
            child: Text(
              title,
              style: TextStyle(
                color: Colors.white,
                fontSize: isMobile ? 13 : 15,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(isMobile ? 12 : 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 1,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1e3a5f),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 1,
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.black87,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
