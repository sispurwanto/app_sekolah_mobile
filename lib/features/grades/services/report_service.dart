import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/models/student_report.dart';

class ReportService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<StudentReport> getStudentReport(
    String schoolId,
    String yearId,
    String studentId,
  ) {
    return _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('transactions_year')
        .doc(yearId)
        .collection('student_reports')
        .doc(studentId)
        .snapshots()
        .map((doc) => StudentReport.fromFirestore(doc));
  }

  Future<void> saveStudentReport({
    required String schoolId,
    required String yearId,
    required StudentReport report,
  }) async {
    await _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('transactions_year')
        .doc(yearId)
        .collection('student_reports')
        .doc(report.idSiswa)
        .set(report.toMap(), SetOptions(merge: true));
  }
}
