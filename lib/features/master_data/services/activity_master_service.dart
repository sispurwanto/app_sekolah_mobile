import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/models/activity_master.dart';

class ActivityMasterService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference _getActivitiesCollection(String schoolId) {
    return _firestore.collection('schools').doc(schoolId).collection('student_activity');
  }

  Stream<List<ActivityMaster>> getActivities(String schoolId) {
    return _getActivitiesCollection(schoolId).snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => ActivityMaster.fromFirestore(doc)).toList();
    });
  }

  Future<void> addActivity(String schoolId, ActivityMaster activity) async {
    await _getActivitiesCollection(schoolId).add(activity.toMap());
  }

  Future<void> updateActivity(String schoolId, ActivityMaster activity) async {
    await _getActivitiesCollection(schoolId).doc(activity.idActivity).update(activity.toMap());
  }

  Future<void> deleteActivity(String schoolId, String activityId) async {
    await _getActivitiesCollection(schoolId).doc(activityId).delete();
  }
}
