import 'package:flutter/material.dart';
import '../../../widgets/app_header.dart';

class UpdateBasicDataScreen extends StatefulWidget {
  const UpdateBasicDataScreen({super.key});

  @override
  State<UpdateBasicDataScreen> createState() => _UpdateBasicDataScreenState();
}

class _UpdateBasicDataScreenState extends State<UpdateBasicDataScreen> {
  bool _sameAsContactAddress = false;

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 700;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Column(
        children: [
          const AppHeader(),
          Expanded(
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
                          style: TextStyle(
                            color: Colors.red,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Center(
                        child: Text(
                          'Employee Basic Data Update',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildSectionHeader(
                        'Employee Basic Information',
                        const Color(0xFF2EAD4B),
                      ),
                      _buildSectionBody(
                        isMobile,
                        [
                          _buildDropdownField('Employee Name (as per SSC)',
                              ['Mr.', 'Ms.', 'Mrs.', 'Dr.']),
                          _buildTextField('Employee Name', ''),
                          _buildDropdownField('Designation', [
                            'Assistant Professor',
                            'Associate Professor',
                            'Professor',
                            'PhD Scholar',
                            'Staff',
                          ]),
                          _buildDropdownField(
                              'Department', ['CSE', 'ECE', 'EEE', 'ME', 'CE']),
                          _buildTextField('Emp ID', ''),
                          _buildDateField('Date of Joining'),
                          _buildDropdownField(
                              'Appointment Type', ['Regular', 'Contract']),
                          _buildTextField('Cabin Number', ''),
                          _buildTextField('Intercom', ''),
                          _buildTextField('Favourite Courses', ''),
                          _buildTextField('Google Scholar Link', ''),
                          _buildTextField('LinkedIn Link', ''),
                          _buildTextField('Instagram Link', ''),
                          _buildTextField('Facebook Link', ''),
                          _buildTextField('Scopus ID', ''),
                          _buildTextField('Personal Website', ''),
                          _buildTextField('Youtube Link', ''),
                          _buildTextField('Twitter Link', ''),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildSectionHeader(
                        'Personal Details',
                        const Color(0xFFF2B233),
                      ),
                      _buildSectionBody(
                        isMobile,
                        [
                          _buildTextField("Father's Name", ''),
                          _buildTextField("Mother's Name", ''),
                          _buildTextField('Identification Marks 1', ''),
                          _buildTextField('Identification Marks 2', ''),
                          _buildDropdownField('Gender', ['M', 'F', 'Other']),
                          _buildDropdownField('Religion',
                              ['Hindu', 'Muslim', 'Christian', 'Other']),
                          _buildDropdownField(
                              'Caste', ['BC-A', 'BC-B', 'SC', 'ST', 'OC']),
                          _buildTextField('Name of the Caste', ''),
                          _buildDropdownField('Blood Group', [
                            'O+VE',
                            'O-VE',
                            'A+VE',
                            'A-VE',
                            'B+VE',
                            'B-VE',
                            'AB+VE',
                            'AB-VE',
                          ]),
                          _buildDropdownField(
                              'Marital Status', ['Married', 'Single', 'Other']),
                          _buildDateField('Date of Birth'),
                          _buildDropdownField(
                              'Differently Abled Person', ['N', 'Y']),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildSectionHeader(
                        'ID Proof Details',
                        const Color(0xFF1E88E5),
                      ),
                      _buildSectionBody(
                        isMobile,
                        [
                          _buildTextField('PAN Number', ''),
                          _buildTextField('Aadhar Card Number', ''),
                          _buildTextField('Voter Id No', ''),
                          _buildTextField('Passport No', ''),
                          _buildTextField('Driving License No', ''),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildSectionHeader(
                        'Contact Address Details',
                        const Color(0xFFE53935),
                      ),
                      _buildSectionBody(
                        isMobile,
                        [
                          _buildDropdownField(
                              'State', ['TELANGANA', 'ANDHRA PRADESH']),
                          _buildDropdownField(
                              'District', ['WARANGAL URBAN', 'WARANGAL RURAL']),
                          _buildDropdownField(
                              'Mandal', ['ELKATHURTHY', 'HANAMKONDA']),
                          _buildDropdownField(
                              'Village', ['KESHAVAPUR', 'HUNTER ROAD']),
                          _buildTextField('Street', ''),
                          _buildTextField('House No.', ''),
                          _buildTextField('Pin Code', ''),
                          _buildTextField('Personal Email ID', ''),
                          _buildTextField('Mobile No1', ''),
                          _buildTextField('College Email ID', ''),
                          _buildTextField('Mobile No2', ''),
                        ],
                      ),
                      CheckboxListTile(
                        value: _sameAsContactAddress,
                        onChanged: (value) {
                          setState(() {
                            _sameAsContactAddress = value ?? false;
                          });
                        },
                        title: const Text(
                          'Select the Checkmark if Contact Address & Permanent is same',
                        ),
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                      ),
                      const SizedBox(height: 8),
                      _buildSectionHeader(
                        'Permanent Address Details',
                        const Color(0xFF1AA6B8),
                      ),
                      _buildSectionBody(
                        isMobile,
                        [
                          _buildDropdownField(
                              'State', ['TELANGANA', 'ANDHRA PRADESH']),
                          _buildDropdownField(
                              'District', ['WARANGAL URBAN', 'WARANGAL RURAL']),
                          _buildDropdownField(
                              'Mandal', ['ELKATHURTHY', 'HANAMKONDA']),
                          _buildDropdownField(
                              'Village', ['KESHAVAPUR', 'HUNTER ROAD']),
                          _buildTextField('Street', ''),
                          _buildTextField('House No.', ''),
                          _buildTextField('Pin Code', ''),
                          _buildTextField('Emergency Contact No1', ''),
                          _buildTextField('Emergency Contact No2', ''),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Center(
                        child: ElevatedButton(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Profile update submitted'),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2EAD4B),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 28,
                              vertical: 12,
                            ),
                          ),
                          child: const Text('Update'),
                        ),
                      ),
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

  Widget _buildSectionHeader(String title, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildSectionBody(bool isMobile, List<Widget> fields) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Wrap(
        spacing: 16,
        runSpacing: 12,
        children: fields.map((field) {
          return SizedBox(
            width: isMobile ? double.infinity : 360,
            child: field,
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTextField(String label, String initialValue) {
    return TextFormField(
      initialValue: initialValue,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
    );
  }

  Widget _buildDropdownField(String label, List<String> items) {
    return DropdownButtonFormField<String>(
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      items: items
          .map((item) => DropdownMenuItem(value: item, child: Text(item)))
          .toList(),
      onChanged: (_) {},
    );
  }

  Widget _buildDateField(String label) {
    return TextFormField(
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
        suffixIcon: const Icon(Icons.calendar_today, size: 18),
      ),
      readOnly: true,
      onTap: () async {
        await showDatePicker(
          context: context,
          firstDate: DateTime(1950),
          lastDate: DateTime.now(),
        );
      },
    );
  }
}
