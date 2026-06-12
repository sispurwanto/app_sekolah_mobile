import 'package:cloud_firestore/cloud_firestore.dart';

class AcademicYear {
  final String id;
  final String name;
  final bool isActive;
  final DateTime? createdAt;
  final String? createdBy;
  final DateTime? updatedAt;
  final String? updatedBy;

  AcademicYear({
    required this.id,
    required this.name,
    this.isActive = false,
    this.createdAt,
    this.createdBy,
    this.updatedAt,
    this.updatedBy,
  });

  factory AcademicYear.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return AcademicYear(
      id: doc.id,
      name: data['name'] ?? '',
      isActive: data['is_active'] ?? false,
      createdAt: data['created_at'] != null
          ? (data['created_at'] as Timestamp).toDate()
          : null,
      createdBy: data['created_by'],
      updatedAt: data['updated_at'] != null
          ? (data['updated_at'] as Timestamp).toDate()
          : null,
      updatedBy: data['updated_by'],
    );
  }

  Map<String, dynamic> toMap() {
    return {'name': name, 'is_active': isActive};
  }
}
