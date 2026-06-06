import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/models/app_user.dart';
import '../../../core/services/secondary_app_service.dart';

class UserManagementService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Get stream of users for a specific school
  Stream<List<AppUser>> getUsers(String schoolId) {
    return _db
        .collection('schools')
        .doc(schoolId)
        .collection('users')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => AppUser.fromFirestore(doc)).toList();
    });
  }

  // Get users by specific role
  Future<List<AppUser>> getUsersByRole(String schoolId, String role) async {
    final snapshot = await _db
        .collection('schools')
        .doc(schoolId)
        .collection('users')
        .where('role', isEqualTo: role)
        .where('is_active', isEqualTo: true)
        .get();
        
    return snapshot.docs.map((doc) => AppUser.fromFirestore(doc)).toList();
  }

  // Add new user
  Future<void> addUser({
    required String schoolId,
    required String name,
    required String email,
    required String password,
    required String role,
  }) async {
    // 1. Create User in Firebase Auth using Secondary App
    final firebaseUser = await SecondaryAppService.createUser(
      email: email,
      password: password,
    );

    if (firebaseUser == null) {
      throw Exception('Gagal membuat user di Firebase Auth');
    }

    final uid = firebaseUser.uid;

    // 2. Save to school's subcollection
    final appUser = AppUser(
      id: uid,
      name: name,
      email: email,
      role: role,
      isActive: true,
    );

    final batch = _db.batch();

    final schoolUserRef = _db
        .collection('schools')
        .doc(schoolId)
        .collection('users')
        .doc(uid);
        
    final currentUserUid = FirebaseAuth.instance.currentUser?.uid;
    final userData = appUser.toMap();
    userData['created_at'] = FieldValue.serverTimestamp();
    userData['created_by'] = currentUserUid;
    userData['updated_at'] = FieldValue.serverTimestamp();
    userData['updated_by'] = currentUserUid;
    
    batch.set(schoolUserRef, userData);

    // 3. Update global mapping
    final globalMappingRef = _db.collection('global_users_mapping').doc(uid);
    
    // We use set with merge: true in case the document exists (e.g., they are already in another school)
    // But since this is a NEW firebase auth user, the document shouldn't exist.
    batch.set(
      globalMappingRef,
      {
        'email': email,
        'name': name,
        'registered_schools': {
          schoolId: role,
        }
      },
      SetOptions(merge: true),
    );

    await batch.commit();
  }

  // Note: For existing users (adding an existing user to another school), 
  // you would skip the SecondaryAppService and just update the mapping and subcollection.
  // We'll keep it simple for now (assuming new users).

  // Update user role or status
  Future<void> updateUser({
    required String schoolId,
    required AppUser user,
  }) async {
    final batch = _db.batch();

    // Update school user
    final schoolUserRef = _db
        .collection('schools')
        .doc(schoolId)
        .collection('users')
        .doc(user.id);
        
    final currentUserUid = FirebaseAuth.instance.currentUser?.uid;
    final userData = user.toMap();
    userData.remove('created_at');
    userData.remove('created_by');
    userData['updated_at'] = FieldValue.serverTimestamp();
    userData['updated_by'] = currentUserUid;
    
    batch.update(schoolUserRef, userData);

    // Update global mapping role if active, or remove if inactive (optional logic, but let's just update role)
    final globalMappingRef = _db.collection('global_users_mapping').doc(user.id);
    
    if (user.isActive) {
      batch.update(globalMappingRef, {
        'registered_schools.$schoolId': user.role,
      });
    } else {
      // If inactive, you might want to remove them from registered schools so they can't login to this school
      batch.update(globalMappingRef, {
        'registered_schools.$schoolId': FieldValue.delete(),
      });
    }

    await batch.commit();
  }
}
