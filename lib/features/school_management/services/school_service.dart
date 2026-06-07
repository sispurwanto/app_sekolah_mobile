import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/models/school.dart';

class SchoolService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String _collection = 'schools';

  // Get stream of schools
  Stream<List<School>> getSchools() {
    return _db.collection(_collection).snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => School.fromFirestore(doc)).toList();
    });
  }

  // Get single school by ID
  Future<School?> getSchool(String id) async {
    final doc = await _db.collection(_collection).doc(id).get();
    if (!doc.exists) return null;
    return School.fromFirestore(doc);
  }

  // Create school
  Future<void> addSchool(School school) async {
    final idToUse = school.id;
    
    final batch = _db.batch();
    
    final schoolRef = _db.collection(_collection).doc(idToUse);
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final data = school.toMap();
    data['created_at'] = FieldValue.serverTimestamp();
    data['created_by'] = uid;
    data['updated_at'] = FieldValue.serverTimestamp();
    data['updated_by'] = uid;
    
    batch.set(schoolRef, data);

    // Automatically map SUPER_ADMIN to current user
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final globalMappingRef = _db.collection('global_users_mapping').doc(user.uid);
      batch.set(
        globalMappingRef,
        {
          'registered_schools': {
            idToUse: 'SUPER_ADMIN',
          }
        },
        SetOptions(merge: true),
      );
    }

    await batch.commit();
  }

  Future<void> updateSchool(School school) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final data = school.toMap();
    
    data.remove('created_at');
    data.remove('created_by');
    
    data['updated_at'] = FieldValue.serverTimestamp();
    data['updated_by'] = uid;

    await _db.collection('schools').doc(school.id).update(data);
  }

  // Delete school
  Future<void> deleteSchool(String schoolId) async {
    await _db.collection(_collection).doc(schoolId).delete();
  }
}
