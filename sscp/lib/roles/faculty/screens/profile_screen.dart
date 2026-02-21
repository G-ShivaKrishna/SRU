import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../widgets/app_header.dart';

class FacultyProfileScreen extends StatefulWidget {
  const FacultyProfileScreen({super.key});

  @override
  State<FacultyProfileScreen> createState() => _FacultyProfileScreenState();
}

class _FacultyProfileScreenState extends State<FacultyProfileScreen> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  Map<String, dynamic>? _data;
  bool _isLoading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _isLoading = true; _loadError = null; });
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('Not logged in');
      final email = user.email ?? '';
      final docId = email.split('@')[0].toUpperCase();
      final doc = await _firestore.collection('faculty').doc(docId).get();
      if (!mounted) return;
      setState(() {
        _data = doc.exists ? (doc.data() ?? {}) : {};
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _loadError = e.toString(); _isLoading = false; });
    }
  }

  String _v(String key) => (_data?[key] ?? '').toString().trim().isEmpty
      ? '-'
      : _data![key].toString().trim();

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    if (_loadError != null) {
      return Scaffold(
        body: Column(children: [
          const AppHeader(),
          Expanded(child: Center(child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text('Failed to load profile:\n$_loadError', textAlign: TextAlign.center),
              ),
              const SizedBox(height: 20),
              ElevatedButton(onPressed: _load, child: const Text('Retry')),
            ],
          ))),
        ]),
      );
    }

    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Column(
        children: [
          const AppHeader(),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(isMobile ? 12 : 16),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1100),
                  child: Column(
                    children: [
                      // Avatar + name banner
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1e3a5f),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: isMobile ? 32 : 44,
                              backgroundColor: Colors.white24,
                              child: Text(
                                (_v('name').isNotEmpty && _v('name') != '-')
                                    ? _v('name')[0].toUpperCase()
                                    : 'F',
                                style: TextStyle(
                                  fontSize: isMobile ? 28 : 38,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 20),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    [_v('title'), _v('name')].where((s) => s != '-').join(' '),
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: isMobile ? 18 : 22,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(_v('designation'),
                                      style: const TextStyle(color: Colors.white70, fontSize: 14)),
                                  Text(_v('department'),
                                      style: const TextStyle(color: Colors.white60, fontSize: 13)),
                                  const SizedBox(height: 4),
                                  Text('ID: ${_v('employeeId')}',
                                      style: const TextStyle(color: Colors.white54, fontSize: 12)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      _card('Employee Basic Information', const Color(0xFF2EAD4B), [
                        _row2('Employee ID', _v('employeeId'), 'Appointment Type', _v('appointmentType')),
                        _row2('Date of Joining', _v('dateOfJoining'), 'Cabin Number', _v('cabinNumber')),
                        _row2('Intercom', _v('intercom'), 'Favourite Courses', _v('favoriteCourses')),
                      ]),
                      const SizedBox(height: 12),

                      _card('Online Profiles & Links', const Color(0xFF1976D2), [
                        _row2('Google Scholar', _v('googleScholarLink'), 'LinkedIn', _v('linkedInLink')),
                        _row2('Scopus ID', _v('scopusId'), 'Personal Website', _v('personalWebsite')),
                        _row2('Instagram', _v('instagramLink'), 'Facebook', _v('facebookLink')),
                        _row2('YouTube', _v('youtubeLink'), 'Twitter / X', _v('twitterLink')),
                      ]),
                      const SizedBox(height: 12),

                      _card('Personal Details', const Color(0xFFF2B233), [
                        _row2("Father's Name", _v('fatherName'), "Mother's Name", _v('motherName')),
                        _row2('Date of Birth', _v('dateOfBirth'), 'Gender', _v('gender')),
                        _row2('Blood Group', _v('bloodGroup'), 'Marital Status', _v('maritalStatus')),
                        _row2('Religion', _v('religion'), 'Caste', _v('caste')),
                        _row2('Caste Name', _v('casteName'), 'Differently Abled', _v('differentlyAbled')),
                        _row2('Identification Mark 1', _v('identificationMark1'), 'Identification Mark 2', _v('identificationMark2')),
                      ]),
                      const SizedBox(height: 12),

                      _card('ID Proof Details', const Color(0xFF1E88E5), [
                        _row2('PAN Number', _v('panNumber'), 'Aadhar Number', _v('aadharNumber')),
                        _row2('Voter ID', _v('voterId'), 'Passport No', _v('passportNo')),
                        _row2('Driving License', _v('drivingLicense'), '', ''),
                      ]),
                      const SizedBox(height: 12),

                      _card('Contact Address', const Color(0xFFE53935), [
                        _row2('State', _v('contactState'), 'District', _v('contactDistrict')),
                        _row2('Mandal', _v('contactMandal'), 'Village', _v('contactVillage')),
                        _row2('Street', _v('contactStreet'), 'House No.', _v('contactHouseNo')),
                        _row2('Pin Code', _v('contactPinCode'), 'Personal Email', _v('personalEmail')),
                        _row2('Mobile No. 1', _v('mobileNo1'), 'Mobile No. 2', _v('mobileNo2')),
                        _row2('College Email', _v('email'), '', ''),
                      ]),
                      const SizedBox(height: 12),

                      _card('Permanent Address', const Color(0xFF1AA6B8), [
                        if (_data?['sameAsContact'] == true)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 6),
                            child: Text('Same as Contact Address',
                                style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey)),
                          )
                        else ...[
                          _row2('State', _v('permanentState'), 'District', _v('permanentDistrict')),
                          _row2('Mandal', _v('permanentMandal'), 'Village', _v('permanentVillage')),
                          _row2('Street', _v('permanentStreet'), 'House No.', _v('permanentHouseNo')),
                          _row2('Pin Code', _v('permanentPinCode'), '', ''),
                        ],
                        _row2('Emergency Contact 1', _v('emergencyContact1'), 'Emergency Contact 2', _v('emergencyContact2')),
                      ]),

                      if (_data?['updatedAt'] != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          'Last updated: ${_formatTs(_data!['updatedAt'])}',
                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      ],
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _card(String title, Color color, List<Widget> rows) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
        color: Colors.white,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: color,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(7)),
            ),
            child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: rows),
          ),
        ],
      ),
    );
  }

  Widget _row2(String l1, String v1, String l2, String v2) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: _cell(l1, v1)),
          if (l2.isNotEmpty) ...[
            const SizedBox(width: 16),
            Expanded(child: _cell(l2, v2)),
          ],
        ],
      ),
    );
  }

  Widget _cell(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF1e3a5f))),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontSize: 12, color: Colors.black87)),
        const Divider(height: 12),
      ],
    );
  }

  String _formatTs(dynamic ts) {
    try {
      final dt = (ts as dynamic).toDate() as DateTime;
      return '${dt.day.toString().padLeft(2,'0')}/${dt.month.toString().padLeft(2,'0')}/${dt.year}  ${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';
    } catch (_) { return ''; }
  }
}
