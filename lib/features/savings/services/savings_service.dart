import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/models/savings.dart';

class SavingsService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Get stream of SavingsSummary for a specific student
  Stream<SavingsSummary?> getSavingsSummaryStream(
    String schoolId,
    String studentId,
  ) {
    return _db
        .collection('schools')
        .doc(schoolId)
        .collection('savings')
        .doc(studentId)
        .snapshots()
        .map((doc) => doc.exists ? SavingsSummary.fromFirestore(doc) : null);
  }

  // Fetch all active savings summaries for reporting (Future)
  Future<List<SavingsSummary>> fetchAllSavingsSummaries(
    String schoolId, {
    Source source = Source.serverAndCache,
  }) async {
    final snapshot = await _db
        .collection('schools')
        .doc(schoolId)
        .collection('savings')
        .where('balance', isGreaterThan: 0)
        .get(GetOptions(source: source));
    return snapshot.docs
        .map((doc) => SavingsSummary.fromFirestore(doc))
        .toList();
  }

  // Get stream of recent transactions for a student
  Stream<List<SavingsTransaction>> getTransactionsStream(
    String schoolId,
    String studentId,
  ) {
    final oneMonthAgo = DateTime.now().subtract(const Duration(days: 30));
    return _db
        .collection('schools')
        .doc(schoolId)
        .collection('savings')
        .doc(studentId)
        .collection('transactions')
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(oneMonthAgo))
        .orderBy('date', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => SavingsTransaction.fromFirestore(doc))
              .toList(),
        );
  }

  // Add a new transaction using a Firestore Transaction to ensure data consistency
  Future<void> addTransaction({
    required String schoolId,
    required String studentId,
    required String studentName,
    required String classId,
    required String type, // 'DEPOSIT' or 'WITHDRAWAL'
    required double amount,
    required String note,
    required DateTime date,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (amount <= 0) throw Exception('Nominal harus lebih dari 0');

    final summaryRef = _db
        .collection('schools')
        .doc(schoolId)
        .collection('savings')
        .doc(studentId);
    final transactionRef = summaryRef.collection('transactions').doc();

    await _db.runTransaction((transaction) async {
      final summarySnapshot = await transaction.get(summaryRef);

      double currentBalance = 0;
      double totalDeposit = 0;
      double totalWithdrawal = 0;

      if (summarySnapshot.exists) {
        currentBalance = (summarySnapshot.data()?['balance'] ?? 0.0).toDouble();
        totalDeposit = (summarySnapshot.data()?['total_deposit'] ?? 0.0)
            .toDouble();
        totalWithdrawal = (summarySnapshot.data()?['total_withdrawal'] ?? 0.0)
            .toDouble();
      }

      if (type == 'WITHDRAWAL' && currentBalance < amount) {
        throw Exception('Saldo tidak mencukupi untuk melakukan penarikan.');
      }

      // Update calculations
      double newBalance = currentBalance;
      if (type == 'DEPOSIT') {
        newBalance += amount;
        totalDeposit += amount;
      } else if (type == 'WITHDRAWAL') {
        newBalance -= amount;
        totalWithdrawal += amount;
      } else {
        throw Exception('Tipe transaksi tidak valid');
      }

      // 1. Set the transaction record
      transaction.set(transactionRef, {
        'type': type,
        'amount': amount,
        'date': Timestamp.fromDate(date),
        'note': note,
        'created_at': FieldValue.serverTimestamp(),
        'created_by': uid,
      });

      // 2. Set/Update the summary record
      transaction.set(summaryRef, {
        'student_id': studentId,
        'student_name': studentName,
        'class_id': classId,
        'balance': newBalance,
        'total_deposit': totalDeposit,
        'total_withdrawal': totalWithdrawal,
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }
}
