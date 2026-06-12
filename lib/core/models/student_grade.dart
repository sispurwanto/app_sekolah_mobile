import 'package:cloud_firestore/cloud_firestore.dart';

class GradeEntry {
  final String type; // Tugas 1, Ulangan Harian, UTS, UAS
  final double score;
  final String date;
  final String notes;

  GradeEntry({
    required this.type,
    required this.score,
    required this.date,
    required this.notes,
  });

  factory GradeEntry.fromMap(Map<String, dynamic> map) {
    return GradeEntry(
      type: map['type'] ?? '',
      score: (map['score'] ?? 0).toDouble(),
      date: map['date'] ?? '',
      notes: map['notes'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {'type': type, 'score': score, 'date': date, 'notes': notes};
  }
}

class SubjectGrade {
  final String subjectName;
  final List<GradeEntry> scores;

  SubjectGrade({required this.subjectName, required this.scores});

  factory SubjectGrade.fromMap(Map<String, dynamic> map) {
    var list = map['scores'] as List? ?? [];
    return SubjectGrade(
      subjectName: map['subject_name'] ?? '',
      scores: list
          .map((e) => GradeEntry.fromMap(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'subject_name': subjectName,
      'scores': scores.map((e) => e.toMap()).toList(),
    };
  }
}

class StudentGrade {
  final String idSiswa;
  final String nameSiswa;
  final Map<String, SubjectGrade> grades; // Key: subjectId

  StudentGrade({
    required this.idSiswa,
    required this.nameSiswa,
    required this.grades,
  });

  factory StudentGrade.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic>? data = doc.data() as Map<String, dynamic>?;
    if (data == null) {
      return StudentGrade(idSiswa: doc.id, nameSiswa: '', grades: {});
    }

    Map<String, SubjectGrade> parsedGrades = {};
    if (data['grades'] != null) {
      Map<String, dynamic> gradesMap = data['grades'] as Map<String, dynamic>;
      gradesMap.forEach((key, value) {
        parsedGrades[key] = SubjectGrade.fromMap(value as Map<String, dynamic>);
      });
    }

    return StudentGrade(
      idSiswa: data['id_siswa'] ?? doc.id,
      nameSiswa: data['name_siswa'] ?? '',
      grades: parsedGrades,
    );
  }

  Map<String, dynamic> toMap() {
    Map<String, dynamic> gradesMap = {};
    grades.forEach((key, value) {
      gradesMap[key] = value.toMap();
    });

    return {'id_siswa': idSiswa, 'name_siswa': nameSiswa, 'grades': gradesMap};
  }
}
