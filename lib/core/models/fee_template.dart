import 'package:cloud_firestore/cloud_firestore.dart';

class FeeTemplate {
  final String id;
  final String title;
  final double amount;
  final String? classId;
  final DateTime? createdAt;
  final String? createdBy;
  final DateTime? updatedAt;
  final String? updatedBy;

  FeeTemplate({
    required this.id,
    required this.title,
    required this.amount,
    this.classId,
    this.createdAt,
    this.createdBy,
    this.updatedAt,
    this.updatedBy,
  });

  factory FeeTemplate.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return FeeTemplate(
      id: doc.id,
      title: data['title'] ?? '',
      amount: (data['amount'] ?? 0).toDouble(),
      classId: data['class_id'],
      createdAt: data['created_at'] != null ? (data['created_at'] as Timestamp).toDate() : null,
      createdBy: data['created_by'],
      updatedAt: data['updated_at'] != null ? (data['updated_at'] as Timestamp).toDate() : null,
      updatedBy: data['updated_by'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'amount': amount,
      'class_id': classId,
    };
  }
}
