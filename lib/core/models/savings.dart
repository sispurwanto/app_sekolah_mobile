import 'package:cloud_firestore/cloud_firestore.dart';

class SavingsSummary {
  final String studentId;
  final String studentName;
  final String classId;
  final double balance;
  final double totalDeposit;
  final double totalWithdrawal;
  final DateTime? updatedAt;

  SavingsSummary({
    required this.studentId,
    required this.studentName,
    required this.classId,
    this.balance = 0.0,
    this.totalDeposit = 0.0,
    this.totalWithdrawal = 0.0,
    this.updatedAt,
  });

  factory SavingsSummary.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return SavingsSummary(
      studentId: data['student_id'] ?? doc.id,
      studentName: data['student_name'] ?? '',
      classId: data['class_id'] ?? '',
      balance: (data['balance'] ?? 0.0).toDouble(),
      totalDeposit: (data['total_deposit'] ?? 0.0).toDouble(),
      totalWithdrawal: (data['total_withdrawal'] ?? 0.0).toDouble(),
      updatedAt: data['updated_at'] != null ? (data['updated_at'] as Timestamp).toDate() : null,
    );
  }
}

class SavingsTransaction {
  final String id;
  final String type; // 'DEPOSIT' or 'WITHDRAWAL'
  final double amount;
  final DateTime date;
  final String note;
  final DateTime? createdAt;
  final String? createdBy;

  SavingsTransaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.date,
    this.note = '',
    this.createdAt,
    this.createdBy,
  });

  factory SavingsTransaction.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return SavingsTransaction(
      id: doc.id,
      type: data['type'] ?? 'DEPOSIT',
      amount: (data['amount'] ?? 0.0).toDouble(),
      date: data['date'] != null ? (data['date'] as Timestamp).toDate() : DateTime.now(),
      note: data['note'] ?? '',
      createdAt: data['created_at'] != null ? (data['created_at'] as Timestamp).toDate() : null,
      createdBy: data['created_by'] ?? '',
    );
  }
}
