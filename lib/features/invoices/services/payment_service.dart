import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/models/payment.dart';
import '../../../core/models/invoice.dart';

class PaymentService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Create a new Payment.
  // If method is CASH (done by Kasir/Bendahara), automatically approve it and update invoice.
  // If method is TRANSFER (done by Wali), leave it PENDING.
  Future<void> createPayment(String schoolId, Payment payment, Invoice invoice) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final batch = _db.batch();

    // The payment document reference
    final paymentRef = _db
        .collection('schools')
        .doc(schoolId)
        .collection('transactions_year')
        .doc(payment.academicYearId)
        .collection('payments')
        .doc(); // Auto ID

    final paymentData = payment.toMap();
    paymentData['created_by'] = uid;
    paymentData['updated_at'] = FieldValue.serverTimestamp();
    paymentData['updated_by'] = uid;

    batch.set(paymentRef, paymentData);

    // If it's cash, it is automatically approved, so we update the invoice immediately
    if (payment.method == 'CASH' && payment.status == 'APPROVED') {
      final double newPaidAmount = invoice.paidAmount + payment.amount;
      String newStatus = invoice.status;
      
      if (newPaidAmount >= invoice.amount) {
        newStatus = 'PAID';
      } else if (newPaidAmount > 0) {
        newStatus = 'PARTIAL';
      }

      final invoiceRef = _db
          .collection('schools')
          .doc(schoolId)
          .collection('transactions_year')
          .doc(invoice.academicYearId)
          .collection('invoices')
          .doc(invoice.classId)
          .collection('invoices_class_data')
          .doc(invoice.studentId)
          .collection('invoice_data')
          .doc(invoice.id);

      batch.update(invoiceRef, {
        'paid_amount': newPaidAmount,
        'status': newStatus,
        'updated_at': FieldValue.serverTimestamp(),
        'updated_by': uid,
      });
    }

    await batch.commit();
  }

  // Create a bulk Payment covering multiple invoices.
  Future<void> createBulkPayment(String schoolId, Payment payment, List<Invoice> invoices) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final batch = _db.batch();

    final paymentRef = _db
        .collection('schools')
        .doc(schoolId)
        .collection('transactions_year')
        .doc(payment.academicYearId)
        .collection('payments')
        .doc();

    final paymentData = payment.toMap();
    paymentData['created_by'] = uid;
    paymentData['updated_at'] = FieldValue.serverTimestamp();
    paymentData['updated_by'] = uid;

    batch.set(paymentRef, paymentData);

    // If CASH, update all invoices immediately
    if (payment.method == 'CASH' && payment.status == 'APPROVED') {
      for (final invoice in invoices) {
        final invoiceRef = _db
            .collection('schools')
            .doc(schoolId)
            .collection('transactions_year')
            .doc(invoice.academicYearId)
            .collection('invoices')
            .doc(invoice.classId)
            .collection('invoices_class_data')
            .doc(invoice.studentId)
            .collection('invoice_data')
            .doc(invoice.id);

        batch.update(invoiceRef, {
          'paid_amount': invoice.amount, // Bulk is always fully paid
          'status': 'PAID',
          'updated_at': FieldValue.serverTimestamp(),
          'updated_by': uid,
        });
      }
    }

    await batch.commit();
  }

  // Approve a pending transfer payment
  // Approve a pending transfer payment (single or bulk)
  Future<void> approvePayment(String schoolId, Payment payment, [Invoice? invoice]) async {
    if (payment.status == 'APPROVED') return;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    final batch = _db.batch();

    // 1. Update Payment status to APPROVED
    final paymentRef = _db
        .collection('schools')
        .doc(schoolId)
        .collection('transactions_year')
        .doc(payment.academicYearId)
        .collection('payments')
        .doc(payment.id);

    batch.update(paymentRef, {
      'status': 'APPROVED',
      'updated_at': FieldValue.serverTimestamp(),
      'updated_by': uid,
    });

    if (payment.invoiceIds != null && payment.invoiceIds!.isNotEmpty) {
      // MULTIPLE OR SINGLE PAYMENT WITHOUT INVOICE OBJECT
      // We iterate over the invoiceIds and use the corresponding amount in invoiceAmounts
      for (int i = 0; i < payment.invoiceIds!.length; i++) {
        final invId = payment.invoiceIds![i];
        final amountPaidForThisInvoice = payment.invoiceAmounts != null && payment.invoiceAmounts!.length > i 
            ? payment.invoiceAmounts![i] 
            : payment.amount;

        final invoiceRef = _db
            .collection('schools')
            .doc(schoolId)
            .collection('transactions_year')
            .doc(payment.academicYearId)
            .collection('invoices')
            .doc(payment.classId)
            .collection('invoices_class_data')
            .doc(payment.studentId)
            .collection('invoice_data')
            .doc(invId);

        final snap = await invoiceRef.get();
        if (snap.exists) {
          final invData = Invoice.fromFirestore(snap);
          final double newPaidAmount = invData.paidAmount + amountPaidForThisInvoice;
          String newStatus = invData.status;

          if (newPaidAmount >= invData.amount) {
            newStatus = 'PAID';
          } else if (newPaidAmount > 0) {
            newStatus = 'PARTIAL';
          }

          batch.update(invoiceRef, {
            'paid_amount': newPaidAmount,
            'status': newStatus,
            'updated_at': FieldValue.serverTimestamp(),
            'updated_by': uid,
          });
        }
      }
    } else if (invoice != null) {
      // SINGLE PAYMENT
      final double newPaidAmount = invoice.paidAmount + payment.amount;
      String newStatus = invoice.status;
      
      if (newPaidAmount >= invoice.amount) {
        newStatus = 'PAID';
      } else if (newPaidAmount > 0) {
        newStatus = 'PARTIAL';
      }

      final invoiceRef = _db
          .collection('schools')
          .doc(schoolId)
          .collection('transactions_year')
          .doc(invoice.academicYearId)
          .collection('invoices')
          .doc(invoice.classId)
          .collection('invoices_class_data')
          .doc(invoice.studentId)
          .collection('invoice_data')
          .doc(invoice.id);

      batch.update(invoiceRef, {
        'paid_amount': newPaidAmount,
        'status': newStatus,
        'updated_at': FieldValue.serverTimestamp(),
        'updated_by': uid,
      });
    }

    await batch.commit();
  }

  // Reject a pending payment
  Future<void> rejectPayment(String schoolId, Payment payment) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    
    await _db
        .collection('schools')
        .doc(schoolId)
        .collection('transactions_year')
        .doc(payment.academicYearId)
        .collection('payments')
        .doc(payment.id)
        .update({
      'status': 'REJECTED',
      'updated_at': FieldValue.serverTimestamp(),
      'updated_by': uid,
    });
  }

  // Get stream of pending payments across the school
  Stream<List<Payment>> getPendingPayments(String schoolId, String academicYearId) {
    return _db
        .collection('schools')
        .doc(schoolId)
        .collection('transactions_year')
        .doc(academicYearId)
        .collection('payments')
        .where('status', isEqualTo: 'PENDING')
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs.map((doc) => Payment.fromFirestore(doc)).toList();
      list.sort((a, b) {
        final aDate = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bDate = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bDate.compareTo(aDate); // descending
      });
      return list;
    });
  }

  // Get approved payments within a specific academic year and date range
  Future<List<Payment>> getApprovedPaymentsByDateRange(String schoolId, String academicYearId, DateTime startDate, DateTime endDate) async {
    final startTimestamp = Timestamp.fromDate(DateTime(startDate.year, startDate.month, startDate.day, 0, 0, 0));
    final endTimestamp = Timestamp.fromDate(DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59));

    final snapshot = await _db
        .collection('schools')
        .doc(schoolId)
        .collection('transactions_year')
        .doc(academicYearId)
        .collection('payments')
        .where('status', isEqualTo: 'APPROVED')
        .get();

    final payments = snapshot.docs.map((doc) => Payment.fromFirestore(doc)).toList();
    
    // Filter by date range
    final filtered = payments.where((p) {
      if (p.createdAt == null) return false;
      return p.createdAt!.isAfter(startTimestamp.toDate().subtract(const Duration(seconds: 1))) && 
             p.createdAt!.isBefore(endTimestamp.toDate().add(const Duration(seconds: 1)));
    }).toList();

    // Sort descending (newest first)
    filtered.sort((a, b) => b.createdAt!.compareTo(a.createdAt!));

    return filtered;
  }

  // Get stream of payments for a specific invoice
  Stream<List<Payment>> getPaymentsForInvoice(String schoolId, String academicYearId, String invoiceId) {
    return _db
        .collection('schools')
        .doc(schoolId)
        .collection('transactions_year')
        .doc(academicYearId)
        .collection('payments')
        .where(Filter.or(
          Filter('invoice_id', isEqualTo: invoiceId),
          Filter('invoice_ids', arrayContains: invoiceId),
        ))
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs.map((doc) => Payment.fromFirestore(doc)).toList();
      list.sort((a, b) {
        final aDate = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bDate = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bDate.compareTo(aDate); // descending
      });
      return list;
    });
  }
}
