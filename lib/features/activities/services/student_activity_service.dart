import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/models/student_activity.dart';

class StudentActivityService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  DocumentReference _getStudentActivityDoc(String schoolId, String academicYearId, String studentId) {
    return _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('transactions_year')
        .doc(academicYearId)
        .collection('student_activity')
        .doc(studentId);
  }

  Stream<StudentActivity> getStudentActivity(String schoolId, String academicYearId, String studentId) {
    return _getStudentActivityDoc(schoolId, academicYearId, studentId).snapshots().map((doc) {
      return StudentActivity.fromFirestore(doc);
    });
  }

  Future<void> addActivityEntry(String schoolId, String academicYearId, String studentId, String studentName, ActivityEntry entry) async {
    final docRef = _getStudentActivityDoc(schoolId, academicYearId, studentId);
    
    await docRef.set({
      'id_siswa': studentId,
      'name_siswa': studentName,
      'data': FieldValue.arrayUnion([entry.toMap()])
    }, SetOptions(merge: true));
  }

  Future<void> removeActivityEntry(String schoolId, String academicYearId, String studentId, ActivityEntry entry) async {
    final docRef = _getStudentActivityDoc(schoolId, academicYearId, studentId);
    
    await docRef.update({
      'data': FieldValue.arrayRemove([entry.toMap()])
    });
  }

  Future<void> updateActivityEntry(String schoolId, String academicYearId, String studentId, ActivityEntry oldEntry, ActivityEntry newEntry) async {
    final docRef = _getStudentActivityDoc(schoolId, academicYearId, studentId);
    
    WriteBatch batch = _firestore.batch();
    
    batch.update(docRef, {
      'data': FieldValue.arrayRemove([oldEntry.toMap()])
    });
    batch.update(docRef, {
      'data': FieldValue.arrayUnion([newEntry.toMap()])
    });
    
    await batch.commit();
  }
}
