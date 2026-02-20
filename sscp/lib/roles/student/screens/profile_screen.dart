import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../widgets/app_header.dart';
import '../../../config/dev_config.dart';
import '../../../services/student_access_service.dart';

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
  bool _isEditMode = false;
  bool _canEditProfile = false;
  bool _isSaving = false;
  late Map<String, TextEditingController> _editControllers;

  @override
  void initState() {
    super.initState();
    _loadStudentData();
  }

  @override
  void dispose() {
    _editControllers.forEach((_, controller) => controller.dispose());
    super.dispose();
  }

  void _initializeEditControllers() {
    _editControllers = {
      'fatherName':
          TextEditingController(text: _studentData?['fatherName'] ?? ''),
      'dateOfBirth':
          TextEditingController(text: _studentData?['dateOfBirth'] ?? ''),
      'gender': TextEditingController(text: _studentData?['gender'] ?? ''),
      'bloodGroup':
          TextEditingController(text: _studentData?['bloodGroup'] ?? ''),
      'nationality':
          TextEditingController(text: _studentData?['nationality'] ?? ''),
      'religion': TextEditingController(text: _studentData?['religion'] ?? ''),
      'caste': TextEditingController(text: _studentData?['caste'] ?? ''),
      'motherTongue':
          TextEditingController(text: _studentData?['motherTongue'] ?? ''),
      'identificationMark': TextEditingController(
          text: _studentData?['identificationMark'] ?? ''),
      'placeOfBirth':
          TextEditingController(text: _studentData?['placeOfBirth'] ?? ''),
      'addressLine1':
          TextEditingController(text: _studentData?['addressLine1'] ?? ''),
      'addressLine2':
          TextEditingController(text: _studentData?['addressLine2'] ?? ''),
      'city': TextEditingController(text: _studentData?['city'] ?? ''),
      'state': TextEditingController(text: _studentData?['state'] ?? ''),
      'country': TextEditingController(text: _studentData?['country'] ?? ''),
      'postalCode':
          TextEditingController(text: _studentData?['postalCode'] ?? ''),
      'phoneNumber':
          TextEditingController(text: _studentData?['phoneNumber'] ?? ''),
      'sscSchool':
          TextEditingController(text: _studentData?['sscSchool'] ?? ''),
      'sscBoard': TextEditingController(text: _studentData?['sscBoard'] ?? ''),
      'sscPercentage':
          TextEditingController(text: _studentData?['sscPercentage'] ?? ''),
      'interCollege':
          TextEditingController(text: _studentData?['interCollege'] ?? ''),
      'interBoard':
          TextEditingController(text: _studentData?['interBoard'] ?? ''),
      'interPercentage':
          TextEditingController(text: _studentData?['interPercentage'] ?? ''),
      'aadharNumber':
          TextEditingController(text: _studentData?['aadharNumber'] ?? ''),
    };
  }

  Future<void> _selectDateOfBirth() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2004),
      firstDate: DateTime(1990),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _editControllers['dateOfBirth']!.text =
            '${picked.day}/${picked.month}/${picked.year}';
      });
    }
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
        _initializeEditControllers();
        return;
      }

      // No user and bypass not enabled - show error
      if (user == null) {
        setState(() {
          _studentData = _getDemoData();
          _isLoading = false;
        });
        _initializeEditControllers();
        return;
      }

      // Fetch from Firestore
      final email = user.email ?? '';
      final rollNumber = email.split('@')[0].toUpperCase();

      final doc = await _firestore.collection('students').doc(rollNumber).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        // Ensure rollNumber is included in the data
        data['rollNumber'] = rollNumber;
        setState(() {
          _studentData = data;
          _canEditProfile = data['canEditProfile'] ?? false;
          _isLoading = false;
        });
        _initializeEditControllers();
      } else {
        setState(() {
          _studentData = _getDemoData();
          _isLoading = false;
        });
        _initializeEditControllers();
      }
    } catch (e) {
      setState(() {
        _studentData = _getDemoData();
        _isLoading = false;
      });
      _initializeEditControllers();
    }
  }

  Future<void> _showRequestAccessDialog() async {
    final user = _auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User not authenticated')),
      );
      return;
    }

    final email = user.email ?? '';
    final rollNumber = email.split('@')[0].toUpperCase();

    // Check if already has pending request
    final requestStatus =
        await StudentAccessService.getStudentRequestStatus(rollNumber);

    if (requestStatus != null) {
      String statusText = '';
      Color statusColor = Colors.grey;

      if (requestStatus['status'] == 'pending') {
        statusText = 'Your request is pending admin approval';
        statusColor = Colors.orange;
      } else if (requestStatus['status'] == 'approved') {
        statusText = 'Your request was approved. Edit access is now available.';
        statusColor = Colors.green;
      } else if (requestStatus['status'] == 'rejected') {
        statusText =
            'Your request was rejected.\n\nReason: ${requestStatus['rejectionReason'] ?? 'Not specified'}';
        statusColor = Colors.red;
      }

      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Request Status'),
            content: Text(
              statusText,
              style: TextStyle(color: statusColor),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
      return;
    }

    // Show request form
    final selectedFields = <String>{
      'Father\'s Name',
      'Date of Birth',
      'Gender',
      'Blood Group',
      'Nationality',
      'Religion',
      'Caste',
      'Mother Tongue',
      'Identification Mark',
      'Place of Birth',
      'Address Line 1',
      'Address Line 2',
      'City',
      'State',
      'Country',
      'Postal Code',
      'Phone Number',
      'SSC Details',
      'Inter Details',
    };

    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: const Text('Request Edit Access'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Select the fields you need to edit:',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Note: Your name and registration details can only be edited by administrators.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.orange,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ...selectedFields.map((field) {
                    final isSelected = selectedFields.contains(field);
                    return CheckboxListTile(
                      title: Text(field),
                      value: isSelected,
                      onChanged: (value) {
                        setState(() {
                          if (value == true) {
                            selectedFields.add(field);
                          } else {
                            selectedFields.remove(field);
                          }
                        });
                      },
                    );
                  }),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: selectedFields.isEmpty
                    ? null
                    : () async {
                        Navigator.pop(context);
                        await _submitEditAccessRequest(
                          rollNumber,
                          selectedFields.toList(),
                        );
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Submit Request'),
              ),
            ],
          ),
        ),
      );
    }
  }

  Future<void> _submitEditAccessRequest(
      String rollNumber, List<String> fieldsToEdit) async {
    try {
      final studentName = _studentData?['name'] ?? 'Unknown';

      final result = await StudentAccessService.requestEditAccess(
        rollNumber,
        studentName,
        fieldsToEdit,
      );

      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Edit access request submitted successfully. Please wait for admin approval.',
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message']),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error submitting request: $e'),
          backgroundColor: Colors.red,
        ),
      );
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
      'year': '3',
      'semester': '6',
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

  Future<void> _saveProfile() async {
    setState(() {
      _isSaving = true;
    });

    try {
      final user = _auth.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User not authenticated')),
        );
        return;
      }

      final email = user.email ?? '';
      final rollNumber = email.split('@')[0].toUpperCase();

      // Check if student has edit access
      final hasAccess = await StudentAccessService.hasEditAccess(rollNumber);

      if (!hasAccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('You do not have permission to edit your profile')),
        );
        return;
      }

      // Prepare updates
      final updates = {
        'fatherName': _editControllers['fatherName']!.text,
        'dateOfBirth': _editControllers['dateOfBirth']!.text,
        'gender': _editControllers['gender']!.text,
        'bloodGroup': _editControllers['bloodGroup']!.text,
        'nationality': _editControllers['nationality']!.text,
        'religion': _editControllers['religion']!.text,
        'caste': _editControllers['caste']!.text,
        'motherTongue': _editControllers['motherTongue']!.text,
        'identificationMark': _editControllers['identificationMark']!.text,
        'placeOfBirth': _editControllers['placeOfBirth']!.text,
        'addressLine1': _editControllers['addressLine1']!.text,
        'addressLine2': _editControllers['addressLine2']!.text,
        'city': _editControllers['city']!.text,
        'state': _editControllers['state']!.text,
        'country': _editControllers['country']!.text,
        'postalCode': _editControllers['postalCode']!.text,
        'phoneNumber': _editControllers['phoneNumber']!.text,
        'sscSchool': _editControllers['sscSchool']!.text,
        'sscBoard': _editControllers['sscBoard']!.text,
        'sscPercentage': _editControllers['sscPercentage']!.text,
        'interCollege': _editControllers['interCollege']!.text,
        'interBoard': _editControllers['interBoard']!.text,
        'interPercentage': _editControllers['interPercentage']!.text,
        'aadharNumber': _editControllers['aadharNumber']!.text,
      };

      // Update in Firestore
      final result = await StudentAccessService.updateStudentProfile(
        rollNumber,
        updates,
      );

      if (result['success'] == true) {
        // Update local data
        setState(() {
          _studentData!.addAll(updates);
          _isEditMode = false;
          _canEditProfile = false;
        });

        // Revoke edit access after successful save
        await StudentAccessService.revokeEditAccess(rollNumber);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Profile updated successfully. Edit access has been revoked.',
            ),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'])),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving profile: $e')),
      );
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
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
        actions: [
          if (_canEditProfile)
            TextButton(
              onPressed: _isEditMode
                  ? null
                  : () {
                      setState(() {
                        _isEditMode = true;
                      });
                    },
              child: Text(
                _isEditMode ? '✓ Editing' : 'Edit',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          else
            TextButton(
              onPressed: () => _showRequestAccessDialog(),
              child: const Text(
                'Request Edit Access',
                style: TextStyle(
                  color: Colors.yellow,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const AppHeader(),
            Padding(
              padding: EdgeInsets.all(isMobile ? 12 : 16),
              child: Column(
                children: [
                  if (_isEditMode)
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.amber[50],
                        border: Border.all(color: Colors.amber),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'You are in edit mode. You can update your profile information except:\n• Student Name (can only be edited by admin)\n• Registration/Hall Ticket Number (fixed records)\n\nOnce saved, your edit access will be automatically revoked.',
                        style: TextStyle(
                          color: Colors.orange,
                          fontSize: 12,
                        ),
                      ),
                    )
                  else if (!_canEditProfile)
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        border: Border.all(color: Colors.blue),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'To edit your profile, you need to request edit access from your admin. Click the "Request Edit Access" button in the top-right corner.',
                        style: TextStyle(
                          color: Colors.blue,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  _buildSectionCard(
                      'Student Basic Information',
                      [
                        _buildInfoRow(
                            'Student Name', _studentData?['name'] ?? 'N/A'),
                        if (_isEditMode)
                          _buildEditableField(
                              'Father\'s Name or Guardian', 'fatherName')
                        else
                          _buildInfoRow('Father\'s Name or Guardian',
                              _studentData?['fatherName'] ?? 'N/A'),
                        _buildInfoRow('Roll Number',
                            _studentData?['rollNumber'] ?? 'N/A'),
                        if (_isEditMode)
                          _buildDateOfBirthField()
                        else
                          _buildInfoRow('Date of Birth',
                              _studentData?['dateOfBirth'] ?? 'N/A'),
                        if (_isEditMode)
                          _buildGenderField()
                        else
                          _buildInfoRow(
                              'Gender', _studentData?['gender'] ?? 'N/A'),
                        if (_isEditMode)
                          _buildBloodGroupDropdown()
                        else
                          _buildInfoRow('Blood Group',
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
                            'Branch', _studentData?['department'] ?? 'N/A'),
                        _buildInfoRow(
                            'Year', _studentData?['year'] ?? 'N/A'),
                        _buildInfoRow(
                            'Semester', _studentData?['semester'] ?? 'N/A'),
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
                        if (_isEditMode)
                          _buildEditableField('Nationality', 'nationality')
                        else
                          _buildInfoRow('Nationality',
                              _studentData?['nationality'] ?? 'N/A'),
                        if (_isEditMode)
                          _buildEditableField('Religion', 'religion')
                        else
                          _buildInfoRow(
                              'Religion', _studentData?['religion'] ?? 'N/A'),
                        if (_isEditMode)
                          _buildEditableField('Caste', 'caste')
                        else
                          _buildInfoRow(
                              'Caste', _studentData?['caste'] ?? 'N/A'),
                        if (_isEditMode)
                          _buildEditableField('Mother Tongue', 'motherTongue')
                        else
                          _buildInfoRow('Mother Tongue',
                              _studentData?['motherTongue'] ?? 'N/A'),
                        if (_isEditMode)
                          _buildEditableField(
                              'Identification Mark', 'identificationMark')
                        else
                          _buildInfoRow('Identification Mark',
                              _studentData?['identificationMark'] ?? 'N/A'),
                        if (_isEditMode)
                          _buildEditableField('Place of Birth', 'placeOfBirth')
                        else
                          _buildInfoRow('Place of Birth',
                              _studentData?['placeOfBirth'] ?? 'N/A'),
                      ],
                      context),
                  const SizedBox(height: 16),
                  _buildSectionCard(
                      'Permanent Address',
                      [
                        if (_isEditMode)
                          _buildEditableField('Address Line 1', 'addressLine1')
                        else
                          _buildInfoRow('Address Line 1',
                              _studentData?['addressLine1'] ?? 'N/A'),
                        if (_isEditMode)
                          _buildEditableField('Address Line 2', 'addressLine2')
                        else
                          _buildInfoRow('Address Line 2',
                              _studentData?['addressLine2'] ?? 'N/A'),
                        if (_isEditMode)
                          _buildEditableField('City', 'city')
                        else
                          _buildInfoRow('City', _studentData?['city'] ?? 'N/A'),
                        if (_isEditMode)
                          _buildEditableField('State', 'state')
                        else
                          _buildInfoRow(
                              'State', _studentData?['state'] ?? 'N/A'),
                        if (_isEditMode)
                          _buildEditableField('Country', 'country')
                        else
                          _buildInfoRow(
                              'Country', _studentData?['country'] ?? 'N/A'),
                        if (_isEditMode)
                          _buildEditableField('Postal Code', 'postalCode')
                        else
                          _buildInfoRow('Postal Code',
                              _studentData?['postalCode'] ?? 'N/A'),
                        if (_isEditMode)
                          _buildEditableField('Phone Number', 'phoneNumber')
                        else
                          _buildInfoRow('Phone Number',
                              _studentData?['phoneNumber'] ?? 'N/A'),
                      ],
                      context),
                  const SizedBox(height: 16),
                  _buildSectionCard(
                      'Academic Details',
                      [
                        if (_isEditMode)
                          _buildEditableField('SSC School Name', 'sscSchool')
                        else
                          _buildInfoRow('SSC School Name',
                              _studentData?['sscSchool'] ?? 'N/A'),
                        if (_isEditMode)
                          _buildEditableField('Board of SSC', 'sscBoard')
                        else
                          _buildInfoRow('Board of SSC',
                              _studentData?['sscBoard'] ?? 'N/A'),
                        if (_isEditMode)
                          _buildEditableField('SSC Percentage', 'sscPercentage')
                        else
                          _buildInfoRow('SSC Percentage',
                              _studentData?['sscPercentage'] ?? 'N/A'),
                        if (_isEditMode)
                          _buildEditableField(
                              'Intermediate College', 'interCollege')
                        else
                          _buildInfoRow('Intermediate College',
                              _studentData?['interCollege'] ?? 'N/A'),
                        if (_isEditMode)
                          _buildEditableField(
                              'Board of Intermediate', 'interBoard')
                        else
                          _buildInfoRow('Board of Intermediate',
                              _studentData?['interBoard'] ?? 'N/A'),
                        if (_isEditMode)
                          _buildEditableField(
                              'Intermediate Percentage', 'interPercentage')
                        else
                          _buildInfoRow('Intermediate Percentage',
                              _studentData?['interPercentage'] ?? 'N/A'),
                      ],
                      context),
                  const SizedBox(height: 16),
                  _buildSectionCard(
                      'Aadhar Card Details',
                      [
                        if (_isEditMode)
                          _buildEditableField('Aadhar Number', 'aadharNumber')
                        else
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
                  if (_isEditMode) ...[
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isSaving
                                ? null
                                : () {
                                    setState(() {
                                      _isEditMode = false;
                                      _initializeEditControllers();
                                    });
                                  },
                            icon: const Icon(Icons.close),
                            label: const Text('Cancel'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isSaving ? null : _saveProfile,
                            icon: _isSaving
                                ? const SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  )
                                : const Icon(Icons.save),
                            label: const Text('Save Changes'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
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

  Widget _buildDateOfBirthField() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Date of Birth',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1e3a5f),
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _editControllers['dateOfBirth'],
            readOnly: true,
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              suffixIcon: IconButton(
                icon: const Icon(Icons.calendar_today, size: 18),
                onPressed: _selectDateOfBirth,
              ),
            ),
            style: const TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildBloodGroupDropdown() {
    final bloodGroups = ['A+', 'A-', 'B+', 'B-', 'O+', 'O-', 'AB+', 'AB-'];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Blood Group',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1e3a5f),
            ),
          ),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            value: _editControllers['bloodGroup']!.text.isEmpty
                ? null
                : _editControllers['bloodGroup']!.text,
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
            ),
            items: bloodGroups.map((String value) {
              return DropdownMenuItem<String>(
                value: value,
                child: Text(value, style: const TextStyle(fontSize: 12)),
              );
            }).toList(),
            onChanged: (String? newValue) {
              if (newValue != null) {
                _editControllers['bloodGroup']!.text = newValue;
              }
            },
            style: const TextStyle(fontSize: 12, color: Colors.black),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildGenderField() {
    final genders = ['MALE', 'FEMALE', 'OTHER'];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Gender',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1e3a5f),
            ),
          ),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            value: _editControllers['gender']!.text.isEmpty
                ? null
                : _editControllers['gender']!.text,
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
            ),
            items: genders.map((String value) {
              return DropdownMenuItem<String>(
                value: value,
                child: Text(value, style: const TextStyle(fontSize: 12)),
              );
            }).toList(),
            onChanged: (String? newValue) {
              if (newValue != null) {
                _editControllers['gender']!.text = newValue;
              }
            },
            style: const TextStyle(fontSize: 12, color: Colors.black),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildEditableField(String label, String fieldKey) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
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
          TextField(
            controller: _editControllers[fieldKey],
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
            ),
            style: const TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
