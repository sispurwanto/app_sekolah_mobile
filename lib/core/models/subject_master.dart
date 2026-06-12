import 'package:cloud_firestore/cloud_firestore.dart';

class SubjectMaster {
  final String id;
  final String name;
  final String code;
  final String description;

  SubjectMaster({
    required this.id,
    required this.name,
    this.code = '',
    this.description = '',
  });

  factory SubjectMaster.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return SubjectMaster(
      id: doc.id,
      name: data['name'] ?? '',
      code: data['code'] ?? '',
      description: data['description'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {'name': name, 'code': code, 'description': description};
  }
}
