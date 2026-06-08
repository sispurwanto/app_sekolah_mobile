import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/models/invoice.dart';
import '../../../core/models/fee_template.dart';

class InvoiceService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Get stream of all invoices for Bendahara/Admin using Collection Group
  Stream<List<Invoice>> getAllInvoices(String schoolId, String academicYearId) {
    return _db
        .collectionGroup('invoice_data')
        .where('school_id', isEqualTo: schoolId) // Filter by school
        .where('academic_year_id', isEqualTo: academicYearId) // Filter by active academic year
        .orderBy('due_date', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => Invoice.fromFirestore(doc)).toList();
    });
  }

  // Get arrears (tunggakan) invoices across the school within a due_date range
  Future<List<Invoice>> getArrearsByDateRange(String schoolId, String academicYearId, DateTime startDate, DateTime endDate) async {
    final startTimestamp = Timestamp.fromDate(DateTime(startDate.year, startDate.month, startDate.day, 0, 0, 0));
    final endTimestamp = Timestamp.fromDate(DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59));

    // Bypassing collectionGroup to avoid Firebase Index requirement:
    // We will fetch all students in the school, then fetch their invoices concurrently.
    final studentsSnapshot = await _db.collection('schools').doc(schoolId).collection('students').get();
    
    List<Invoice> invoices = [];
    
    final futures = studentsSnapshot.docs.map((studentDoc) async {
      final studentId = studentDoc.id;
      final classId = studentDoc.data()['class_id'] as String?;
      if (classId == null || classId.isEmpty) return <Invoice>[];

      final invSnapshot = await _db
          .collection('schools')
          .doc(schoolId)
          .collection('transactions_year')
          .doc(academicYearId)
          .collection('invoices')
          .doc(classId)
          .collection('invoices_class_data')
          .doc(studentId)
          .collection('invoice_data')
          .get();
          
      return invSnapshot.docs.map((doc) => Invoice.fromFirestore(doc)).toList();
    });

    final results = await Future.wait(futures);
    for (var list in results) {
      invoices.addAll(list);
    }
    
    // Filter by due_date range and status locally to avoid composite index requirement
    final filtered = invoices.where((inv) {
      if (inv.status != 'UNPAID' && inv.status != 'PARTIAL') return false;
      if (inv.dueDate == null) return false;
      return inv.dueDate!.isAfter(startTimestamp.toDate().subtract(const Duration(seconds: 1))) && 
             inv.dueDate!.isBefore(endTimestamp.toDate().add(const Duration(seconds: 1)));
    }).toList();

    // Sort by due date
    filtered.sort((a, b) => a.dueDate!.compareTo(b.dueDate!));

    return filtered;
  }

  // Get stream of invoices for a specific student in a specific academic year and class
  // Path: schools/{schoolId}/transactions_year/{academicYearId}/invoices/{classId}/invoices_class_data/{studentId}/invoice_data
  Stream<List<Invoice>> getStudentInvoices(String schoolId, String academicYearId, String classId, String studentId) {
    return _db
        .collection('schools')
        .doc(schoolId)
        .collection('transactions_year')
        .doc(academicYearId)
        .collection('invoices')
        .doc(classId)
        .collection('invoices_class_data')
        .doc(studentId)
        .collection('invoice_data')
        .snapshots()
        .map((snapshot) {
      var invoices = snapshot.docs.map((doc) => Invoice.fromFirestore(doc)).toList();
      invoices.sort((a, b) {
        int weight(String status) => status == 'PAID' ? 0 : status == 'PARTIAL' ? 1 : 2;
        int statusCmp = weight(a.status).compareTo(weight(b.status));
        if (statusCmp != 0) return statusCmp;
        return (a.dueDate ?? DateTime.now()).compareTo(b.dueDate ?? DateTime.now());
      });
      return invoices;
    });
  }

  // Create manual invoice
  Future<void> addInvoice(String schoolId, Invoice invoice) async {
    if (invoice.studentId.isEmpty) throw Exception('Student ID is required to create an invoice');
    if (invoice.academicYearId.isEmpty) throw Exception('Academic Year ID is required');
    if (invoice.classId.isEmpty) throw Exception('Class ID is required');
    
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final batch = _db.batch();

    final classInvoiceRef = _db
        .collection('schools')
        .doc(schoolId)
        .collection('transactions_year')
        .doc(invoice.academicYearId)
        .collection('invoices')
        .doc(invoice.classId);

    batch.set(classInvoiceRef, {
      'status': 'ACTIVE',
      'updated_at': FieldValue.serverTimestamp(),
      'updated_by': uid,
    }, SetOptions(merge: true));

    final studentInvoiceRef = classInvoiceRef
        .collection('invoices_class_data')
        .doc(invoice.studentId);

    batch.set(studentInvoiceRef, {
      'status': 'ACTIVE',
      'updated_at': FieldValue.serverTimestamp(),
      'updated_by': uid,
    }, SetOptions(merge: true));
        
    final docRef = studentInvoiceRef.collection('invoice_data').doc();
    final idToUse = invoice.id.isEmpty ? docRef.id : invoice.id;
    
    final invoiceData = invoice.toMap();
    invoiceData['school_id'] = schoolId;
    invoiceData['created_at'] = FieldValue.serverTimestamp();
    invoiceData['created_by'] = uid;
    invoiceData['updated_at'] = FieldValue.serverTimestamp();
    invoiceData['updated_by'] = uid;
    
    batch.set(studentInvoiceRef.collection('invoice_data').doc(idToUse), invoiceData);

    await batch.commit();
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
        .collection('transactions_year')
        .doc(invoice.academicYearId)
        .collection('invoices')
        .doc(invoice.classId)
        .collection('invoices_class_data')
        .doc(invoice.studentId)
        .collection('invoice_data')
        .doc(invoice.id)
        .update(data);
  }

  // Delete invoice
  Future<void> deleteInvoice(String schoolId, String academicYearId, String classId, String studentId, String invoiceId) async {
    await _db
        .collection('schools')
        .doc(schoolId)
        .collection('transactions_year')
        .doc(academicYearId)
        .collection('invoices')
        .doc(classId)
        .collection('invoices_class_data')
        .doc(studentId)
        .collection('invoice_data')
        .doc(invoiceId)
        .delete();
  }

  // Generate Invoices for a specific student based on Fee Templates
  Future<void> generateInvoicesForStudent({
    required String schoolId,
    required String academicYearId,
    required String classId,
    required String studentId,
    required String studentName,
  }) async {
    if (classId.isEmpty || academicYearId.isEmpty) return;

    // 1. Fetch all Fee Templates for this school
    final templatesSnapshot = await _db
        .collection('schools')
        .doc(schoolId)
        .collection('fee_templates')
        .get();

    final templates = templatesSnapshot.docs.map((doc) => FeeTemplate.fromFirestore(doc)).toList();

    // 2. Filter templates (Generic / No Class OR Specific to this class)
    final applicableTemplates = templates.where((t) => t.classId == null || t.classId!.isEmpty || t.classId == classId).toList();

    if (applicableTemplates.isEmpty) return;

    // 3. Prepare batch write
    final batch = _db.batch();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    
    final classInvoiceRef = _db
        .collection('schools')
        .doc(schoolId)
        .collection('transactions_year')
        .doc(academicYearId)
        .collection('invoices')
        .doc(classId);

    batch.set(classInvoiceRef, {
      'status': 'ACTIVE',
      'updated_at': FieldValue.serverTimestamp(),
      'updated_by': uid,
    }, SetOptions(merge: true));

    final studentInvoiceRef = classInvoiceRef
        .collection('invoices_class_data')
        .doc(studentId);

    batch.set(studentInvoiceRef, {
      'status': 'ACTIVE',
      'updated_at': FieldValue.serverTimestamp(),
      'updated_by': uid,
    }, SetOptions(merge: true));
    
    final invoiceCollectionRef = studentInvoiceRef.collection('invoice_data');

    // 4. Check existing invoices to prevent duplicates
    final existingInvoicesSnapshot = await invoiceCollectionRef.get();
    final existingTitles = existingInvoicesSnapshot.docs.map((doc) => doc.data()['title'] as String).toSet();

    for (var template in applicableTemplates) {
      if (template.frequency == 'MONTHLY') {
        // Generate 12 months
        final months = [
          {'name': 'Juli', 'number': 7, 'yearOffset': 0},
          {'name': 'Agustus', 'number': 8, 'yearOffset': 0},
          {'name': 'September', 'number': 9, 'yearOffset': 0},
          {'name': 'Oktober', 'number': 10, 'yearOffset': 0},
          {'name': 'November', 'number': 11, 'yearOffset': 0},
          {'name': 'Desember', 'number': 12, 'yearOffset': 0},
          {'name': 'Januari', 'number': 1, 'yearOffset': 1},
          {'name': 'Februari', 'number': 2, 'yearOffset': 1},
          {'name': 'Maret', 'number': 3, 'yearOffset': 1},
          {'name': 'April', 'number': 4, 'yearOffset': 1},
          {'name': 'Mei', 'number': 5, 'yearOffset': 1},
          {'name': 'Juni', 'number': 6, 'yearOffset': 1},
        ];

        // Extract base year from academicYearId if possible
        int baseYear = DateTime.now().year;
        final yearMatch = RegExp(r'(\d{4})').firstMatch(academicYearId);
        if (yearMatch != null) {
          baseYear = int.parse(yearMatch.group(1)!);
        }

        for (var month in months) {
          final invoiceTitle = '${template.title} - ${month['name']}';
          if (!existingTitles.contains(invoiceTitle)) {
            final docRef = invoiceCollectionRef.doc();
            
            // Calc due date
            DateTime dueDate = DateTime.now();
            if (template.dueDateDay != null) {
              int targetYear = baseYear + (month['yearOffset'] as int);
              int targetMonth = month['number'] as int;
              int targetDay = template.dueDateDay!;
              // handle invalid day
              dueDate = DateTime(targetYear, targetMonth, targetDay);
            }

            batch.set(docRef, {
              'studentId': studentId,
              'studentName': studentName,
              'title': invoiceTitle,
              'amount': template.amount,
              'paid_amount': 0.0,
              'status': 'UNPAID',
              'due_date': Timestamp.fromDate(dueDate),
              'school_id': schoolId,
              'academic_year_id': academicYearId,
              'class_id': classId,
              'created_at': FieldValue.serverTimestamp(),
              'created_by': uid,
              'updated_at': FieldValue.serverTimestamp(),
              'updated_by': uid,
            });
          }
        }
      } else {
        // ONCE / YEARLY
        if (!existingTitles.contains(template.title)) {
          final docRef = invoiceCollectionRef.doc(); // Auto ID
          
          DateTime dueDate = template.exactDueDate ?? DateTime.now();
          
          final invoiceData = {
            'student_id': studentId,
            'student_name': studentName,
            'title': template.title,
            'amount': template.amount,
            'paid_amount': 0.0,
            'status': 'UNPAID',
            'due_date': Timestamp.fromDate(dueDate),
            'school_id': schoolId,
            'academic_year_id': academicYearId,
            'class_id': classId,
            'created_at': FieldValue.serverTimestamp(),
            'created_by': uid,
            'updated_at': FieldValue.serverTimestamp(),
            'updated_by': uid,
          };
          
          batch.set(docRef, invoiceData);
        }
      }
    }

    // 5. Commit batch
    await batch.commit();
  }

  // Bulk Generate Invoices for a specific Template across all applicable students
  Future<void> generateInvoicesForTemplate({
    required String schoolId,
    required String academicYearId,
    required FeeTemplate template,
  }) async {
    if (academicYearId.isEmpty) throw Exception('Tahun Ajaran aktif belum diatur');

    // 1. Get all students that match the template class (or all active students if template class is empty)
    Query query = _db
        .collection('schools')
        .doc(schoolId)
        .collection('students')
        .where('academic_year_id', isEqualTo: academicYearId)
        .where('status', isEqualTo: 'ACTIVE');
        
    if (template.classId != null && template.classId!.isNotEmpty) {
      query = query.where('class_id', isEqualTo: template.classId);
    }
    
    final studentSnapshots = await query.get();
    if (studentSnapshots.docs.isEmpty) return; // No students found
    
    final students = studentSnapshots.docs;
    final uid = FirebaseAuth.instance.currentUser?.uid;

    // Process in chunks of 100 students to avoid exceeding Firestore batch limit of 500
    for (var i = 0; i < students.length; i += 100) {
      final chunk = students.skip(i).take(100).toList();
      final batch = _db.batch();
      
      for (var studentDoc in chunk) {
        final data = studentDoc.data() as Map<String, dynamic>;
        final studentId = studentDoc.id;
        final studentName = data['name'] ?? '';
        final classId = data['class_id'] ?? '';
        final status = data['status'] ?? 'ACTIVE';
        
        if (classId.isEmpty || status != 'ACTIVE') continue;
        
        final classInvoiceRef = _db
            .collection('schools')
            .doc(schoolId)
            .collection('transactions_year')
            .doc(academicYearId)
            .collection('invoices')
            .doc(classId);

        batch.set(classInvoiceRef, {
          'status': 'ACTIVE',
          'updated_at': FieldValue.serverTimestamp(),
          'updated_by': uid,
        }, SetOptions(merge: true));

        final studentInvoiceRef = classInvoiceRef
            .collection('invoices_class_data')
            .doc(studentId);

        batch.set(studentInvoiceRef, {
          'status': 'ACTIVE',
          'updated_at': FieldValue.serverTimestamp(),
          'updated_by': uid,
        }, SetOptions(merge: true));
        
        if (template.frequency == 'MONTHLY') {
          // Generate 12 months
          final months = [
            {'name': 'Juli', 'number': 7, 'yearOffset': 0},
            {'name': 'Agustus', 'number': 8, 'yearOffset': 0},
            {'name': 'September', 'number': 9, 'yearOffset': 0},
            {'name': 'Oktober', 'number': 10, 'yearOffset': 0},
            {'name': 'November', 'number': 11, 'yearOffset': 0},
            {'name': 'Desember', 'number': 12, 'yearOffset': 0},
            {'name': 'Januari', 'number': 1, 'yearOffset': 1},
            {'name': 'Februari', 'number': 2, 'yearOffset': 1},
            {'name': 'Maret', 'number': 3, 'yearOffset': 1},
            {'name': 'April', 'number': 4, 'yearOffset': 1},
            {'name': 'Mei', 'number': 5, 'yearOffset': 1},
            {'name': 'Juni', 'number': 6, 'yearOffset': 1},
          ];

          int baseYear = DateTime.now().year;
          final yearMatch = RegExp(r'(\d{4})').firstMatch(academicYearId);
          if (yearMatch != null) {
            baseYear = int.parse(yearMatch.group(1)!);
          }

          for (var month in months) {
            final invoiceTitle = '${template.title} - ${month['name']}';
            
            // Note: In bulk generation we check existing query which is just for one title at a time.
            // Since we process Monthly, we need to check if ANY invoice contains this title.
            // Since we previously only queried `template.title`, we should query all invoices.
            // However, querying ALL existing invoices per student is inefficient in the inner loop.
            // But we already have a collection query. Let's just create them blindly unless we fetched all first.
            // Actually, we must prevent duplicates. Let's just do a quick get for the specific title.
            final existingCheck = await studentInvoiceRef.collection('invoice_data')
                .where('title', isEqualTo: invoiceTitle)
                .get();

            if (existingCheck.docs.isEmpty) {
              final docRef = studentInvoiceRef.collection('invoice_data').doc();
              
              DateTime dueDate = DateTime.now();
              if (template.dueDateDay != null) {
                int targetYear = baseYear + (month['yearOffset'] as int);
                int targetMonth = month['number'] as int;
                int targetDay = template.dueDateDay!;
                dueDate = DateTime(targetYear, targetMonth, targetDay);
              }

              batch.set(docRef, {
                'student_id': studentId,
                'student_name': studentName,
                'title': invoiceTitle,
                'amount': template.amount,
                'paid_amount': 0.0,
                'status': 'UNPAID',
                'due_date': Timestamp.fromDate(dueDate),
                'school_id': schoolId,
                'academic_year_id': academicYearId,
                'class_id': classId,
                'created_at': FieldValue.serverTimestamp(),
                'created_by': uid,
                'updated_at': FieldValue.serverTimestamp(),
                'updated_by': uid,
              });
            }
          }
        } else {
          // ONCE / YEARLY
          final existingInvoices = await studentInvoiceRef.collection('invoice_data')
              .where('title', isEqualTo: template.title)
              .get();
              
          if (existingInvoices.docs.isEmpty) {
            final docRef = studentInvoiceRef.collection('invoice_data').doc();
            DateTime dueDate = template.exactDueDate ?? DateTime.now();
            
            batch.set(docRef, {
              'student_id': studentId,
              'student_name': studentName,
              'title': template.title,
              'amount': template.amount,
              'paid_amount': 0.0,
              'status': 'UNPAID',
              'due_date': Timestamp.fromDate(dueDate),
              'school_id': schoolId,
              'academic_year_id': academicYearId,
              'class_id': classId,
              'created_at': FieldValue.serverTimestamp(),
              'created_by': uid,
              'updated_at': FieldValue.serverTimestamp(),
              'updated_by': uid,
            });
          }
        }
      }
      
      await batch.commit();
    }
  }
}
