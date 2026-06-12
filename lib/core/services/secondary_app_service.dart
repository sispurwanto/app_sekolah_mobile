import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../firebase_options.dart';

class SecondaryAppService {
  /// Creates a new user in Firebase Auth without logging out the current admin.
  /// It does this by spinning up a temporary secondary Firebase app instance.
  static Future<User?> createUser({
    required String email,
    required String password,
  }) async {
    FirebaseApp? tempApp;
    try {
      // Initialize a temporary app instance
      tempApp = await Firebase.initializeApp(
        name: 'SecondaryApp',
        options: DefaultFirebaseOptions.currentPlatform,
      );

      // Get Auth instance for the temporary app
      final auth = FirebaseAuth.instanceFor(app: tempApp);

      // Create the user
      final userCredential = await auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Important: We must sign out from the secondary app to clear its session,
      // though deleting the app usually suffices.
      await auth.signOut();

      return userCredential.user;
    } catch (e) {
      rethrow;
    } finally {
      // Always delete the temporary app to prevent memory leaks and state issues
      if (tempApp != null) {
        await tempApp.delete();
      }
    }
  }
}
