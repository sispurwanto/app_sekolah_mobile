import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/models/student.dart';
import '../../invoices/services/invoice_service.dart';
import '../../invoices/services/payment_service.dart';

class StudentService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Get stream of all students
  Stream<List<Student>> getStudents(String schoolId) {
    return _db
        .collection('schools')
        .doc(schoolId)
        .collection('students')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => Student.fromFirestore(doc))
              .toList();
        });
  }

  // Fetch students by class (Future for efficiency)
  Future<List<Student>> fetchStudentsByClass(
    String schoolId,
    String classId, {
    String statusFilter = 'SEMUA',
    Source source = Source.serverAndCache,
  }) async {
    var query = _db
        .collection('schools')
        .doc(schoolId)
        .collection('students');

    // Base Query with status filter (if not ALL and not ACTIVE since ACTIVE is guaranteed in 'students' path)
    Query<Map<String, dynamic>> finalQuery = query;
    if (statusFilter != 'SEMUA') {
      finalQuery = finalQuery.where('status', isEqualTo: statusFilter);
    }

    if (classId.isNotEmpty) {
      final snapshot = await finalQuery
          .where('class_id', isEqualTo: classId)
          .get(GetOptions(source: source));
      return snapshot.docs.map((doc) => Student.fromFirestore(doc)).toList();
    } else {
      // Limit to avoid massive reads
      final snapshot = await finalQuery
          .limit(500)
          .get(GetOptions(source: source));
      return snapshot.docs.map((doc) => Student.fromFirestore(doc)).toList();
    }
  }

  Future<Student?> getStudentById(String schoolId, String studentId) async {
    var doc = await _db
        .collection('schools')
        .doc(schoolId)
        .collection('students')
        .doc(studentId)
        .get();

    if (doc.exists) {
      return Student.fromFirestore(doc);
    }
    return null;
  }

  // Get stream of a single student (useful for WALI)
  Stream<Student?> getStudentStream(String schoolId, String studentId) async* {
    yield* _db
        .collection('schools')
        .doc(schoolId)
        .collection('students')
        .doc(studentId)
        .snapshots()
        .map((snapshot) {
          if (!snapshot.exists) return null;
          return Student.fromFirestore(snapshot);
        });
  }

  // Create student
  Future<void> addStudent(String schoolId, Student student) async {
    final batch = _db.batch();

    // Gunakan NIS sebagai ID Dokumen
    final idToUse = student.nis;
    final studentRef = _db
        .collection('schools')
        .doc(schoolId)
        .collection('students')
        .doc(idToUse);

    // Save student
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final studentData = student.toMap();
    studentData['created_at'] = FieldValue.serverTimestamp();
    studentData['created_by'] = uid;
    studentData['updated_at'] = FieldValue.serverTimestamp();
    studentData['updated_by'] = uid;

    batch.set(studentRef, studentData);

    // If there is a guardian, auto link in guardian's document
    if (student.guardianId.isNotEmpty) {
      final guardianRef = _db
          .collection('schools')
          .doc(schoolId)
          .collection('users')
          .doc(student.guardianId);
      batch.set(guardianRef, {
        'childrens': {idToUse: true},
      }, SetOptions(merge: true));
    }

    if (student.academicYearId.isNotEmpty && student.classId.isNotEmpty) {
      final classDocRef = _db
          .collection('schools')
          .doc(schoolId)
          .collection('transactions_year')
          .doc(student.academicYearId)
          .collection('class_data')
          .doc(student.classId);

      // Create placeholder for class_data so it exists in Firebase Console
      batch.set(classDocRef, {
        'status': 'ACTIVE',
        'created_at': FieldValue.serverTimestamp(),
        'created_by': uid,
        'updated_at': FieldValue.serverTimestamp(),
        'updated_by': uid,
      }, SetOptions(merge: true));

      final classDataRef = classDocRef.collection('students').doc(idToUse);

      final studentClassData =
          studentData; // Use the same data as the master student
      studentClassData['status'] = 'ACTIVE';
      studentClassData['joined_at'] = FieldValue.serverTimestamp();

      batch.set(classDataRef, studentClassData);
    }

    await batch.commit();
  }

  // Update student
  Future<void> updateStudent(String schoolId, Student student) async {
    final batch = _db.batch();

    final studentRef = _db
        .collection('schools')
        .doc(schoolId)
        .collection('students')
        .doc(student.id);

    final studentData = student.toMap();
    if (student.status == 'INACTIVE' || student.status == 'GRADUATED') {
      studentData['class_id'] = '';
      studentData['school_id'] = '';
    }

    // To handle guardian changes perfectly, we would need the old guardian id to remove the child from their map.
    // For simplicity, we just ensure the new guardian gets the child added.
    batch.set(studentRef, studentData, SetOptions(merge: true));

    if (student.guardianId.isNotEmpty) {
      final guardianRef = _db
          .collection('schools')
          .doc(schoolId)
          .collection('users')
          .doc(student.guardianId);
      batch.set(guardianRef, {
        'childrens': {student.id: true},
      }, SetOptions(merge: true));
    }

    if (student.academicYearId.isNotEmpty && student.classId.isNotEmpty) {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      final classDocRef = _db
          .collection('schools')
          .doc(schoolId)
          .collection('transactions_year')
          .doc(student.academicYearId)
          .collection('class_data')
          .doc(student.classId);

      // Update placeholder for class_data
      batch.set(classDocRef, {
        'status': 'ACTIVE',
        'updated_at': FieldValue.serverTimestamp(),
        'updated_by': uid,
      }, SetOptions(merge: true));

      final classDataRef = classDocRef.collection('students').doc(student.id);

      final studentClassData = student.toMap();
      studentClassData['status'] = 'ACTIVE';
      studentClassData['updated_at'] = FieldValue.serverTimestamp();

      batch.set(classDataRef, studentClassData, SetOptions(merge: true));
    }

    await batch.commit();
  }

  // Delete student
  Future<void> deleteStudent(
    String schoolId,
    String studentId,
    String guardianId,
  ) async {
    final batch = _db.batch();
    final studentRef = _db
        .collection('schools')
        .doc(schoolId)
        .collection('students')
        .doc(studentId);

    batch.delete(studentRef);

    if (guardianId.isNotEmpty) {
      final guardianRef = _db
          .collection('schools')
          .doc(schoolId)
          .collection('users')
          .doc(guardianId);
      // Remove child from map
      batch.update(guardianRef, {'childrens.$studentId': FieldValue.delete()});
    }

    await batch.commit();
  }
}
