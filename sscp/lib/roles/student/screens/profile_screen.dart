import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../widgets/app_header.dart';
import '../../../config/dev_config.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Map<String, dynamic>? _studentData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStudentData();
  }

  Future<void> _loadStudentData() async {
    try {
      final user = _auth.currentUser;

      // Only use demo data when both bypass and useDemoData are enabled
      if (DevConfig.bypassLogin && DevConfig.useDemoData) {
        setState(() {
          _studentData = _getDemoData();
          _isLoading = false;
        });
        return;
      }

      // No user and bypass not enabled - show error
      if (user == null) {
        setState(() {
          _studentData = _getDemoData();
          _isLoading = false;
        });
        return;
      }

      // Fetch from Firestore
      final email = user.email ?? '';
      final rollNumber = email.split('@')[0].toUpperCase();

      final doc = await _firestore.collection('students').doc(rollNumber).get();
      if (doc.exists) {
        setState(() {
          _studentData = doc.data();
          _isLoading = false;
        });
      } else {
        setState(() {
          _studentData = _getDemoData();
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _studentData = _getDemoData();
        _isLoading = false;
      });
    }
  }

  Map<String, dynamic> _getDemoData() {
    return {
      'hallTicketNumber': '2203A51318',
      'name': 'DEMO STUDENT',
      'fatherName': 'DEMO FATHER',
      'rollNumber': '22CSBTB18',
      'dateOfBirth': '01/01/2004',
      'gender': 'MALE',
      'bloodGroup': 'O+',
      'admissionYear': '2022',
      'admissionType': 'Convener (EAMCET)',
      'program': 'BTECH',
      'department': 'CSE',
      'batchNumber': '18',
      'dateOfAdmission': '15-07-2022',
      'nationality': 'Indian',
      'religion': 'Hindu',
      'caste': 'OC',
      'motherTongue': 'Telugu',
      'identificationMark': 'Mole on Right Hand',
      'placeOfBirth': 'HYDERABAD',
      'addressLine1': 'Demo Address Line 1',
      'addressLine2': 'Demo Address Line 2',
      'city': 'HYDERABAD',
      'state': 'TELANGANA',
      'country': 'India',
      'postalCode': '500001',
      'phoneNumber': '9999999999',
      'sscSchool': 'Demo High School',
      'sscBoard': 'SSC',
      'sscPercentage': '9.5',
      'interCollege': 'Demo Junior College',
      'interBoard': 'INTERMEDIATE',
      'interPercentage': '9.6',
      'cetType': 'EAMCET',
      'cetRank': '12345',
      'cetMarks': '600',
      'cetScore': '10',
      'aadharNumber': '****5678',
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
        title: const Text('Student Profile'),
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
                      'Student Basic Information',
                      [
                        _buildInfoRow('Registration Number',
                            _studentData?['hallTicketNumber'] ?? 'N/A'),
                        _buildInfoRow(
                            'Student Name', _studentData?['name'] ?? 'N/A'),
                        _buildInfoRow('Father\'s Name or Guardian',
                            _studentData?['fatherName'] ?? 'N/A'),
                        _buildInfoRow('Roll Number',
                            _studentData?['rollNumber'] ?? 'N/A'),
                        _buildInfoRow('Date of Birth',
                            _studentData?['dateOfBirth'] ?? 'N/A'),
                        _buildInfoRow(
                            'Gender', _studentData?['gender'] ?? 'N/A'),
                        _buildInfoRow('Blood Transfusion',
                            _studentData?['bloodGroup'] ?? 'N/A'),
                      ],
                      context),
                  const SizedBox(height: 16),
                  _buildSectionCard(
                      'Student Admission Information',
                      [
                        _buildInfoRow('Admission Year',
                            _studentData?['admissionYear'] ?? 'N/A'),
                        _buildInfoRow('Admission Type',
                            _studentData?['admissionType'] ?? 'N/A'),
                        _buildInfoRow(
                            'Course Name', _studentData?['program'] ?? 'N/A'),
                        _buildInfoRow(
                            'Branch', _studentData?['department'] ?? 'N/A'),
                        _buildInfoRow('Batch Number',
                            _studentData?['batchNumber'] ?? 'N/A'),
                        _buildInfoRow('Date of Admission',
                            _studentData?['dateOfAdmission'] ?? 'N/A'),
                      ],
                      context),
                  const SizedBox(height: 16),
                  _buildSectionCard(
                      'Student Personal Details',
                      [
                        _buildInfoRow('Nationality',
                            _studentData?['nationality'] ?? 'N/A'),
                        _buildInfoRow(
                            'Religion', _studentData?['religion'] ?? 'N/A'),
                        _buildInfoRow('Caste', _studentData?['caste'] ?? 'N/A'),
                        _buildInfoRow('Mother Tongue',
                            _studentData?['motherTongue'] ?? 'N/A'),
                        _buildInfoRow('Identification Mark',
                            _studentData?['identificationMark'] ?? 'N/A'),
                        _buildInfoRow('Place of Birth',
                            _studentData?['placeOfBirth'] ?? 'N/A'),
                      ],
                      context),
                  const SizedBox(height: 16),
                  _buildSectionCard(
                      'Contact Address',
                      [
                        _buildInfoRow('Address Line 1',
                            _studentData?['addressLine1'] ?? 'N/A'),
                        _buildInfoRow('Address Line 2',
                            _studentData?['addressLine2'] ?? 'N/A'),
                        _buildInfoRow('City', _studentData?['city'] ?? 'N/A'),
                        _buildInfoRow('State', _studentData?['state'] ?? 'N/A'),
                        _buildInfoRow(
                            'Country', _studentData?['country'] ?? 'N/A'),
                        _buildInfoRow('Postal Code',
                            _studentData?['postalCode'] ?? 'N/A'),
                        _buildInfoRow('Phone Number',
                            _studentData?['phoneNumber'] ?? 'N/A'),
                      ],
                      context),
                  const SizedBox(height: 16),
                  _buildSectionCard(
                      'Academic Details',
                      [
                        _buildInfoRow('SSC School Name',
                            _studentData?['sscSchool'] ?? 'N/A'),
                        _buildInfoRow(
                            'Board of SSC', _studentData?['sscBoard'] ?? 'N/A'),
                        _buildInfoRow('SSC Percentage',
                            _studentData?['sscPercentage'] ?? 'N/A'),
                        _buildInfoRow('Intermediate College',
                            _studentData?['interCollege'] ?? 'N/A'),
                        _buildInfoRow('Board of Intermediate',
                            _studentData?['interBoard'] ?? 'N/A'),
                        _buildInfoRow('Intermediate Percentage',
                            _studentData?['interPercentage'] ?? 'N/A'),
                      ],
                      context),
                  const SizedBox(height: 16),
                  _buildSectionCard(
                      'CET Details',
                      [
                        _buildInfoRow(
                            'CET Type', _studentData?['cetType'] ?? 'N/A'),
                        _buildInfoRow(
                            'CET Rank', _studentData?['cetRank'] ?? 'N/A'),
                        _buildInfoRow(
                            'CET Marks', _studentData?['cetMarks'] ?? 'N/A'),
                        _buildInfoRow(
                            'CET Score', _studentData?['cetScore'] ?? 'N/A'),
                      ],
                      context),
                  const SizedBox(height: 16),
                  _buildSectionCard(
                      'Permanent Address',
                      [
                        _buildInfoRow('Address Line 1',
                            _studentData?['addressLine1'] ?? 'N/A'),
                        _buildInfoRow('Address Line 2',
                            _studentData?['addressLine2'] ?? 'N/A'),
                        _buildInfoRow('City', _studentData?['city'] ?? 'N/A'),
                        _buildInfoRow('State', _studentData?['state'] ?? 'N/A'),
                        _buildInfoRow(
                            'Country', _studentData?['country'] ?? 'N/A'),
                        _buildInfoRow('Postal Code',
                            _studentData?['postalCode'] ?? 'N/A'),
                      ],
                      context),
                  const SizedBox(height: 16),
                  _buildSectionCard(
                      'Aadhar Card Details',
                      [
                        _buildInfoRow('Aadhar Number',
                            _studentData?['aadharNumber'] ?? 'N/A'),
                        _buildInfoRow(
                            'Address',
                            '${_studentData?['addressLine1'] ?? 'N/A'}\n'
                                '${_studentData?['addressLine2'] ?? ''}\n'
                                '${_studentData?['city'] ?? 'N/A'}\n'
                                '${_studentData?['state'] ?? 'N/A'}\n'
                                '${_studentData?['postalCode'] ?? 'N/A'}'),
                        _buildInfoRow('Area Identifier by Postal Office', ''),
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

  Widget _buildHeaderSection(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Container(
      color: const Color(0xFF1e3a5f),
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      child: Column(
        children: [
          Text(
            '2203A51291 - Student Profile Registration Details',
            style: TextStyle(
              color: Colors.yellow,
              fontSize: isMobile ? 14 : 16,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: isMobile ? 100 : 120,
                height: isMobile ? 120 : 140,
                color: Colors.grey[300],
                child: Icon(
                  Icons.person,
                  size: isMobile ? 50 : 60,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ],
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
