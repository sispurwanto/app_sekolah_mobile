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
    required String teacherName,
    required String gradeType,
    required String dateStr,
    required List<Map<String, dynamic>>
    studentGradesData, // [{ 'id': '...', 'name': '...', 'score': 80, 'notes': '...' }]
  }) async {
    final batch = _firestore.batch();
    
    for (var student in studentGradesData) {
      final studentId = student['id'];
      final studentName = student['name'];
      final newScore = student['score'];
      final newNotes = student['notes'];

      final docRef = _firestore
          .collection('schools')
          .doc(schoolId)
          .collection('transactions_year')
          .doc(yearId)
          .collection('student_grades')
          .doc(studentId);

      final docSnapshot = await docRef.get();
      List<Map<String, dynamic>> existingScoresMapList = [];
      
      if (docSnapshot.exists) {
        final data = docSnapshot.data() as Map<String, dynamic>?;
        if (data != null && data['grades'] != null) {
          final gradesData = data['grades'] as Map<String, dynamic>;
          if (gradesData[subjectId] != null && gradesData[subjectId]['scores'] != null) {
            existingScoresMapList = List<Map<String, dynamic>>.from(gradesData[subjectId]['scores']);
          }
        }
      }

      // Cari apakah tipe nilai ini sudah ada
      int existingIndex = existingScoresMapList.indexWhere((s) => s['type'] == gradeType);
      
      if (existingIndex >= 0) {
        // Jika sudah ada, timpa data lamanya
        existingScoresMapList[existingIndex] = {
          'type': gradeType,
          'score': newScore,
          'date': dateStr,
          'notes': newNotes,
        };
      } else {
        // Jika belum ada, tambahkan
        existingScoresMapList.add({
          'type': gradeType,
          'score': newScore,
          'date': dateStr,
          'notes': newNotes,
        });
      }

      // Tulis ulang (overwrite specific subject)
      batch.set(docRef, {
        'id_siswa': studentId,
        'name_siswa': studentName,
        'grades': {
          subjectId: {
            'subject_name': subjectName,
            'teacher_name': teacherName,
            'scores': existingScoresMapList,
          },
        },
      }, SetOptions(merge: true));
    }

    await batch.commit();
  }
}
