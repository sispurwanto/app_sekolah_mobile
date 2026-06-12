import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/models/subject_master.dart';

class SubjectService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<List<SubjectMaster>> getSubjects(String schoolId) {
    return _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('subjects')
        .orderBy('name')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => SubjectMaster.fromFirestore(doc))
              .toList();
        });
  }

  Future<void> addSubject(String schoolId, SubjectMaster subject) async {
    await _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('subjects')
        .add(subject.toMap());
  }

  Future<void> updateSubject(String schoolId, SubjectMaster subject) async {
    await _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('subjects')
        .doc(subject.id)
        .update(subject.toMap());
  }

  Future<void> deleteSubject(String schoolId, String subjectId) async {
    await _firestore
        .collection('schools')
        .doc(schoolId)
        .collection('subjects')
        .doc(subjectId)
        .delete();
  }
}
