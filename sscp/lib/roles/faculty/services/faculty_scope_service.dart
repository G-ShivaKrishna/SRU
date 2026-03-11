import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../services/user_service.dart';

class FacultyScopeService {
  FacultyScopeService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  Future<String> resolveCurrentFacultyId() async {
    final cached = UserService.getCurrentUserId();
    if (cached != null && cached.trim().isNotEmpty) {
      return cached.trim().toUpperCase();
    }

    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Not logged in');
    }

    final email = (user.email ?? '').toLowerCase().trim();
    if (email.isEmpty) {
      throw Exception('Faculty email not available');
    }

    final facultyDocs = await _firestore
        .collection('faculty')
        .where('firebaseEmail', isEqualTo: email)
        .limit(1)
        .get();

    QuerySnapshot<Map<String, dynamic>> fallbackDocs;
    if (facultyDocs.docs.isEmpty) {
      fallbackDocs = await _firestore
          .collection('faculty')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();
    } else {
      fallbackDocs = facultyDocs;
    }

    if (fallbackDocs.docs.isEmpty) {
      throw Exception('Faculty profile not found');
    }

    final facultyDoc = fallbackDocs.docs.first;
    final facultyId = facultyDoc.id.trim().toUpperCase();
    UserService.cacheCurrentUser(
      userId: facultyId,
      role: 'faculty',
      userData: facultyDoc.data(),
    );
    return facultyId;
  }

  Future<List<Map<String, dynamic>>> loadStudentsForAssignment({
    required String department,
    required int year,
    required List<String> assignedBatches,
  }) async {
    final allowedBatchTokens = _buildBatchTokens(assignedBatches);
    if (allowedBatchTokens.isEmpty) {
      return [];
    }

    QuerySnapshot<Map<String, dynamic>> snap;
    if (year > 0) {
      snap = await _firestore
          .collection('students')
          .where('year', isEqualTo: year)
          .get();

      if (snap.docs.isEmpty) {
        snap = await _firestore.collection('students').get();
      }
    } else {
      snap = await _firestore.collection('students').get();
    }

    final normalizedDepartment = _normalize(department);

    final students = <Map<String, dynamic>>[];
    for (final doc in snap.docs) {
      final data = doc.data();
      final studentDepartment =
          _normalize(data['department']?.toString() ?? '');
      final studentYear = _parseInt(data['year']);
      final status = _normalize(data['status']?.toString() ?? 'active');

      if (normalizedDepartment.isNotEmpty &&
          studentDepartment != normalizedDepartment) {
        continue;
      }
      if (year > 0 && studentYear != year) {
        continue;
      }
      if (status == 'graduated' || status == 'inactive') {
        continue;
      }
      if (!_matchesAssignedBatch(data, allowedBatchTokens)) {
        continue;
      }

      students.add({
        'rollNo': doc.id,
        'studentId': doc.id,
        'name': (data['name'] ?? data['studentName'] ?? '').toString(),
        'studentName': (data['name'] ?? data['studentName'] ?? '').toString(),
        'hallTicketNumber': (data['hallTicketNumber'] ?? doc.id).toString(),
        'batchNumber': (data['batchNumber'] ?? '').toString(),
        'section': (data['section'] ?? '').toString(),
        'department': (data['department'] ?? '').toString(),
        'year': studentYear,
      });
    }

    students.sort((a, b) => (a['hallTicketNumber'] as String)
        .compareTo(b['hallTicketNumber'] as String));
    return students;
  }

  bool assignmentContainsSection(
      List<String> assignedBatches, String selectedSection) {
    final tokens = _buildBatchTokens(assignedBatches);
    return tokens.contains(_normalize(selectedSection));
  }

  Set<String> _buildBatchTokens(List<String> batches) {
    final tokens = <String>{};
    for (final batch in batches) {
      final trimmed = batch.trim();
      if (trimmed.isEmpty) {
        continue;
      }
      tokens.add(_normalize(trimmed));

      final parts = trimmed
          .split(RegExp(r'[-_/\\s]+'))
          .map(_normalize)
          .where((part) => part.isNotEmpty);
      tokens.addAll(parts);
    }
    return tokens;
  }

  bool _matchesAssignedBatch(
      Map<String, dynamic> data, Set<String> allowedBatchTokens) {
    final candidates = <String>{
      _normalize(data['batchNumber']?.toString() ?? ''),
      _normalize(data['section']?.toString() ?? ''),
      _normalize(data['batch']?.toString() ?? ''),
      _normalize(data['assignedBatch']?.toString() ?? ''),
    };

    for (final candidate in candidates) {
      if (candidate.isEmpty) {
        continue;
      }
      if (allowedBatchTokens.contains(candidate)) {
        return true;
      }

      final parts = candidate
          .split(RegExp(r'[-_/\\s]+'))
          .where((part) => part.isNotEmpty);
      for (final part in parts) {
        if (allowedBatchTokens.contains(part)) {
          return true;
        }
      }
    }

    return false;
  }

  String _normalize(String value) {
    return value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  int _parseInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.floor();
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
