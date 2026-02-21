import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../widgets/app_header.dart';

class UpdateBasicDataScreen extends StatefulWidget {
  const UpdateBasicDataScreen({super.key});

  @override
  State<UpdateBasicDataScreen> createState() => _UpdateBasicDataScreenState();
}

class _UpdateBasicDataScreenState extends State<UpdateBasicDataScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  bool _isLoading = true;
  bool _isSaving = false;
  String? _loadError;
  String _facultyDocId = '';

  // Read-only fields
  String _readOnlyName = '';
  String _readOnlyEmpId = '';
  String _readOnlyDesignation = '';
  String _readOnlyDept = '';
  String _readOnlyCollegeEmail = '';

  // Basic Info controllers
  String? _title;
  final _dateOfJoiningCtrl = TextEditingController();
  String? _appointmentType;
  final _cabinCtrl = TextEditingController();
  final _intercomCtrl = TextEditingController();
  final _favoriteCoursesCtrl = TextEditingController();
  final _googleScholarCtrl = TextEditingController();
  final _linkedInCtrl = TextEditingController();
  final _instagramCtrl = TextEditingController();
  final _facebookCtrl = TextEditingController();
  final _scopusCtrl = TextEditingController();
  final _websiteCtrl = TextEditingController();
  final _youtubeCtrl = TextEditingController();
  final _twitterCtrl = TextEditingController();

  // Personal Details
  final _fatherNameCtrl = TextEditingController();
  final _motherNameCtrl = TextEditingController();
  final _idMark1Ctrl = TextEditingController();
  final _idMark2Ctrl = TextEditingController();
  String? _gender;
  String? _religion;
  String? _caste;
  final _casteNameCtrl = TextEditingController();
  String? _bloodGroup;
  String? _maritalStatus;
  final _dobCtrl = TextEditingController();
  String? _differentlyAbled;

  // ID Proof
  final _panCtrl = TextEditingController();
  final _aadharCtrl = TextEditingController();
  final _voterCtrl = TextEditingController();
  final _passportCtrl = TextEditingController();
  final _dlCtrl = TextEditingController();

  // Contact Address
  String? _conState;
  String? _conDistrict;
  String? _conMandal;
  String? _conVillage;
  final _conStreetCtrl = TextEditingController();
  final _conHouseCtrl = TextEditingController();
  final _conPinCtrl = TextEditingController();
  final _personalEmailCtrl = TextEditingController();
  final _mobile1Ctrl = TextEditingController();
  final _mobile2Ctrl = TextEditingController();

  // Permanent Address
  bool _sameAsContact = false;
  String? _perState;
  String? _perDistrict;
  String? _perMandal;
  String? _perVillage;
  final _perStreetCtrl = TextEditingController();
  final _perHouseCtrl = TextEditingController();
  final _perPinCtrl = TextEditingController();
  final _emergency1Ctrl = TextEditingController();
  final _emergency2Ctrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    for (final c in [
      _dateOfJoiningCtrl, _cabinCtrl, _intercomCtrl, _favoriteCoursesCtrl,
      _googleScholarCtrl, _linkedInCtrl, _instagramCtrl, _facebookCtrl,
      _scopusCtrl, _websiteCtrl, _youtubeCtrl, _twitterCtrl,
      _fatherNameCtrl, _motherNameCtrl, _idMark1Ctrl, _idMark2Ctrl,
      _casteNameCtrl, _dobCtrl,
      _panCtrl, _aadharCtrl, _voterCtrl, _passportCtrl, _dlCtrl,
      _conStreetCtrl, _conHouseCtrl, _conPinCtrl, _personalEmailCtrl,
      _mobile1Ctrl, _mobile2Ctrl,
      _perStreetCtrl, _perHouseCtrl, _perPinCtrl,
      _emergency1Ctrl, _emergency2Ctrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() { _isLoading = true; _loadError = null; });
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('Not logged in');
      final email = user.email ?? '';
      _facultyDocId = email.split('@')[0].toUpperCase();
      final doc = await _firestore.collection('faculty').doc(_facultyDocId).get();
      final d = doc.exists ? (doc.data() ?? {}) : <String, dynamic>{};
      _populate(d, email);
      setState(() => _isLoading = false);
    } catch (e) {
      setState(() { _loadError = e.toString(); _isLoading = false; });
    }
  }

  void _populate(Map<String, dynamic> d, String authEmail) {
    _readOnlyName       = d['name'] ?? '';
    _readOnlyEmpId      = d['employeeId'] ?? _facultyDocId;
    _readOnlyDesignation = d['designation'] ?? '';
    _readOnlyDept       = d['department'] ?? '';
    _readOnlyCollegeEmail = d['email'] ?? authEmail;

    _title              = _valid(d['title'], ['Mr.', 'Ms.', 'Mrs.', 'Dr.']);
    _dateOfJoiningCtrl.text = d['dateOfJoining'] ?? '';
    _appointmentType    = _valid(d['appointmentType'], ['Regular', 'Contract']);
    _cabinCtrl.text     = d['cabinNumber'] ?? '';
    _intercomCtrl.text  = d['intercom'] ?? '';
    _favoriteCoursesCtrl.text = d['favoriteCourses'] ?? '';
    _googleScholarCtrl.text   = d['googleScholarLink'] ?? '';
    _linkedInCtrl.text  = d['linkedInLink'] ?? '';
    _instagramCtrl.text = d['instagramLink'] ?? '';
    _facebookCtrl.text  = d['facebookLink'] ?? '';
    _scopusCtrl.text    = d['scopusId'] ?? '';
    _websiteCtrl.text   = d['personalWebsite'] ?? '';
    _youtubeCtrl.text   = d['youtubeLink'] ?? '';
    _twitterCtrl.text   = d['twitterLink'] ?? '';

    _fatherNameCtrl.text = d['fatherName'] ?? '';
    _motherNameCtrl.text = d['motherName'] ?? '';
    _idMark1Ctrl.text   = d['identificationMark1'] ?? '';
    _idMark2Ctrl.text   = d['identificationMark2'] ?? '';
    _gender             = _valid(d['gender'], ['M', 'F', 'Other']);
    _religion           = _valid(d['religion'], ['Hindu', 'Muslim', 'Christian', 'Other']);
    _caste              = _valid(d['caste'], ['BC-A', 'BC-B', 'SC', 'ST', 'OC']);
    _casteNameCtrl.text = d['casteName'] ?? '';
    _bloodGroup         = _valid(d['bloodGroup'], ['O+VE','O-VE','A+VE','A-VE','B+VE','B-VE','AB+VE','AB-VE']);
    _maritalStatus      = _valid(d['maritalStatus'], ['Married', 'Single', 'Other']);
    _dobCtrl.text       = d['dateOfBirth'] ?? '';
    _differentlyAbled   = _valid(d['differentlyAbled'], ['N', 'Y']);

    _panCtrl.text       = d['panNumber'] ?? '';
    _aadharCtrl.text    = d['aadharNumber'] ?? '';
    _voterCtrl.text     = d['voterId'] ?? '';
    _passportCtrl.text  = d['passportNo'] ?? '';
    _dlCtrl.text        = d['drivingLicense'] ?? '';

    _conState    = _valid(d['contactState'],    _states);
    _conDistrict = _valid(d['contactDistrict'], _districts);
    _conMandal   = _valid(d['contactMandal'],   _mandals);
    _conVillage  = _valid(d['contactVillage'],  _villages);
    _conStreetCtrl.text  = d['contactStreet'] ?? '';
    _conHouseCtrl.text   = d['contactHouseNo'] ?? '';
    _conPinCtrl.text     = d['contactPinCode'] ?? '';
    _personalEmailCtrl.text = d['personalEmail'] ?? '';
    _mobile1Ctrl.text    = d['mobileNo1'] ?? '';
    _mobile2Ctrl.text    = d['mobileNo2'] ?? '';

    _sameAsContact = d['sameAsContact'] ?? false;
    _perState    = _valid(d['permanentState'],    _states);
    _perDistrict = _valid(d['permanentDistrict'], _districts);
    _perMandal   = _valid(d['permanentMandal'],   _mandals);
    _perVillage  = _valid(d['permanentVillage'],  _villages);
    _perStreetCtrl.text  = d['permanentStreet'] ?? '';
    _perHouseCtrl.text   = d['permanentHouseNo'] ?? '';
    _perPinCtrl.text     = d['permanentPinCode'] ?? '';
    _emergency1Ctrl.text = d['emergencyContact1'] ?? '';
    _emergency2Ctrl.text = d['emergencyContact2'] ?? '';
  }

  /// Returns value only if it's in the allowed list, else null.
  String? _valid(dynamic val, List<String> allowed) {
    if (val == null) return null;
    return allowed.contains(val.toString()) ? val.toString() : null;
  }

  void _copySameAsContact() {
    setState(() {
      _perState    = _conState;
      _perDistrict = _conDistrict;
      _perMandal   = _conMandal;
      _perVillage  = _conVillage;
      _perStreetCtrl.text  = _conStreetCtrl.text;
      _perHouseCtrl.text   = _conHouseCtrl.text;
      _perPinCtrl.text     = _conPinCtrl.text;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Please fill all mandatory fields (marked *)'),
        backgroundColor: Colors.red,
      ));
      return;
    }
    setState(() => _isSaving = true);
    try {
      final data = {
        // Read-only fields (kept in sync)
        'name': _readOnlyName,
        'employeeId': _readOnlyEmpId,
        'designation': _readOnlyDesignation,
        'department': _readOnlyDept,
        'email': _readOnlyCollegeEmail,
        // Basic Info
        'title': _title ?? '',
        'dateOfJoining': _dateOfJoiningCtrl.text.trim(),
        'appointmentType': _appointmentType ?? '',
        'cabinNumber': _cabinCtrl.text.trim(),
        'intercom': _intercomCtrl.text.trim(),
        'favoriteCourses': _favoriteCoursesCtrl.text.trim(),
        'googleScholarLink': _googleScholarCtrl.text.trim(),
        'linkedInLink': _linkedInCtrl.text.trim(),
        'instagramLink': _instagramCtrl.text.trim(),
        'facebookLink': _facebookCtrl.text.trim(),
        'scopusId': _scopusCtrl.text.trim(),
        'personalWebsite': _websiteCtrl.text.trim(),
        'youtubeLink': _youtubeCtrl.text.trim(),
        'twitterLink': _twitterCtrl.text.trim(),
        // Personal
        'fatherName': _fatherNameCtrl.text.trim(),
        'motherName': _motherNameCtrl.text.trim(),
        'identificationMark1': _idMark1Ctrl.text.trim(),
        'identificationMark2': _idMark2Ctrl.text.trim(),
        'gender': _gender ?? '',
        'religion': _religion ?? '',
        'caste': _caste ?? '',
        'casteName': _casteNameCtrl.text.trim(),
        'bloodGroup': _bloodGroup ?? '',
        'maritalStatus': _maritalStatus ?? '',
        'dateOfBirth': _dobCtrl.text.trim(),
        'differentlyAbled': _differentlyAbled ?? '',
        // ID Proof
        'panNumber': _panCtrl.text.trim(),
        'aadharNumber': _aadharCtrl.text.trim(),
        'voterId': _voterCtrl.text.trim(),
        'passportNo': _passportCtrl.text.trim(),
        'drivingLicense': _dlCtrl.text.trim(),
        // Contact Address
        'contactState': _conState ?? '',
        'contactDistrict': _conDistrict ?? '',
        'contactMandal': _conMandal ?? '',
        'contactVillage': _conVillage ?? '',
        'contactStreet': _conStreetCtrl.text.trim(),
        'contactHouseNo': _conHouseCtrl.text.trim(),
        'contactPinCode': _conPinCtrl.text.trim(),
        'personalEmail': _personalEmailCtrl.text.trim(),
        'mobileNo1': _mobile1Ctrl.text.trim(),
        'mobileNo2': _mobile2Ctrl.text.trim(),
        // Permanent Address
        'sameAsContact': _sameAsContact,
        'permanentState': _perState ?? '',
        'permanentDistrict': _perDistrict ?? '',
        'permanentMandal': _perMandal ?? '',
        'permanentVillage': _perVillage ?? '',
        'permanentStreet': _perStreetCtrl.text.trim(),
        'permanentHouseNo': _perHouseCtrl.text.trim(),
        'permanentPinCode': _perPinCtrl.text.trim(),
        'emergencyContact1': _emergency1Ctrl.text.trim(),
        'emergencyContact2': _emergency2Ctrl.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      await _firestore.collection('faculty').doc(_facultyDocId).set(data, SetOptions(merge: true));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Profile updated successfully!'),
        backgroundColor: Colors.green,
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Failed to save: $e'),
        backgroundColor: Colors.red,
      ));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ─── Static option lists ──────────────────────────────────────────────────
  static const _states    = ['ANDHRA PRADESH', 'TELANGANA', 'KARNATAKA', 'TAMIL NADU', 'MAHARASHTRA', 'OTHER'];
  static const _districts = ['WARANGAL URBAN', 'WARANGAL RURAL', 'HYDERABAD', 'KARIMNAGAR', 'OTHER'];
  static const _mandals   = ['ELKATHURTHY', 'HANAMKONDA', 'KAZIPET', 'WARANGAL', 'OTHER'];
  static const _villages  = ['KESHAVAPUR', 'HUNTER ROAD', 'HANAMKONDA', 'KAZIPET', 'OTHER'];

  // ─── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 700;
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Column(
        children: [
          const AppHeader(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _loadError != null
                    ? _buildLoadError()
                    : Form(
                        key: _formKey,
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(16),
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 1200),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Center(
                                    child: Text(
                                      'Before Attendance Please update your profile',
                                      style: TextStyle(color: Colors.red, fontSize: 15, fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  const Center(
                                    child: Text(
                                      'Employee Basic Data Update',
                                      style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  _sectionHeader('Employee Basic Information', const Color(0xFF2EAD4B)),
                                  _sectionBody(isMobile, [
                                    _dropdownField('Title', ['Mr.', 'Ms.', 'Mrs.', 'Dr.'], _title, (v) => setState(() => _title = v)),
                                    _readOnlyField('Employee Name', _readOnlyName),
                                    _readOnlyField('Designation', _readOnlyDesignation),
                                    _readOnlyField('Department', _readOnlyDept),
                                    _readOnlyField('Employee ID', _readOnlyEmpId),
                                    _dateField('Date of Joining', _dateOfJoiningCtrl),
                                    _dropdownField('Appointment Type', ['Regular', 'Contract'], _appointmentType, (v) => setState(() => _appointmentType = v)),
                                    _textField('Cabin Number', _cabinCtrl),
                                    _textField('Intercom', _intercomCtrl),
                                    _textField('Favourite Courses', _favoriteCoursesCtrl),
                                    _textField('Google Scholar Link', _googleScholarCtrl),
                                    _textField('LinkedIn Link', _linkedInCtrl),
                                    _textField('Instagram Link', _instagramCtrl),
                                    _textField('Facebook Link', _facebookCtrl),
                                    _textField('Scopus ID', _scopusCtrl),
                                    _textField('Personal Website', _websiteCtrl),
                                    _textField('YouTube Link', _youtubeCtrl),
                                    _textField('Twitter / X Link', _twitterCtrl),
                                  ]),
                                  const SizedBox(height: 16),
                                  _sectionHeader('Personal Details *', const Color(0xFFF2B233)),
                                  _sectionBody(isMobile, [
                                    _textField("Father's Name", _fatherNameCtrl, required: true),
                                    _textField("Mother's Name", _motherNameCtrl, required: true),
                                    _textField('Identification Mark 1', _idMark1Ctrl, required: true),
                                    _textField('Identification Mark 2', _idMark2Ctrl),
                                    _dropdownField('Gender *', ['M', 'F', 'Other'], _gender, (v) => setState(() => _gender = v), required: true),
                                    _dropdownField('Religion *', ['Hindu', 'Muslim', 'Christian', 'Other'], _religion, (v) => setState(() => _religion = v), required: true),
                                    _dropdownField('Caste *', ['BC-A', 'BC-B', 'SC', 'ST', 'OC'], _caste, (v) => setState(() => _caste = v), required: true),
                                    _textField('Name of the Caste *', _casteNameCtrl, required: true),
                                    _dropdownField('Blood Group *', ['O+VE','O-VE','A+VE','A-VE','B+VE','B-VE','AB+VE','AB-VE'], _bloodGroup, (v) => setState(() => _bloodGroup = v), required: true),
                                    _dropdownField('Marital Status *', ['Married', 'Single', 'Other'], _maritalStatus, (v) => setState(() => _maritalStatus = v), required: true),
                                    _dateField('Date of Birth *', _dobCtrl, required: true),
                                    _dropdownField('Differently Abled *', ['N', 'Y'], _differentlyAbled, (v) => setState(() => _differentlyAbled = v), required: true),
                                  ]),
                                  const SizedBox(height: 16),
                                  _sectionHeader('ID Proof Details *', const Color(0xFF1E88E5)),
                                  _sectionBody(isMobile, [
                                    _textField('PAN Number *', _panCtrl, required: true),
                                    _textField('Aadhar Card Number *', _aadharCtrl, required: true),
                                    _textField('Voter ID No', _voterCtrl),
                                    _textField('Passport No', _passportCtrl),
                                    _textField('Driving License No', _dlCtrl),
                                  ]),
                                  const SizedBox(height: 16),
                                  _sectionHeader('Contact Address Details *', const Color(0xFFE53935)),
                                  _sectionBody(isMobile, [
                                    _dropdownField('State *', _states, _conState, (v) => setState(() => _conState = v), required: true),
                                    _dropdownField('District *', _districts, _conDistrict, (v) => setState(() => _conDistrict = v), required: true),
                                    _dropdownField('Mandal *', _mandals, _conMandal, (v) => setState(() => _conMandal = v), required: true),
                                    _dropdownField('Village *', _villages, _conVillage, (v) => setState(() => _conVillage = v), required: true),
                                    _textField('Street *', _conStreetCtrl, required: true),
                                    _textField('House No. *', _conHouseCtrl, required: true),
                                    _textField('Pin Code *', _conPinCtrl, required: true, keyboardType: TextInputType.number),
                                    _textField('Personal Email ID *', _personalEmailCtrl, required: true, keyboardType: TextInputType.emailAddress),
                                    _textField('Mobile No. 1 *', _mobile1Ctrl, required: true, keyboardType: TextInputType.phone),
                                    _readOnlyField('College Email ID', _readOnlyCollegeEmail),
                                    _textField('Mobile No. 2', _mobile2Ctrl, keyboardType: TextInputType.phone),
                                  ]),
                                  CheckboxListTile(
                                    value: _sameAsContact,
                                    onChanged: (v) {
                                      setState(() => _sameAsContact = v ?? false);
                                      if (_sameAsContact) _copySameAsContact();
                                    },
                                    title: const Text('Select if Contact Address & Permanent Address are the same'),
                                    controlAffinity: ListTileControlAffinity.leading,
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                  const SizedBox(height: 4),
                                  _sectionHeader('Permanent Address Details *', const Color(0xFF1AA6B8)),
                                  _sectionBody(isMobile, [
                                    _dropdownField('State *', _states, _perState, (v) => setState(() => _perState = v), required: !_sameAsContact),
                                    _dropdownField('District *', _districts, _perDistrict, (v) => setState(() => _perDistrict = v), required: !_sameAsContact),
                                    _dropdownField('Mandal *', _mandals, _perMandal, (v) => setState(() => _perMandal = v), required: !_sameAsContact),
                                    _dropdownField('Village *', _villages, _perVillage, (v) => setState(() => _perVillage = v), required: !_sameAsContact),
                                    _textField('Street *', _perStreetCtrl, required: !_sameAsContact),
                                    _textField('House No. *', _perHouseCtrl, required: !_sameAsContact),
                                    _textField('Pin Code *', _perPinCtrl, required: !_sameAsContact, keyboardType: TextInputType.number),
                                    _textField('Emergency Contact No. 1 *', _emergency1Ctrl, required: true, keyboardType: TextInputType.phone),
                                    _textField('Emergency Contact No. 2', _emergency2Ctrl, keyboardType: TextInputType.phone),
                                  ]),
                                  const SizedBox(height: 20),
                                  Center(
                                    child: ElevatedButton(
                                      onPressed: _isSaving ? null : _save,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF2EAD4B),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                                      ),
                                      child: _isSaving
                                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                          : const Text('Update Profile', style: TextStyle(fontSize: 16)),
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadError() {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.error_outline, size: 64, color: Colors.red),
        const SizedBox(height: 16),
        Text('Failed to load profile: $_loadError'),
        const SizedBox(height: 20),
        ElevatedButton(onPressed: _loadData, child: const Text('Retry')),
      ]),
    );
  }

  Widget _sectionHeader(String title, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
      child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
    );
  }

  Widget _sectionBody(bool isMobile, List<Widget> fields) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(4), bottomRight: Radius.circular(4)),
      ),
      child: Wrap(
        spacing: 16,
        runSpacing: 12,
        children: fields.map((f) => SizedBox(width: isMobile ? double.infinity : 360, child: f)).toList(),
      ),
    );
  }

  Widget _readOnlyField(String label, String value) {
    return TextFormField(
      initialValue: value,
      readOnly: true,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
        filled: true,
        fillColor: Colors.grey[100],
        suffixIcon: const Icon(Icons.lock_outline, size: 16, color: Colors.grey),
      ),
    );
  }

  Widget _textField(String label, TextEditingController ctrl, {
    bool required = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextFormField(
      controller: ctrl,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      validator: required
          ? (v) => (v == null || v.trim().isEmpty) ? 'This field is required' : null
          : null,
    );
  }

  Widget _dropdownField(String label, List<String> items, String? value,
      ValueChanged<String?> onChanged, {bool required = false}) {
    return DropdownButtonFormField<String>(
      value: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      items: items.map((i) => DropdownMenuItem(value: i, child: Text(i))).toList(),
      onChanged: onChanged,
      validator: required ? (v) => (v == null || v.isEmpty) ? 'This field is required' : null : null,
    );
  }

  Widget _dateField(String label, TextEditingController ctrl, {bool required = false}) {
    return TextFormField(
      controller: ctrl,
      readOnly: true,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
        suffixIcon: const Icon(Icons.calendar_today, size: 16),
      ),
      onTap: () async {
        DateTime? init;
        try { init = ctrl.text.isNotEmpty ? DateTime.parse(ctrl.text) : null; } catch (_) {}
        final picked = await showDatePicker(
          context: context,
          initialDate: init ?? DateTime(1990),
          firstDate: DateTime(1950),
          lastDate: DateTime.now(),
        );
        if (picked != null) {
          ctrl.text = '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
        }
      },
      validator: required ? (v) => (v == null || v.trim().isEmpty) ? 'This field is required' : null : null,
    );
  }
}
