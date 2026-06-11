import 'package:cloud_firestore/cloud_firestore.dart';

class ActivityMaster {
  final String idActivity;
  final String nameActivity;

  ActivityMaster({
    required this.idActivity,
    required this.nameActivity,
  });

  factory ActivityMaster.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return ActivityMaster(
      idActivity: doc.id,
      nameActivity: data['name_activity'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name_activity': nameActivity,
    };
  }
}
