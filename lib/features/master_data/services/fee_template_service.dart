import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/models/fee_template.dart';

class FeeTemplateService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<List<FeeTemplate>> getFeeTemplates(String schoolId, String academicYearId) {
    return _db
        .collection('schools')
        .doc(schoolId)
        .collection('fee_templates')
        .where('academic_year_id', isEqualTo: academicYearId)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => FeeTemplate.fromFirestore(doc))
              .toList();
        });
  }

  Future<void> addFeeTemplate(String schoolId, FeeTemplate template) async {
    final idToUse = template.id;
    final uid = FirebaseAuth.instance.currentUser?.uid;

    final data = template.toMap();
    data['created_at'] = FieldValue.serverTimestamp();
    data['created_by'] = uid;
    data['updated_at'] = FieldValue.serverTimestamp();
    data['updated_by'] = uid;

    await _db
        .collection('schools')
        .doc(schoolId)
        .collection('fee_templates')
        .doc(idToUse)
        .set(data);
  }

  Future<void> updateFeeTemplate(String schoolId, FeeTemplate template) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final data = template.toMap();

    data.remove('created_at');
    data.remove('created_by');

    data['updated_at'] = FieldValue.serverTimestamp();
    data['updated_by'] = uid;

    await _db
        .collection('schools')
        .doc(schoolId)
        .collection('fee_templates')
        .doc(template.id)
        .update(data);
  }

  Future<void> deleteFeeTemplate(String schoolId, String templateId) async {
    await _db
        .collection('schools')
        .doc(schoolId)
        .collection('fee_templates')
        .doc(templateId)
        .delete();
  }
}
