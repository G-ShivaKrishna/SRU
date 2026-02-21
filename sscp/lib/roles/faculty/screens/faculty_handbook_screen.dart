import 'package:flutter/material.dart';
import '../../../widgets/app_header.dart';

class FacultyHandbookScreen extends StatefulWidget {
  const FacultyHandbookScreen({super.key});

  @override
  State<FacultyHandbookScreen> createState() => _FacultyHandbookScreenState();
}

class _FacultyHandbookScreenState extends State<FacultyHandbookScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String _searchQuery = '';
  bool _showTableOfContents = false;
  bool _matchFoundInLastBuild = false;
  bool _showNoMatch = false;

  final List<HandbookSection> _sections = [
    HandbookSection('cover', 'Cover Page', 0),
    HandbookSection('introduction', '1. Introduction & Overview', 1),
    HandbookSection('employment', '2. Employment & Recruitment', 2),
    HandbookSection('benefits', '3. Benefits & Facilities', 3),
    HandbookSection('policies', '4. Policies & Procedures', 4),
    HandbookSection('campus', '5. Campus Facilities', 5),
    HandbookSection('academic', '6. Academic Systems', 6),
    HandbookSection('admin', '7. Administrative Procedures', 7),
    HandbookSection('designations', '8. University Designations', 8),
    HandbookSection('sru_policies', '9. SRU Policies', 9),
    HandbookSection('research', '10. Research & Supervision', 10),
    HandbookSection('conduct', '11. Code of Conduct', 11),
    HandbookSection('sdgs', '12. SDGs & Innovation', 12),
    HandbookSection('annexures', 'Annexures', 13),
  ];

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _matchFoundInLastBuild = false;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final noMatch = _searchQuery.isNotEmpty && !_matchFoundInLastBuild;
      if (_showNoMatch != noMatch) {
        setState(() {
          _showNoMatch = noMatch;
        });
      }
    });

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Column(
        children: [
          // AppHeader
          const AppHeader(),

          // Main content
          Expanded(
            child: Row(
              children: [
                // Table of Contents Sidebar
                if (_showTableOfContents)
                  Container(
                    width: 280,
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      border:
                          Border(right: BorderSide(color: Colors.grey[300]!)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A237E),
                            border: Border(
                                bottom: BorderSide(color: Colors.grey[300]!)),
                          ),
                          child: const Text(
                            'Table of Contents',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        Expanded(
                          child: ListView.builder(
                            itemCount: _sections.length,
                            itemBuilder: (context, index) {
                              final section = _sections[index];
                              return ListTile(
                                dense: true,
                                title: Text(
                                  section.title,
                                  style: const TextStyle(fontSize: 13),
                                ),
                                onTap: () {
                                  setState(() {
                                    _showTableOfContents = false;
                                  });
                                },
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),

                // Main Content Area
                Expanded(
                  child: Column(
                    children: [
                      // Header with controls
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border(
                              bottom: BorderSide(color: Colors.grey[300]!)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.arrow_back),
                                  onPressed: () => Navigator.of(context).pop(),
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'Faculty Handbook',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1A237E),
                                  ),
                                ),
                                const Spacer(),
                                // Table of Contents Toggle
                                OutlinedButton.icon(
                                  onPressed: () {
                                    setState(() {
                                      _showTableOfContents =
                                          !_showTableOfContents;
                                    });
                                  },
                                  icon: Icon(_showTableOfContents
                                      ? Icons.menu_open
                                      : Icons.menu_book),
                                  label: Text(_showTableOfContents
                                      ? 'Hide Contents'
                                      : 'Show Contents'),
                                ),
                                const SizedBox(width: 8),
                                // Print button
                                OutlinedButton.icon(
                                  onPressed: () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content: Text(
                                              'Print functionality coming soon')),
                                    );
                                  },
                                  icon: const Icon(Icons.print),
                                  label: const Text('Print'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            // Search bar
                            Row(
                              children: [
                                SizedBox(
                                  width: 400,
                                  child: TextField(
                                    controller: _searchController,
                                    decoration: InputDecoration(
                                      hintText: 'Search handbook...',
                                      prefixIcon: const Icon(Icons.search),
                                      suffixIcon: _searchQuery.isNotEmpty
                                          ? IconButton(
                                              icon: const Icon(Icons.clear),
                                              onPressed: () {
                                                setState(() {
                                                  _searchController.clear();
                                                  _searchQuery = '';
                                                });
                                              },
                                            )
                                          : null,
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 8),
                                    ),
                                    onChanged: (value) {
                                      setState(() {
                                        _searchQuery = value.toLowerCase();
                                      });
                                    },
                                  ),
                                ),
                                if (_searchQuery.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(left: 12),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: _showNoMatch
                                            ? Colors.red[50]
                                            : Colors.green[50],
                                        border: Border.all(
                                            color: _showNoMatch
                                                ? Colors.red[300]!
                                                : Colors.green[300]!),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            _showNoMatch
                                                ? Icons.error_outline
                                                : Icons.check_circle,
                                            color: _showNoMatch
                                                ? Colors.red[700]
                                                : Colors.green[700],
                                            size: 16,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            _showNoMatch
                                                ? 'No matches found'
                                                : 'Searching for "$_searchQuery"',
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: _showNoMatch
                                                  ? Colors.red[900]
                                                  : Colors.green[900],
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Scrollable Content
                      Expanded(
                        child: SingleChildScrollView(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(24),
                          child: Container(
                            constraints: const BoxConstraints(maxWidth: 900),
                            child: _buildHandbookContent(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHandbookContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildCoverPage(),
        const Divider(height: 60, thickness: 2),
        _buildIntroduction(),
        const Divider(height: 60, thickness: 2),
        _buildEmployment(),
        const Divider(height: 60, thickness: 2),
        _buildBenefits(),
        const Divider(height: 60, thickness: 2),
        _buildPolicies(),
        const Divider(height: 60, thickness: 2),
        _buildCampusFacilities(),
        const Divider(height: 60, thickness: 2),
        _buildAcademicSystems(),
        const Divider(height: 60, thickness: 2),
        _buildAdministrative(),
        const Divider(height: 60, thickness: 2),
        _buildDesignations(),
        const Divider(height: 60, thickness: 2),
        _buildSRUPolicies(),
        const Divider(height: 60, thickness: 2),
        _buildResearch(),
        const Divider(height: 60, thickness: 2),
        _buildCodeOfConduct(),
        const Divider(height: 60, thickness: 2),
        _buildSDGsAndSRiX(),
        const Divider(height: 60, thickness: 2),
        _buildAnnexures(),
      ],
    );
  }

  Widget _buildCoverPage() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 40),
        _buildChapterTitle('SR UNIVERSITY'),
        const SizedBox(height: 20),
        _buildSectionTitle('STAFF HANDBOOK'),
        const SizedBox(height: 40),
        _buildParagraph('Ananthasagar, Hasanparthy'),
        _buildParagraph('Warangal, Telangana, India-506371'),
        const SizedBox(height: 20),
        _buildParagraph('Academic Year 2024-25'),
      ],
    );
  }

  Widget _buildIntroduction() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildChapterTitle('1. INTRODUCTION & OVERVIEW'),
        _buildSectionTitle('1.1 Staff Handbook Purpose and Scope'),
        _buildParagraph(
          'Welcome to SR University; we wish you a successful journey. The SR University staff handbook serves as your guide to key policies, procedures, and resources. It is subject to updates, which will be communicated promptly. Please review its contents to effectively support your role. For inquiries, teaching staff should contact the Office of Dean (Faculty Affairs); non-teaching staff should contact the Office of Registrar.',
        ),
        const SizedBox(height: 20),
        _buildSectionTitle('1.2 University Overview'),
        _buildParagraph(
          'SR University (SRU), a State Private University in Warangal, Telangana, is spread on a 170-acre campus with approximately 11,000 students, 1,200 staff, and over 140 programs across five Schools. SRU has achieved notable recognition in the National Institutional Ranking Framework (NIRF), ranking 98th in Engineering for 2023 and 2024 as one of the youngest universities, and is positioned in the 101-150 band in the University category.',
        ),
        const SizedBox(height: 16),
        _buildSubsectionTitle('Schools'),
        _buildBulletPoint(
            'School of Computer Science and Artificial Intelligence'),
        _buildBulletPoint('School of Engineering'),
        _buildBulletPoint('School of Business'),
        _buildBulletPoint('School of Agriculture'),
        _buildBulletPoint('School of Sciences and Humanities'),
        const SizedBox(height: 16),
        _buildSubsectionTitle('Centers'),
        _buildBulletPoint(
            'Center for Artificial Intelligence & Deep Learning (CAIDL)'),
        _buildBulletPoint('Center for Embedded Systems and IoT (CEIoT)'),
        _buildBulletPoint('Center for Materials and Manufacturing (CMM)'),
        _buildBulletPoint('Center for Emerging Energy Technologies (CEET)'),
        _buildBulletPoint('Center for Construction Methods & Materials (CCMM)'),
        _buildBulletPoint('Center for Creative Cognition (CCC)'),
        _buildBulletPoint(
            'Nest for Entrepreneurship in Science & Technology (NEST)'),
        _buildBulletPoint('Collaboratory for Social Innovation (CSI)'),
        _buildBulletPoint('Center for Design (CoD)'),
        _buildBulletPoint('Center for Informetrics and Statistics (CIS)'),
        _buildBulletPoint('Center for Emerging Materials (CEM)'),
        const SizedBox(height: 16),
        _buildSubsectionTitle('Research'),
        _buildParagraph(
          'SR University boasts over 5400 publications, 550 patents, and over ₹20 Crore in research funding from 50+ projects. SRU is recognized as a Scientific and Industrial Research Organisation (SIRO) by the Govt of India.',
        ),
        const SizedBox(height: 16),
        _buildSubsectionTitle('Staff Benefits'),
        _buildParagraph(
          'SR University provides a comprehensive benefits package for its staff. Benefits include PF, Medical Insurance, Research Incentive (up to ₹1.1 Lakh/publication), Professional Allowance (₹1 Lakh/year), Seed Grant (up to ₹10 Lakh), Full-time PhD student hiring allowance (up to ₹28.8 Lakh/three years), 80% of consultancy profits, and annual appraisal allowance (up to ₹1.5 Lakh/year), alongside attractive growth and promotion opportunities.',
        ),
        const SizedBox(height: 20),
        _buildSectionTitle('1.3 University Vision and Mission'),
        _buildSubheading('Vision'),
        _buildParagraph(
          'To accelerate the pace of transformation and advancement of the regional innovation ecosystem through academic excellence, industry relevance, and social responsibility.',
        ),
        _buildSubheading('Mission'),
        _buildBulletPoint(
            'Produce technically competent, industry-ready, and socially conscious leaders'),
        _buildBulletPoint(
            'Engage in path-breaking research and disseminate the outcomes'),
        _buildBulletPoint(
            'Collaborate with Industry, Government, and non-profit organizations for the benefit of the community'),
      ],
    );
  }

  Widget _buildEmployment() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildChapterTitle('2. EMPLOYMENT & RECRUITMENT'),
        _buildSectionTitle('2.1 Classification of Employment'),
        _buildSubheading('a. Regular Staff'),
        _buildParagraph(
          'A regular staff member is permanently employed. This includes individuals in permanent positions confirmed based on criteria, provided they meet performance standards and adhere to University Service Regulations.',
        ),
        _buildSubheading('b. Fixed Term (Contractual) Staff'),
        _buildParagraph(
          'Fixed Term (Contractual) staff are individuals appointed for a predetermined duration. Their employment terminates upon contract completion or as per contract clauses.',
        ),
        _buildSubheading('c. Part-Time Staff'),
        _buildParagraph(
          'Part-time staff work fewer than standard hours, receive a fixed monthly salary, and are ineligible for benefits provided to full-time staff.',
        ),
        _buildSubheading('d. Adjunct Faculty'),
        _buildParagraph(
          'Adjunct Faculty are academic or industry professionals appointed contractually to teach courses or perform collaborative research, sharing their expertise with faculty and students.',
        ),
        _buildSubheading('e. Faculty of Practice'),
        _buildParagraph(
          'Eligibility for Faculty of Practice requires industry experts with proven expertise and significant professional experience in fields including engineering, science, technology, entrepreneurship, and various other domains.',
        ),
        const SizedBox(height: 20),
        _buildSectionTitle('2.2 How to Reach SR University Campus'),
        _buildParagraph(
          'The SR University campus is located at Ananthsagar, Hasanparthy, Hanamkonda, Telangana 506371. It is situated 14 km from Hanamkonda city, 16 km from Kazipet Railway Station, and 29 km from Warangal Railway Station. The nearest airport is Rajiv Gandhi International Airport in Hyderabad, approximately 140 km away.',
        ),
        const SizedBox(height: 20),
        _buildSectionTitle('3.1 Modes of Recruitment'),
        _buildBulletPoint(
            'Advertisement: Positions publicized via social media, newspapers, online job portals'),
        _buildBulletPoint(
            'Internal Promotion: SRU facilitates promotion of existing staff'),
        _buildBulletPoint(
            'Networking and Referrals: Suitable candidates identified through recommendations'),
        _buildBulletPoint(
            'Direct Outreach: Talent acquisition team contacts exceptional candidates'),
        _buildBulletPoint(
            'Campus Visits: Interviews conducted at esteemed institutions'),
        const SizedBox(height: 20),
        _buildSectionTitle('3.2 Staff Recruitment Process'),
        _buildBulletPoint(
            'Position Announcement by Dean of Faculty Affairs or Registrar'),
        _buildBulletPoint('Application Review by screening committee'),
        _buildBulletPoint('Interviews and Presentations'),
        _buildBulletPoint('Selection and Offer'),
        _buildBulletPoint('Joining and Onboarding'),
        const SizedBox(height: 20),
        _buildSectionTitle('3.3 Joining and Settling Down'),
        _buildParagraph(
          'New staff members may email the Office of the Dean (Faculty Affairs) or the Registrar\'s Office to request accommodation at the Institute Guest House. Staff from distant locations are eligible for complimentary accommodation for up to four nights.',
        ),
        const SizedBox(height: 20),
        _buildSectionTitle('3.4 On-boarding Policy (Induction Process)'),
        _buildParagraph(
          'The induction process familiarizes new staff with SRU\'s core values, vision, mission, key personnel, processes, and their designated roles. A personal file is established for each staff member, updated throughout their employment.',
        ),
        const SizedBox(height: 16),
        _buildSubheading('On-boarding Checklist (Contacts & Timings)'),
        _buildTable(
          [
            'S.No',
            'Item',
            'Contact Person',
            'Block & Room',
            'Available Timings'
          ],
          [
            [
              '1',
              'Employee ID',
              'J. Sambamurthy (9989899611)',
              'Block-I, Room 1103',
              'Monday, 9:00 am - 12:00 pm',
            ],
            [
              '2',
              'Group Medical Insurance Form',
              '-',
              '-',
              '-',
            ],
            [
              '3',
              'Biometric Registration',
              '-',
              '-',
              '-',
            ],
            [
              '4',
              'Inclusion in SRU WhatsApp Group',
              'Ms. K. Sneha (9550467663)',
              'Block-I, Room 1011',
              'Monday, 12:00 pm - 1:00 pm',
            ],
            [
              '5',
              'Bank Account Opening Form',
              'P. Sagar (9182714569)',
              'SRiX, Room 7012',
              'Monday, 2:00 pm - 3:00 pm',
            ],
            [
              '6',
              'SRU official email ID',
              'V. Purnima (9966614130)',
              'Block-I, Room 1103',
              'Monday, 9:00 am - 5:00 pm',
            ],
            [
              '7',
              'Login Credentials for SRU portals (www.sruniv.com & www.sraap.in)',
              '-',
              '-',
              '-',
            ],
            [
              '8',
              'Professional Photograph for website',
              '-',
              '-',
              '-',
            ],
            [
              '9',
              'Library Membership Registration',
              'R. Sammi Reddy (9989734069)',
              'Block-I, Ground Floor Library',
              'Monday, 9:00 am - 5:00 pm',
            ],
          ],
          columnWidths: const {
            0: FixedColumnWidth(40),
            1: FlexColumnWidth(2.4),
            2: FlexColumnWidth(2),
            3: FlexColumnWidth(1.8),
            4: FlexColumnWidth(2),
          },
        ),
        const SizedBox(height: 20),
        _buildSectionTitle('3.6 Probation and Confirmation'),
        _buildParagraph(
          'The probationary period allows new staff to demonstrate their capabilities and suitability within SRU. Satisfactory performance results in confirmation as a permanent staff member.',
        ),
        const SizedBox(height: 20),
        _buildSectionTitle('3.9 Teaching'),
        _buildParagraph(
          'Teaching constitutes a primary responsibility for faculty members. The Center for Experiential Learning (CEL) provides support for faculty development. The maximum faculty workload is 16 hours per week, equivalent to 224 hours per 14-week semester.',
        ),
        const SizedBox(height: 20),
        _buildSectionTitle('3.10 Workload Guidelines'),
        _buildParagraph(
          'Professor: 12 hrs; Associate Professor: 14 hrs; Assistant Professor: 16 hrs; Staff without research mandate: 20 hrs. Reductions: Assistant Dean/Associate Dean: 2 hours; Dean/Dept Head: 4 hrs; Pro VC and Registrar: 8 Hrs.',
        ),
      ],
    );
  }

  Widget _buildBenefits() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildChapterTitle('3. BENEFITS & FACILITIES'),
        _buildSectionTitle('4.1 Group Medical Insurance'),
        _buildParagraph(
          'We offer a comprehensive Group Medical Insurance program for full-time staff and their eligible dependents. Coverage includes Sum Insured of ₹5,00,000 with pre-hospitalization (30 days), post-hospitalization (60 days), organ donor expenses, domiciliary treatment, day care procedures, and road ambulance cover (₹2,000 per hospitalization).',
        ),
        const SizedBox(height: 12),
        _buildSubheading('Age Limits'),
        _buildTable(
          ['Relationship', 'Minimum Age of Entry', 'Maximum Age of Entry'],
          [
            ['Employee', '18 Years', '65 Years'],
            ['Spouse', '18 Years', '65 Years'],
            ['Dependent Child', 'Day 1', '25 Years'],
          ],
          columnWidths: const {
            0: FlexColumnWidth(2),
            1: FlexColumnWidth(2),
            2: FlexColumnWidth(2),
          },
        ),
        const SizedBox(height: 12),
        _buildSubheading('Benefits of the Policy'),
        _buildTable(
          ['Benefit', 'Coverage'],
          [
            ['Medical Expenses Cover', 'Covered up to Sum Insured'],
            ['Pre-Hospitalisation', '30 days'],
            ['Post-Hospitalisation', '60 days'],
            ['Organ Donor Expenses', 'Covered up to Sum Insured'],
            ['Domiciliary Treatment', 'Covered up to Sum Insured'],
            ['Day Care Procedures', 'All Day Care covered up to Sum Insured'],
            ['Road Ambulance Cover', 'Rs 2,000 per Hospitalisation'],
            ['30 Days Waiting Period', 'Waived'],
            ['1st Year Disease Waiting Period', 'Applicable'],
            ['Pre-Existing Disease Waiting Period', '36 Months'],
            ['Maternity Cover', 'Not Applicable'],
            ['Pre and Post Natal Cover', 'Not Covered'],
            ['Baby Covered from Day 1', 'Not Covered'],
          ],
          columnWidths: const {
            0: FlexColumnWidth(2.2),
            1: FlexColumnWidth(2.8),
          },
        ),
        _buildParagraph(
          'Note: The terms and conditions of the policy are applicable for the academic year 2023-24 only and may change based on the vendor for 2025-26.',
        ),
        const SizedBox(height: 20),
        _buildSectionTitle('4.2 Staff Club'),
        _buildParagraph(
          'The SRU Staff Club cultivates community among staff members. Membership is automatic for all staff upon joining SRU. Activities include social events, celebrations, cultural gatherings, and family-friendly outings.',
        ),
        _buildSubheading('Staff Club Membership Amount:'),
        _buildTable(
          ['Range of Salary', 'Staff Club Membership Amount'],
          [
            ['Less than Rs. 50,000/-', 'Rs. 100/-'],
            ['Rs. 50,000 to Rs. 1,00,000/-', 'Rs. 250/-'],
            ['More than Rs. 1,00,000/-', 'Rs. 350/-'],
          ],
          columnWidths: const {
            0: FlexColumnWidth(3),
            1: FlexColumnWidth(2),
          },
        ),
        const SizedBox(height: 20),
        _buildSectionTitle('4.3 Employee Children Scholarship'),
        _buildParagraph(
          'Tuition Fee Concession for children of employees attending SR Education Society Institutions is granted according to the institution\'s policy. Eligibility is contingent upon merit and seat availability.',
        ),
        const SizedBox(height: 20),
        _buildSectionTitle('4.4 Provident Fund'),
        _buildParagraph(
          'The Provident Fund (PF) constitutes a long-term savings scheme to provide financial security for staff. Contributions are made by both the staff member and the employer.',
        ),
        const SizedBox(height: 20),
        _buildSectionTitle('4.5 Leave Travel Concession (LTC)'),
        _buildParagraph(
          'An LTC amount of up to ₹1 Lakh is payable once in a block of three years, subject to SRU policy. This benefit may be availed from the employee\'s SRTOP5 plus amount.',
        ),
        const SizedBox(height: 20),
        _buildSectionTitle(
            '4.6 Medical Facility and Emergency Medical Transport'),
        _buildParagraph(
          'SRU provides an emergency medical transport (Ambulance) facility on campus. A wellness center is available in Block-3 for routine medical needs.',
        ),
        _buildSubheading('Emergency Contacts:'),
        _buildBulletPoint('Mr. Sai Kumar, Ambulance Driver: 7989738242'),
        _buildBulletPoint('Mr. A. Ravi, Sr. Assistant: 9948649083'),
        _buildBulletPoint('Wellness centre: B.Pavani - 6300390746'),
        const SizedBox(height: 20),
        _buildSectionTitle(
            '4.7 Support System Beyond Working Hours and Maintenance-Related Issues'),
        _buildParagraph(
          'SRU supports staff undertaking research and teaching-related tasks outside regular working hours. Labs and the central library are accessible during extended periods, and refreshment facilities are available. Faculty should inform respective block supervisors in advance for extended stays.',
        ),
        const SizedBox(height: 16),
        _buildSectionTitle('4.8 Maintenance-Related Issues'),
        _buildParagraph(
          'Each university block has a designated Maintenance In-Charge. Contact the respective In-Charge for building repairs, electrical/plumbing issues, equipment malfunction, or other infrastructure concerns.',
        ),
        _buildSubheading('Block Supervisors'),
        _buildTable(
          ['Block', 'Supervisor', 'Contact'],
          [
            ['Block 1', 'Mr. K. Thirupathi', '8374970067'],
            ['Block 2', 'Ms. P. Rajamma', '8465959651'],
            ['Block 3', 'Mr. S. Joginder', '9652429412'],
            ['SRiX', 'Mr. D. Raji Reddy', '6304733869'],
            ['Agriculture School', 'Mr. Y. Sudhakar', '6281566857'],
          ],
          columnWidths: const {
            0: FlexColumnWidth(1.5),
            1: FlexColumnWidth(2.2),
            2: FlexColumnWidth(1.4),
          },
        ),
        _buildSubheading('Escalation Matrix'),
        _buildBulletPoint(
            'Second Level: Ms. J. Ramadevi, Jr. Assistant - 9963084035'),
        _buildBulletPoint(
            'Third Level: Sridhar Reddy, Facilities Manager - 9989293164'),
        _buildBulletPoint(
            'Final Level: Mr. A. Ravi, Sr. Assistant - 9948649083'),
        const SizedBox(height: 20),
        _buildSectionTitle('4.9 Open Door Policy'),
        _buildParagraph(
          'The university maintains an "Open Door Policy," encouraging staff members to submit suggestions, concerns, or feedback regarding university operations. Staff may approach any office bearer, including the Vice Chancellor, via various communication channels.',
        ),
        const SizedBox(height: 20),
        _buildSectionTitle('4.10 360-Degree Feedback'),
        _buildParagraph(
          'SRU implements a 360-degree feedback system to ensure comprehensive staff evaluation. This system collects input from multiple sources, including deans, faculty, peers, and students, providing holistic performance assessment.',
        ),
        const SizedBox(height: 20),
        _buildSectionTitle(
            '4.11 Bachelor Staff Accommodation at University Hostels'),
        _buildParagraph(
          'The university offers limited shared accommodation for bachelor staff in university hostels at a nominal charge of ₹15,000. Three meals per day are provided free of charge for resident staff. Accommodation is subject to availability.',
        ),
      ],
    );
  }

  Widget _buildPolicies() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildChapterTitle('4. POLICIES & PROCEDURES'),
        _buildSectionTitle(
            '5.0 Prohibition of Private Tuitions / Holding an Office of Profit'),
        _buildParagraph(
          'All university staff members are prohibited from offering private tuition to SRU or external students. Staff shall not engage in other business activities or hold offices of profit. Non-compliance may result in disciplinary action.',
        ),
        const SizedBox(height: 20),
        _buildSectionTitle('6.0 Dress Code'),
        _buildParagraph(
          'The staff dress code at SRU aims to maintain a professional and respectful appearance. The standard dress code is business casual: neat, clean attire suitable for a professional academic setting. On Monday and Tuesday, formal attire is mandatory. T-shirts, slippers, sandals and jeans are not allowed on these occasions.',
        ),
        const SizedBox(height: 20),
        _buildSectionTitle('7.0 Gift Policy'),
        _buildParagraph(
          'Staff members are prohibited from accepting or offering gifts valued over ₹5,000. Gifts must be commensurate with the occasion, recipient\'s status, and relationship with SRU. Staff must avoid gifts that could compromise professional integrity.',
        ),
        const SizedBox(height: 20),
        _buildSectionTitle('8.0 Biometric Attendance'),
        _buildParagraph(
          'The university utilizes a biometric attendance system for accurate recording of staff attendance. Adherence to biometric procedures is mandatory. Attendance must be recorded at the commencement and conclusion of each working day.',
        ),
        const SizedBox(height: 20),
        _buildSectionTitle('9.0 Termination'),
        _buildParagraph(
          'Staff appointments are subject to termination due to non-performance or engagement in actions including: cheating, academic dishonesty, acceptance of bribes, criminal cases, anti-national activities, theft, sexual harassment, or participation in illegal strikes.',
        ),
        const SizedBox(height: 20),
        _buildSectionTitle('10.0 Conflict of Interest'),
        _buildParagraph(
          'SRU prioritizes transparency, ethics, and integrity. Staff must diligently identify and address potential conflicts of interest. Disclosure is required if a close relative is involved in purchasing decisions, tender processes, or job applications at SRU.',
        ),
        const SizedBox(height: 20),
        _buildSectionTitle('11.0 Examination Duties'),
        _buildParagraph(
          'Examination duties are an inherent part of the academic process. All staff are expected to participate in various examination-related activities.',
        ),
        _buildSubheading('Invigilation Guidelines:'),
        _buildBulletPoint('Dean/Head: one duty'),
        _buildBulletPoint('Professor: two duties'),
        _buildBulletPoint('Associate Professor: three duties'),
        _buildBulletPoint('Assistant Professor and PhD scholars: eight duties'),
      ],
    );
  }

  Widget _buildCampusFacilities() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildChapterTitle('5. CAMPUS FACILITIES'),
        _buildSectionTitle('12.1 Library Facilities'),
        _buildParagraph(
          'The university\'s Central Library serves as a comprehensive repository of knowledge, featuring an extensive collection of books, journals, e-books, e-journals, and multimedia resources. The library operates from 08:00 to 20:00 on working days and 10:00 to 16:00 on holidays.',
        ),
        const SizedBox(height: 20),
        _buildSectionTitle('12.2 Parking'),
        _buildParagraph(
          'Vehicle entry permits (stickers) are issued to facilitate entry onto SR University premises. Staff should contact the designated person to obtain a sticker. A maximum of two stickers will be allotted per staff member.',
        ),
        _buildSubheading('Contact:'),
        _buildBulletPoint('Security officer: K. Venkateshwar Rao - 9618503127'),
        const SizedBox(height: 20),
        _buildSectionTitle('12.3 Stationery Stores'),
        _buildParagraph(
          'A stationery store is located behind Block-I to support staff professional needs. A standard stationery kit is provided to each faculty member at the commencement of every semester.',
        ),
        _buildSubheading('Contact:'),
        _buildBulletPoint(
            'Stationary store in charge: G. Surender - 9966290920'),
        const SizedBox(height: 20),
        _buildSectionTitle('12.4 Canteen & Refreshment Services'),
        _buildParagraph(
          'The University features a spacious, two-storeyed cafeteria on the ground floor of SRiX Block. Equipped with modern facilities, it offers breakfast, lunch, snacks, and beverages from 08:30 to 18:00. Three additional refreshment points are available across campus.',
        ),
      ],
    );
  }

  Widget _buildAcademicSystems() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildChapterTitle('6. ACADEMIC SYSTEMS'),
        _buildSectionTitle('13.1 Academic Calendar'),
        _buildParagraph(
          'The Academic Calendar delineates the start and end dates for each academic term, registration periods, examination weeks, grade submission deadlines, fees payment deadlines, working Saturdays, and inter-term breaks. It also lists significant activities and official university holidays.',
        ),
        const SizedBox(height: 20),
        _buildSectionTitle('13.2 Course Plan'),
        _buildParagraph(
          'The Course Plan offers a comprehensive overview of the course syllabus, detailing topics, schedule of coverage, course outcomes, assessment methods, and recommended resources. Carefully designed to align with overall program outcomes.',
        ),
        const SizedBox(height: 20),
        _buildSectionTitle('13.3 Summer Semester'),
        _buildParagraph(
          'The summer semester provides students with an opportunity to recover academic progress by completing missed or failed courses. Faculty compensation during the summer semester is based on instructional hours per course.',
        ),
        const SizedBox(height: 20),
        _buildSectionTitle('14.0 No Plastic Usage'),
        _buildParagraph(
          'The university underscores its commitment to environmental sustainability through a "No Plastic Water Bottle Usage" policy across campus. Staff are encouraged to utilize reusable water bottles and access filtered water coolers.',
        ),
        const SizedBox(height: 20),
        _buildSectionTitle('15.0 Mentoring Process'),
        _buildParagraph(
          'Faculty members are assigned to groups of students as mentees. Primary mentor responsibilities include establishing connection, building trust, providing academic guidance, counseling, and regularly monitoring progress.',
        ),
        _buildSubheading('Mentor Responsibilities:'),
        _buildBulletPoint('Establish connection and build trust'),
        _buildBulletPoint('Provide academic and career guidance'),
        _buildBulletPoint('Regular one-on-one and group meetings'),
        _buildBulletPoint('Monitor progress and offer feedback'),
        _buildBulletPoint('Maintain confidentiality and respect privacy'),
        _buildParagraph(
          'One hour weekly is allocated for mentoring activities. Mentors are expected to achieve a feedback rating exceeding 4 out of 5.',
        ),
      ],
    );
  }

  Widget _buildAdministrative() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildChapterTitle('7. ADMINISTRATIVE PROCEDURES'),
        _buildSectionTitle(
            '16. Procedure for Obtaining No Objection Certificate (NOC)'),
        _buildParagraph(
          'Staff members seeking external employment must submit a formal application for a No Objection Certificate (NOC) to the Registrar\'s Office. The application shall explicitly state the staff member\'s intent to apply for positions at other institutions.',
        ),
        const SizedBox(height: 20),
        _buildSectionTitle('17. Whistleblower Policy'),
        _buildParagraph(
          'Faculty and staff are encouraged to report cases of misconduct, supported by relevant proof, to the Office of the VC. The identity of whistleblowers will be kept confidential. Reportable cases include misconduct in academics, research, financial dealings, or misuse of university resources.',
        ),
      ],
    );
  }

  Widget _buildDesignations() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildChapterTitle('8. UNIVERSITY DESIGNATIONS'),
        _buildSectionTitle('18.1 Chancellor'),
        _buildParagraph(
          'The Chancellor serves as the Head of the University, exercising general control over its affairs. The Chancellor presides over Governing Body meetings and the University convocation.',
        ),
        const SizedBox(height: 16),
        _buildSectionTitle('18.2 Pro Chancellor'),
        _buildParagraph(
          'The Pro Chancellor assists the Chancellor in discharging duties and performs the same functions as the Chancellor.',
        ),
        const SizedBox(height: 16),
        _buildSectionTitle('18.3 Vice Chancellor'),
        _buildParagraph(
          'The Vice Chancellor serves as Chairman of the Academic Council and is the executive officer of the University. This role entails general supervision and administrative control, implementation of Board decisions, and ensuring rule compliance.',
        ),
        const SizedBox(height: 16),
        _buildSectionTitle('18.4 Pro Vice Chancellor'),
        _buildParagraph(
          'The Pro Vice Chancellor is responsible for managing key academic activities, including overseeing programs to maintain high standards, ensuring smooth conduct of examinations, and handling faculty recruitment.',
        ),
        const SizedBox(height: 16),
        _buildSectionTitle('18.5 Registrar'),
        _buildParagraph(
          'The Registrar safeguards university property, manages official communication, and records meeting minutes. As head of non-teaching staff, ensures smooth operations encompassing admissions, enrollments, and registrations.',
        ),
        const SizedBox(height: 16),
        _buildSectionTitle('18.6 Chief Finance and Accounts Officer'),
        _buildParagraph(
          'The CFAO generally supervises university funds and advises on financial policy. This role includes preparing annual accounts and the budget, monitoring cash and bank balances.',
        ),
        const SizedBox(height: 16),
        _buildSectionTitle('18.7 School Dean'),
        _buildParagraph(
          'School Deans enhance their academic units\' visibility, growth, and engagement. They represent their school in forums, cultivate Industry Collaborations, and champion strategic evolution.',
        ),
        const SizedBox(height: 16),
        _buildSectionTitle('18.19 Dean Academics'),
        _buildParagraph(
          'The Dean Academics oversees university academic regulations, environment, and proceedings. Key responsibilities include preparing the annual/semester academic calendar and yearly Student Handbook.',
        ),
        const SizedBox(height: 16),
        _buildSectionTitle('18.31 Dean Research'),
        _buildParagraph(
          'The Dean of Research strategically plans for university research growth. Responsibilities include overseeing patents, Ph.D. scholars, publications, grants, and consultancy.',
        ),
        const SizedBox(height: 16),
        _buildSubheading(
            'Additional Designations (Refer to full handbook for complete list):'),
        _buildBulletPoint('Associate School Dean'),
        _buildBulletPoint('Department Head'),
        _buildBulletPoint('Director of Evaluation'),
        _buildBulletPoint('Controller of Examination'),
        _buildBulletPoint('Dean Student Welfare'),
        _buildBulletPoint('Director Sports'),
        _buildBulletPoint('Dean PG Programs'),
        _buildBulletPoint('Dean Mentoring'),
        _buildBulletPoint('Dean Faculty Affairs'),
        _buildBulletPoint('Director Placement'),
        _buildBulletPoint('Director IQAC'),
        _buildBulletPoint(
            'And many more specialized roles (65 total designations)'),
      ],
    );
  }

  Widget _buildSRUPolicies() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildChapterTitle('9. SRU POLICIES'),
        _buildParagraph(
          'SRU has implemented policies to foster a fair, transparent, and supportive academic and professional environment for all staff. Key university policies include:',
        ),
        const SizedBox(height: 16),
        _buildBulletPoint(
            'Leave Policy (Annexure-I): Defines various leave types: casual, medical, maternity, paternity, sabbatical'),
        _buildBulletPoint(
            'Travel Policy (Annexure-II): Outlines procedures for official travel'),
        _buildBulletPoint(
            'Leave Travel Concession (Annexure-III): Offers travel benefits'),
        _buildBulletPoint(
            'Teaching Staff Promotion Policy (Annexure-IV): Details criteria for career progression'),
        _buildBulletPoint(
            'Plagiarism Policy: Defines plagiarism and consequences of misconduct'),
        _buildBulletPoint(
            'Sexual Harassment Policy (Annexure-V): Zero-tolerance approach'),
        _buildBulletPoint(
            'Grievance Redressal Policy (Annexure-VI): Addresses workplace complaints'),
        _buildBulletPoint(
            'IT Resources Management Policy: Ensures responsible use of digital infrastructure'),
        _buildBulletPoint(
            'Research Ethics Policy (Annexure-VII): Mandates integrity in research'),
        const SizedBox(height: 16),
        _buildParagraph(
          'All staff members are urged to read, understand, and comply with these policies to ensure a smooth and productive academic experience.',
        ),
      ],
    );
  }

  Widget _buildResearch() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildChapterTitle('10. RESEARCH & SUPERVISION'),
        _buildSectionTitle('20.0 Recognition as Supervisors'),
        _buildParagraph(
          'The Vice-Chancellor accords recognition for guiding research work. Permanent SRU faculty (Professor/Associate Professor/Assistant Professor) with a Ph.D. and at least two Scopus-indexed research publications are eligible.',
        ),
        _buildSubheading('Requirements:'),
        _buildBulletPoint('Ph.D. degree with two Scopus-indexed publications'),
        _buildBulletPoint(
            'Minimum two years of research or teaching experience post-Ph.D.'),
        _buildBulletPoint('Current employees p Ph.D. at university are exempt'),
        const SizedBox(height: 20),
        _buildSectionTitle('20.1 Allocation of Supervisor(s)'),
        _buildParagraph(
          'An eligible Professor, Associate Professor, or Assistant Professor can supervise up to eight, six, or four Ph.D. scholars, respectively. Co-supervision counts as half a slot per scholar for each supervisor.',
        ),
        _buildSubheading('Guidelines:'),
        _buildBulletPoint(
            'Professor: Maximum 8 scholars; Associate Professor: 6; Assistant Professor: 4'),
        _buildBulletPoint('Co-supervision counts as 0.5 slot per supervisor'),
        _buildBulletPoint(
            'Faculty nearing retirement not permitted to take new scholars'),
        _buildBulletPoint(
            'Re-appointed retired faculty may continue until age 70'),
      ],
    );
  }

  Widget _buildCodeOfConduct() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildChapterTitle('11. CODE OF CONDUCT'),
        _buildParagraph(
          'SRU staff members are expected to uphold the highest standards of professionalism, integrity, and ethical conduct, fostering a positive academic environment and mutual respect.',
        ),
        const SizedBox(height: 16),
        _buildSubsectionTitle('Professionalism and Integrity'),
        _buildBulletPoint(
            'Treat all individuals with respect, fairness, dignity'),
        _buildBulletPoint(
            'Maintain research, teaching, and scholarly integrity'),
        _buildBulletPoint('Maintain confidentiality and protect privacy'),
        _buildBulletPoint('Avoid conflicts of interest'),
        _buildBulletPoint('Comply with all laws, regulations, and policies'),
        const SizedBox(height: 16),
        _buildSubsectionTitle('Teaching and Mentoring'),
        _buildBulletPoint(
            'Create supportive and inclusive learning environment'),
        _buildBulletPoint('Demonstrate fairness in examinations and feedback'),
        _buildBulletPoint('Encourage open dialogue and diverse perspectives'),
        _buildBulletPoint(
            'Guide and mentor students\' academic and professional development'),
        const SizedBox(height: 16),
        _buildSubsectionTitle('Research and Scholarly Activities'),
        _buildBulletPoint('Conduct research with integrity and transparency'),
        _buildBulletPoint('Publish findings in reputable venues'),
        _buildBulletPoint('Seek external research funding'),
        _buildBulletPoint('Mentor and supervise students in research'),
        const SizedBox(height: 16),
        _buildSubsectionTitle('Collegiality and Collaboration'),
        _buildBulletPoint('Respect colleagues\' contributions'),
        _buildBulletPoint('Promote teamwork and constructive dialogue'),
        _buildBulletPoint('Collaborate on interdisciplinary initiatives'),
        _buildBulletPoint('Participate in university governance'),
        _buildBulletPoint('Encourage academic freedom and diversity'),
      ],
    );
  }

  Widget _buildSDGsAndSRiX() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildChapterTitle('12. SUSTAINABLE DEVELOPMENT & INNOVATION'),
        _buildSectionTitle('22.0 Sustainable Development Goals (SDGs)'),
        _buildParagraph(
          'SRU actively addresses the Sustainable Development Goals (SDGs) by integrating sustainability into its academic, operational, and research endeavors. The curriculum educates students to be advocates for sustainable practices.',
        ),
        const SizedBox(height: 16),
        _buildSubheading('17 SDGs Addressed:'),
        _buildBulletPoint('No Poverty'),
        _buildBulletPoint('Zero Hunger'),
        _buildBulletPoint('Good Health and Well Being'),
        _buildBulletPoint('Quality Education'),
        _buildBulletPoint('Gender Equality'),
        _buildBulletPoint('Clean Water and Sanitation'),
        _buildBulletPoint('Affordable and Clean Energy'),
        _buildBulletPoint('Decent Work and Economic Growth'),
        _buildBulletPoint('Industry, Innovation and Infrastructure'),
        _buildBulletPoint('Reduced Inequalities'),
        _buildBulletPoint('Sustainable Cities and Communities'),
        _buildBulletPoint('Responsible Consumption and Production'),
        _buildBulletPoint('Climate Action'),
        _buildBulletPoint('Life Below Water'),
        _buildBulletPoint('Life on Land'),
        _buildBulletPoint('Peace, Justice and Strong Institutions'),
        _buildBulletPoint('Partnerships for the Goals'),
        const SizedBox(height: 20),
        _buildSectionTitle('23.0 SR Innovation Exchange (SRiX)'),
        _buildParagraph(
          'SR University hosts SRiX, a Technology Business Incubator sponsored by NSTEDB, DST, Govt of India. It has incubated 84 start-ups (8 women-led), collectively valued over ₹100 Crore.',
        ),
        const SizedBox(height: 16),
        _buildSubheading('Support Provided:'),
        _buildBulletPoint('Idea Validation and End-to-end product development'),
        _buildBulletPoint(
            'Mentoring Support: Branding, marketing, Business Expansion'),
        _buildBulletPoint(
            'Legal Support: Company incorporation, IP, Patenting'),
        _buildBulletPoint(
            'Funding Support: Seed capital, Grants, Investor connect'),
        _buildBulletPoint(
            'Financial Services: Accounting, Filings, Valuations'),
        _buildBulletPoint(
            'Connections & Networking: Mentors, investors, industry partners'),
        _buildBulletPoint('Human Resources: Hiring and team management'),
        const SizedBox(height: 16),
        _buildParagraph(
          'Staff members are encouraged to make full use of SRiX facilities, apply for funding programs, promote staff-led student startups, and be mentors for start-ups.',
        ),
      ],
    );
  }

  Widget _buildAnnexures() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildChapterTitle('ANNEXURES'),
        _buildSectionTitle('ANNEXURE-I: LEAVE POLICY'),
        _buildParagraph(
          'The Leave Policy is designed to support faculty in managing their personal and professional commitments while ensuring smooth functioning of academic activities.',
        ),
        const SizedBox(height: 16),
        _buildSubheading('Types of Leave:'),
        _buildTable(
          [
            'Type of Leave',
            'Teaching Staff Eligibility',
            'Non-Teaching Staff Eligibility',
            'Purpose',
            'Approving Authority',
          ],
          [
            [
              'Casual Leave',
              '12 days/year (including late/early permission)',
              '12 days/year',
              'Personal needs',
              'Reporting Officer',
            ],
            [
              'Vacation Leave',
              '4 weeks (weekly chunks)',
              '2 weeks (weekly chunks)',
              'Semester break / vacation',
              '-',
            ],
            [
              'Duty Leave',
              'Max 10',
              'Max 10',
              'Professional/Official engagements',
              'Pro VC for faculty; Registrar for non-teaching (through Reporting Officer)',
            ],
            [
              'Maternity Leave',
              '84 days (extendable to 180 days)',
              '84 days (extendable to 180 days)',
              'Maternity',
              '-',
            ],
            [
              'Paternity Leave',
              '5 days',
              '5 days',
              'Paternity',
              '-',
            ],
            [
              'Medical Leave',
              '6 days/year',
              '6 days/year',
              'Medical needs',
              '-',
            ],
            [
              'Earned Leave',
              '1/3 of period during vacation (Max 180 days)',
              '4 days/year + 1/3 during vacation (Max 180 days)',
              'Personal/Medical needs',
              '-',
            ],
            [
              'Sabbatical Leave (SL)',
              '2 months/year, up to 2 years',
              '2 months/year, up to 2 years',
              'Study/Research/Academic pursuits',
              'Vice Chancellor (through Reporting Officer)',
            ],
            [
              'Extraordinary Leave without Pay',
              '15 days/year, accumulates',
              '15 days/year, accumulates',
              'Valid reasons',
              '-',
            ],
            [
              'Deputation/Lien',
              '1-year lien for every 5 years',
              '1-year lien for every 5 years',
              'Deputation / Lien',
              '-',
            ],
          ],
          columnWidths: const {
            0: FlexColumnWidth(2),
            1: FlexColumnWidth(2.6),
            2: FlexColumnWidth(2.6),
            3: FlexColumnWidth(2),
            4: FlexColumnWidth(2.2),
          },
        ),
        const SizedBox(height: 12),
        _buildBulletPoint(
            'Casual Leave: 12 days/year (including late/early permission)'),
        _buildBulletPoint(
            'Vacation Leave: Teaching staff - 4 weeks; Non-teaching - 2 weeks'),
        _buildBulletPoint(
            'Duty Leave: Max 10 days for professional engagement'),
        _buildBulletPoint('Maternity Leave: 84 days (extendable to 180 days)'),
        _buildBulletPoint('Paternity Leave: 5 days'),
        _buildBulletPoint('Medical Leave: 6 days/year'),
        _buildBulletPoint(
            'Earned Leave: 1/3 of period during vacation (Max 180 days)'),
        _buildBulletPoint(
            'Sabbatical Leave: 2 months per year, max 2 years career'),
        _buildBulletPoint(
            'Extraordinary Leave: 15 days/year without pay, can accumulate'),
        _buildBulletPoint('Deputation/Lien: 1-year lien for every 5 years'),
        const SizedBox(height: 20),
        _buildSectionTitle('ANNEXURE-II: TRAVEL POLICY'),
        _buildParagraph(
          'The policy makes travel for work easier while ensuring cost-effectiveness and compliance. Applicable to all teaching and non-teaching staff.',
        ),
        _buildSubheading('Key Guidelines:'),
        _buildBulletPoint('Travel should be cost-effective and judicious'),
        _buildBulletPoint('Consider teleconferencing as alternative'),
        _buildBulletPoint('Plan trips to cut costs'),
        _buildBulletPoint(
            'Submit expense claims within 7 days of return journey'),
        _buildBulletPoint('Carry photo identity cards and visiting cards'),
        const SizedBox(height: 12),
        _buildSubheading('Travel Entitlements and Reimbursements'),
        _buildScrollableTable(
          [
            'Category',
            'Local Transport (Metro)',
            'Local Transport (Non-metro)',
            'Domestic Travel',
            'Accommodation (Metro)',
            'Accommodation (Non-metro)',
            'Meals/Incidentals (Metro)',
            'Meals/Incidentals (Non-metro)',
          ],
          [
            [
              'C1',
              'Personal four-wheeler, A/C taxi / equivalent',
              'Rs 16 per km + Toll or actuals (whichever lower)',
              'Air (Business/Premier Economy), Train (AC-I/EC)',
              'No limit (actuals)',
              'No limit (actuals)',
              'No limit (actuals)',
              'No limit (actuals)',
            ],
            [
              'C2',
              'Personal four-wheeler, A/C taxi',
              'Rs 12 per km + Toll or actuals (whichever lower)',
              'Air (Economy), Train (AC-II)/Chair Car, AC Bus',
              'Up to Rs 5,500',
              'Up to Rs 3,500',
              'Up to Rs 2,000',
              'Up to Rs 1,000',
            ],
            [
              'C3',
              'Bus/Auto/Local Train/Two-wheeler/Personal four-wheeler',
              'Rs 4 per km (two-wheeler) / Rs 8 per km (auto); Rs 10 per km personal four-wheeler + Toll',
              'Air (Economy) or Train (AC-III) or Chair Car or AC Bus',
              'Up to Rs 4,000',
              'Up to Rs 2,500',
              'Up to Rs 1,500',
              'Up to Rs 500',
            ],
            [
              'C4',
              'Bus/Train/Auto/Local Train/Two-wheeler',
              'Rs 4 per km (two-wheeler) / Rs 8 per km (auto)',
              'Train (AC-III) or AC Bus',
              'Up to Rs 2,500',
              'Up to Rs 2,000',
              'Up to Rs 1,000',
              'Up to Rs 500',
            ],
          ],
        ),
        const SizedBox(height: 20),
        _buildSectionTitle('ANNEXURE-III: LEAVE TRAVEL CONCESSION (LTC)'),
        _buildParagraph(
          'LTC is an employee benefit facilitating travel for staff and families. Up to ₹1 Lakh payable once in three years. Can be availed from SRTOP5 plus amount.',
        ),
        _buildSubheading('General Rules:'),
        _buildBulletPoint(
            'Eligible for two hometown and one anywhere in India visit in three-year block'),
        _buildBulletPoint('Advance intimation to Registrar required'),
        _buildBulletPoint('Can be availed during holidays and vacation only'),
        _buildBulletPoint('Claim must be submitted within one month'),
        const SizedBox(height: 20),
        _buildSectionTitle('ANNEXURE-IV: TEACHING STAFF PROMOTION POLICY'),
        _buildParagraph(
          'SRU has a well-defined promotion policy providing transparency and fairness. Key criteria include qualifications, experience, research contributions, and teaching excellence.',
        ),
        const SizedBox(height: 12),
        _buildTable(
          ['Position', 'Basic Pay', 'Minimum Qualification', 'Experience'],
          [
            [
              'Assistant Professor (Level 10/11/12)',
              '57,700 / 68,900 / 79,800',
              'Degree with at least 75% / PG with at least 55% and Ph.D. / NET (or) PG degree (M.E., M.Tech.) with at least 55%',
              'Grade 11: 3 years; Grade 12: 6 years',
            ],
            [
              'Associate Professor',
              '1,31,400',
              'Same as above',
              'Minimum 8 years teaching/research equivalent to Assistant Professor or above',
            ],
            [
              'Professor',
              '1,44,200',
              'Same as above',
              'Minimum 10 years teaching/research; at least 3 years as Associate Professor or equivalent',
            ],
            [
              'Senior Professor',
              '1,82,200',
              'Same as above',
              '10 years post PhD; 5 years as Professor',
            ],
          ],
          columnWidths: const {
            0: FlexColumnWidth(2.2),
            1: FlexColumnWidth(1.4),
            2: FlexColumnWidth(3.2),
            3: FlexColumnWidth(2.2),
          },
        ),
        _buildParagraph(
          'Note: Pre-PhD and Post PG experience is considered. Full-Time PhD experience: 2 years.',
        ),
        _buildSubheading('Positions:'),
        _buildBulletPoint('Assistant Professor (Levels 10/11/12)'),
        _buildBulletPoint('Associate Professor'),
        _buildBulletPoint('Professor'),
        _buildBulletPoint('Senior Professor'),
        const SizedBox(height: 20),
        _buildSectionTitle('ANNEXURE-V: SEXUAL HARASSMENT POLICY'),
        _buildParagraph(
          'SRU is committed to providing a safe and respectful environment. This policy aims to prevent and address any form of sexual harassment.',
        ),
        _buildSubheading('Internal Complaints Committee (ICC):'),
        _buildBulletPoint(
            'Presiding Officer: Woman faculty member at senior level'),
        _buildBulletPoint(
            'Two faculty members with experience in social work or legal knowledge'),
        _buildBulletPoint('Three students (UG, PG, research scholar levels)'),
        _buildBulletPoint('One member from NGO committed to women\'s cause'),
        _buildParagraph('At least half of ICC members shall be women.'),
        const SizedBox(height: 20),
        _buildSectionTitle('ANNEXURE-VI: GRIEVANCE REDRESSAL'),
        _buildParagraph(
          'A mechanism that enables staff to communicate concerns to management. Provides fair and transparent process for resolving staff complaints.',
        ),
        _buildSubheading('Scope:'),
        _buildBulletPoint(
            'Individual grievances regarding employment, working conditions'),
        _buildBulletPoint('Committee will meet as and when required'),
        _buildBulletPoint('Minimum three members present in meeting'),
        _buildBulletPoint(
            'Recommendations submitted to VC within three months'),
        const SizedBox(height: 20),
        _buildSectionTitle('ANNEXURE-VII: RESEARCH ETHICS POLICY'),
        _buildParagraph(
          'Sets forth ethical standards for conducting research at SR University. Applies to all researchers including faculty, scholars, students, and collaborators.',
        ),
        _buildSubheading('General Principles:'),
        _buildBulletPoint('Respect for life and dignity'),
        _buildBulletPoint('Integrity and accountability'),
        _buildBulletPoint('Transparency and openness'),
        _buildBulletPoint('Justice and equity'),
        _buildBulletPoint('Scientific and social responsibility'),
        _buildBulletPoint('Compliance with laws and institutional policies'),
        const SizedBox(height: 16),
        _buildSubheading('Key Areas:'),
        _buildBulletPoint(
            'Human Research Ethics: IHEC approval required, informed consent'),
        _buildBulletPoint(
            'Animal Research Ethics: IAEC approval, apply 3Rs principle'),
        _buildBulletPoint(
            'Chemical Ethics: Safety standards, proper handling and disposal'),
        _buildBulletPoint(
            'Biosafety and Bioethics: IBSC approval for GMOs and biological materials'),
        const SizedBox(height: 20),
        _buildSectionTitle('24. Guidelines for Daily Lecture Preparation'),
        _buildSubheading('Slide Preparation Standards:'),
        _buildBulletPoint('Update Department and School names'),
        _buildBulletPoint('Include Course Code, Title, Unit information'),
        _buildBulletPoint('Add instructor name and designation'),
        _buildBulletPoint('Use theme color RGB: 24, 78, 145'),
        _buildBulletPoint('Use Aptos (Body) font, bold, 24 pt'),
        _buildBulletPoint('Prepare 15-20 slides per lecture'),
        _buildBulletPoint('Include animations, videos, simulations'),
        _buildBulletPoint('End with recap slide and next lecture preview'),
        const SizedBox(height: 20),
        _buildSectionTitle('25. Rubrics for Course File Evaluation'),
        _buildTable(
          ['Item', 'Parameters', 'Max Marks'],
          [
            [
              'Timetable Parameters',
              'Defined format, slots as per guidelines',
              '2',
            ],
            [
              'Syllabus with Course Outcomes',
              'Defined format, adequate hours, current text/reference books',
              '2',
            ],
            [
              'List of Students',
              'Error-free list with enrollment number and name',
              '2',
            ],
            [
              'Course Plan (CO-PO Mapping)',
              'Topic-wise micro segregation, responsibilities for multi-instructor courses',
              '5',
            ],
            [
              'Mid Question Paper & Make-up Mid',
              'COs and solution, difficulty distribution, proper format',
              '5',
            ],
            [
              'Industry Talk',
              'Details and photograph',
              '2',
            ],
            [
              'Award list of Mid Exam and Analysis',
              'Complete list and analysis',
              '2',
            ],
            [
              'Startup/Case Study Discussion',
              'Discussion record and outcomes',
              '2',
            ],
            [
              'Continuous Evaluation Sheets',
              'Judicious distribution, error-free format, analysis',
              '5',
            ],
            [
              'Advanced/Slow Learners Steps',
              'Details and record',
              '5',
            ],
            [
              'Course Material',
              'Clarity and professionalism, latest pedagogy',
              '(50 * L_Credit) / Total_Credits',
            ],
            [
              'Lab Assignments/Activities',
              'Questions with solutions where possible',
              '(50 * P_Credit) / Total_Credits',
            ],
            [
              'Tutorial Assignments/Activities',
              'Questions with solutions where possible',
              '(50 * T_Credit) / Total_Credits',
            ],
            [
              'MOOCs/Certifications',
              'Relevance, latest, job-based certifications',
              '5',
            ],
            [
              'End Question Paper & End-up Mid',
              'COs and solution, difficulty distribution, proper format',
              '10',
            ],
            [
              'Final Marks and Grade Sheet',
              'AVGP and class average, timely submission',
              '5',
            ],
            [
              'Best/Innovative Practices (Digital/AI Tools)',
              'Justification and benefits accrued',
              '5',
            ],
            [
              'Result Analysis & Suggestions',
              'Course attainment and micro-level suggestions',
              '5',
            ],
          ],
          columnWidths: const {
            0: FlexColumnWidth(2.2),
            1: FlexColumnWidth(4.2),
            2: FlexColumnWidth(1.4),
          },
        ),
        const SizedBox(height: 20),
        _buildSectionTitle('26. Mid Term and End Exam Question Paper Template'),
        _buildTemplateBox(
          'SR UNIVERSITY\n'
          'SCHOOL OF __________________________\n'
          'DEPARTMENT OF ______________________\n\n'
          'Program Name: _______________________\n'
          'Exam Type: __________________________\n'
          'Academic Year: 2024-25\n\n'
          'Course Coordinator Name: ____________\n'
          'Course Code: ____________  Course Title: ____________\n'
          'Year/Sem: ____________  Regulation: ____________\n'
          'Date of Exam: ____________  Time: ____________\n'
          'Duration: 2 Hours  Max. Marks: ____________\n\n'
          'ANSWER ALL QUESTIONS\n'
          'Q. No. | Question | Marks | CO\n',
        ),
        const SizedBox(height: 20),
        _buildSectionTitle('27. Assignment Template'),
        _buildTemplateBox(
          'SR UNIVERSITY\n'
          'SCHOOL OF Engineering  DEPARTMENT OF EEE\n\n'
          'Program Name: ____________  Assignment Type: ____________\n'
          'Lab/Recitation  Academic Year: 2024-25\n\n'
          'Course Coordinator Name: ____________\n'
          'Instructor(s) Name: ____________\n'
          'Course Code: ____________  Course Title: ____________\n'
          'Year/Sem: ____________  Regulation: R20\n'
          'Date and Day of Assignment: ____________  Time(s): ____________\n'
          'Duration: ____ Hours  Applicable to Batches: ____________\n\n'
          'Assignment Number: 01 / 12\n'
          'Q. No. | Question | Expected Time to complete\n',
        ),
        const SizedBox(height: 20),
        _buildSectionTitle('28. National Education Policy (NEP) 2020 @ SRU'),
        _buildParagraph(
          'SR University is committed to implementing NEP 2020, aligning academic and administrative frameworks with the policy\'s vision.',
        ),
        _buildSubheading('Key Implementation Areas:'),
        _buildBulletPoint(
            'Multidisciplinary/Interdisciplinary Education: Offering minors across departments'),
        _buildBulletPoint(
            'Academic Bank of Credits: ABC system integration, credit transfer'),
        _buildBulletPoint(
            'Skill Development: Industry-relevant skills, experiential learning'),
        _buildBulletPoint(
            'Indian Knowledge Systems: Integration of IKS with modern methods'),
        _buildBulletPoint(
            'Outcome-based Education: Clear POs, PSOs, and COs defined'),
        _buildBulletPoint(
            'Research and Innovation: Robust research culture, R&D centers'),
        _buildBulletPoint(
            'Global Standards: International benchmarking and collaborations'),
        _buildBulletPoint(
            'Student Support: Flexible pathways, mental health services'),
        _buildBulletPoint(
            'Sustainability: Environmental stewardship and green initiatives'),
        const SizedBox(height: 20),
        _buildSectionTitle('ANNEXURE-VIII: ACADEMIC AND ADMINISTRATIVE BODIES'),
        _buildSubheading('Key Bodies:'),
        _buildBulletPoint(
            'I. Governing Body: Guides and directs university functioning'),
        _buildBulletPoint(
            'II. Board of Management: Operational backbone for academic and administrative'),
        _buildBulletPoint(
            'III. Academic Council: Academic powerhouse under VC leadership'),
        _buildBulletPoint(
            'IV. Board of Studies: Academic engine within each department'),
        _buildBulletPoint(
            'V. Finance Committee: Financial guardian of university'),
        _buildBulletPoint(
            'VI. Examination Board: Watchful guardian of academic integrity'),
        _buildBulletPoint(
            'VII. Selection/Promotion Committees: Faculty appointments'),
        _buildBulletPoint('VIII. IQAC Committee: Internal quality assurance'),
        _buildBulletPoint('IX. Admissions Committee: Student selection'),
        _buildBulletPoint('X. Fee Fixation Committee: Tuition and fees'),
        _buildBulletPoint('XI. Student Grievance Redressal: Student concerns'),
        _buildBulletPoint('XII. Staff Grievance Redressal: Staff concerns'),
        _buildBulletPoint(
            'XIII. Prevention of Sexual Harassment: Safe environment'),
        _buildBulletPoint('XIV. Anti-Ragging Committee: Ragging-free campus'),
        _buildBulletPoint('XV. Unfair Means Committee: Exam integrity'),
        _buildBulletPoint(
            'XVI. University Research Committee: Research policy'),
        _buildBulletPoint(
            'XVII. Placements Committee: Student-employer bridge'),
        _buildBulletPoint(
            'XVIII. Library Advisory Committee: Library guidance'),
        _buildBulletPoint('XIX. Proctorial Committee: Campus discipline'),
        _buildBulletPoint('XX. IT Committee: Technology planning'),
        _buildBulletPoint(
            'XXI. University Sports Committee: Sports development'),
      ],
    );
  }

  // Helper method to build highlighted text
  TextSpan _buildHighlightedTextSpan(String text, TextStyle baseStyle) {
    if (_searchQuery.isEmpty) {
      return TextSpan(text: text, style: baseStyle);
    }

    final List<TextSpan> spans = [];
    final lowerText = text.toLowerCase();
    final query = _searchQuery.toLowerCase();
    int start = 0;

    while (start < text.length) {
      final index = lowerText.indexOf(query, start);
      if (index == -1) {
        spans.add(TextSpan(
          text: text.substring(start),
          style: baseStyle,
        ));
        break;
      }

      _matchFoundInLastBuild = true;

      if (index > start) {
        spans.add(TextSpan(
          text: text.substring(start, index),
          style: baseStyle,
        ));
      }

      spans.add(TextSpan(
        text: text.substring(index, index + query.length),
        style: baseStyle.copyWith(
          backgroundColor: Colors.yellow,
          fontWeight: FontWeight.bold,
        ),
      ));

      start = index + query.length;
    }

    return TextSpan(children: spans);
  }

  // Helper widgets for formatting
  Widget _buildChapterTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16, top: 8),
      child: RichText(
        text: _buildHighlightedTextSpan(
          title,
          const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A237E),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 16),
      child: RichText(
        text: _buildHighlightedTextSpan(
          title,
          const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Color(0xFF283593),
          ),
        ),
      ),
    );
  }

  Widget _buildSubsectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 16),
      child: RichText(
        text: _buildHighlightedTextSpan(
          title,
          const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF303F9F),
          ),
        ),
      ),
    );
  }

  Widget _buildSubheading(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 12),
      child: RichText(
        text: _buildHighlightedTextSpan(
          title,
          const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF3949AB),
          ),
        ),
      ),
    );
  }

  Widget _buildParagraph(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: RichText(
        textAlign: TextAlign.justify,
        text: _buildHighlightedTextSpan(
          text,
          const TextStyle(
            fontSize: 14,
            height: 1.6,
            color: Colors.black87,
          ),
        ),
      ),
    );
  }

  Widget _buildBulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          Expanded(
            child: RichText(
              text: _buildHighlightedTextSpan(
                text,
                const TextStyle(fontSize: 14, height: 1.5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTable(
    List<String> headers,
    List<List<String>> rows, {
    Map<int, TableColumnWidth>? columnWidths,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Table(
        border: TableBorder.all(color: Colors.grey[300]!),
        columnWidths: columnWidths,
        children: [
          TableRow(
            decoration: BoxDecoration(color: Colors.grey[200]),
            children: headers
                .map((header) => _buildTableCell(
                      header,
                      const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ))
                .toList(),
          ),
          ...rows.map((row) {
            return TableRow(
              children: row
                  .map((cell) => _buildTableCell(
                        cell,
                        const TextStyle(fontSize: 13),
                      ))
                  .toList(),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildScrollableTable(
    List<String> headers,
    List<List<String>> rows,
  ) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 900),
        child: _buildTable(headers, rows),
      ),
    );
  }

  Widget _buildTableCell(String text, TextStyle style) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: RichText(
        text: _buildHighlightedTextSpan(text, style),
      ),
    );
  }

  Widget _buildTemplateBox(String content) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(top: 8, bottom: 12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(6),
      ),
      child: RichText(
        text: _buildHighlightedTextSpan(
          content,
          const TextStyle(
            fontSize: 13,
            height: 1.4,
            fontFamily: 'monospace',
          ),
        ),
      ),
    );
  }
}

class HandbookSection {
  final String id;
  final String title;
  final int order;

  HandbookSection(this.id, this.title, this.order);
}
