import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/models/student_grade.dart';

class GradeService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<StudentGrade> getStudentGrades(
    String schoolId,
    String yearId,
    String studentId,
  ) {
    return _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('transactions_year')
        .doc(yearId)
        .collection('student_grades')
        .doc(studentId)
        .snapshots()
        .map((doc) => StudentGrade.fromFirestore(doc));
  }

  // Digunakan untuk batch insert/update nilai ke banyak siswa sekaligus
  Future<void> addBulkGrades({
    required String schoolId,
    required String yearId,
    required String subjectId,
    required String subjectName,
    required String gradeType,
    required String dateStr,
    required List<Map<String, dynamic>>
    studentGradesData, // [{ 'id': '...', 'name': '...', 'score': 80, 'notes': '...' }]
  }) async {
    final batch = _firestore.batch();

    for (var student in studentGradesData) {
      final studentId = student['id'];
      final studentName = student['name'];
      final grade = GradeEntry(
        type: gradeType,
        score: student['score'],
        date: dateStr,
        notes: student['notes'],
      );

      final docRef = _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('transactions_year')
          .doc(yearId)
          .collection('student_grades')
          .doc(studentId);

      // Gunakan set dengan merge: true agar struktur dasar terbentuk jika belum ada
      batch.set(docRef, {
        'id_siswa': studentId,
        'name_siswa': studentName,
        'grades': {
          subjectId: {
            'subject_name': subjectName,
            'scores': FieldValue.arrayUnion([grade.toMap()]),
          },
        },
      }, SetOptions(merge: true));
    }

    await batch.commit();
  }
}
