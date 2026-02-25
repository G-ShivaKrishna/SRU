import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

/// One-click seeder: uploads random attendance for every faculty-assigned
/// subject × every working day (Mon–Sat) of February 2026.
class SeedAttendancePage extends StatefulWidget {
  const SeedAttendancePage({super.key});

  @override
  State<SeedAttendancePage> createState() => _SeedAttendancePageState();
}

class _SeedAttendancePageState extends State<SeedAttendancePage> {
  final _firestore = FirebaseFirestore.instance;
  final _rng = Random();

  bool _running = false;
  bool _done = false;
  bool _cancelled = false;

  int _totalJobs = 0;   // assignments × working-days
  int _completed = 0;
  int _skipped = 0;     // already-existing docs skipped
  int _errors = 0;
  final List<String> _log = [];

  // ── Feb 2026 working days (Mon–Sat, no Sundays) ─────────────────────────
  static final List<DateTime> _workingDays = () {
    final days = <DateTime>[];
    for (var d = 1; d <= 28; d++) {
      final dt = DateTime(2026, 2, d);
      if (dt.weekday != DateTime.sunday) days.add(dt);
    }
    return days;
  }();

  // ── random helpers ───────────────────────────────────────────────────────
  bool _randomPresent() => _rng.nextDouble() < 0.75; // ~75 % attendance rate
  String _randomLtp() => ['L', 'L', 'L', 'T', 'P'][_rng.nextInt(5)];
  int _randomPeriod() => _rng.nextInt(9) + 1; // 1-9
  String _randomUnit() => '${_rng.nextInt(6) + 1}';
  String _randomTopic(String sub) {
    const topics = [
      'Introduction & Overview',
      'Fundamental Concepts',
      'Advanced Techniques',
      'Problem Solving',
      'Practical Applications',
      'Review & Discussion',
      'Case Study',
      'Revision',
    ];
    return '$sub – ${topics[_rng.nextInt(topics.length)]}';
  }

  void _addLog(String msg) {
    setState(() {
      _log.add(msg);
      if (_log.length > 200) _log.removeAt(0);
    });
  }

  // ── main seed logic ──────────────────────────────────────────────────────
  Future<void> _startSeed() async {
    // Confirm
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Seed February 2026 Attendance?'),
        content: const Text(
          'This will upload attendance records for every faculty-assigned '
          'subject on every working day (Mon–Sat) of February 2026.\n\n'
          '• ~75 % of students will be marked Present randomly.\n'
          '• Already-existing records for a date/subject combo will be skipped.\n\n'
          'This may take a few minutes. Continue?',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1e3a5f)),
            child: const Text('Seed Now',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() {
      _running = true;
      _done = false;
      _cancelled = false;
      _completed = 0;
      _skipped = 0;
      _errors = 0;
      _log.clear();
    });

