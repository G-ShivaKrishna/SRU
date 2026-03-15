import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class HallticketManagementPage extends StatefulWidget {
  const HallticketManagementPage({super.key});

  @override
  State<HallticketManagementPage> createState() =>
      _HallticketManagementPageState();
}

class _HallticketManagementPageState extends State<HallticketManagementPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<Map<String, String>> _allSubjects = [];
  List<Map<String, String>> _filteredSubjects = [];
  List<String> _branches = [];
  String? _selectedBranch;
  final Map<String, DateTime?> _subjectDates = {};
  final Map<String, TimeOfDay?> _subjectTimes = {};
  final Set<String> _savingSubjectIds = <String>{};
  final Map<String, Map<String, dynamic>> _draftScheduleBySubjectId = {};

  bool _isLoadingBranches = true;
  bool _isLoadingSubjects = true;
  bool _isSaving = false;
  bool _isReleasing = false;

  @override
  void initState() {
    super.initState();
    _loadBranches();
  }

  Future<void> _loadBranches() async {
    setState(() => _isLoadingBranches = true);

    try {
      final branches = <String>{};

      final studentSnapshot = await _firestore.collection('students').get();
      for (final doc in studentSnapshot.docs) {
        final data = doc.data();
        final branch =
            (data['branch'] ?? data['department'] ?? data['dept'] ?? '')
                .toString()
                .trim()
                .toUpperCase();
        if (branch.isNotEmpty) {
          branches.add(branch);
        }
      }

      if (branches.isEmpty) {
        final subjectSnapshot = await _firestore.collection('subjects').get();
        for (final doc in subjectSnapshot.docs) {
          final data = doc.data();
          final branch =
              (data['branch'] ?? data['department'] ?? data['dept'] ?? '')
                  .toString()
                  .trim()
                  .toUpperCase();
          if (branch.isNotEmpty) {
            branches.add(branch);
          }
        }
      }

      final sortedBranches = branches.toList()..sort();

      if (!mounted) return;
      setState(() {
        _branches = sortedBranches;
        _selectedBranch =
            sortedBranches.isNotEmpty ? sortedBranches.first : null;
        _isLoadingBranches = false;
      });

      await _loadSubjects();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _branches = [];
        _selectedBranch = null;
        _isLoadingBranches = false;
      });

      await _loadSubjects();
    }
  }

  Future<void> _loadSubjects() async {
    setState(() {
      _isLoadingSubjects = true;
      _allSubjects = [];
      _filteredSubjects = [];
      _subjectDates.clear();
      _subjectTimes.clear();
      _draftScheduleBySubjectId.clear();
    });

    try {
      final snapshot = await _firestore.collection('subjects').get();
      final subjects = <Map<String, String>>[];

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final name =
            (data['name'] ?? data['subjectName'] ?? '').toString().trim();
        final code =
            (data['code'] ?? data['subjectCode'] ?? '').toString().trim();
        final branch =
            (data['department'] ?? data['branch'] ?? data['dept'] ?? '')
                .toString()
                .trim()
                .toUpperCase();

        if (name.isEmpty || branch.isEmpty) {
          continue;
        }

        subjects.add({
          'id': doc.id,
          'name': name,
          'code': code,
          'branch': branch,
          'label': code.isEmpty ? name : '$code - $name',
        });
      }

      if (!mounted) return;
      setState(() {
        _allSubjects = subjects;
      });
      _filterSubjectsForBranch();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _allSubjects = [];
        _filteredSubjects = [];
        _subjectDates.clear();
        _subjectTimes.clear();
        _draftScheduleBySubjectId.clear();
        _isLoadingSubjects = false;
      });
    }
  }

  Future<void> _filterSubjectsForBranch() async {
    final selectedBranch = (_selectedBranch ?? '').toUpperCase();
    final filtered = _allSubjects.where((subject) {
      final subjectBranch = (subject['branch'] ?? '').toUpperCase();
      return selectedBranch.isNotEmpty && subjectBranch == selectedBranch;
    }).toList()
      ..sort((a, b) => (a['label'] ?? '')
          .toLowerCase()
          .compareTo((b['label'] ?? '').toLowerCase()));

    setState(() {
      _filteredSubjects = filtered;
      _subjectDates.clear();
      _subjectTimes.clear();
      _draftScheduleBySubjectId.clear();
      _isLoadingSubjects = false;
    });

    await _loadDraftSchedulesForBranch();
  }

  Future<void> _pickDateForSubject(String subjectId) async {
    final now = DateTime.now();
    final current = _subjectDates[subjectId];
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? now,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365 * 3)),
    );

    if (picked != null) {
      setState(() => _subjectDates[subjectId] = picked);
      await _maybeAutoSaveSubject(subjectId);
    }
  }

  Future<void> _pickTimeForSubject(String subjectId) async {
    final current = _subjectTimes[subjectId];
    final picked = await showTimePicker(
      context: context,
      initialTime: current ?? TimeOfDay.now(),
    );

    if (picked != null) {
      setState(() => _subjectTimes[subjectId] = picked);
      await _maybeAutoSaveSubject(subjectId);
    }
  }

  Map<String, String>? _subjectById(String subjectId) {
    for (final subject in _filteredSubjects) {
      if ((subject['id'] ?? '') == subjectId) return subject;
    }
    return null;
  }

  Future<void> _maybeAutoSaveSubject(String subjectId) async {
    if (_savingSubjectIds.contains(subjectId)) return;

    final subject = _subjectById(subjectId);
    if (subject == null) return;

    final date = _effectiveDateForSubject(subjectId);
    final time = _effectiveTimeForSubject(subjectId);
    if (date == null || time == null) return;

    await _createHallticketScheduleForSubject(subject,
        showSuccessMessage: false);
  }

  Future<void> _loadDraftSchedulesForBranch() async {
    if (_selectedBranch == null || _selectedBranch!.isEmpty) return;

    final branch = _selectedBranch!;
    try {
      final snapshot = await _firestore
          .collection('hallticketSchedules')
          .where('branch', isEqualTo: branch)
          .get();

      final draftDocs = snapshot.docs.where((doc) {
        final data = doc.data();
        return (data['releaseStatus'] ?? 'draft').toString() == 'draft';
      }).toList();

      final bySubject = <String, Map<String, dynamic>>{};
      for (final doc in draftDocs) {
        final data = doc.data();
        final subjectId = (data['subjectId'] ?? '').toString();
        if (subjectId.isNotEmpty) {
          bySubject[subjectId] = {
            ...data,
            'docId': doc.id,
          };
        }
      }

      if (!mounted) return;
      setState(() {
        _draftScheduleBySubjectId
          ..clear()
          ..addAll(bySubject);
      });
    } catch (_) {
      // ignore and continue with local row scheduling
    }
  }

  DateTime? _effectiveDateForSubject(String subjectId) {
    final localDate = _subjectDates[subjectId];
    if (localDate != null) return localDate;

    final draft = _draftScheduleBySubjectId[subjectId];
    final ts = draft?['examDateTime'] as Timestamp?;
    return ts?.toDate();
  }

  TimeOfDay? _effectiveTimeForSubject(String subjectId) {
    final localTime = _subjectTimes[subjectId];
    if (localTime != null) return localTime;

    final draft = _draftScheduleBySubjectId[subjectId];
    final ts = draft?['examDateTime'] as Timestamp?;
    final dt = ts?.toDate();
    if (dt == null) return null;
    return TimeOfDay(hour: dt.hour, minute: dt.minute);
  }

  Future<void> _createHallticketScheduleForSubject(
    Map<String, String> subject, {
    bool showSuccessMessage = true,
  }) async {
    if (_selectedBranch == null || _selectedBranch!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a branch')),
      );
      return;
    }

    final subjectId = subject['id'] ?? '';
    final selectedDate = _effectiveDateForSubject(subjectId);
    final selectedTime = _effectiveTimeForSubject(subjectId);

    if (subjectId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid subject')),
      );
      return;
    }

    if (selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select exam date')),
      );
      return;
    }

    if (selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select exam time')),
      );
      return;
    }

    final selectedSubjectName = subject['name'] ?? '';
    final selectedSubjectCode = subject['code'] ?? '';

    if (selectedSubjectName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selected subject is invalid')),
      );
      return;
    }

    final combinedDateTime = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
      selectedTime.hour,
      selectedTime.minute,
    );
    final selectedExamDate = DateFormat('yyyy-MM-dd').format(selectedDate);

    final createdBy = FirebaseAuth.instance.currentUser?.email ?? 'admin';

    setState(() {
      _isSaving = true;
      _savingSubjectIds.add(subjectId);
    });

    try {
      final branchSchedules = await _firestore
          .collection('hallticketSchedules')
          .where('branch', isEqualTo: _selectedBranch)
          .get();

      final draftSchedules = branchSchedules.docs.where((doc) {
        final data = doc.data();
        return (data['releaseStatus'] ?? 'draft').toString() == 'draft';
      }).toList();

      final existingForSubject = draftSchedules.where((doc) {
        return (doc.data()['subjectId'] ?? '').toString() == subjectId;
      }).toList();

      final sameDayCount = draftSchedules.where((doc) {
        final data = doc.data();
        final isSameDay =
            (data['examDate'] ?? '').toString() == selectedExamDate;
        final isSameSubject = (data['subjectId'] ?? '').toString() == subjectId;
        return isSameDay && !isSameSubject;
      }).length;

      if (sameDayCount >= 1) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Only one exam is allowed per day'),
          ),
        );
        return;
      }

      final payload = {
        'branch': _selectedBranch,
        'course': _selectedBranch,
        'subjectId': subjectId,
        'subjectName': selectedSubjectName,
        'subjectCode': selectedSubjectCode,
        'examDate': selectedExamDate,
        'examTime': selectedTime.format(context),
        'examDateTime': Timestamp.fromDate(combinedDateTime),
        'entryType': 'subject_schedule',
        'isIndividualHallticket': false,
        'isActive': true,
        'releaseStatus': 'draft',
        'createdBy': createdBy,
      };

      if (existingForSubject.isNotEmpty) {
        await _firestore
            .collection('hallticketSchedules')
            .doc(existingForSubject.first.id)
            .update({
          ...payload,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        await _firestore.collection('hallticketSchedules').add({
          ...payload,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      if (!mounted) return;

      if (showSuccessMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Subject schedule saved. Combined hallticket will be generated only on release.')),
        );
      }

      setState(() {
        _subjectDates[subjectId] = selectedDate;
        _subjectTimes[subjectId] = selectedTime;
      });
      await _loadDraftSchedulesForBranch();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create hallticket schedule: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _savingSubjectIds.remove(subjectId);
        });
      }
    }
  }

  Future<void> _releaseHallticket() async {
    if (_selectedBranch == null || _selectedBranch!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a branch')),
      );
      return;
    }

    setState(() => _isReleasing = true);

    try {
      final branch = _selectedBranch!;
      final branchSubjects = _allSubjects
          .where((s) => (s['branch'] ?? '').toUpperCase() == branch)
          .toList();

      final schedulesSnapshot = await _firestore
          .collection('hallticketSchedules')
          .where('branch', isEqualTo: branch)
          .get();

      final draftDocs = schedulesSnapshot.docs.where((doc) {
        final data = doc.data();
        return (data['releaseStatus'] ?? 'draft').toString() == 'draft';
      }).toList();

      if (branchSubjects.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No backend subjects found for selected branch'),
          ),
        );
        return;
      }

      if (draftDocs.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('Schedule all subjects first, then release hallticket'),
          ),
        );
        return;
      }

      final scheduledSubjectIds = draftDocs
          .map((doc) => (doc.data()['subjectId'] ?? '').toString())
          .where((id) => id.isNotEmpty)
          .toSet();
      final branchSubjectIds =
          branchSubjects.map((s) => (s['id'] ?? '').toString()).toSet();

      if (scheduledSubjectIds.length != branchSubjectIds.length ||
          !branchSubjectIds.difference(scheduledSubjectIds).isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Please schedule all branch subjects before release (${scheduledSubjectIds.length}/${branchSubjectIds.length})',
            ),
          ),
        );
        return;
      }

      final perDayCount = <String, int>{};
      for (final doc in draftDocs) {
        final date = (doc.data()['examDate'] ?? '').toString();
        if (date.isEmpty) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Every subject must have a valid date and time'),
            ),
          );
          return;
        }
        perDayCount[date] = (perDayCount[date] ?? 0) + 1;
      }

      final exceedsOnePerDay = perDayCount.entries.any((e) => e.value > 1);
      if (exceedsOnePerDay) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Release blocked: only one exam allowed per day'),
          ),
        );
        return;
      }

      final scheduleEntries = draftDocs.map((doc) {
        final d = doc.data();
        final ts = d['examDateTime'] as Timestamp?;
        return {
          'scheduleId': doc.id,
          'course': (d['course'] ?? d['branch'] ?? '').toString(),
          'subjectId': (d['subjectId'] ?? '').toString(),
          'subjectName': (d['subjectName'] ?? '').toString(),
          'subjectCode': (d['subjectCode'] ?? '').toString(),
          'examDate': (d['examDate'] ?? '').toString(),
          'examTime': (d['examTime'] ?? '').toString(),
          'examDateTime': ts,
        };
      }).toList()
        ..sort((a, b) {
          final aTs = a['examDateTime'] as Timestamp?;
          final bTs = b['examDateTime'] as Timestamp?;
          if (aTs == null && bTs == null) return 0;
          if (aTs == null) return 1;
          if (bTs == null) return -1;
          return aTs.toDate().compareTo(bTs.toDate());
        });

      final releasedBy = FirebaseAuth.instance.currentUser?.email ?? 'admin';
      final releaseRef = await _firestore.collection('hallticketReleases').add({
        'branch': branch,
        'hallticketType': 'combined_branch',
        'isIndividualHallticket': false,
        'subjectCount': scheduleEntries.length,
        'schedules': scheduleEntries,
        'releasedBy': releasedBy,
        'releasedAt': FieldValue.serverTimestamp(),
        'status': 'released',
      });

      final batch = _firestore.batch();
      for (final doc in draftDocs) {
        batch.update(
          _firestore.collection('hallticketSchedules').doc(doc.id),
          {
            'releaseStatus': 'released',
            'hallticketReleaseId': releaseRef.id,
            'releasedBy': releasedBy,
            'releasedAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          },
        );
      }
      await batch.commit();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Combined hallticket released successfully for branch'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to release hallticket: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isReleasing = false);
      }
    }
  }

  Future<void> _toggleSchedule(String docId, bool currentValue) async {
    await _firestore.collection('hallticketSchedules').doc(docId).update({
      'isActive': !currentValue,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _deleteSchedule(String docId) async {
    await _firestore.collection('hallticketSchedules').doc(docId).delete();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 700;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hallticket Management'),
        backgroundColor: const Color(0xFF1e3a5f),
        foregroundColor: Colors.white,
      ),
      body: (_isLoadingBranches || _isLoadingSubjects)
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(isMobile ? 12 : 16),
              child: Column(
                children: [
                  _buildCreateCard(isMobile),
                  const SizedBox(height: 16),
                  _buildSchedulesList(),
                ],
              ),
            ),
    );
  }

  Widget _buildCreateCard(bool isMobile) {
    if (_branches.isEmpty) {
      return Card(
        elevation: 2,
        child: Padding(
          padding: EdgeInsets.all(isMobile ? 12 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Create Hallticket Schedule',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1e3a5f),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'No branches found in backend data. Please add branch/department values in students or subjects collections.',
                style: TextStyle(color: Colors.redAccent),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _loadBranches,
                icon: const Icon(Icons.refresh),
                label: const Text('Reload Branches'),
              ),
            ],
          ),
        ),
      );
    }

    if (_filteredSubjects.isEmpty) {
      return Card(
        elevation: 2,
        child: Padding(
          padding: EdgeInsets.all(isMobile ? 12 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Create Hallticket Schedule',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1e3a5f),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'No subjects found for branch ${_selectedBranch ?? ''}. Please add subjects in backend.',
                style: const TextStyle(color: Colors.redAccent),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _loadSubjects,
                icon: const Icon(Icons.refresh),
                label: const Text('Reload Subjects'),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 12 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Create Hallticket Schedule',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1e3a5f),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _selectedBranch,
              decoration: const InputDecoration(
                labelText: 'Select Branch',
                border: OutlineInputBorder(),
              ),
              items: _branches
                  .map((branch) => DropdownMenuItem<String>(
                        value: branch,
                        child: Text(branch),
                      ))
                  .toList(),
              onChanged: (value) {
                setState(() => _selectedBranch = value);
                _filterSubjectsForBranch();
              },
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Subjects auto-fetched for ${_selectedBranch ?? ''} (${_filteredSubjects.length}). Date + time are autosaved.',
                style: const TextStyle(
                  color: Color(0xFF1e3a5f),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 10),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _filteredSubjects.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final subject = _filteredSubjects[index];
                final subjectId = subject['id'] ?? '';
                final label = subject['label'] ?? '';
                final effectiveDate = _effectiveDateForSubject(subjectId);
                final effectiveTime = _effectiveTimeForSubject(subjectId);
                final dateText = effectiveDate == null
                    ? 'Date'
                    : DateFormat('dd MMM yyyy').format(effectiveDate);
                final timeText = effectiveTime == null
                    ? 'Time'
                    : effectiveTime.format(context);
                final isSavingRow = _savingSubjectIds.contains(subjectId);

                return Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1e3a5f),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => _pickDateForSubject(subjectId),
                              child: Text(dateText),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => _pickTimeForSubject(subjectId),
                              child: Text(timeText),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: isSavingRow
                                  ? Colors.orange.withOpacity(0.15)
                                  : Colors.green.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: isSavingRow
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(
                                    Icons.cloud_done,
                                    size: 18,
                                    color: Colors.green,
                                  ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed:
                    (_isSaving || _isReleasing) ? null : _releaseHallticket,
                icon: _isReleasing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.publish),
                label: Text(
                  _isReleasing
                      ? 'Releasing...'
                      : 'Generate & Release Combined Hallticket',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSchedulesList() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _firestore
          .collection('hallticketSchedules')
          .orderBy('examDateTime', descending: false)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return const Center(
            child: Text('Failed to load hallticket schedules'),
          );
        }

        final selectedBranch = (_selectedBranch ?? '').toUpperCase();
        final allDocs = snapshot.data?.docs ?? [];
        final docs = allDocs.where((doc) {
          if (selectedBranch.isEmpty) return true;
          final branch = (doc.data()['branch'] ?? '').toString().toUpperCase();
          return branch == selectedBranch;
        }).toList();

        if (docs.isEmpty) {
          return const Center(
            child: Text('No schedules found for selected branch'),
          );
        }

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data();

            final branch = (data['branch'] ?? 'N/A').toString();
            final subjectName = (data['subjectName'] ?? 'N/A').toString();
            final subjectCode = (data['subjectCode'] ?? '').toString();
            final isActive = (data['isActive'] ?? false) as bool;
            final releaseStatus =
                (data['releaseStatus'] ?? 'draft').toString().toUpperCase();
            final isReleased = releaseStatus == 'RELEASED';

            final ts = data['examDateTime'] as Timestamp?;
            final dateTime = ts?.toDate();
            final dateLabel = dateTime == null
                ? (data['examDate'] ?? 'N/A').toString()
                : DateFormat('dd MMM yyyy').format(dateTime);
            final timeLabel = dateTime == null
                ? (data['examTime'] ?? 'N/A').toString()
                : DateFormat('hh:mm a').format(dateTime);

            return Card(
              elevation: 1,
              child: ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                title: Text(
                  '$branch${subjectCode.isNotEmpty ? ' - $subjectCode' : ''}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  'Subject: $subjectName\nDate: $dateLabel    Time: $timeLabel\nStatus: $releaseStatus',
                ),
                leading: CircleAvatar(
                  backgroundColor: isActive ? Colors.green : Colors.grey,
                  radius: 14,
                  child: Icon(
                    isActive ? Icons.check : Icons.pause,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
                trailing: Wrap(
                  spacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Switch(
                      value: isActive,
                      onChanged: isReleased
                          ? null
                          : (_) => _toggleSchedule(doc.id, isActive),
                    ),
                    IconButton(
                      onPressed:
                          isReleased ? null : () => _deleteSchedule(doc.id),
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      tooltip: 'Delete',
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
