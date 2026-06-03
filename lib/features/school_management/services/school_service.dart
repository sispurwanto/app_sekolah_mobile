import 'package:cloud_firestore/cloud_firestore.dart';
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

  // Create school
  Future<void> addSchool(School school) async {
    final docRef = _db.collection(_collection).doc();
    // Use the generated ID or the one provided
    final idToUse = school.id.isEmpty ? docRef.id : school.id;
    
    await _db.collection(_collection).doc(idToUse).set(school.toMap());
  }

  // Update school
  Future<void> updateSchool(School school) async {
    await _db.collection(_collection).doc(school.id).update(school.toMap());
  }

  // Delete school
  Future<void> deleteSchool(String schoolId) async {
    await _db.collection(_collection).doc(schoolId).delete();
  }
}
