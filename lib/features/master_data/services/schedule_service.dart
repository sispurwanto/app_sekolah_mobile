import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
        .snapshots()
        .map((snapshot) {
          final List<ClassSchedule> list = [];
          for (var doc in snapshot.docs) {
            final teacherSchedule = TeacherSchedule.fromFirestore(doc);
            for (var schedule in teacherSchedule.data) {
              if (schedule.classId == classId) {
                list.add(schedule);
              }
            }
          }
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
        .doc(teacherId)
        .snapshots()
        .map((doc) {
          if (!doc.exists) return [];
          final teacherSchedule = TeacherSchedule.fromFirestore(doc);
          final list = teacherSchedule.data;
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
    final docRef = _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('transactions_year')
        .doc(yearId)
        .collection('schedules')
        .doc(schedule.teacherId);

    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? 'system';

    return _firestore.runTransaction((transaction) async {
      final docSnapshot = await transaction.get(docRef);
      if (!docSnapshot.exists) {
        transaction.set(docRef, {
          'id': schedule.teacherId,
          'teacherName': schedule.teacherName,
          'created_date': FieldValue.serverTimestamp(),
          'created_by': currentUid,
          'updated_at': FieldValue.serverTimestamp(),
          'updated_by': currentUid,
          'data': [schedule.toMap()],
        });
      } else {
        transaction.update(docRef, {
          'updated_at': FieldValue.serverTimestamp(),
          'updated_by': currentUid,
          'data': FieldValue.arrayUnion([schedule.toMap()]),
        });
      }
    });
  }

  Future<void> updateSchedule(
    String schoolId,
    String yearId,
    ClassSchedule newSchedule,
  ) async {
    final docRef = _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('transactions_year')
        .doc(yearId)
        .collection('schedules')
        .doc(newSchedule.teacherId);

    return _firestore.runTransaction((transaction) async {
      final docSnapshot = await transaction.get(docRef);
      if (!docSnapshot.exists) return;

      final teacherSchedule = TeacherSchedule.fromFirestore(docSnapshot);
      final List<Map<String, dynamic>> updatedData = [];
      
      for (var schedule in teacherSchedule.data) {
        if (schedule.id == newSchedule.id) {
          updatedData.add(newSchedule.toMap());
        } else {
          updatedData.add(schedule.toMap());
        }
      }

      final currentUid = FirebaseAuth.instance.currentUser?.uid ?? 'system';
      transaction.update(docRef, {
        'data': updatedData,
        'updated_at': FieldValue.serverTimestamp(),
        'updated_by': currentUid,
      });
    });
  }

  Future<void> deleteSchedule(
    String schoolId,
    String yearId,
    String teacherId,
    String scheduleId,
  ) async {
    final docRef = _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('transactions_year')
        .doc(yearId)
        .collection('schedules')
        .doc(teacherId);

    return _firestore.runTransaction((transaction) async {
      final docSnapshot = await transaction.get(docRef);
      if (!docSnapshot.exists) return;

      final teacherSchedule = TeacherSchedule.fromFirestore(docSnapshot);
      final List<Map<String, dynamic>> updatedData = [];
      
      for (var schedule in teacherSchedule.data) {
        if (schedule.id != scheduleId) {
          updatedData.add(schedule.toMap());
        }
      }

      final currentUid = FirebaseAuth.instance.currentUser?.uid ?? 'system';
      transaction.update(docRef, {
        'data': updatedData,
        'updated_at': FieldValue.serverTimestamp(),
        'updated_by': currentUid,
      });
    });
  }
}
