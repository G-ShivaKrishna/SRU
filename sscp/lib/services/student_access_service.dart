import 'package:cloud_firestore/cloud_firestore.dart';

class StudentAccessService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Search students by roll number or name
  static Future<List<Map<String, dynamic>>> searchStudents(String query) async {
    try {
      if (query.isEmpty) {
        // Return all students if query is empty
        final snapshot =
            await _firestore.collection('students').limit(50).get();
        return snapshot.docs
            .map((doc) => {'id': doc.id, ...doc.data()})
            .toList();
      }

      final queryLower = query.toLowerCase();
      final results = <Map<String, dynamic>>[];

      // Search by hallTicketNumber (roll number)
      final rollNumberQuery = await _firestore
          .collection('students')
          .where('hallTicketNumber',
              isGreaterThanOrEqualTo: query.toUpperCase())
          .where('hallTicketNumber', isLessThan: query.toUpperCase() + 'z')
          .limit(20)
          .get();

      for (var doc in rollNumberQuery.docs) {
        final data = doc.data();
        results.add({
          'id': doc.id,
          ...data,
        });
      }

      // Search by name (case-insensitive)
      final nameQuery = await _firestore.collection('students').limit(50).get();

      for (var doc in nameQuery.docs) {
        final data = doc.data();
        final studentName = (data['name'] ?? '').toString().toLowerCase();

        if (studentName.contains(queryLower) &&
            !results.any((r) => r['id'] == doc.id)) {
          results.add({
            'id': doc.id,
            ...data,
          });
        }
      }

      return results;
    } catch (e) {
      print('Error searching students: $e');
      return [];
    }
  }

  // Grant edit profile access to a student
  static Future<Map<String, dynamic>> grantEditAccess(
    String hallTicketNumber,
  ) async {
    try {
      await _firestore.collection('students').doc(hallTicketNumber).update({
        'canEditProfile': true,
        'editAccessGrantedAt': FieldValue.serverTimestamp(),
      });

      return {
        'success': true,
        'message': 'Edit access granted to $hallTicketNumber',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Error granting access: $e',
      };
    }
  }

  // Revoke edit profile access from a student
  static Future<Map<String, dynamic>> revokeEditAccess(
    String hallTicketNumber,
  ) async {
    try {
      await _firestore.collection('students').doc(hallTicketNumber).update({
        'canEditProfile': false,
        'editAccessRevokedAt': FieldValue.serverTimestamp(),
      });

      return {
        'success': true,
        'message': 'Edit access revoked from $hallTicketNumber',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Error revoking access: $e',
      };
    }
  }

  // Check if student has edit access
  static Future<bool> hasEditAccess(String hallTicketNumber) async {
    try {
      final doc =
          await _firestore.collection('students').doc(hallTicketNumber).get();

      if (!doc.exists) {
        return false;
      }

      final data = doc.data() as Map<String, dynamic>;
      return data['canEditProfile'] ?? false;
    } catch (e) {
      print('Error checking edit access: $e');
      return false;
    }
  }

  // Get students with edit access
  static Future<List<Map<String, dynamic>>> getStudentsWithEditAccess() async {
    try {
      final snapshot = await _firestore
          .collection('students')
          .where('canEditProfile', isEqualTo: true)
          .get();

      return snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
    } catch (e) {
      print('Error getting students with edit access: $e');
      return [];
    }
  }

  // Update student profile
  static Future<Map<String, dynamic>> updateStudentProfile(
    String hallTicketNumber,
    Map<String, dynamic> updates,
  ) async {
    try {
      // Check if student has edit access
      final hasAccess = await hasEditAccess(hallTicketNumber);

      if (!hasAccess) {
        return {
          'success': false,
          'message': 'Student does not have permission to edit profile',
        };
      }

      await _firestore.collection('students').doc(hallTicketNumber).update({
        ...updates,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return {
        'success': true,
        'message': 'Profile updated successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Error updating profile: $e',
      };
    }
  }

  // Get student by hallTicketNumber
  static Future<Map<String, dynamic>?> getStudent(
    String hallTicketNumber,
  ) async {
    try {
      final doc =
          await _firestore.collection('students').doc(hallTicketNumber).get();

      if (!doc.exists) {
        return null;
      }

      return {'id': doc.id, ...doc.data() as Map<String, dynamic>};
    } catch (e) {
      print('Error getting student: $e');
      return null;
    }
  }

  // Grant edit access to multiple students
  static Future<Map<String, dynamic>> grantEditAccessToMultiple(
    List<String> hallTicketNumbers,
  ) async {
    try {
      final batch = _firestore.batch();
      final timestamp = FieldValue.serverTimestamp();

      for (var hallTicketNumber in hallTicketNumbers) {
        final docRef = _firestore.collection('students').doc(hallTicketNumber);

        batch.update(docRef, {
          'canEditProfile': true,
          'editAccessGrantedAt': timestamp,
        });
      }

      await batch.commit();

      return {
        'success': true,
        'message':
            'Edit access granted to ${hallTicketNumbers.length} students',
        'count': hallTicketNumbers.length,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Error granting access: $e',
      };
    }
  }

  // Admin method to update student name (no permission check required)
  static Future<Map<String, dynamic>> updateStudentNameAsAdmin(
    String hallTicketNumber,
    String newName,
  ) async {
    try {
      if (newName.trim().isEmpty) {
        return {
          'success': false,
          'message': 'Student name cannot be empty',
        };
      }

      await _firestore.collection('students').doc(hallTicketNumber).update({
        'name': newName.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return {
        'success': true,
        'message': 'Student name updated successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Error updating student name: $e',
      };
    }
  }

  // Admin method to update student admission information
  static Future<Map<String, dynamic>> updateStudentAdmissionInfoAsAdmin(
    String hallTicketNumber,
    String? admissionYear,
    String? admissionType,
    String? dateOfAdmission,
  ) async {
    try {
      final updates = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (admissionYear != null && admissionYear.isNotEmpty) {
        updates['admissionYear'] = admissionYear;
      }
      if (admissionType != null && admissionType.isNotEmpty) {
        updates['admissionType'] = admissionType;
      }
      if (dateOfAdmission != null && dateOfAdmission.isNotEmpty) {
        updates['dateOfAdmission'] = dateOfAdmission;
      }

      if (updates.length == 1) {
        // Only timestamp, no other updates
        return {
          'success': false,
          'message': 'Please provide at least one field to update',
        };
      }

      await _firestore
          .collection('students')
          .doc(hallTicketNumber)
          .update(updates);

      return {
        'success': true,
        'message': 'Student admission information updated successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Error updating admission information: $e',
      };
    }
  }

  // Student requests edit access
  static Future<Map<String, dynamic>> requestEditAccess(
    String hallTicketNumber,
    String studentName,
    List<String> fieldsToEdit,
  ) async {
    try {
      // Check if already has access
      final hasAccess = await hasEditAccess(hallTicketNumber);
      if (hasAccess) {
        return {
          'success': false,
          'message': 'You already have edit access granted',
        };
      }

      // Check if request already pending
      final existingRequest = await _firestore
          .collection('editAccessRequests')
          .where('hallTicketNumber', isEqualTo: hallTicketNumber)
          .where('status', isEqualTo: 'pending')
          .limit(1)
          .get();

      if (existingRequest.docs.isNotEmpty) {
        return {
          'success': false,
          'message': 'You already have a pending request',
        };
      }

      // Create new request
      await _firestore.collection('editAccessRequests').add({
        'hallTicketNumber': hallTicketNumber,
        'studentName': studentName,
        'fieldsToEdit': fieldsToEdit,
        'status': 'pending', // pending, approved, rejected
        'requestedAt': FieldValue.serverTimestamp(),
        'approvedAt': null,
        'rejectedAt': null,
        'approvedBy': null,
      });

      return {
        'success': true,
        'message': 'Edit access request submitted successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Error submitting request: $e',
      };
    }
  }

  // Get pending edit access requests
  static Future<List<Map<String, dynamic>>> getPendingEditAccessRequests() async {
    try {
      final snapshot = await _firestore
          .collection('editAccessRequests')
          .where('status', isEqualTo: 'pending')
          .orderBy('requestedAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => {
                'requestId': doc.id,
                ...doc.data(),
              })
          .toList();
    } catch (e) {
      print('Error getting pending requests: $e');
      return [];
    }
  }

  // Get all edit access requests (pending and processed)
  static Future<List<Map<String, dynamic>>> getAllEditAccessRequests() async {
    try {
      final snapshot = await _firestore
          .collection('editAccessRequests')
          .orderBy('requestedAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => {
                'requestId': doc.id,
                ...doc.data(),
              })
          .toList();
    } catch (e) {
      print('Error getting requests: $e');
      return [];
    }
  }

  // Approve edit access request
  static Future<Map<String, dynamic>> approveEditAccessRequest(
    String requestId,
    String hallTicketNumber,
  ) async {
    try {
      final batch = _firestore.batch();
      final timestamp = FieldValue.serverTimestamp();

      // Update request status
      batch.update(
        _firestore.collection('editAccessRequests').doc(requestId),
        {
          'status': 'approved',
          'approvedAt': timestamp,
          'approvedBy': 'admin',
        },
      );

      // Grant access to student
      batch.update(
        _firestore.collection('students').doc(hallTicketNumber),
        {
          'canEditProfile': true,
          'editAccessGrantedAt': timestamp,
        },
      );

      await batch.commit();

      return {
        'success': true,
        'message': 'Edit access approved successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Error approving request: $e',
      };
    }
  }

  // Reject edit access request
  static Future<Map<String, dynamic>> rejectEditAccessRequest(
    String requestId,
    String? reason,
  ) async {
    try {
      await _firestore.collection('editAccessRequests').doc(requestId).update({
        'status': 'rejected',
        'rejectedAt': FieldValue.serverTimestamp(),
        'rejectionReason': reason ?? 'Rejected by admin',
      });

      return {
        'success': true,
        'message': 'Request rejected successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Error rejecting request: $e',
      };
    }
  }

  // Get request status for a student
  static Future<Map<String, dynamic>?> getStudentRequestStatus(
    String hallTicketNumber,
  ) async {
    try {
      final snapshot = await _firestore
          .collection('editAccessRequests')
          .where('hallTicketNumber', isEqualTo: hallTicketNumber)
          .orderBy('requestedAt', descending: true)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        return null;
      }

      final doc = snapshot.docs.first;
      return {
        'requestId': doc.id,
        ...doc.data(),
      };
    } catch (e) {
      print('Error getting request status: $e');
      return null;
    }
  }
}
