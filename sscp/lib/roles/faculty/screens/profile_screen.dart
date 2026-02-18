import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../widgets/app_header.dart';
import '../../../config/dev_config.dart';
import '../../../services/student_access_service.dart';

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
  bool _isEditMode = false;
  bool _canEditProfile = false;
  bool _isSaving = false;
  late Map<String, TextEditingController> _editControllers;

  @override
  void initState() {
    super.initState();
    _loadFacultyData();
  }

  @override
  void dispose() {
    _editControllers.forEach((_, controller) => controller.dispose());
    super.dispose();
  }

  void _initializeEditControllers() {
    _editControllers = {
      'designation':
          TextEditingController(text: _facultyData?['designation'] ?? ''),
      'department':
          TextEditingController(text: _facultyData?['department'] ?? ''),
      'dateOfBirth':
          TextEditingController(text: _facultyData?['dateOfBirth'] ?? ''),
      'phoneNumber':
          TextEditingController(text: _facultyData?['phoneNumber'] ?? ''),
      'email': TextEditingController(text: _facultyData?['email'] ?? ''),
      'addressLine1':
          TextEditingController(text: _facultyData?['addressLine1'] ?? ''),
      'addressLine2':
          TextEditingController(text: _facultyData?['addressLine2'] ?? ''),
      'city': TextEditingController(text: _facultyData?['city'] ?? ''),
      'state': TextEditingController(text: _facultyData?['state'] ?? ''),
      'country': TextEditingController(text: _facultyData?['country'] ?? ''),
      'postalCode':
          TextEditingController(text: _facultyData?['postalCode'] ?? ''),
      'qualification':
          TextEditingController(text: _facultyData?['qualification'] ?? ''),
      'specialization':
          TextEditingController(text: _facultyData?['specialization'] ?? ''),
      'experience':
          TextEditingController(text: _facultyData?['experience'] ?? ''),
      'dateOfJoining':
          TextEditingController(text: _facultyData?['dateOfJoining'] ?? ''),
    };
  }

  Future<void> _loadFacultyData() async {
    try {
      final user = _auth.currentUser;

      if (DevConfig.bypassLogin && DevConfig.useDemoData) {
        setState(() {
          _facultyData = _getDemoData();
          _isLoading = false;
        });
        _initializeEditControllers();
        return;
      }

      if (user == null) {
        setState(() {
          _facultyData = _getDemoData();
          _isLoading = false;
        });
        _initializeEditControllers();
        return;
      }

      final email = user.email ?? '';
      final facultyId = email.split('@')[0].toUpperCase();

      final doc = await _firestore.collection('faculty').doc(facultyId).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        setState(() {
          _facultyData = data;
          _canEditProfile = data['canEditProfile'] ?? false;
          _isLoading = false;
        });
        _initializeEditControllers();
      } else {
        setState(() {
          _facultyData = _getDemoData();
          _isLoading = false;
        });
        _initializeEditControllers();
      }
    } catch (e) {
      setState(() {
        _facultyData = _getDemoData();
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
    final facultyId = email.split('@')[0].toUpperCase();

    // Check if already has pending request
    final requestStatus =
        await StudentAccessService.getStudentRequestStatus(facultyId);

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
      'Designation',
      'Phone Number',
      'Email',
      'Address',
      'Qualification',
      'Specialization',
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
                    'Select the fields you want to edit:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  ...[
                    'Designation',
                    'Phone Number',
                    'Email',
                    'Address',
                    'Qualification',
                    'Specialization',
                  ].map((field) => CheckboxListTile(
                        value: selectedFields.contains(field),
                        onChanged: (value) {
                          setState(() {
                            if (value == true) {
                              selectedFields.add(field);
                            } else {
                              selectedFields.remove(field);
                            }
                          });
                        },
                        title: Text(field),
                        dense: true,
                      )),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: selectedFields.isNotEmpty
                    ? () {
                        Navigator.pop(context);
                        _submitEditAccessRequest(
                            facultyId, selectedFields.toList());
                      }
                    : null,
                child: const Text('Request Access'),
              ),
            ],
          ),
        ),
      );
    }
  }

  Future<void> _submitEditAccessRequest(
      String facultyId, List<String> fieldsToEdit) async {
    try {
      final facultyName = _facultyData?['name'] ?? 'Unknown';

      final result = await StudentAccessService.requestEditAccess(
        facultyId,
        facultyName,
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
      final facultyId = email.split('@')[0].toUpperCase();

      // Check if faculty has edit access
      final hasAccess =
          await StudentAccessService.hasEditAccess(facultyId);

      if (!hasAccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('You do not have permission to edit your profile')),
        );
        return;
      }

      // Prepare updates
      final updates = {
        'designation': _editControllers['designation']!.text,
        'phoneNumber': _editControllers['phoneNumber']!.text,
        'email': _editControllers['email']!.text,
        'addressLine1': _editControllers['addressLine1']!.text,
        'addressLine2': _editControllers['addressLine2']!.text,
        'city': _editControllers['city']!.text,
        'state': _editControllers['state']!.text,
        'country': _editControllers['country']!.text,
        'postalCode': _editControllers['postalCode']!.text,
        'qualification': _editControllers['qualification']!.text,
        'specialization': _editControllers['specialization']!.text,
        'experience': _editControllers['experience']!.text,
        'dateOfJoining': _editControllers['dateOfJoining']!.text,
      };

      // Update in Firestore
      final result = await StudentAccessService.updateStudentProfile(
        facultyId,
        updates,
      );

      if (result['success'] == true) {
        // Update local data
        setState(() {
          _facultyData!.addAll(updates);
          _isEditMode = false;
          _canEditProfile = false;
        });

        // Revoke edit access after successful save
        await StudentAccessService.revokeEditAccess(facultyId);

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
        actions: [
          if (_canEditProfile)
            TextButton(
              onPressed: _isEditMode
                  ? () => setState(() => _isEditMode = false)
                  : () => setState(() => _isEditMode = true),
              child: Text(
                _isEditMode ? 'Cancel' : 'Edit',
                style: const TextStyle(color: Colors.white),
              ),
            )
          else
            TextButton(
              onPressed: () => _showRequestAccessDialog(),
              child: const Text(
                'Request Edit',
                style: TextStyle(color: Colors.white),
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
                  _buildSectionCard(
                      'Faculty Basic Information',
                      [
                        _isEditMode
                            ? _buildEditableField('Designation', 'designation')
                            : _buildInfoRow('Designation',
                                _facultyData?['designation'] ?? 'N/A'),
                        _isEditMode
                            ? _buildEditableField('Department', 'department')
                            : _buildInfoRow(
                                'Department',
                                _facultyData?['department'] ?? 'N/A'),
                        _buildInfoRow(
                            'Name', _facultyData?['name'] ?? 'N/A'),
                        _buildInfoRow('Date of Birth',
                            _facultyData?['dateOfBirth'] ?? 'N/A'),
                      ],
                      context),
                  const SizedBox(height: 16),
                  _buildSectionCard(
                      'Employment Information',
                      [
                        _buildInfoRow('Date of Joining',
                            _facultyData?['dateOfJoining'] ?? 'N/A'),
                        _isEditMode
                            ? _buildEditableField(
                                'Qualification', 'qualification')
                            : _buildInfoRow('Qualification',
                                _facultyData?['qualification'] ?? 'N/A'),
                        _isEditMode
                            ? _buildEditableField(
                                'Specialization', 'specialization')
                            : _buildInfoRow('Specialization',
                                _facultyData?['specialization'] ?? 'N/A'),
                        _buildInfoRow(
                            'Experience', _facultyData?['experience'] ?? 'N/A'),
                      ],
                      context),
                  const SizedBox(height: 16),
                  _buildSectionCard(
                      'Contact Information',
                      [
                        _isEditMode
                            ? _buildEditableField('Phone Number', 'phoneNumber')
                            : _buildInfoRow('Phone Number',
                                _facultyData?['phoneNumber'] ?? 'N/A'),
                        _isEditMode
                            ? _buildEditableField('Email', 'email')
                            : _buildInfoRow(
                                'Email', _facultyData?['email'] ?? 'N/A'),
                        _isEditMode
                            ? _buildEditableField('Address Line 1', 'addressLine1')
                            : _buildInfoRow('Address Line 1',
                                _facultyData?['addressLine1'] ?? 'N/A'),
                        _isEditMode
                            ? _buildEditableField('Address Line 2', 'addressLine2')
                            : _buildInfoRow('Address Line 2',
                                _facultyData?['addressLine2'] ?? 'N/A'),
                        _isEditMode
                            ? _buildEditableField('City', 'city')
                            : _buildInfoRow(
                                'City', _facultyData?['city'] ?? 'N/A'),
                        _isEditMode
                            ? _buildEditableField('State', 'state')
                            : _buildInfoRow(
                                'State', _facultyData?['state'] ?? 'N/A'),
                        _isEditMode
                            ? _buildEditableField('Country', 'country')
                            : _buildInfoRow(
                                'Country', _facultyData?['country'] ?? 'N/A'),
                        _isEditMode
                            ? _buildEditableField('Postal Code', 'postalCode')
                            : _buildInfoRow('Postal Code',
                                _facultyData?['postalCode'] ?? 'N/A'),
                      ],
                      context),
                  if (_isEditMode) ...[
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isSaving ? null : _saveProfile,
                        icon: _isSaving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white),
                                ),
                              )
                            : const Icon(Icons.save),
                        label: Text(_isSaving ? 'Saving...' : 'Save Changes'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1e3a5f),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
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
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 8,
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
