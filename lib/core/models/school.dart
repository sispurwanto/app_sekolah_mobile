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
  final String? bankName;
  final String? bankAccountNumber;
  final String? bankAccountName;
  final DateTime? createdAt;
  final String? createdBy;
  final DateTime? updatedAt;
  final String? updatedBy;

  School({
    required this.id,
    required this.name,
    required this.address,
    required this.phone,
    required this.email,
    required this.status,
    required this.package,
    required this.studentLimit,
    this.bankName,
    this.bankAccountNumber,
    this.bankAccountName,
    this.createdAt,
    this.createdBy,
    this.updatedAt,
    this.updatedBy,
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
      bankName: data['bank_name'],
      bankAccountNumber: data['bank_account_number'],
      bankAccountName: data['bank_account_name'],
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
      'address': address,
      'phone': phone,
      'email': email,
      'status': status,
      'package': package,
      'student_limit': studentLimit,
      if (bankName != null) 'bank_name': bankName,
      if (bankAccountNumber != null) 'bank_account_number': bankAccountNumber,
      if (bankAccountName != null) 'bank_account_name': bankAccountName,
    };
  }
}
