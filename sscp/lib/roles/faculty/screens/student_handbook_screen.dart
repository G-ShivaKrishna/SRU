import 'package:flutter/material.dart';
import '../../../widgets/app_header.dart';

class StudentHandbookScreen extends StatefulWidget {
  const StudentHandbookScreen({super.key});

  @override
  State<StudentHandbookScreen> createState() => _StudentHandbookScreenState();
}

class _StudentHandbookScreenState extends State<StudentHandbookScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String _searchQuery = '';
  bool _showTableOfContents = false;
  bool _matchFoundInLastBuild = false;
  bool _showNoMatch = false;

  final List<HandbookSection> _sections = [
    HandbookSection('cover', 'Cover Page', 0),
    HandbookSection('messages', 'Messages from Leadership', 1),
    HandbookSection('toc', 'Table of Contents', 2),
    HandbookSection('about', '1. About SR University', 3),
    HandbookSection('academic', '2. Academic Policies', 4),
    HandbookSection('conduct', '3. Student Conduct and Responsibilities', 5),
    HandbookSection('campus', '4. Campus Life and Student Services', 6),
    HandbookSection('career', '5. Career Services and Entrepreneurship', 7),
    HandbookSection('alumni', '6. Alumni Network', 8),
    HandbookSection(
        'agriculture', '7. School of Agriculture Academic Policies', 9),
    HandbookSection('phd', '8. PhD Regulations', 10),
    HandbookSection('annexure', 'Annexures', 11),
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
                                  // Implement scroll to section functionality
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
                                  'Student Handbook',
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
                                // Print/Download button
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
        _buildMessages(),
        const Divider(height: 60, thickness: 2),
        _buildTableOfContents(),
        const Divider(height: 60, thickness: 2),
        _buildAboutSection(),
        const Divider(height: 60, thickness: 2),
        _buildAcademicPolicies(),
        const Divider(height: 60, thickness: 2),
        _buildStudentConduct(),
        const Divider(height: 60, thickness: 2),
        _buildCampusLife(),
        const Divider(height: 60, thickness: 2),
        _buildCareerServices(),
        const Divider(height: 60, thickness: 2),
        _buildAlumniNetwork(),
        const Divider(height: 60, thickness: 2),
        _buildAgriculturePolicies(),
        const Divider(height: 60, thickness: 2),
        _buildPhDRegulations(),
        const Divider(height: 60, thickness: 2),
        _buildAnnexures(),
      ],
    );
  }

  Widget _buildCoverPage() {
    return Center(
      child: Column(
        children: [
          const SizedBox(height: 40),
          const Text(
            'STUDENT HANDBOOK',
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A237E),
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Applicable for students admitted into UG/PG/PhD Programs\nfrom Academic Year 2025-2026',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, height: 1.6),
          ),
          const SizedBox(height: 10),
          const Text(
            '(BBA/BCA/B.Sc./B. Tech/MBA/MCA/M.Sc./M. Tech/PhD)',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, fontStyle: FontStyle.italic),
          ),
          const SizedBox(height: 40),
          const Text(
            'June 2025',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 60),
        ],
      ),
    );
  }

  Widget _buildMessages() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Message from the Chancellor'),
        _buildParagraph(
          'Dear Students,\n\n'
          'It is with great pleasure that we welcome you to SR University. Your enthusiasm and energy bring vibrancy to our campus community. '
          'At SR University, we are reimagining education through innovative practices, aiming to create a dynamic ecosystem that nurtures holistic development.\n\n'
          'As you embark on this exciting journey, we look forward to growing, exploring, and learning together. Our university values academic excellence, '
          'diversity, and a spirit of inquiry. Here, you\'ll find a culture that encourages curiosity, critical thinking, and collaboration. You will have the '
          'opportunity to work alongside distinguished faculty on groundbreaking research and creative projects, while also gaining fresh perspectives through '
          'interaction with your talented peers.\n\n'
          'We are committed to providing a rich, inclusive learning environment where every student is empowered to reach their full potential. As you begin this '
          'transformative phase, know that we are deeply invested in your growth and success.\n\n'
          'Welcome to SRU. We wish you a fulfilling and inspiring educational experience.\n\n'
          'Warm regards,\n'
          'Varada Reddy Anagandula\n'
          'Chancellor, SR University',
        ),
        const SizedBox(height: 30),
        _buildSectionTitle('Vice-Chancellor – Prof. Deepak Garg'),
        _buildParagraph(
          'Prof. Deepak Garg holds a Ph.D. in Computer Science, with a specialization in Efficient Algorithm Design, and brings over 25 years of academic '
          'leadership and research experience. He has previously served as Professor and Dean at Thapar Institute of Engineering & Technology and Bennett University.\n\n'
          'Widely recognized as a leading voice in Artificial Intelligence in India, Prof. Garg writes a regular column titled "Breaking Shackles" in The Times of India, '
          'addressing higher education and AI trends. He has been an advisor to prestigious bodies such as AIRAWAT (Govt. of India\'s Supercomputing Mission), NAAC, NBA, UGC, and AICTE.\n\n'
          'A passionate advocate for innovation and entrepreneurship, Prof. Garg actively mentors startups and serves on advisory boards of Drishya AI, ByteXL, and Global AI Hub. '
          'He is the only CAC ABET Commissioner from India and has been a Program Evaluator (PEV) for over seven years.\n\n'
          'He has served on the Board of Governors of the IEEE Education Society (USA) and chaired several IEEE bodies in India. With over 180 research publications, 2600+ citations, '
          'and an h-index of 22, his work spans Reinforcement Learning and Generative AI. He has mentored 14 Ph.D. scholars and led prestigious collaborations with over 100 global '
          'universities and industries.\n\n'
          'Prof. Garg also served as Director of the NVIDIA-Bennett Research Center on AI and led leadingindia.ai, India\'s largest AI skilling initiative, impacting over a million students. '
          'He has delivered 350+ invited talks and keynotes across the country. His vision is to position SR University as a national benchmark for excellence in private higher education.',
        ),
      ],
    );
  }

  Widget _buildTableOfContents() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Table of Contents'),
        _buildTOCItem('1. ABOUT SR UNIVERSITY', '1'),
        _buildTOCItem('2. ACADEMIC POLICIES', '3'),
        _buildTOCSubItem(
            '2.1. Student Enrolment and Registration Process', '3'),
        _buildTOCSubItem('2.2. Institution Timings and Dress Code', '3'),
        _buildTOCSubItem(
            '2.3. SR Academic and Administration Portal (SRAAP)', '4'),
        _buildTOCSubItem('2.4. Mentoring And Academic Advising', '4'),
        _buildTOCSubItem('2.5. Batch Representative System', '7'),
        _buildTOCSubItem('2.6. Learning Management System', '7'),
        _buildTOCSubItem('2.7. Key Academic Terminology', '7'),
        _buildTOCSubItem('2.8. Program Curriculum', '8'),
        _buildTOCSubItem(
            '2.9. Curriculum Structure and Course Classification', '8'),
        _buildTOCSubItem('2.10. International Pathways and Study Options', '9'),
        _buildTOCSubItem('2.11. Honours And Minor Degree Options', '9'),
        _buildTOCSubItem('2.12. Course Registration', '10'),
        _buildTOCSubItem('2.13. Attendance And Detention Policies', '10'),
        _buildTOCSubItem('2.14. Grading System and CGPA Calculation', '11'),
        _buildTOCSubItem(
            '2.15. Examination Process and Grade Improvement Policy', '13'),
        _buildTOCSubItem(
            '2.16. Promotion Policy and Minimum Academic Requirement', '17'),
        _buildTOCSubItem('2.17. Change of Branch', '18'),
        _buildTOCSubItem('2.18. Credit Transfer', '19'),
        _buildTOCSubItem('2.19. Academic Bank of Credits', '20'),
        _buildTOCSubItem('2.20. Flexible Entry and Exit Options', '20'),
        _buildTOCSubItem('2.21. Gamification', '21'),
        _buildTOCSubItem(
            '2.22. Degree Award Requirements and Academic Honors', '26'),
        _buildTOCSubItem(
            '2.23. Open Door Policy and Feedback Mechanisms', '27'),
        _buildTOCItem('3. STUDENT CONDUCT AND RESPONSIBILITIES', '27'),
        _buildTOCSubItem('3.1. Student Code of Conduct', '27'),
        _buildTOCSubItem('3.2. Acts of Indiscipline and Misconduct', '29'),
        _buildTOCSubItem(
            '3.3. Punishment Provisions in Cases of Ragging', '32'),
        _buildTOCSubItem(
            '3.4. Prevention of Sexual Harassment in Workplace', '32'),
        _buildTOCSubItem('3.5. Student Council Formation', '33'),
        _buildTOCItem('4. CAMPUS LIFE AND STUDENT SERVICES', '35'),
        _buildTOCSubItem('4.1. Clubs', '36'),
        _buildTOCSubItem('4.2. Sports and Games', '40'),
        _buildTOCSubItem(
            '4.3. Library, IT, Wi-Fi, Stationery and Photocopy', '41'),
        _buildTOCSubItem('4.4. Lost and Found Facility', '43'),
        _buildTOCSubItem('4.5. Health and Wellness Center', '43'),
        _buildTOCSubItem('4.6. Hostels and Cafeteria', '43'),
        _buildTOCSubItem('4.7. University Social Media', '44'),
        _buildTOCItem('5. CAREER SERVICES AND ENTREPRENEURSHIP', '46'),
        _buildTOCSubItem(
            '5.1. Centre For Student Services and Placements (CSSP)', '46'),
        _buildTOCSubItem('5.2. SR Innovation Exchange (SRiX)', '46'),
        _buildTOCSubItem(
            '5.3. Nest For Entrepreneurship in Science and Technology', '47'),
        _buildTOCItem('6. ALUMNI NETWORK', '48'),
        _buildTOCSubItem('6.1. Alumni Connect', '48'),
        _buildTOCSubItem('6.2. Alumni Services and Resources', '49'),
        _buildTOCSubItem('6.3. Alumni Chapters', '49'),
        _buildTOCItem('7. SCHOOL OF AGRICULTURE ACADEMIC POLICIES', '49'),
        _buildTOCItem('8. PHD REGULATIONS', '55'),
        _buildTOCItem('Annexure -I: Research Ethics', '66'),
        _buildTOCItem('Annexure -II: IT Resource Management Policy', '80'),
        _buildTOCItem('Annexure -III: Undertaking by Student and Parent', '84'),
      ],
    );
  }

  Widget _buildAboutSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildChapterTitle('1. ABOUT SR UNIVERSITY'),
        _buildSubsectionTitle('Welcome to SR University'),
        _buildParagraph(
          'Congratulations on becoming a part of SR University!\n\n'
          'This handbook is your essential companion throughout your academic journey.',
        ),
        const SizedBox(height: 20),
        _buildParagraph(
          'SR University (SRU) is a State Private University located in Warangal, Telangana. Spread across a 170-acre verdant campus, '
          'the university is home to over 11,000 students and more than 1,200 faculty and staff, with 140+ academic programs offered across five distinct schools.',
        ),
        const SizedBox(height: 20),
        _buildSubsectionTitle('Rankings and Accreditations'),
        _buildBulletPoint(
          'NIRF Rankings: SRU is one of the youngest universities in India to achieve national recognition. It ranked 98th in Engineering in the years 2023 and 2024. '
          'In the University category, it is placed in the 101–150 rank band.',
        ),
        _buildBulletPoint(
          'NBA Accreditation: All undergraduate B.Tech programs in Computer Science Engineering (CSE), Electronics and Communication Engineering (ECE), '
          'Electrical and Electronics Engineering (EEE), Mechanical Engineering (ME), and Civil Engineering (CE) are accredited under Tier-I by the National Board of Accreditation (NBA).',
        ),
        const SizedBox(height: 20),
        _buildSubsectionTitle('Academic Schools'),
        _buildParagraph(
          'SR University offers a comprehensive range of undergraduate, postgraduate, and doctoral programs across the following five academic schools:',
        ),
        _buildBulletPoint(
            'School of Computer Science and Artificial Intelligence'),
        _buildBulletPoint('School of Engineering'),
        _buildBulletPoint('School of Business'),
        _buildBulletPoint('School of Agriculture'),
        _buildBulletPoint('School of Sciences and Humanities'),
        const SizedBox(height: 20),
        _buildSubsectionTitle('Research and Innovation Centers'),
        _buildParagraph(
          'SRU is committed to multidisciplinary research and innovation through its state-of-the-art centers:',
        ),
        _buildBulletPoint(
            'Center for Artificial Intelligence & Deep Learning (CAIDL)'),
        _buildBulletPoint('Center for Embedded Systems and IoT (CEIoT)'),
        _buildBulletPoint('Center for Materials and Manufacturing (CMM)'),
        _buildBulletPoint('Center for Emerging Energy Technologies (CEET)'),
        _buildBulletPoint(
            'Center for Construction Methods and Materials (CCMM)'),
        _buildBulletPoint('Center for Creative Cognition (CCC)'),
        _buildBulletPoint(
            'Nest for Entrepreneurship in Science and Technology (NEST)'),
        _buildBulletPoint('Collaboratory for Social Innovation (CSI)'),
        _buildBulletPoint('Center for Design (CoD)'),
        _buildBulletPoint('Center for Informetrics and Statistics (CIS)'),
        _buildBulletPoint('Center for Emerging Materials (CEM)'),
        const SizedBox(height: 20),
        _buildSubsectionTitle('Vision'),
        _buildParagraph(
          'To accelerate the transformation and advancement of the regional innovation ecosystem through academic excellence, industry relevance, and social responsibility.',
        ),
        const SizedBox(height: 20),
        _buildSubsectionTitle('Mission'),
        _buildBulletPoint(
            'Develop technically competent, industry-ready, and socially responsible leaders.'),
        _buildBulletPoint(
            'Undertake groundbreaking research and actively disseminate its outcomes.'),
        _buildBulletPoint(
            'Foster collaborations with industry, government, and non-profit organizations to serve the broader community.'),
      ],
    );
  }

  Widget _buildAcademicPolicies() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildChapterTitle('2. ACADEMIC POLICIES'),

        _buildSubsectionTitle(
            '2.1. Student Enrolment and Registration Process'),
        _buildParagraph(
          'Enrollment and registration mark the formal beginning of a student\'s academic journey at SR University. The entire process—from admission to final '
          'enrollment—is systematically structured, ensuring accuracy and transparency.',
        ),
        _buildParagraph(
            '(Refer to Flowchart 1.1 for a step-by-step overview.)'),
        const SizedBox(height: 16),

        _buildSubheading('Identification Card Policy'),
        _buildBulletPoint(
            'Each student will receive an Identification Card with their photograph, name, and other key details.'),
        _buildBulletPoint(
            'Wearing the ID card is mandatory at all times while on university premises.'),
        _buildBulletPoint(
            'Students must also wear their ID cards when representing SR University in external events.'),
        _buildBulletPoint(
            'A replacement ID card will be issued upon payment of a prescribed fine.'),

        const SizedBox(height: 20),
        _buildSubsectionTitle('2.2. Institution Timings and Dress Code'),

        _buildSubheading('Institution Timings'),
        _buildBulletPoint(
            'Timings for all UG, PG and PhD Courses: 9.00 A.M. to 5.00 P.M.'),
        _buildBulletPoint(
            'Bus Timings for Day-scholars: Arrival - 8.50 A.M. Departure - 5.05 P.M.'),

        const SizedBox(height: 16),
        _buildSubheading('Dress Code'),
        _buildParagraph(
            'Students are expected to maintain socially appropriate dress on campus.'),
        _buildBulletPoint(
            'Every Monday and Tuesday students have to wear formal dress.'),
        _buildBulletPoint(
            'During technical presentations, seminars, meetings, university functions and placement activities students must wear formal dress.'),

        const SizedBox(height: 16),
        _buildSubheading('Formal Dress Guidelines'),
        _buildParagraph('For Male Students:'),
        _buildBulletPoint('Shirt: Collared, full or half-sleeve formal shirt.'),
        _buildBulletPoint(
            'Trousers: Plain formal trousers (jeans, half pants or cargo pants are not allowed).'),
        _buildBulletPoint(
            'Footwear: Formal shoes (Chappals, Slippers and Sandals are not allowed).'),
        _buildBulletPoint(
            'Optional: Tie and blazer for presentations, seminars and placement activities.'),

        _buildParagraph('For Female Students:'),
        _buildBulletPoint('Salwar Kameez: Neat and modest with dupatta.'),
        _buildBulletPoint(
            'Kurti with Leggings/Churidar: Should be formal in design and length.'),
        _buildBulletPoint(
            'Saree/Formal Western Wear: Should be appropriate and professional.'),
        _buildBulletPoint(
            'Footwear: Closed-toe sandals or formal shoes (no slippers or flip-flops).'),

        const SizedBox(height: 20),
        _buildSubsectionTitle(
            '2.3. SR Academic and Administration Portal (SRAAP)'),
        _buildParagraph(
          'The SR Academic and Administration Portal (SRAAP) is a centralized digital platform designed to streamline academic and administrative processes for students.',
        ),
        _buildSubheading('Key Features:'),
        _buildBulletPoint('Profile Management'),
        _buildBulletPoint('Course Enrollment'),
        _buildBulletPoint('Attendance Tracking'),
        _buildBulletPoint('Academic Performance Monitoring'),
        _buildBulletPoint('Exam Fee Payments'),
        _buildBulletPoint('Gamification Modules'),
        _buildBulletPoint('Access to Academic Calendar and Regulations'),
        _buildBulletPoint('Feedback Submission for Faculty'),
        _buildBulletPoint('Grievance Redressal'),

        _buildParagraph('Support Contact: Mr. D. Kishore, sraap@sru.edu.in'),

        const SizedBox(height: 20),
        _buildSubsectionTitle('2.4. Mentoring and Academic Advising'),
        _buildParagraph(
          'SR University places high value on mentorship as a cornerstone of student success. Each student is assigned a dedicated faculty mentor at the time of enrollment.',
        ),
        _buildSubheading('Mentor Responsibilities:'),
        _buildBulletPoint('Support academic and personal development.'),
        _buildBulletPoint(
            'Maintain a dedicated WhatsApp group for real-time updates.'),
        _buildBulletPoint(
            'Guide students through challenges and growth opportunities.'),

        _buildSubheading('Mentoring Engagement Requirements:'),
        _buildBulletPoint('Minimum one face-to-face meeting per semester.'),
        _buildBulletPoint(
            'Minimum one group mentor–mentee meeting per semester.'),
        _buildBulletPoint(
            'Open-door policy: Students are encouraged to reach out to their mentors at any time for guidance.'),

        _buildSubheading('Academic Advising'),
        _buildParagraph(
            'Academic advising enhances the mentoring relationship by empowering students to make informed, strategic decisions.'),
        _buildParagraph('Advising Areas:'),
        _buildBulletPoint('Course Selection and Planning'),
        _buildBulletPoint('Goal Setting (Academic and Career)'),
        _buildBulletPoint('Performance Monitoring'),
        _buildBulletPoint(
            'Internship, Research, and Higher Education Opportunities'),

        // Continue with more sections...
        const SizedBox(height: 20),
        _buildSubsectionTitle('2.14. Grading System and CGPA Calculation'),
        _buildParagraph(
          'University follows a relative grading system to assess student performance in each course. Grades are awarded based on '
          'a student\'s performance relative to their peers, ensuring a fair evaluation process.',
        ),

        _buildSubheading('Grading System for UG (Relative Grading System)'),
        _buildGradeTable([
          ['Letter Grade', 'Performance', 'Grade Point'],
          ['A', 'Excellent', '10'],
          ['B', 'Very Good', '8'],
          ['C', 'Good', '7'],
          ['D', 'Average', '6'],
          ['R', 'Repeat due to inadequate Attendance/detained', '0'],
          ['F', 'Fail/Malpractice', '0'],
          ['I', 'Incomplete due to exam fee not paid/absence in end exam', '0'],
        ]),

        const SizedBox(height: 16),
        _buildSubheading(
            'Grading System for PG and PhD (Absolute Grading System)'),
        _buildGradeTable([
          ['Letter Grade', 'Performance', 'Marks Range', 'Grade Point'],
          ['A', 'Excellent', '90-100', '10'],
          ['B', 'Very Good', '80-89', '9'],
          ['C', 'Good', '70-79', '8'],
          ['D', 'Average', '60-69', '7'],
          ['R', 'Repeat', '-', '0'],
          ['F', 'Fail/Malpractice', '-', '0'],
          ['I', 'Incomplete', '-', '0'],
        ]),

        const SizedBox(height: 20),
        _buildSubsectionTitle('2.21. Gamification'),
        _buildParagraph(
          'The University envisions an engaging and rewarding student journey by integrating gamification into academic and extracurricular activities.',
        ),
        _buildSubheading('Types of Coins'),
        _buildBulletPoint(
            'Alpha Coins - Academic Purpose: Given to students who perform well in curricular and co-curricular activities.'),
        _buildBulletPoint(
            'Sigma Coins - Non-Academic Purpose: Given to students who perform well in extracurricular activities.'),
        _buildParagraph('**Note: 1 coin = 0.10 Rupee'),

        const SizedBox(height: 16),
        _buildSubheading('Badge Types'),
        _buildGradeTable([
          ['Badge Name', 'Associated Coin', 'Threshold Value', 'Status'],
          ['BRAVE Welcome Badge', 'ALPHA and SIGMA', '0-999', 'L0'],
          ['HUSTLER', 'Alpha Coin', '1000-1999', 'L1 Permanent'],
          ['PROGRESSIVE', 'Alpha Coin', '2000-4999', 'L2 Permanent'],
          ['BRAINIAC', 'Alpha Coin', '5000-9999', 'L3 Permanent'],
          ['PIONEER', 'Alpha Coin', '10000-24999', 'L4 Permanent'],
          ['TITAN', 'Alpha Coin', '>=25000', 'L5 Permanent'],
          ['HIGH-FLYER', 'Sigma Coin', '1000-1999', 'L1 Permanent'],
          ['ADVENTURER', 'Sigma Coin', '2000-4999', 'L2 Permanent'],
          ['MAVERICK', 'Sigma Coin', '5000-9999', 'L3 Permanent'],
          ['ELITE', 'Sigma Coin', '10000-24999', 'L4 Permanent'],
          ['CONQUEROR', 'Sigma Coin', '>=25000', 'L5 Permanent'],
          ['ACE HIGHEST', 'alpha and Sigma', '>=25000', 'L5+L5 Permanent'],
        ]),
      ],
    );
  }

  Widget _buildStudentConduct() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildChapterTitle('3. STUDENT CONDUCT AND RESPONSIBILITIES'),
        _buildSubsectionTitle('3.1. Student Code of Conduct'),
        _buildParagraph(
          'The University is committed to fostering a culture rooted in responsibility, inclusivity, and academic integrity.',
        ),
        _buildSubheading('Student Responsibilities'),
        _buildBulletPoint(
            'To produce Identity Card whenever asked by any official/staff of the university.'),
        _buildBulletPoint(
            'To foster and maintain a vibrant academic, intellectual, cultural and social atmosphere.'),
        _buildBulletPoint(
            'To respect the laws of the country, human rights and to always conduct in a responsible and dignified manner.'),
        _buildSubheading('General Campus Conduct'),
        _buildBulletPoint(
            'Respect and Inclusivity: Embrace diversity and uphold mutual respect.'),
        _buildBulletPoint(
            'Personal Appearance and Behaviour: Maintain decency in attire and uphold decorum.'),
        _buildBulletPoint(
            'Social Media Use: Posting defamatory or inappropriate content is prohibited.'),
        _buildBulletPoint(
            'SRU discourages the use of single-use plastics on campus.'),
        _buildSubheading('Academic Integrity'),
        _buildBulletPoint(
            'Original Work: All submissions must be the student\'s own.'),
        _buildBulletPoint(
            'Plagiarism: Students must properly acknowledge all external ideas, images, data, and digital content.'),
        _buildBulletPoint(
            'Cheating and Fabrication: Use of unauthorized aids or falsifying records is prohibited.'),
        _buildSubheading('Discipline and Prohibited Conduct'),
        _buildBulletPoint(
            'Substance Abuse: Zero-tolerance policy toward alcohol, drugs, tobacco.'),
        _buildBulletPoint(
            'Harassment and Discrimination: Any form of harassment is forbidden.'),
        _buildBulletPoint(
            'Possession of Weapons: Strictly prohibited on campus.'),
        _buildSubheading('Mobile Phone Policy'),
        _buildBulletPoint(
            'Permitted Use: Mobile phones must be used responsibly.'),
        _buildBulletPoint(
            'Prohibited Areas: Usage is banned in classrooms, laboratories, and examination halls.'),
        _buildBulletPoint(
            'Banned Content: Accessing or distributing offensive, pornographic, or illegal material is punishable.'),
        const SizedBox(height: 20),
        _buildSubsectionTitle(
            '3.2. Acts of Indiscipline and Misconduct – Punishment and Penalties'),
        _buildParagraph(
          'Any act of indiscipline and misconduct committed by a student inside or outside the campus shall be an act of violation of the code of conduct.',
        ),
        _buildInfoBox(
          'Examples of Misconduct:',
          [
            'Groupism of any kind that would distort harmony',
            'Possession or consumption of narcotic drugs, tobacco, alcohol',
            'Indulging in anti-institutional, anti-national activities',
            'Damaging or defacing University property',
            'Assault upon, or intimidation of faculty, staff, or students',
            'Harassment whether physical, verbal, mental, or sexual',
            'Committing forgery or tampering with University documents',
            'Misuse of Internet and social media',
            'Theft of university/Hostel property',
          ],
        ),
        const SizedBox(height: 20),
        _buildSubsectionTitle('3.3. Punishment Provisions in Cases of Ragging'),
        _buildParagraph(
          'Any student or group of students found guilty of ragging on campus or off campus shall be liable to one or more of the following punishments:',
        ),
        _buildBulletPoint(
            'Debarring from appearing in any exam or withholding results'),
        _buildBulletPoint(
            'Suspension from attending classes and academic privileges'),
        _buildBulletPoint('Withdrawing scholarships and other benefits'),
        _buildBulletPoint('Cancellation of admission'),
        _buildBulletPoint(
            'Rustication from the institution for periods varying from 1 to 4 semesters'),
        _buildBulletPoint('Expulsion from the institution'),
        _buildBulletPoint('Fine ranging between Rs. 25,000/- and Rs. 1 Lakh'),
        _buildBulletPoint(
            'Imprisonment for a term which may extend to two years or with fine which may extend to ten thousand rupees or with both'),
      ],
    );
  }

  Widget _buildCampusLife() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildChapterTitle('4. CAMPUS LIFE AND STUDENT SERVICES'),
        _buildParagraph(
          'The University is committed to holistic student development by fostering a vibrant campus life that balances academics with extracurricular activities.',
        ),
        _buildSubsectionTitle('4.1. Clubs'),
        _buildParagraph(
          'Clubs at the university provide a platform for students to develop talents, explore interests, and pursue passions. Students are encouraged to join at least one club per semester.',
        ),
        _buildSubheading('Active Clubs for 2025-26:'),
        _buildClubList([
          'Garden Club - University Level',
          'Organic Farming Club - University Level',
          'Yoga Club - University Level',
          'Master Communicators Club - University Level',
          'Painting And Sketching - University Level',
          'Community Service Center - University Level',
          'Martial Arts Club - University Level',
          'Adventure Club - University Level',
          'Cultural Club - University Level',
          'Sports Club - University Level',
          'Drama and Theatre Club - University Level',
          'Photography and Movie Making - University Level',
          'Dance and Music Club - University Level',
          'Robotics Club - MECH',
          'SAE Club - MECH',
          'Renewable Energy Club - MECH',
          'Coding Club - CS&AI',
          'Data Science Club - CS&AI',
          'Cyber Security Club - CS&AI',
          'AIML Club - CS&AI',
          'ElectrAIfy Club - EEE',
          'Byte Optimizers Club - ECE',
          'Marketing Club - Business',
          'HR Club - Business',
          'Finance Club - Business',
          'AGRIGYAN - SOA',
        ]),
        const SizedBox(height: 20),
        _buildSubsectionTitle('4.2. Sports and Games'),
        _buildParagraph(
          'SR University encourages sports and recreational activities. The vast campus provides number of fields for different sports and games.',
        ),
        _buildSubheading('Outdoor Games:'),
        _buildBulletPoint('Athletics Track and Field'),
        _buildBulletPoint('Basketball Court'),
        _buildBulletPoint('Volleyball Court'),
        _buildBulletPoint('Cricket Ground and Practice Nets'),
        _buildBulletPoint('Football Field'),
        _buildBulletPoint('Lawn Tennis Court'),
        _buildBulletPoint('Badminton Court'),
        _buildSubheading('Indoor Games:'),
        _buildBulletPoint('Table Tennis'),
        _buildBulletPoint('Carroms'),
        _buildBulletPoint('Chess'),
        _buildSubheading('Gymnasium Hall'),
        _buildParagraph(
            'Timings: 5.30 A.M. to 7.30 A.M. (morning) and 5.00 P.M. to 7.00 P.M. (evening)'),
        _buildParagraph(
            'Contact: Dr. P. Srinivas Goud, 9949279800, p.sreenivas@sru.edu.in'),
        const SizedBox(height: 20),
        _buildSubsectionTitle(
            '4.3. Library, IT, Wi-Fi, Stationery and Photocopy'),
        _buildSubheading('University Library'),
        _buildParagraph('Spread over 1000 sq.mtrs., featuring:'),
        _buildBulletPoint('Around 50,000 books'),
        _buildBulletPoint('66 Journals (54 Indian, 12 International)'),
        _buildBulletPoint('13 Magazines'),
        _buildBulletPoint('30,000 online e-journals (Full Text)'),
        _buildSubheading('Working Hours:'),
        _buildBulletPoint('Monday to Friday: 8.00 A.M. to 8.00 P.M.'),
        _buildBulletPoint('Saturday and Sunday: 10.00 A.M. to 4.00 P.M.'),
        _buildSubheading('Borrowing Privileges:'),
        _buildGradeTable([
          ['Category', 'No. of Books', 'Period of Loan'],
          ['UG students', '4', 'One month'],
          ['PG students', '6', 'One month'],
          ['Research scholars', '6', 'One month'],
        ]),
        const SizedBox(height: 20),
        _buildSubsectionTitle('4.5. Health and Wellness Center'),
        _buildParagraph(
            'The University Health Centre has two beds with a nurse and doctor available during the day.'),
        _buildParagraph('Timings: 9:00 A.M. to 5:00 P.M.'),
        _buildBulletPoint('Nurse: Ms. B. Pavani - 6300390764'),
        _buildBulletPoint('Ambulance Driver: Sai Kumar - 7989738242'),
        _buildSubheading('Counselling:'),
        _buildBulletPoint(
            'Boys: Mr. Benson - 7207362300, stu.counseling@sru.edu.in'),
        _buildBulletPoint(
            'Girls: Ms. Swapna - 7207672300, stu.counseling@sru.edu.in'),
      ],
    );
  }

  Widget _buildCareerServices() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildChapterTitle('5. CAREER SERVICES AND ENTREPRENEURSHIP'),
        _buildSubsectionTitle(
            '5.1. Center for Student Services and Placements (CSSP)'),
        _buildParagraph(
          'The CSSP at University plays a pivotal role in shaping students\' professional journeys.',
        ),
        _buildSubheading('Key Services of CSSP:'),
        _buildBulletPoint('Placement Training'),
        _buildBulletPoint('Skill Development Courses'),
        _buildBulletPoint('Internship Opportunities'),
        _buildBulletPoint('Portfolio Development'),
        _buildParagraph(
            'Contact: Mr. Sunil Reddy - 96765 61828 or Mr. D. Sridhar - 9000966994'),
        _buildParagraph('Email: stu.cssp@sru.edu.in'),
        const SizedBox(height: 20),
        _buildSubsectionTitle('5.2. SR Innovation Exchange (SRiX)'),
        _buildParagraph(
          'SRiX is a DST sponsored Technology Business Incubator bringing entrepreneurs, mentors, researchers, and academicians together.',
        ),
        _buildSubheading('Support Provided:'),
        _buildBulletPoint('Idea Valuation/Validation'),
        _buildBulletPoint('End-to-end product development support'),
        _buildBulletPoint('Incubation and Acceleration Support'),
        _buildBulletPoint('Mentoring Support'),
        _buildBulletPoint(
            'Legal Support: IP, Patenting, Regulatory Compliance'),
        _buildBulletPoint(
            'Funding Support: Seed capital, Grants, Angel Investors, VCs'),
        _buildParagraph(
            'Contact: Ch. Prashanth - 9177822489, ch.prashanth@sru.edu.in'),
        const SizedBox(height: 20),
        _buildSubsectionTitle(
            '5.3. Nest for Entrepreneurship in Science and Technology'),
        _buildParagraph(
          'NEST serves as a vital component of the startup ecosystem, offering an incubation platform for aspiring student and faculty entrepreneurs.',
        ),
        _buildSubheading('NEST Provides:'),
        _buildBulletPoint('Infrastructure and mentoring support'),
        _buildBulletPoint('Business and Market strategies awareness'),
        _buildBulletPoint('IP and Legal advisory services'),
        _buildBulletPoint('Seed funding for Innovation and startups'),
        _buildBulletPoint('Networking with VCs/Angel investors'),
        _buildParagraph('Contact:'),
        _buildBulletPoint(
            'Dr. B. Girirajan - 8525002366, girirajan.b@sru.edu.in'),
        _buildBulletPoint(
            'Dr. A. Chakradhar - 9908246759, chakradhar.a@sru.edu.in'),
      ],
    );
  }

  Widget _buildAlumniNetwork() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildChapterTitle('6. ALUMNI NETWORK'),
        _buildSubsectionTitle('6.1. Alumni Connect'),
        _buildParagraph(
          'Alumni Affairs at SR University acts as the essential bridge between the institution and its graduates, nurturing a lifelong connection well beyond graduation.',
        ),
        _buildParagraph(
            'Portal Registration Link: https://alumni.sru.edu.in/user/signup.dz'),
        _buildSubheading('Alumni are encouraged to:'),
        _buildBulletPoint('Participate in reunions and networking events'),
        _buildBulletPoint(
            'Leverage career services and mentoring opportunities'),
        _buildBulletPoint('Contribute towards institutional growth'),
        const SizedBox(height: 20),
        _buildSubsectionTitle('6.2. Alumni Services and Resources'),
        _buildParagraph(
            'As a valued member of our alumni community, you have access to:'),
        _buildBulletPoint('Job Postings and Career Counselling'),
        _buildBulletPoint('Alumni Events and Online Networking Platforms'),
        _buildBulletPoint('Library Access and Continued Education Support'),
        _buildBulletPoint('Mentorship Programs'),
        _buildBulletPoint('Local and Regional Chapters'),
        const SizedBox(height: 20),
        _buildSubsectionTitle('6.3. Alumni Chapters'),
        _buildBulletPoint('Hyderabad Alumni Chapter – Established in 2024'),
        _buildBulletPoint('Warangal Alumni Chapter – Established in 2024'),
        _buildBulletPoint('Bengaluru Alumni Chapter – Launch in progress'),
        _buildBulletPoint('USA Alumni Chapter – Formation underway'),
      ],
    );
  }

  Widget _buildAgriculturePolicies() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildChapterTitle('7. SCHOOL OF AGRICULTURE ACADEMIC POLICIES'),
        _buildSubsectionTitle('7.1. Attendance and Examination Policies'),
        _buildParagraph(
          'The minimum attendance in a prescribed course is 75%. The attendance shall be reckoned for theory and practical separately.',
        ),
        _buildBulletPoint(
            'Minimum attendance can be relaxed up to 10% on medical grounds (i.e., up to 65%)'),
        _buildBulletPoint(
            'As per ICAR recommendations, 85% attendance is required for student READY programmes'),
        _buildSubheading('Mid-semester Examinations'),
        _buildBulletPoint('Duration: One and half hours'),
        _buildBulletPoint('Marks allotted: 50'),
        _buildBulletPoint('Conducted after 50% of working days in a semester'),
        _buildSubheading('Semester Final Examinations'),
        _buildBulletPoint('Duration: Two and half hours'),
        _buildBulletPoint('Marks allotted: 100'),
        _buildBulletPoint('Common spot valuation system for answer scripts'),
        const SizedBox(height: 20),
        _buildSubsectionTitle('7.2. Promotion Policy'),
        _buildBulletPoint(
            'Promotion to second year: Automatic promotion irrespective of backlogs'),
        _buildBulletPoint(
            'Promotion to third year: Must have passed all first-year courses'),
        _buildBulletPoint(
            'Promotion to fourth year: Must have passed all second-year courses'),
        const SizedBox(height: 20),
        _buildSubsectionTitle('7.3. Multiple Entry and Exit'),
        _buildParagraph('Exit Options:'),
        _buildBulletPoint(
            'After 1st year: UG Certificate (completion of 10 weeks internship required)'),
        _buildBulletPoint(
            'After 2nd year: UG Diploma (completion of 10 weeks internship required)'),
        _buildBulletPoint('After 4 years: B.Sc. (Hons.) Agriculture Degree'),
      ],
    );
  }

  Widget _buildPhDRegulations() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildChapterTitle('8. PHD REGULATIONS'),
        _buildSubsectionTitle('Introduction'),
        _buildParagraph(
          'The PhD Regulations will govern the conditions for admission, registration, coursework, conduct of examinations and evaluation of scholars\' '
          'performance leading to the award of PhD Degree. Effective for batches admitted from 2024-25 onwards.',
        ),
        _buildSubheading('Category of PhD Scholars:'),
        _buildBulletPoint(
            'Full-time Scholar: All scholars who pursue full-time research in SRU'),
        _buildBulletPoint(
            'Part-time Scholar: Working professionals or non-working candidates pursuing PhD while continuing their jobs'),
        const SizedBox(height: 20),
        _buildSubsectionTitle('8.1. PhD Assistantship'),
        _buildBulletPoint(
            'Full-time scholars are eligible to receive Rs. 40,000 per month'),
        _buildBulletPoint(
            'Scholars choosing hostel facility: Rs. 25,000 per month + accommodation + meals + laundry'),
        _buildBulletPoint('Valid for 3 years from admission registration'),
        _buildBulletPoint(
            'First 3 months\' assistantship kept as security deposit'),
        const SizedBox(height: 20),
        _buildSubsectionTitle('8.2. Eligibility Criteria'),
        _buildParagraph(
            'Candidates eligible to seek admission to PhD program:'),
        _buildBulletPoint(
            'Master\'s degree with at least 55% marks or equivalent grade'),
        _buildBulletPoint('4-year bachelor\'s degree with minimum 75% marks'),
        _buildBulletPoint('M.Phil. with at least 55% marks'),
        _buildBulletPoint(
            '5% relaxation for SC/ST/OBC/Differently abled/EWS candidates'),
        const SizedBox(height: 20),
        _buildSubsectionTitle('8.6. Course Work'),
        _buildBulletPoint('Minimum 12 credits required'),
        _buildBulletPoint('Includes Research Methodology course of 4 credits'),
        _buildBulletPoint(
            'Scholars after B.Tech require additional 12 credits'),
        _buildBulletPoint(
            'Minimum 60% marks in each course and 8.0 CGPA overall required'),
        _buildBulletPoint(
            'Maximum duration: 2 semesters (can be extended to 2 years)'),
        const SizedBox(height: 20),
        _buildSubsectionTitle('8.7. Comprehensive Examination'),
        _buildBulletPoint(
            'Oral examination conducted after course work completion'),
        _buildBulletPoint(
            'Panel includes SRC members and two experts from SRU'),
        _buildBulletPoint(
            'One re-attempt allowed within 45 days if performance unsatisfactory'),
        _buildBulletPoint(
            'Registration cancelled if second attempt also fails'),
        const SizedBox(height: 20),
        _buildSubsectionTitle('8.9. Synopsis'),
        _buildParagraph('Scholar eligible to submit synopsis when:'),
        _buildBulletPoint(
            'All objectives aligned with approved plan are completed'),
        _buildBulletPoint('70% of thesis is written'),
        _buildBulletPoint('8-point Publication Criteria is met'),
        _buildSubheading('Publication Criteria (8 points):'),
        _buildGradeTable([
          ['Publication Type', 'Credits'],
          ['SCIE/SSCI Q1, ABDC A* subscription-based', '8'],
          ['SCIE/SSCI Q1, ABDC A* Open Access/hybrid', '4'],
          ['SCIE/SSCI (Q2-Q4), ABDC A subscription', '4'],
          ['SCIE/SSCI (Q2-Q4) Open Access/hybrid', '2'],
          ['Scopus Journal', '1'],
          ['Scopus Book Chapter (first two)', '1'],
          ['Patent Published (first two)', '1'],
          ['Patent Granted', '4'],
          ['Scopus Conference (first 4)', '1'],
        ]),
        const SizedBox(height: 20),
        _buildSubsectionTitle('8.10. Thesis Submission Policy'),
        _buildBulletPoint('Eligible after completing synopsis successfully'),
        _buildBulletPoint('Required research publications must be published'),
        _buildBulletPoint(
            'All fees paid in full including thesis and viva fee'),
        _buildBulletPoint(
            'Minimum 2.5 years, maximum: 6-8 years (with extensions)'),
        _buildBulletPoint(
            'Female scholars and persons with disabilities: up to 10 years'),
      ],
    );
  }

  Widget _buildAnnexures() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildChapterTitle('ANNEXURES'),
        _buildSubsectionTitle('ANNEXURE-I: RESEARCH ETHICS'),
        _buildParagraph(
          'SRU\'s Research Ethics Policy mandates trustworthiness and transparency in all research findings. All campuses utilize premium '
          'anti-plagiarism software, Turnitin/iThenticate.',
        ),
        _buildSubheading('Plagiarism Policy'),
        _buildParagraph(
          'Plagiarism is "to offer work or ideas from another source as one\'s own, with or without authorization of the source author(s), '
          'directly by verbatim copying or by usage of any AI software."',
        ),
        _buildSubheading('Forms of Plagiarism:'),
        _buildBulletPoint(
            'Verbatim: Not using quotation marks or proper citation'),
        _buildBulletPoint(
            'Cut and paste: Copying content from internet without references'),
        _buildBulletPoint(
            'Paraphrasing: Replicating someone\'s work by changing few words'),
        _buildBulletPoint('Collusion: Working together without permission'),
        _buildBulletPoint('Inaccurate citation: Not following standard format'),
        _buildBulletPoint(
            'Auto-plagiarism: Submitting same work multiple times'),
        _buildSubheading('Plagiarism Levels and Penalties:'),
        _buildBulletPoint(
            'Level 0: Up to 10% similarity - No penalty (single source <1%)'),
        _buildBulletPoint(
            'Level 1: 10-20% similarity - Revise and resubmit within 30 days'),
        _buildBulletPoint(
            'Level 2: Above 20% - Barred for one year, may forfeit registration'),
        const SizedBox(height: 20),
        _buildSubsectionTitle('ANNEXURE-II: IT RESOURCE MANAGEMENT POLICY'),
        _buildParagraph(
          'The University acknowledges the crucial significance of information technology in fulfilling objectives and carrying out administrative tasks.',
        ),
        _buildSubheading('Key Policies:'),
        _buildBulletPoint(
            'Software Installation and Licensing: No pirated software allowed'),
        _buildBulletPoint(
            'Network and Internet Use: Authorized access only, proper IP allocation'),
        _buildBulletPoint(
            'Email Account Use: For academic and official purposes only'),
        _buildBulletPoint(
            'Open-source and Free Software: Encouraged for IT operations'),
        const SizedBox(height: 20),
        _buildSubsectionTitle(
            'ANNEXURE-III: UNDERTAKING BY STUDENT AND PARENT'),
        _buildParagraph(
          'All students and parents must read and sign an undertaking acknowledging:',
        ),
        _buildBulletPoint('Academic Commitments & Responsibilities'),
        _buildBulletPoint('Disciplinary Matters and Anti-Ragging'),
        _buildBulletPoint('Documentation and Financial Responsibilities'),
        _buildBulletPoint('Publication and Research Ethics'),
        _buildBulletPoint('Hostel Rules (if applicable)'),
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
        // No more matches, add remaining text
        spans.add(TextSpan(
          text: text.substring(start),
          style: baseStyle,
        ));
        break;
      }

      // Add text before match
      if (index > start) {
        spans.add(TextSpan(
          text: text.substring(start, index),
          style: baseStyle,
        ));
      }

      // Add highlighted match
      spans.add(TextSpan(
        text: text.substring(index, index + query.length),
        style: baseStyle.copyWith(
          backgroundColor: Colors.yellow,
          fontWeight: FontWeight.bold,
        ),
      ));

      _matchFoundInLastBuild = true;

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

  Widget _buildTOCItem(String title, String page) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: RichText(
              text: _buildHighlightedTextSpan(
                title,
                const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
            ),
          ),
          Text(
            page,
            style: const TextStyle(fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildTOCSubItem(String title, String page) {
    return Padding(
      padding: const EdgeInsets.only(left: 20, top: 2, bottom: 2),
      child: Row(
        children: [
          Expanded(
            child: RichText(
              text: _buildHighlightedTextSpan(
                title,
                const TextStyle(fontSize: 13),
              ),
            ),
          ),
          Text(
            page,
            style: const TextStyle(fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildGradeTable(List<List<String>> data) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Table(
        border: TableBorder.all(color: Colors.grey[300]!),
        columnWidths: const {
          0: FlexColumnWidth(2),
          1: FlexColumnWidth(2),
          2: FlexColumnWidth(1.5),
        },
        children: data.asMap().entries.map((entry) {
          final isHeader = entry.key == 0;
          return TableRow(
            decoration: BoxDecoration(
              color: isHeader ? Colors.grey[200] : Colors.white,
            ),
            children: entry.value.map((cell) {
              return Padding(
                padding: const EdgeInsets.all(8),
                child: RichText(
                  text: _buildHighlightedTextSpan(
                    cell,
                    TextStyle(
                      fontSize: 13,
                      fontWeight:
                          isHeader ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              );
            }).toList(),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildClubList(List<String> clubs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: clubs.map((club) => _buildBulletPoint(club)).toList(),
    );
  }

  Widget _buildInfoBox(String title, List<String> items) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        border: Border.all(color: Colors.blue[200]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            text: _buildHighlightedTextSpan(
              title,
              const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1565C0),
              ),
            ),
          ),
          const SizedBox(height: 8),
          ...items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 4, left: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('• ',
                        style: TextStyle(color: Color(0xFF1565C0))),
                    Expanded(
                      child: RichText(
                        text: _buildHighlightedTextSpan(
                          item,
                          const TextStyle(fontSize: 13),
                        ),
                      ),
                    ),
                  ],
                ),
              )),
        ],
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
