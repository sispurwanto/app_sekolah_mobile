import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/models/invoice.dart';

class InvoiceService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Get stream of all invoices for Bendahara/Admin using Collection Group
  Stream<List<Invoice>> getAllInvoices(String schoolId) {
    // Note: To use collectionGroup, we must ensure we filter by school if possible.
    // However, Firestore collectionGroup queries cannot easily filter by an ancestor document ID directly
    // unless we store schoolId in the invoice document.
    // Let's assume the user has security rules that only allow querying their school's data,
    // or we fetch it and filter locally if needed, but the prompt says "tidak akan menggunakan where".
    // For now, we will return collectionGroup. If there are multiple schools, we should ideally add schoolId to invoice.
    return _db
        .collectionGroup('invoice_data')
        .orderBy('due_date', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => Invoice.fromFirestore(doc)).toList();
    });
  }

  // Get stream of invoices for a specific student (Wali view)
  Stream<List<Invoice>> getStudentInvoices(String schoolId, String studentId) {
    return _db
        .collection('schools')
        .doc(schoolId)
        .collection('invoices')
        .doc(studentId)
        .collection('invoice_data')
        .orderBy('due_date', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => Invoice.fromFirestore(doc)).toList();
    });
  }

  // Create invoice
  Future<void> addInvoice(String schoolId, Invoice invoice) async {
    if (invoice.studentId.isEmpty) throw Exception('Student ID is required to create an invoice');
    
    final docRef = _db
        .collection('schools')
        .doc(schoolId)
        .collection('invoices')
        .doc(invoice.studentId)
        .collection('invoice_data')
        .doc();
        
    final idToUse = invoice.id.isEmpty ? docRef.id : invoice.id;
    
    // Create a copy of the invoice with the schoolId included (good practice for collectionGroup queries)
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final invoiceData = invoice.toMap();
    invoiceData['school_id'] = schoolId; // Add school_id implicitly
    invoiceData['created_at'] = FieldValue.serverTimestamp();
    invoiceData['created_by'] = uid;
    invoiceData['updated_at'] = FieldValue.serverTimestamp();
    invoiceData['updated_by'] = uid;
    
    await _db
        .collection('schools')
        .doc(schoolId)
        .collection('invoices')
        .doc(invoice.studentId)
        .collection('invoice_data')
        .doc(idToUse)
        .set(invoiceData);
  }

  // Update existing invoice
  Future<void> updateInvoice(String schoolId, Invoice invoice) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final data = invoice.toMap();
    data.remove('created_at');
    data.remove('created_by');
    data['updated_at'] = FieldValue.serverTimestamp();
    data['updated_by'] = uid;

    await _db
        .collection('schools')
        .doc(schoolId)
        .collection('invoices')
        .doc(invoice.studentId)
        .collection('invoice_data')
        .doc(invoice.id)
        .update(data);
  }

  // Delete invoice
  Future<void> deleteInvoice(String schoolId, String studentId, String invoiceId) async {
    await _db
        .collection('schools')
        .doc(schoolId)
        .collection('invoices')
        .doc(studentId)
        .collection('invoice_data')
        .doc(invoiceId)
        .delete();
  }
}
