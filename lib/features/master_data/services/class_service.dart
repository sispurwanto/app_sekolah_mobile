import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/models/app_class.dart';
import '../../master_data/services/academic_year_service.dart';

class ClassService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<List<AppClass>> getClasses(String schoolId, {String? teacherId}) {
    var query = _db
        .collection('schools')
        .doc(schoolId)
        .collection('classes');
        
    if (teacherId != null && teacherId.isNotEmpty) {
      return query.where('teacher_id', isEqualTo: teacherId).snapshots().map((snapshot) {
        return snapshot.docs.map((doc) => AppClass.fromFirestore(doc)).toList();
      });
    }

    return query.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => AppClass.fromFirestore(doc)).toList();
    });
  }

  Future<void> addClass(String schoolId, AppClass appClass) async {
    final idToUse = appClass.id;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    
    final data = appClass.toMap();
    data['created_at'] = FieldValue.serverTimestamp();
    data['created_by'] = uid;
    data['updated_at'] = FieldValue.serverTimestamp();
    data['updated_by'] = uid;

    final batch = _db.batch();

    final classRef = _db
        .collection('schools')
        .doc(schoolId)
        .collection('classes')
        .doc(idToUse);
        
    batch.set(classRef, data);

    final activeYear = await AcademicYearService().getActiveAcademicYear(schoolId);
    if (activeYear != null) {
      final classDataRef = _db
          .collection('schools')
          .doc(schoolId)
          .collection('transactions_year')
          .doc(activeYear.id)
          .collection('class_data')
          .doc(idToUse);
          
      batch.set(classDataRef, {
        'status': 'ACTIVE',
        'updated_at': FieldValue.serverTimestamp(),
        'updated_by': uid,
        'teacher': appClass.teacherId != null ? {
          'id': appClass.teacherId,
          'name': appClass.teacherName,
        } : null,
      }, SetOptions(merge: true));
    }

    await batch.commit();
  }

  Future<void> updateClass(String schoolId, AppClass appClass) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final data = appClass.toMap();
    
    // Jangan ubah created_at & created_by
    data.remove('created_at');
    data.remove('created_by');
    
    data['updated_at'] = FieldValue.serverTimestamp();
    data['updated_by'] = uid;

    final batch = _db.batch();

    final classRef = _db
        .collection('schools')
        .doc(schoolId)
        .collection('classes')
        .doc(appClass.id);
        
    batch.update(classRef, data);

    final activeYear = await AcademicYearService().getActiveAcademicYear(schoolId);
    if (activeYear != null) {
      final classDataRef = _db
          .collection('schools')
          .doc(schoolId)
          .collection('transactions_year')
          .doc(activeYear.id)
          .collection('class_data')
          .doc(appClass.id);
          
      batch.set(classDataRef, {
        'status': 'ACTIVE',
        'updated_at': FieldValue.serverTimestamp(),
        'updated_by': uid,
        'teacher': appClass.teacherId != null ? {
          'id': appClass.teacherId,
          'name': appClass.teacherName,
        } : null,
      }, SetOptions(merge: true));
    }

    await batch.commit();
  }

  Future<void> deleteClass(String schoolId, String classId) async {
    await _db
        .collection('schools')
        .doc(schoolId)
        .collection('classes')
        .doc(classId)
        .delete();
  }
}