    try {
      // ── 1. Fetch all faculty assignments ──────────────────────────────
      _addLog('Fetching faculty assignments…');
      final assignSnap =
          await _firestore.collection('facultyAssignments').get();
      final assignments = assignSnap.docs;

      if (assignments.isEmpty) {
        _addLog('⚠ No faculty assignments found. Nothing to seed.');
        setState(() => _done = true);
        return;
      }
      _addLog('Found ${assignments.length} assignment(s).');

      // ── 2. Prefetch students grouped by batchNumber ───────────────────
      _addLog('Fetching all students…');
      final studentSnap = await _firestore.collection('students').get();
      // batchNumber → list of student maps
      final Map<String, List<Map<String, dynamic>>> studentsByBatch = {};
      for (final doc in studentSnap.docs) {
        final d = doc.data();
        final batch = (d['batchNumber'] as String? ?? '').trim();
        if (batch.isEmpty) continue;
        studentsByBatch.putIfAbsent(batch, () => []).add({
          'rollNo': doc.id,
          'name': d['name'] as String? ?? doc.id,
          'hallTicketNumber': d['hallTicketNumber'] as String? ?? doc.id,
          'batchNumber': batch,
        });
      }
      _addLog(
          'Found ${studentSnap.docs.length} students across '
          '${studentsByBatch.length} batch(es).');

      // ── 3. Preload existing dateStr+subjectCode combos to skip dupes ──
      _addLog('Checking existing attendance records…');
      final existingSnap = await _firestore
          .collection('attendance')
          .where('date',
              isGreaterThanOrEqualTo: Timestamp.fromDate(DateTime(2026, 2, 1)))
          .where('date',
              isLessThanOrEqualTo:
                  Timestamp.fromDate(DateTime(2026, 2, 28, 23, 59, 59)))
          .get();
      final existingKeys = <String>{};
      for (final doc in existingSnap.docs) {
        final d = doc.data();
        existingKeys.add(
            '${d['dateStr']}_${(d['subjectCode'] as String? ?? '')}');
      }
      _addLog(
          'Found ${existingKeys.length} existing Feb-2026 record(s) — will skip duplicates.');

      // ── 4. Build job list ─────────────────────────────────────────────
      _totalJobs = assignments.length * _workingDays.length;
      setState(() {});
      _addLog(
          'Total jobs: ${assignments.length} assignments × '
          '${_workingDays.length} working days = $_totalJobs records.');

      // ── 5. Iterate and write ──────────────────────────────────────────
      var batchWrite = _firestore.batch();
      var batchCount = 0;
      const maxPerBatch = 400; // Firestore limit is 500; use 400 for safety

      for (final assignDoc in assignments) {
        if (_cancelled) break;
        final ad = assignDoc.data();
        final facultyId = ad['facultyId'] as String? ?? 'UNKNOWN';
        final subjectCode = (ad['subjectCode'] as String? ?? '').trim();
        final subjectName = (ad['subjectName'] as String? ?? '').trim();
        final department = (ad['department'] as String? ?? '').trim();
        final year =
            ad['year'] is int ? ad['year'] as int : int.tryParse('${ad['year']}') ?? 0;
        final semester = ad['semester'] as String? ?? '';
        final batches =
            List<String>.from(ad['batches'] ?? []);

        if (subjectCode.isEmpty || batches.isEmpty) {
          for (var _ in _workingDays) {
            setState(() => _skipped++);
          }
          continue;
        }

        // Collect students for all batches in this assignment
        final List<Map<String, dynamic>> students = [];
        for (final b in batches) {
          students.addAll(studentsByBatch[b] ?? []);
        }

        if (students.isEmpty) {
          _addLog(
              '⚠  $subjectCode – no students in batches ${batches.join(', ')}. Skipping.');
          for (var _ in _workingDays) {
            setState(() => _skipped++);
          }
          continue;
        }

        for (final day in _workingDays) {
          if (_cancelled) break;

          final dateStr = DateFormat('dd-MM-yyyy').format(day);
          final key = '${dateStr}_$subjectCode';

          if (existingKeys.contains(key)) {
            setState(() {
              _skipped++;
              _completed++;
            });
            continue;
          }

          // Build student attendance list
          final ltpType = _randomLtp();
          final period = _randomPeriod();
          final unit = _randomUnit();
          final topic = _randomTopic(subjectCode);

          final studentList = students.map((s) {
            return {
              'rollNo': s['rollNo'],
              'name': s['name'],
              'hallTicketNumber': s['hallTicketNumber'],
              'batchNumber': s['batchNumber'],
              'present': _randomPresent(),
            };
          }).toList();

          final presentCount =
              studentList.where((s) => s['present'] == true).length;
          final absentCount = studentList.length - presentCount;

          final newRef = _firestore.collection('attendance').doc();
          batchWrite.set(newRef, {
            'dateStr': dateStr,
            'date': Timestamp.fromDate(
                DateTime(day.year, day.month, day.day)),
            'facultyId': facultyId,
            'subjectCode': subjectCode,
            'subjectName': subjectName,
            'department': department,
            'year': year,
            'semester': semester,
            'batches': batches,
            'ltpType': ltpType,
            'topicCovered': topic,
            'unitExpNo': unit,
            'periods': [period],
            'students': studentList,
            'presentCount': presentCount,
            'absentCount': absentCount,
            'totalStudents': studentList.length,
            'seeded': true,
            'submittedAt': FieldValue.serverTimestamp(),
          });

          batchCount++;
          existingKeys.add(key); // prevent re-adding same key twice

          // Flush batch when full
          if (batchCount >= maxPerBatch) {
            try {
              await batchWrite.commit();
              _addLog('  ✓ Committed batch of $batchCount records.');
            } catch (e) {
              _addLog('  ✗ Batch commit error: $e');
              setState(() => _errors += batchCount);
            }
            batchWrite = _firestore.batch();
            batchCount = 0;
          }

          setState(() => _completed++);
        }

        _addLog(
            '✓  $subjectCode (${batches.join(', ')}): '
            '${students.length} students seeded.');
      }

      // Flush remaining
      if (batchCount > 0 && !_cancelled) {
        try {
          await batchWrite.commit();
          _addLog('  ✓ Committed final batch of $batchCount records.');
        } catch (e) {
          _addLog('  ✗ Final batch error: $e');
          setState(() => _errors += batchCount);
        }
      }
    } catch (e) {
      _addLog('Fatal error: $e');
      setState(() => _errors++);
    } finally {
      setState(() {
        _running = false;
        _done = true;
      });
      _addLog(_cancelled
          ? '⛔ Seeding cancelled by user.'
          : '🎉 Seeding complete! '
              '$_completed processed, $_skipped skipped, $_errors errors.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final pct = _totalJobs > 0 ? _completed / _totalJobs : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Seed Feb 2026 Attendance'),
        backgroundColor: const Color(0xFF1e3a5f),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── info card ────────────────────────────────────────────────
            Card(
              color: const Color(0xFF1e3a5f).withOpacity(0.07),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('What this does',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 8),
                    _bullet('Reads every faculty assignment from Firestore.'),
                    _bullet(
                        'For each assignment × each working day (Mon–Sat) in '
                        'February 2026, creates one attendance document.'),
                    _bullet(
                        '~75 % of students are randomly marked Present; '
                        'rest Absent.'),
                    _bullet(
                        'Skips dates/subjects that already have a record.'),
                    _bullet(
                        'All seeded docs are tagged  seeded: true  for easy cleanup.'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ── stats row ────────────────────────────────────────────────
            if (_running || _done) ...[
              LinearProgressIndicator(
                value: _totalJobs > 0 ? pct.clamp(0.0, 1.0) : null,
                minHeight: 8,
                backgroundColor: Colors.grey.shade200,
                valueColor: const AlwaysStoppedAnimation(Color(0xFF1e3a5f)),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _stat('Processed', '$_completed',
                      const Color(0xFF1e3a5f)),
                  _stat('Skipped', '$_skipped', Colors.orange),
                  _stat('Errors', '$_errors', Colors.red),
                  if (_totalJobs > 0)
                    _stat('Total', '$_totalJobs', Colors.grey),
                ],
              ),
              const SizedBox(height: 8),
            ],

            // ── action buttons ───────────────────────────────────────────
            Row(children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _running ? null : _startSeed,
                  icon: _running
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.cloud_upload),
                  label: Text(_done
                      ? 'Seed Again'
                      : _running
                          ? 'Seeding…'
                          : 'Start Seeding'),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1e3a5f),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14)),
                ),
              ),
              if (_running) ...[
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  onPressed: () => setState(() => _cancelled = true),
                  icon: const Icon(Icons.stop),
                  label: const Text('Cancel'),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14)),
                ),
              ],
            ]),
            const SizedBox(height: 16),

            // ── log ──────────────────────────────────────────────────────
            if (_log.isNotEmpty) ...[
              const Text('Log',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 6),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade900,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.all(10),
                  child: ListView.builder(
                    reverse: true,
                    itemCount: _log.length,
                    itemBuilder: (_, i) => Text(
                      _log[_log.length - 1 - i],
                      style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                          color: Colors.greenAccent),
                    ),
                  ),
                ),
              ),
            ] else
              const Expanded(
                child: Center(
                  child: Text(
                    'Press "Start Seeding" to begin.',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _bullet(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('• ', style: TextStyle(fontSize: 13)),
          Expanded(
              child: Text(text, style: const TextStyle(fontSize: 13))),
        ]),
      );

  Widget _stat(String label, String value, Color color) => Column(
        children: [
          Text(value,
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: color)),
          Text(label,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
        ],
      );
}
