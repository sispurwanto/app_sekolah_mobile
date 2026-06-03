// File updated to use Environment variables.
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'core/env/env_config.dart';

/// Default [FirebaseOptions] for use with your Firebase apps.
///
/// Example:
/// ```dart
/// import 'firebase_options.dart';
/// // ...
/// await Firebase.initializeApp(
///   options: DefaultFirebaseOptions.currentPlatform,
/// );
/// ```
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: EnvConfig.firebaseWebApiKey,
    appId: EnvConfig.firebaseWebAppId,
    messagingSenderId: EnvConfig.firebaseMessagingSenderId,
    projectId: EnvConfig.firebaseProjectId,
    authDomain: EnvConfig.firebaseWebAuthDomain,
    storageBucket: EnvConfig.firebaseStorageBucket,
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: EnvConfig.firebaseAndroidApiKey,
    appId: EnvConfig.firebaseAndroidAppId,
    messagingSenderId: EnvConfig.firebaseMessagingSenderId,
    projectId: EnvConfig.firebaseProjectId,
    storageBucket: EnvConfig.firebaseStorageBucket,
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: EnvConfig.firebaseIosApiKey,
    appId: EnvConfig.firebaseIosAppId,
    messagingSenderId: EnvConfig.firebaseMessagingSenderId,
    projectId: EnvConfig.firebaseProjectId,
    storageBucket: EnvConfig.firebaseStorageBucket,
    iosBundleId: EnvConfig.firebaseIosBundleId,
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: EnvConfig.firebaseIosApiKey,
    appId: EnvConfig.firebaseIosAppId,
    messagingSenderId: EnvConfig.firebaseMessagingSenderId,
    projectId: EnvConfig.firebaseProjectId,
    storageBucket: EnvConfig.firebaseStorageBucket,
    iosBundleId: EnvConfig.firebaseIosBundleId,
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: EnvConfig.firebaseWindowsApiKey,
    appId: EnvConfig.firebaseWindowsAppId,
    messagingSenderId: EnvConfig.firebaseMessagingSenderId,
    projectId: EnvConfig.firebaseProjectId,
    authDomain: EnvConfig.firebaseWebAuthDomain,
    storageBucket: EnvConfig.firebaseStorageBucket,
  );
}
