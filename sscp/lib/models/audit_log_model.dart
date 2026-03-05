import 'package:cloud_firestore/cloud_firestore.dart';

/// Audit log entry model for tracking all backend operations
class AuditLogEntry {
  final String logId;
  final DateTime timestamp;
  final String userId; // FAC001, ADM001, FEE001, 22CSBTB01
  final String userRole; // faculty, admin, fee_payment, student
  final String operation; // create, update, delete, approve, reject, submit
  final String module; // marks, attendance, fees, courses, students, etc.
  final String subModule; // cie_marks, supply_marks, supply_fees, etc.
  final String targetEntity; // studentMarks, attendance, feePayments, etc.
  final String? targetId; // document ID or identifier
  final List<String> affectedUsers; // for batch operations
  final Map<String, dynamic> details; // operation-specific details
  final Map<String, dynamic>? metadata; // optional: IP, device info

  AuditLogEntry({
    required this.logId,
    required this.timestamp,
    required this.userId,
    required this.userRole,
    required this.operation,
    required this.module,
    required this.subModule,
    required this.targetEntity,
    this.targetId,
    required this.affectedUsers,
    required this.details,
    this.metadata,
  });

  /// Create from Firestore document
  factory AuditLogEntry.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AuditLogEntry(
      logId: doc.id,
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      userId: data['userId'] ?? '',
      userRole: data['userRole'] ?? '',
      operation: data['operation'] ?? '',
      module: data['module'] ?? '',
      subModule: data['subModule'] ?? '',
      targetEntity: data['targetEntity'] ?? '',
      targetId: data['targetId'],
      affectedUsers: List<String>.from(data['affectedUsers'] ?? []),
      details: Map<String, dynamic>.from(data['details'] ?? {}),
      metadata: data['metadata'] != null
          ? Map<String, dynamic>.from(data['metadata'])
          : null,
    );
  }

  /// Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'timestamp': FieldValue.serverTimestamp(),
      'userId': userId,
      'userRole': userRole,
      'operation': operation,
      'module': module,
      'subModule': subModule,
      'targetEntity': targetEntity,
      'targetId': targetId,
      'affectedUsers': affectedUsers,
      'details': details,
      'metadata': metadata,
    };
  }

  /// Get human-readable description of the log entry
  String getDescription() {
    final user = userId;
    switch (subModule) {
      case 'cie_marks':
        final year = details['year']?.toString() ?? '';
        final sem = details['semester']?.toString() ?? '';
        final dept = details['department']?.toString() ?? '';
        final batch = details['batch']?.toString() ?? '';
        final subject = details['subjectName'] ?? details['courseCode'] ?? '';
        final savedVia = details['savedVia']?.toString() ?? '';
        
        final context = [
          if (year.isNotEmpty) 'Year $year',
          if (sem.isNotEmpty) 'Sem $sem',
          if (dept.isNotEmpty) dept,
          if (batch.isNotEmpty) 'Batch $batch',
        ].join(', ');
        
        var desc = '$user posted CIE marks for ${affectedUsers.length} student(s)';
        if (subject.isNotEmpty) desc += ' - $subject';
        if (context.isNotEmpty) desc += ' ($context)';
        if (savedVia.isNotEmpty) desc += ' [$savedVia]';
        
        return desc;
      case 'supply_marks':
        return '$user posted Supply marks for ${affectedUsers.length} student(s)';
      case 'makeup_marks':
        return '$user posted Makeup Mid marks for ${affectedUsers.length} student(s)';
      case 'supply_fees':
        final status = details['status']?.toString() ?? '';
        return '$user updated Supply fee status to "$status" for ${affectedUsers.join(", ")}';
      case 'makeup_fees':
        final status = details['status']?.toString() ?? '';
        return '$user updated Makeup Mid fee status to "$status" for ${affectedUsers.join(", ")}';
      case 'student_promotion':
        return '$user ${operation}d ${affectedUsers.length} student(s)';
      case 'backlog_management':
        return '$user ${operation}d backlog for ${affectedUsers.join(", ")}';
      case 'registration_window':
        return '$user ${operation}d registration window: ${details['windowTitle']}';
      case 'student_access':
        return '$user ${operation}d access for ${affectedUsers.join(", ")}';
      case 'course_management':
        return '$user ${operation}d course: ${details['courseName'] ?? details['courseCode']}';
      case 'subject_management':
        return '$user ${operation}d subject: ${details['subjectName'] ?? details['subjectCode']}';
      case 'attendance_admin':
        return '$user ${operation}d attendance record';
      case 'grievance':
        final type = details['grievanceType']?.toString() ?? '';
        return '$user ${operation}d ${type.isNotEmpty ? '$type ' : ''}grievance';
      case 'faculty_profile':
        final fields = details['updatedFields'] as List?;
        final fieldCount = fields?.length ?? 0;
        return '$user updated profile ($fieldCount field${fieldCount != 1 ? 's' : ''} changed)';
      case 'feedback':
        return '$user submitted feedback for faculty ${details['facultyId']}';
      default:
        return '$user performed $operation on $module';
    }
  }
}
