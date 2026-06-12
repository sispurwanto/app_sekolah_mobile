import 'package:cloud_firestore/cloud_firestore.dart';

class Invoice {
  final String id;
  final String studentId;
  final String studentName;
  final String title;
  final double amount;
  final double paidAmount;
  final String status;
  final DateTime dueDate;
  final String schoolId;
  final String academicYearId;
  final String classId;
  final DateTime? createdAt;
  final String? createdBy;
  final DateTime? updatedAt;
  final String? updatedBy;

  Invoice({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.title,
    required this.amount,
    this.paidAmount = 0.0,
    required this.dueDate,
    required this.schoolId,
    required this.academicYearId,
    required this.classId,
    this.status = 'UNPAID',
    this.createdAt,
    this.createdBy,
    this.updatedAt,
    this.updatedBy,
  });

  factory Invoice.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Invoice(
      id: doc.id,
      studentId: data['student_id'] ?? data['studentId'] ?? '',
      studentName: data['student_name'] ?? data['studentName'] ?? 'Unknown',
      title: data['title'] ?? 'Tagihan',
      amount: (data['amount'] ?? 0).toDouble(),
      paidAmount: (data['paid_amount'] ?? 0).toDouble(),
      status: data['status'] ?? 'UNPAID',
      dueDate: data['due_date'] != null
          ? (data['due_date'] as Timestamp).toDate()
          : DateTime.now(),
      schoolId: data['school_id'] ?? '',
      academicYearId: data['academic_year_id'] ?? '',
      classId: data['class_id'] ?? '',
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
      'student_id': studentId,
      'student_name': studentName,
      'title': title,
      'amount': amount,
      'paid_amount': paidAmount,
      'status': status,
      'due_date': Timestamp.fromDate(dueDate),
      'school_id': schoolId,
      'academic_year_id': academicYearId,
      'class_id': classId,
      'created_at': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
    };
  }
}
