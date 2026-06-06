import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/models/academic_year.dart';

class AcademicYearService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<List<AcademicYear>> getAcademicYears(String schoolId) {
    return _db
        .collection('schools')
        .doc(schoolId)
        .collection('academic_years')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => AcademicYear.fromFirestore(doc)).toList();
    });
  }

  Future<void> addAcademicYear(String schoolId, AcademicYear year) async {
    final idToUse = year.id;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    
    final data = year.toMap();
    data['created_at'] = FieldValue.serverTimestamp();
    data['created_by'] = uid;
    data['updated_at'] = FieldValue.serverTimestamp();
    data['updated_by'] = uid;

    await _db
        .collection('schools')
        .doc(schoolId)
        .collection('academic_years')
        .doc(idToUse)
        .set(data);
  }

  Future<void> updateAcademicYear(String schoolId, AcademicYear year) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final data = year.toMap();
    
    data.remove('created_at');
    data.remove('created_by');
    
    data['updated_at'] = FieldValue.serverTimestamp();
    data['updated_by'] = uid;

    await _db
        .collection('schools')
        .doc(schoolId)
        .collection('academic_years')
        .doc(year.id)
        .update(data);
  }

  Future<void> deleteAcademicYear(String schoolId, String yearId) async {
    await _db
        .collection('schools')
        .doc(schoolId)
        .collection('academic_years')
        .doc(yearId)
        .delete();
  }
}
