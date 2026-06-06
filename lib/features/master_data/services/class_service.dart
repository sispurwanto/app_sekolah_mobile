import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/models/app_class.dart';

class ClassService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<List<AppClass>> getClasses(String schoolId) {
    return _db
        .collection('schools')
        .doc(schoolId)
        .collection('classes')
        .snapshots()
        .map((snapshot) {
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

    await _db
        .collection('schools')
        .doc(schoolId)
        .collection('classes')
        .doc(idToUse)
        .set(data);
  }

  Future<void> updateClass(String schoolId, AppClass appClass) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final data = appClass.toMap();
    
    // Jangan ubah created_at & created_by
    data.remove('created_at');
    data.remove('created_by');
    
    data['updated_at'] = FieldValue.serverTimestamp();
    data['updated_by'] = uid;

    await _db
        .collection('schools')
        .doc(schoolId)
        .collection('classes')
        .doc(appClass.id)
        .update(data);
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
