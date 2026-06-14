import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

class TeacherSchedule {
  final String teacherId;
  final String teacherName;
  final List<ClassSchedule> data;

  TeacherSchedule({
    required this.teacherId,
    required this.teacherName,
    required this.data,
  });

  factory TeacherSchedule.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> docData = doc.data() as Map<String, dynamic>? ?? {};
    List<dynamic> dataList = docData['data'] ?? [];
    
    return TeacherSchedule(
      teacherId: doc.id,
      teacherName: docData['teacherName'] ?? '',
      data: dataList.map((item) {
        return ClassSchedule.fromMap(
          item as Map<String, dynamic>,
          doc.id,
          docData['teacherName'] ?? '',
        );
      }).toList(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'teacherId': teacherId,
      'teacherName': teacherName,
      'data': data.map((item) => item.toMap()).toList(),
    };
  }
}

class ClassSchedule {
  final String id;
  final String classId;
  final String className;
  final String subjectId;
  final String subjectName;
  final String teacherId;
  final String teacherName;
  final int dayOfWeek; // 1 = Senin, 7 = Minggu
  final String startTime;
  final String endTime;

  ClassSchedule({
    String? id,
    required this.classId,
    required this.className,
    required this.subjectId,
    required this.subjectName,
    required this.teacherId,
    required this.teacherName,
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
  }) : id = id ?? const Uuid().v4();

  factory ClassSchedule.fromMap(Map<String, dynamic> data, String tId, String tName) {
    return ClassSchedule(
      id: data['id'],
      classId: data['classId'] ?? '',
      className: data['className'] ?? '',
      subjectId: data['subjectId'] ?? '',
      subjectName: data['subjectName'] ?? '',
      teacherId: tId,
      teacherName: tName,
      dayOfWeek: data['dayOfWeek'] ?? 1,
      startTime: data['startTime'] ?? '',
      endTime: data['endTime'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'classId': classId,
      'className': className,
      'subjectId': subjectId,
      'subjectName': subjectName,
      // teacherId and teacherName are stored in the parent doc, 
      // but we can store them here too for redundancy or ignore them.
      // Better to not store them to save space since they are in parent.
      'dayOfWeek': dayOfWeek,
      'startTime': startTime,
      'endTime': endTime,
    };
  }

  String get dayName {
    const days = [
      'Senin',
      'Selasa',
      'Rabu',
      'Kamis',
      'Jumat',
      'Sabtu',
      'Minggu',
    ];
    if (dayOfWeek >= 1 && dayOfWeek <= 7) {
      return days[dayOfWeek - 1];
    }
    return 'Unknown';
  }
}
