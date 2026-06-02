import 'package:cloud_firestore/cloud_firestore.dart';

class School {
  final String id;
  final String name;
  final String address;
  final String phone;
  final String email;
  final String status;
  final String package;
  final int studentLimit;
  final DateTime? createdAt;

  School({
    required this.id,
    required this.name,
    required this.address,
    required this.phone,
    required this.email,
    required this.status,
    required this.package,
    required this.studentLimit,
    this.createdAt,
  });

  factory School.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return School(
      id: doc.id,
      name: data['name'] ?? '',
      address: data['address'] ?? '',
      phone: data['phone'] ?? '',
      email: data['email'] ?? '',
      status: data['status'] ?? 'ACTIVE',
      package: data['package'] ?? 'BASIC',
      studentLimit: data['student_limit'] ?? 0,
      createdAt: data['created_at'] != null ? (data['created_at'] as Timestamp).toDate() : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'address': address,
      'phone': phone,
      'email': email,
      'status': status,
      'package': package,
      'student_limit': studentLimit,
      'created_at': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
    };
  }
}
