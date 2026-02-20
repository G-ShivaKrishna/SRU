import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a single subject assignment for a faculty member
/// A faculty can have multiple assignments (different subjects to different batches)
class FacultyAssignment {
  final String id;
  final String facultyId;
  final String facultyName;
  final String department;
  final String subjectCode;
  final String subjectName;
  final List<String> assignedBatches; // e.g., ['CSE-A', 'CSE-B', 'ECE-A']
  final String academicYear; // e.g., '2024-25'
  final String semester; // e.g., 'I', 'II'
  final int year; // Student year: 1, 2, 3, 4
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? createdBy;

  FacultyAssignment({
    required this.id,
    required this.facultyId,
    required this.facultyName,
    required this.department,
    required this.subjectCode,
    required this.subjectName,
    required this.assignedBatches,
    required this.academicYear,
    required this.semester,
    required this.year,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
    this.createdBy,
  });

  /// Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'facultyId': facultyId,
      'facultyName': facultyName,
      'department': department,
      'subjectCode': subjectCode,
      'subjectName': subjectName,
      'assignedBatches': assignedBatches,
      'academicYear': academicYear,
      'semester': semester,
      'year': year,
      'isActive': isActive,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'createdBy': createdBy,
    };
  }

  /// Create from Firestore document
  factory FacultyAssignment.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return FacultyAssignment(
      id: doc.id,
      facultyId: data['facultyId'] ?? '',
      facultyName: data['facultyName'] ?? '',
      department: data['department'] ?? '',
      subjectCode: data['subjectCode'] ?? '',
      subjectName: data['subjectName'] ?? '',
      assignedBatches: List<String>.from(data['assignedBatches'] ?? []),
      academicYear: data['academicYear'] ?? '',
      semester: data['semester'] ?? '',
      year: data['year'] ?? 1,
      isActive: data['isActive'] ?? true,
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] as Timestamp).toDate()
          : DateTime.now(),
      createdBy: data['createdBy'],
    );
  }

  /// Copy with method for updates
  FacultyAssignment copyWith({
    String? id,
    String? facultyId,
    String? facultyName,
    String? department,
    String? subjectCode,
    String? subjectName,
    List<String>? assignedBatches,
    String? academicYear,
    String? semester,
    int? year,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
  }) {
    return FacultyAssignment(
      id: id ?? this.id,
      facultyId: facultyId ?? this.facultyId,
      facultyName: facultyName ?? this.facultyName,
      department: department ?? this.department,
      subjectCode: subjectCode ?? this.subjectCode,
      subjectName: subjectName ?? this.subjectName,
      assignedBatches: assignedBatches ?? this.assignedBatches,
      academicYear: academicYear ?? this.academicYear,
      semester: semester ?? this.semester,
      year: year ?? this.year,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
    );
  }

  @override
  String toString() {
    return 'FacultyAssignment(id: $id, facultyId: $facultyId, subject: $subjectName, batches: $assignedBatches)';
  }
}

/// Subject types for classification
enum SubjectType {
  core,    // Core/Mandatory subject
  oe,      // Open Elective
  pe,      // Programme Elective
}

extension SubjectTypeExtension on SubjectType {
  String get displayName {
    switch (this) {
      case SubjectType.core:
        return 'Core';
      case SubjectType.oe:
        return 'OE';
      case SubjectType.pe:
        return 'PE';
    }
  }

  String get fullName {
    switch (this) {
      case SubjectType.core:
        return 'Core Subject';
      case SubjectType.oe:
        return 'Open Elective';
      case SubjectType.pe:
        return 'Programme Elective';
    }
  }

  static SubjectType fromString(String? value) {
    if (value == null || value.isEmpty) return SubjectType.core;
    switch (value.toUpperCase()) {
      case 'OE':
      case 'OPEN ELECTIVE':
      case 'OPEN':
        return SubjectType.oe;
      case 'PE':
      case 'PROGRAMME ELECTIVE':
      case 'PROGRAM ELECTIVE':
      case 'PROFESSIONAL ELECTIVE':
        return SubjectType.pe;
      default:
        return SubjectType.core;
    }
  }
}

/// Represents a subject that can be assigned to faculty
class Subject {
  final String id;
  final String code;
  final String name;
  final String department;
  final int credits;
  final int year; // Which year students study this
  final String semester;
  final SubjectType subjectType; // Core, OE (Open Elective), PE (Programme Elective)
  final bool isActive;

  Subject({
    required this.id,
    required this.code,
    required this.name,
    required this.department,
    required this.credits,
    required this.year,
    required this.semester,
    this.subjectType = SubjectType.core,
    this.isActive = true,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'code': code,
      'name': name,
      'department': department,
      'credits': credits,
      'year': year,
      'semester': semester,
      'subjectType': subjectType.displayName,
      'isActive': isActive,
    };
  }

  factory Subject.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Subject(
      id: doc.id,
      code: data['code'] ?? '',
      name: data['name'] ?? '',
      department: data['department'] ?? '',
      credits: data['credits'] ?? 0,
      year: data['year'] ?? 1,
      semester: data['semester'] ?? 'I',
      subjectType: SubjectTypeExtension.fromString(data['subjectType']?.toString()),
      isActive: data['isActive'] ?? true,
    );
  }

  @override
  String toString() => '$code - $name';
}

/// Represents a batch of students
class StudentBatch {
  final String id;
  final String batchName; // e.g., 'CSE-A', 'ECE-B'
  final String department;
  final int year;
  final String academicYear;
  final int studentCount;

  StudentBatch({
    required this.id,
    required this.batchName,
    required this.department,
    required this.year,
    required this.academicYear,
    this.studentCount = 0,
  });

  factory StudentBatch.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return StudentBatch(
      id: doc.id,
      batchName: data['batchName'] ?? '',
      department: data['department'] ?? '',
      year: data['year'] ?? 1,
      academicYear: data['academicYear'] ?? '',
      studentCount: data['studentCount'] ?? 0,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'batchName': batchName,
      'department': department,
      'year': year,
      'academicYear': academicYear,
      'studentCount': studentCount,
    };
  }

  @override
  String toString() => batchName;
}
