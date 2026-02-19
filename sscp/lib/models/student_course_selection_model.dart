import 'package:cloud_firestore/cloud_firestore.dart';

class StudentCourseSelection {
  final String id;
  final String studentId;
  final String year;
  final String branch;
  final List<String> selectedCourseIds; // List of course IDs selected
  final Map<String, dynamic> selectionsByType; // {OE: [ids], PE: [ids], SE: [ids]}
  final bool isSubmitted;
  final DateTime createdAt;
  final DateTime updatedAt;

  StudentCourseSelection({
    required this.id,
    required this.studentId,
    required this.year,
    required this.branch,
    required this.selectedCourseIds,
    required this.selectionsByType,
    this.isSubmitted = false,
    required this.createdAt,
    required this.updatedAt,
  });

  // Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'studentId': studentId,
      'year': year,
      'branch': branch,
      'selectedCourseIds': selectedCourseIds,
      'selectionsByType': selectionsByType,
      'isSubmitted': isSubmitted,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  // Create from Firestore document
  factory StudentCourseSelection.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return StudentCourseSelection(
      id: doc.id,
      studentId: data['studentId'] ?? '',
      year: data['year'] ?? '',
      branch: data['branch'] ?? '',
      selectedCourseIds: List<String>.from(data['selectedCourseIds'] ?? []),
      selectionsByType: data['selectionsByType'] ?? {},
      isSubmitted: data['isSubmitted'] ?? false,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
    );
  }

  // Copy with method
  StudentCourseSelection copyWith({
    String? id,
    String? studentId,
    String? year,
    String? branch,
    List<String>? selectedCourseIds,
    Map<String, dynamic>? selectionsByType,
    bool? isSubmitted,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return StudentCourseSelection(
      id: id ?? this.id,
      studentId: studentId ?? this.studentId,
      year: year ?? this.year,
      branch: branch ?? this.branch,
      selectedCourseIds: selectedCourseIds ?? this.selectedCourseIds,
      selectionsByType: selectionsByType ?? this.selectionsByType,
      isSubmitted: isSubmitted ?? this.isSubmitted,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
