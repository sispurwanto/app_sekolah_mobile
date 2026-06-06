import 'package:cloud_firestore/cloud_firestore.dart';

class Student {
  final String id;
  final String nis;
  final String nisn;
  final String name;
  final String gender;
  final DateTime birthDate;
  final String classId;
  final String guardianId;
  final String academicYearId;
  final String status;
  final DateTime? createdAt;
  final String? createdBy;
  final DateTime? updatedAt;
  final String? updatedBy;

  Student({
    required this.id,
    required this.nis,
    required this.nisn,
    required this.name,
    required this.gender,
    required this.birthDate,
    required this.classId,
    required this.guardianId,
    required this.academicYearId,
    required this.status,
    this.createdAt,
    this.createdBy,
    this.updatedAt,
    this.updatedBy,
  });

  factory Student.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Student(
      id: doc.id,
      nis: data['nis'] ?? '',
      nisn: data['nisn'] ?? '',
      name: data['name'] ?? '',
      gender: data['gender'] ?? 'L',
      birthDate: data['birth_date'] != null 
          ? (data['birth_date'] as Timestamp).toDate() 
          : DateTime.now(),
      classId: data['class_id'] ?? '',
      guardianId: data['guardian_id'] ?? '',
      academicYearId: data['academic_year_id'] ?? '',
      status: data['status'] ?? 'ACTIVE',
      createdAt: data['created_at'] != null ? (data['created_at'] as Timestamp).toDate() : null,
      createdBy: data['created_by'],
      updatedAt: data['updated_at'] != null ? (data['updated_at'] as Timestamp).toDate() : null,
      updatedBy: data['updated_by'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'nis': nis,
      'nisn': nisn,
      'name': name,
      'gender': gender,
      'birth_date': Timestamp.fromDate(birthDate),
      'class_id': classId,
      'guardian_id': guardianId,
      'academic_year_id': academicYearId,
      'status': status,
    };
  }
}
