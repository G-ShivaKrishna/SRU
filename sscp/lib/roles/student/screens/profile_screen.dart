import 'package:flutter/material.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
            _buildHeaderSection(context),
            Padding(
              padding: EdgeInsets.all(isMobile ? 12 : 16),
              child: Column(
                children: [
                  _buildSectionCard(
                      'Student Basic Information',
                      [
                        _buildInfoRow('Registration Number', '2203A51291'),
                        _buildInfoRow(
                            'Student Name', 'GOTTIMUKKULA SHIVA KRISHNA REDDY'),
                        _buildInfoRow('Father\'s Name or Guardian',
                            'GOTTIMUKKULA SRINIVAS REDDY'),
                        _buildInfoRow('Roll Number', '22CSBTB09'),
                        _buildInfoRow('Date of Birth', '18/08/2004'),
                        _buildInfoRow('Gender', 'MALE'),
                        _buildInfoRow('Blood Transfusion', 'O+'),
                      ],
                      context),
                  const SizedBox(height: 16),
                  _buildSectionCard(
                      'Student Admission Information',
                      [
                        _buildInfoRow('Admission Year', '2022'),
                        _buildInfoRow('Admission Type', 'Convener (EAMCET)'),
                        _buildInfoRow('Course Name', 'BTECH'),
                        _buildInfoRow('Branch', 'CSE'),
                        _buildInfoRow('Batch Number', '22CSBTB09'),
                        _buildInfoRow('Date of Admission', '15-07-2022'),
                      ],
                      context),
                  const SizedBox(height: 16),
                  _buildSectionCard(
                      'Student Personal Details',
                      [
                        _buildInfoRow('Nationality', 'Indian'),
                        _buildInfoRow('Religion', 'Hindu'),
                        _buildInfoRow('Caste', 'SC'),
                        _buildInfoRow('Mother Tongue', 'Telugu'),
                        _buildInfoRow(
                            'Identification Mark', 'Mole on Left Shoulder'),
                        _buildInfoRow('Place of Birth', 'HYDERABAD'),
                      ],
                      context),
                  const SizedBox(height: 16),
                  _buildSectionCard(
                      'Contact Address',
                      [
                        _buildInfoRow(
                            'Address Line 1', 'H.NO.6-3-RAMA KRISHNA NAGAR'),
                        _buildInfoRow('Address Line 2', 'JANGAON'),
                        _buildInfoRow('City', 'JANGAON'),
                        _buildInfoRow('State', 'TELANGANA'),
                        _buildInfoRow('Country', 'India'),
                        _buildInfoRow('Postal Code', '506167'),
                        _buildInfoRow('Phone Number', '7032704281'),
                      ],
                      context),
                  const SizedBox(height: 16),
                  _buildSectionCard(
                      'Academic Details',
                      [
                        _buildInfoRow('SSC School Name', 'Sri Saraswathi'),
                        _buildInfoRow('Board of SSC', 'SSC'),
                        _buildInfoRow('SSC Percentage', '9.2'),
                        _buildInfoRow('Intermediate College',
                            'Sri Saraswathi Junior College'),
                        _buildInfoRow(
                            'Board of Intermediate', 'JUNIOR COLLEGE'),
                        _buildInfoRow('Intermediate Percentage', '9.4'),
                      ],
                      context),
                  const SizedBox(height: 16),
                  _buildSectionCard(
                      'CET Details',
                      [
                        _buildInfoRow('CET Type', 'EAMCET'),
                        _buildInfoRow('CET Rank', '45846'),
                        _buildInfoRow('CET Marks', '515'),
                        _buildInfoRow('CET Score', '9'),
                      ],
                      context),
                  const SizedBox(height: 16),
                  _buildSectionCard(
                      'Permanent Address',
                      [
                        _buildInfoRow(
                            'Address Line 1', 'H.NO.6-3-RAMA KRISHNA NAGAR'),
                        _buildInfoRow('Address Line 2', 'JANGAON'),
                        _buildInfoRow('City', 'JANGAON'),
                        _buildInfoRow('State', 'TELANGANA'),
                        _buildInfoRow('Country', 'India'),
                        _buildInfoRow('Postal Code', '506167'),
                      ],
                      context),
                  const SizedBox(height: 16),
                  _buildSectionCard(
                      'Aadhar Card Details',
                      [
                        _buildInfoRow('Aadhar Number', '****1234'),
                        _buildInfoRow('Address',
                            'H.NO.6-3-RAMA KRISHNA NAGAR\nJANGAON\nJANGAON\nTELANGANA\n506167'),
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
