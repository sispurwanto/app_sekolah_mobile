import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/models/class_schedule.dart';

class ScheduleService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<List<ClassSchedule>> getSchedulesByClass(
    String schoolId,
    String yearId,
    String classId,
  ) {
    return _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('transactions_year')
        .doc(yearId)
        .collection('schedules')
        .where('classId', isEqualTo: classId)
        .snapshots()
        .map((snapshot) {
          final list = snapshot.docs
              .map((doc) => ClassSchedule.fromFirestore(doc))
              .toList();
          list.sort((a, b) {
            int dayCmp = a.dayOfWeek.compareTo(b.dayOfWeek);
            if (dayCmp != 0) return dayCmp;
            return a.startTime.compareTo(b.startTime);
          });
          return list;
        });
  }

  Stream<List<ClassSchedule>> getSchedulesByTeacher(
    String schoolId,
    String yearId,
    String teacherId,
  ) {
    return _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('transactions_year')
        .doc(yearId)
        .collection('schedules')
        .where('teacherId', isEqualTo: teacherId)
        .snapshots()
        .map((snapshot) {
          final list = snapshot.docs
              .map((doc) => ClassSchedule.fromFirestore(doc))
              .toList();
          list.sort((a, b) {
            int dayCmp = a.dayOfWeek.compareTo(b.dayOfWeek);
            if (dayCmp != 0) return dayCmp;
            return a.startTime.compareTo(b.startTime);
          });
          return list;
        });
  }

  Future<void> addSchedule(
    String schoolId,
    String yearId,
    ClassSchedule schedule,
  ) async {
    await _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('transactions_year')
        .doc(yearId)
        .collection('schedules')
        .add(schedule.toMap());
  }

  Future<void> updateSchedule(
    String schoolId,
    String yearId,
    ClassSchedule schedule,
  ) async {
    await _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('transactions_year')
        .doc(yearId)
        .collection('schedules')
        .doc(schedule.id)
        .update(schedule.toMap());
  }

  Future<void> deleteSchedule(
    String schoolId,
    String yearId,
    String scheduleId,
  ) async {
    await _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('transactions_year')
        .doc(yearId)
        .collection('schedules')
        .doc(scheduleId)
        .delete();
  }
}
