import 'package:cloud_firestore/cloud_firestore.dart';

enum CourseType { OE, PE, SE } // OE: Open Elective, PE: Program Elective, SE: Subject Elective

class Course {
  final String id;
  final String code;
  final String name;
  final int credits;
  final CourseType type;
  final List<String> applicableYears; // e.g., ['1', '2', '3', '4']
  final List<String> applicableBranches; // e.g., ['CSE', 'ECE']
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  Course({
    required this.id,
    required this.code,
    required this.name,
    required this.credits,
    required this.type,
    required this.applicableYears,
    required this.applicableBranches,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  // Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'code': code,
      'name': name,
      'credits': credits,
      'type': type.toString().split('.').last,
      'applicableYears': applicableYears,
      'applicableBranches': applicableBranches,
      'isActive': isActive,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  // Create from Firestore document
  factory Course.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Course(
      id: doc.id,
      code: data['code'] ?? '',
      name: data['name'] ?? '',
      credits: data['credits'] ?? 0,
      type: _stringToCourseType(data['type'] ?? 'OE'),
      applicableYears: List<String>.from(data['applicableYears'] ?? []),
      applicableBranches: List<String>.from(data['applicableBranches'] ?? []),
      isActive: data['isActive'] ?? true,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
    );
  }

  // Helper to convert string to CourseType
  static CourseType _stringToCourseType(String value) {
    switch (value) {
      case 'OE':
        return CourseType.OE;
      case 'PE':
        return CourseType.PE;
      case 'SE':
        return CourseType.SE;
      default:
        return CourseType.OE;
    }
  }

  // Copy with method
  Course copyWith({
    String? id,
    String? code,
    String? name,
    int? credits,
    CourseType? type,
    List<String>? applicableYears,
    List<String>? applicableBranches,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Course(
      id: id ?? this.id,
      code: code ?? this.code,
      name: name ?? this.name,
      credits: credits ?? this.credits,
      type: type ?? this.type,
      applicableYears: applicableYears ?? this.applicableYears,
      applicableBranches: applicableBranches ?? this.applicableBranches,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class CourseRequirement {
  final String id;
  final String year; // '1', '2', '3', '4'
  final String branch; // 'CSE', 'ECE', etc.
  final int oeCount; // How many Open Electives required
  final int peCount; // How many Program Electives required
  final int seCount; // How many Subject Electives required
  final DateTime createdAt;
  final DateTime updatedAt;

  CourseRequirement({
    required this.id,
    required this.year,
    required this.branch,
    required this.oeCount,
    required this.peCount,
    required this.seCount,
    required this.createdAt,
    required this.updatedAt,
  });

  // Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'year': year,
      'branch': branch,
      'oeCount': oeCount,
      'peCount': peCount,
      'seCount': seCount,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  // Create from Firestore document
  factory CourseRequirement.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CourseRequirement(
      id: doc.id,
      year: data['year'] ?? '',
      branch: data['branch'] ?? '',
      oeCount: data['oeCount'] ?? 0,
      peCount: data['peCount'] ?? 0,
      seCount: data['seCount'] ?? 0,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
    );
  }

  // Copy with method
  CourseRequirement copyWith({
    String? id,
    String? year,
    String? branch,
    int? oeCount,
    int? peCount,
    int? seCount,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CourseRequirement(
      id: id ?? this.id,
      year: year ?? this.year,
      branch: branch ?? this.branch,
      oeCount: oeCount ?? this.oeCount,
      peCount: peCount ?? this.peCount,
      seCount: seCount ?? this.seCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class CourseRegistrationSettings {
  final String id;
  final bool isRegistrationEnabled;
  final DateTime registrationStartDate;
  final DateTime registrationEndDate;
  final DateTime? lastModifiedBy; // Will store admin's timestamp
  final DateTime createdAt;
  final DateTime updatedAt;

  CourseRegistrationSettings({
    required this.id,
    required this.isRegistrationEnabled,
    required this.registrationStartDate,
    required this.registrationEndDate,
    this.lastModifiedBy,
    required this.createdAt,
    required this.updatedAt,
  });

  // Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'isRegistrationEnabled': isRegistrationEnabled,
      'registrationStartDate': registrationStartDate,
      'registrationEndDate': registrationEndDate,
      'lastModifiedBy': lastModifiedBy,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  // Create from Firestore document
  factory CourseRegistrationSettings.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CourseRegistrationSettings(
      id: doc.id,
      isRegistrationEnabled: data['isRegistrationEnabled'] ?? false,
      registrationStartDate:
          (data['registrationStartDate'] as Timestamp).toDate(),
      registrationEndDate: (data['registrationEndDate'] as Timestamp).toDate(),
      lastModifiedBy: data['lastModifiedBy'] != null
          ? (data['lastModifiedBy'] as Timestamp).toDate()
          : null,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
    );
  }

  // Copy with method
  CourseRegistrationSettings copyWith({
    String? id,
    bool? isRegistrationEnabled,
    DateTime? registrationStartDate,
    DateTime? registrationEndDate,
    DateTime? lastModifiedBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CourseRegistrationSettings(
      id: id ?? this.id,
      isRegistrationEnabled: isRegistrationEnabled ?? this.isRegistrationEnabled,
      registrationStartDate:
          registrationStartDate ?? this.registrationStartDate,
      registrationEndDate: registrationEndDate ?? this.registrationEndDate,
      lastModifiedBy: lastModifiedBy ?? this.lastModifiedBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
