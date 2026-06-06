import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/models/student.dart';

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
      return snapshot.docs.map((doc) => Student.fromFirestore(doc)).toList();
    });
  }

  Future<Student?> getStudentById(String schoolId, String studentId) async {
    final doc = await _db
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
  Stream<Student?> getStudentStream(String schoolId, String studentId) {
    return _db
        .collection('schools')
        .doc(schoolId)
        .collection('students')
        .doc(studentId)
        .snapshots()
        .map((doc) {
      if (!doc.exists) return null;
      return Student.fromFirestore(doc);
    });
  }

  // Create student
  Future<void> addStudent(String schoolId, Student student) async {
    final batch = _db.batch();
    
    // Gunakan NIS sebagai ID Dokumen
    final idToUse = student.nis; 
    final studentRef = _db.collection('schools').doc(schoolId).collection('students').doc(idToUse);
    
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
      final guardianRef = _db.collection('schools').doc(schoolId).collection('users').doc(student.guardianId);
      batch.set(
        guardianRef,
        {
          'childrens': {
            idToUse: true,
          }
        },
        SetOptions(merge: true)
      );
    }

    await batch.commit();
  }

  // Update student
  Future<void> updateStudent(String schoolId, Student student) async {
    final batch = _db.batch();
    final studentRef = _db.collection('schools').doc(schoolId).collection('students').doc(student.id);

    // To handle guardian changes perfectly, we would need the old guardian id to remove the child from their map.
    // For simplicity, we just ensure the new guardian gets the child added.
    batch.update(studentRef, student.toMap());

    if (student.guardianId.isNotEmpty) {
      final guardianRef = _db.collection('schools').doc(schoolId).collection('users').doc(student.guardianId);
      batch.set(
        guardianRef,
        {
          'childrens': {
            student.id: true,
          }
        },
        SetOptions(merge: true)
      );
    }

    await batch.commit();
  }

  // Delete student
  Future<void> deleteStudent(String schoolId, String studentId, String guardianId) async {
    final batch = _db.batch();
    final studentRef = _db.collection('schools').doc(schoolId).collection('students').doc(studentId);
    
    batch.delete(studentRef);

    if (guardianId.isNotEmpty) {
      final guardianRef = _db.collection('schools').doc(schoolId).collection('users').doc(guardianId);
      // Remove child from map
      batch.update(
        guardianRef,
        {
          'childrens.$studentId': FieldValue.delete(),
        }
      );
    }

    await batch.commit();
  }
}
