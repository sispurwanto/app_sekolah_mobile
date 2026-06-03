import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/models/invoice.dart';

class InvoiceService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Get stream of invoices for a school
  Stream<List<Invoice>> getInvoices(String schoolId) {
    return _db
        .collection('schools')
        .doc(schoolId)
        .collection('invoices')
        .orderBy('due_date', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => Invoice.fromFirestore(doc)).toList();
    });
  }

  // Create invoice
  Future<void> addInvoice(String schoolId, Invoice invoice) async {
    final docRef = _db.collection('schools').doc(schoolId).collection('invoices').doc();
    final idToUse = invoice.id.isEmpty ? docRef.id : invoice.id;
    
    await _db
        .collection('schools')
        .doc(schoolId)
        .collection('invoices')
        .doc(idToUse)
        .set(invoice.toMap());
  }

  // Update invoice
  Future<void> updateInvoice(String schoolId, Invoice invoice) async {
    await _db
        .collection('schools')
        .doc(schoolId)
        .collection('invoices')
        .doc(invoice.id)
        .update(invoice.toMap());
  }

  // Delete invoice
  Future<void> deleteInvoice(String schoolId, String invoiceId) async {
    await _db
        .collection('schools')
        .doc(schoolId)
        .collection('invoices')
        .doc(invoiceId)
        .delete();
  }
}
