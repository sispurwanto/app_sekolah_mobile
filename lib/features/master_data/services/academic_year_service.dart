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
          return snapshot.docs
              .map((doc) => AcademicYear.fromFirestore(doc))
              .toList();
        });
  }

  Future<void> _ensureSingleActive(String schoolId, String? excludeId) async {
    final activeYears = await _db
        .collection('schools')
        .doc(schoolId)
        .collection('academic_years')
        .where('is_active', isEqualTo: true)
        .get();

    for (var doc in activeYears.docs) {
      if (doc.id != excludeId) {
        throw Exception(
          'Tahun Ajaran Aktif sudah ada (${doc.data()['name']}). Nonaktifkan terlebih dahulu!',
        );
      }
    }
  }

  Future<AcademicYear?> getActiveAcademicYear(String schoolId) async {
    final snapshot = await _db
        .collection('schools')
        .doc(schoolId)
        .collection('academic_years')
        .where('is_active', isEqualTo: true)
        .limit(1)
        .get();

    if (snapshot.docs.isNotEmpty) {
      return AcademicYear.fromFirestore(snapshot.docs.first);
    }
    return null;
  }

  Future<void> addAcademicYear(String schoolId, AcademicYear year) async {
    // Selalu cek jika sudah ada yang aktif, tidak boleh tambah sama sekali
    await _ensureSingleActive(schoolId, null);
    final idToUse = year.id;
    final uid = FirebaseAuth.instance.currentUser?.uid;

    final data = year.toMap();
    data['created_at'] = FieldValue.serverTimestamp();
    data['created_by'] = uid;
    data['updated_at'] = FieldValue.serverTimestamp();
    data['updated_by'] = uid;

    final batch = _db.batch();

    final academicYearRef = _db
        .collection('schools')
        .doc(schoolId)
        .collection('academic_years')
        .doc(idToUse);

    batch.set(academicYearRef, data);

    // Initialize transaction folder
    final transactionRef = _db
        .collection('schools')
        .doc(schoolId)
        .collection('transactions_year')
        .doc(idToUse);

    batch.set(transactionRef, {
      'status': year.isActive ? 'ACTIVE' : 'INACTIVE',
      'created_at': FieldValue.serverTimestamp(),
      'created_by': uid,
      'updated_at': FieldValue.serverTimestamp(),
      'updated_by': uid,
    });

    await batch.commit();
  }

  Future<void> updateAcademicYear(String schoolId, AcademicYear year) async {
    // if (year.isActive) {
    await _ensureSingleActive(schoolId, year.id);
    // }
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final data = year.toMap();

    data.remove('created_at');
    data.remove('created_by');

    data['updated_at'] = FieldValue.serverTimestamp();
    data['updated_by'] = uid;

    final batch = _db.batch();

    final academicYearRef = _db
        .collection('schools')
        .doc(schoolId)
        .collection('academic_years')
        .doc(year.id);

    batch.update(academicYearRef, data);

    final transactionRef = _db
        .collection('schools')
        .doc(schoolId)
        .collection('transactions_year')
        .doc(year.id);

    final transactionDoc = await transactionRef.get();
    if (transactionDoc.exists) {
      batch.update(transactionRef, {
        'status': year.isActive ? 'ACTIVE' : 'INACTIVE',
        'updated_at': FieldValue.serverTimestamp(),
        'updated_by': uid,
      });
    } else {
      batch.set(transactionRef, {
        'status': year.isActive ? 'ACTIVE' : 'INACTIVE',
        'created_at': FieldValue.serverTimestamp(),
        'created_by': uid,
        'updated_at': FieldValue.serverTimestamp(),
        'updated_by': uid,
      });
    }

    await batch.commit();
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
