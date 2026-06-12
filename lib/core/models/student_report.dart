import 'package:cloud_firestore/cloud_firestore.dart';

class ReportSubject {
  final String subjectId;
  final String subjectName;
  final double score;
  final String predicate; // A, B, C, D
  final String description;

  ReportSubject({
    required this.subjectId,
    required this.subjectName,
    required this.score,
    required this.predicate,
    required this.description,
  });

  factory ReportSubject.fromMap(Map<String, dynamic> map) {
    return ReportSubject(
      subjectId: map['subjectId'] ?? '',
      subjectName: map['subject_name'] ?? '',
      score: (map['score'] ?? 0).toDouble(),
      predicate: map['predicate'] ?? '',
      description: map['description'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'subjectId': subjectId,
      'subject_name': subjectName,
      'score': score,
      'predicate': predicate,
      'description': description,
    };
  }
}

class Extracurricular {
  final String name;
  final String score; // A, B, C
  final String notes;

  Extracurricular({
    required this.name,
    required this.score,
    required this.notes,
  });

  factory Extracurricular.fromMap(Map<String, dynamic> map) {
    return Extracurricular(
      name: map['name'] ?? '',
      score: map['score'] ?? '',
      notes: map['notes'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {'name': name, 'score': score, 'notes': notes};
  }
}

class Attendance {
  final int sick;
  final int permission;
  final int absent;

  Attendance({this.sick = 0, this.permission = 0, this.absent = 0});

  factory Attendance.fromMap(Map<String, dynamic>? map) {
    if (map == null) return Attendance();
    return Attendance(
      sick: map['sick'] ?? 0,
      permission: map['permission'] ?? 0,
      absent: map['absent'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {'sick': sick, 'permission': permission, 'absent': absent};
  }
}

class SemesterReport {
  final bool isPublished;
  final String datePublished;
  final String teacherNotes;
  final Attendance attendance;
  final List<Extracurricular> extracurriculars;
  final List<ReportSubject> subjects;

  SemesterReport({
    this.isPublished = false,
    this.datePublished = '',
    this.teacherNotes = '',
    required this.attendance,
    required this.extracurriculars,
    required this.subjects,
  });

  factory SemesterReport.fromMap(Map<String, dynamic>? map) {
    if (map == null) {
      return SemesterReport(
        attendance: Attendance(),
        extracurriculars: [],
        subjects: [],
      );
    }

    var extraList = map['extracurricular'] as List? ?? [];
    var subjectList = map['subjects'] as List? ?? [];

    return SemesterReport(
      isPublished: map['is_published'] ?? false,
      datePublished: map['date_published'] ?? '',
      teacherNotes: map['teacher_notes'] ?? '',
      attendance: Attendance.fromMap(
        map['attendance'] as Map<String, dynamic>?,
      ),
      extracurriculars: extraList
          .map((e) => Extracurricular.fromMap(e))
          .toList(),
      subjects: subjectList.map((e) => ReportSubject.fromMap(e)).toList(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'is_published': isPublished,
      'date_published': datePublished,
      'teacher_notes': teacherNotes,
      'attendance': attendance.toMap(),
      'extracurricular': extracurriculars.map((e) => e.toMap()).toList(),
      'subjects': subjects.map((e) => e.toMap()).toList(),
    };
  }
}

class StudentReport {
  final String idSiswa;
  final String nameSiswa;
  final Map<String, SemesterReport> semesters; // Key: '1' atau '2'

  StudentReport({
    required this.idSiswa,
    required this.nameSiswa,
    required this.semesters,
  });

  factory StudentReport.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic>? data = doc.data() as Map<String, dynamic>?;
    if (data == null) {
      return StudentReport(idSiswa: doc.id, nameSiswa: '', semesters: {});
    }

    Map<String, SemesterReport> parsedSemesters = {};
    if (data['semesters'] != null) {
      Map<String, dynamic> semMap = data['semesters'] as Map<String, dynamic>;
      semMap.forEach((key, value) {
        parsedSemesters[key] = SemesterReport.fromMap(
          value as Map<String, dynamic>,
        );
      });
    }

    return StudentReport(
      idSiswa: data['id_siswa'] ?? doc.id,
      nameSiswa: data['name_siswa'] ?? '',
      semesters: parsedSemesters,
    );
  }

  Map<String, dynamic> toMap() {
    Map<String, dynamic> semMap = {};
    semesters.forEach((key, value) {
      semMap[key] = value.toMap();
    });

    return {'id_siswa': idSiswa, 'name_siswa': nameSiswa, 'semesters': semMap};
  }
}
