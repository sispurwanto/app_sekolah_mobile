import 'package:cloud_firestore/cloud_firestore.dart';

class Payment {
  final String id;
  final String invoiceId;
  final String invoiceTitle;
  final List<String>? invoiceIds;
  final List<String>? invoiceTitles;
  final List<double>? invoiceAmounts;
  final String studentId;
  final String studentName;
  final String classId;
  final double amount;
  final String method; // CASH, TRANSFER
  final String status; // PENDING, APPROVED, REJECTED
  final String referenceNote;
  final String schoolId;
  final String academicYearId;
  final DateTime? createdAt;
  final String? createdBy;
  final DateTime? updatedAt;
  final String? updatedBy;

  Payment({
    required this.id,
    required this.invoiceId,
    required this.invoiceTitle,
    this.invoiceIds,
    this.invoiceTitles,
    this.invoiceAmounts,
    required this.studentId,
    required this.studentName,
    required this.classId,
    required this.amount,
    required this.method,
    required this.status,
    this.referenceNote = '',
    required this.schoolId,
    required this.academicYearId,
    this.createdAt,
    this.createdBy,
    this.updatedAt,
    this.updatedBy,
  });

  factory Payment.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Payment(
      id: doc.id,
      invoiceId: data['invoice_id'] ?? '',
      invoiceTitle: data['invoice_title'] ?? '',
      invoiceIds: data['invoice_ids'] != null
          ? List<String>.from(data['invoice_ids'])
          : null,
      invoiceTitles: data['invoice_titles'] != null
          ? List<String>.from(data['invoice_titles'])
          : null,
      invoiceAmounts: data['invoice_amounts'] != null
          ? List<dynamic>.from(
              data['invoice_amounts'],
            ).map((e) => (e as num).toDouble()).toList()
          : null,
      studentId: data['student_id'] ?? '',
      studentName: data['student_name'] ?? '',
      classId: data['class_id'] ?? '',
      amount: (data['amount'] ?? 0).toDouble(),
      method: data['method'] ?? 'CASH',
      status: data['status'] ?? 'PENDING',
      referenceNote: data['reference_note'] ?? '',
      schoolId: data['school_id'] ?? '',
      academicYearId: data['academic_year_id'] ?? '',
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
    final Map<String, dynamic> result = {
      'invoice_id': invoiceId,
      'invoice_title': invoiceTitle,
      'student_id': studentId,
      'student_name': studentName,
      'class_id': classId,
      'amount': amount,
      'method': method,
      'status': status,
      'reference_note': referenceNote,
      'school_id': schoolId,
      'academic_year_id': academicYearId,
      'created_at': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
    };
    if (invoiceIds != null) result['invoice_ids'] = invoiceIds;
    if (invoiceTitles != null) result['invoice_titles'] = invoiceTitles;
    if (invoiceAmounts != null) result['invoice_amounts'] = invoiceAmounts;
    return result;
  }
}
