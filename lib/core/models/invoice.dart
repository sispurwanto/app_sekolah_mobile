import 'package:cloud_firestore/cloud_firestore.dart';

class Invoice {
  final String id;
  final String studentId;
  final String studentName;
  final String title;
  final double amount;
  final String status; // 'UNPAID', 'PARTIAL', 'PAID'
  final DateTime dueDate;
  final DateTime? createdAt;

  Invoice({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.title,
    required this.amount,
    required this.status,
    required this.dueDate,
    this.createdAt,
  });

  factory Invoice.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Invoice(
      id: doc.id,
      studentId: data['student_id'] ?? '',
      studentName: data['student_name'] ?? 'Unknown',
      title: data['title'] ?? 'Tagihan',
      amount: (data['amount'] ?? 0).toDouble(),
      status: data['status'] ?? 'UNPAID',
      dueDate: data['due_date'] != null 
          ? (data['due_date'] as Timestamp).toDate() 
          : DateTime.now().add(const Duration(days: 30)),
      createdAt: data['created_at'] != null 
          ? (data['created_at'] as Timestamp).toDate() 
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'student_id': studentId,
      'student_name': studentName,
      'title': title,
      'amount': amount,
      'status': status,
      'due_date': Timestamp.fromDate(dueDate),
      'created_at': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
    };
  }
}
