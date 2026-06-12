import 'package:cloud_firestore/cloud_firestore.dart';

class AppClass {
  final String id;
  final String name;
  final String level;
  final String description;
  final String? teacherId;
  final String? teacherName;
  final DateTime? createdAt;
  final String? createdBy;
  final DateTime? updatedAt;
  final String? updatedBy;

  AppClass({
    required this.id,
    required this.name,
    required this.level,
    this.description = '',
    this.teacherId,
    this.teacherName,
    this.createdAt,
    this.createdBy,
    this.updatedAt,
    this.updatedBy,
  });

  factory AppClass.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return AppClass(
      id: doc.id,
      name: data['name'] ?? '',
      level: data['level'] ?? '',
      description: data['description'] ?? '',
      teacherId: data['teacher_id'],
      teacherName: data['teacher_name'],
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
    return {
      'name': name,
      'level': level,
      'description': description,
      'teacher_id': teacherId,
      'teacher_name': teacherName,
    };
  }
}
