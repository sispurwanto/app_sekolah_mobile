import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'core/providers/school_provider.dart';
import 'core/providers/user_provider.dart';
import 'core/models/global_user_mapping.dart';
import 'core/utils/snackbar_utils.dart';
import 'core/utils/dialog_utils.dart';
import 'features/auth/services/auth_service.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/school_selection/screens/school_selection_screen.dart';
import 'features/dashboard/screens/dashboard_screen.dart';
import 'core/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  } catch (e) {
    debugPrint('Firebase initialization error: $e');
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AuthService>(create: (_) => AuthService()),
        ChangeNotifierProvider<SchoolProvider>(create: (_) => SchoolProvider()),
        ChangeNotifierProvider<UserProvider>(create: (_) => UserProvider()),
        StreamProvider<User?>(
          create: (context) => context.read<AuthService>().userStream,
          initialData: null,
        ),
      ],
      child: MaterialApp(
        title: 'App Sekolah',
        navigatorKey: DialogUtils.navigatorKey,
        scaffoldMessengerKey: SnackbarUtils.scaffoldMessengerKey,
        theme: AppTheme.lightTheme,
        home: const AuthWrapper(),
      ),
    );
  }
}

/// AuthWrapper bertugas mengecek status login dari Firebase Auth dan State Sekolah.
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<User?>();

    // 1. Jika belum login, tampilkan LoginScreen
    if (user == null) {
      return const LoginScreen();
    }

    // 2. Jika sudah login, ambil GlobalUserMapping dari Firestore secara realtime
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('global_users_mapping')
          .doc(user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Memuat Data...'),
                ],
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            body: Center(child: Text('Error: ${snapshot.error}')),
          );
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Scaffold(
            body: Center(
              child: Text('Data user tidak ditemukan di global_users_mapping'),
            ),
          );
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;
        final userMapping = GlobalUserMapping.fromMap(data);
        final registeredSchools = userMapping.registeredSchools;

        WidgetsBinding.instance.addPostFrameCallback((_) {
          final userProvider = context.read<UserProvider>();
          if (userProvider.userMapping?.email != userMapping.email) {
            userProvider.setUserMapping(userMapping);
          }
        });

        if (registeredSchools.isEmpty) {
          return const Scaffold(
            body: Center(
              child: Text('Anda belum terdaftar di sekolah manapun.'),
            ),
          );
        }

        final schoolProvider = context.watch<SchoolProvider>();

        // 3. Jika hanya 1 sekolah, otomatis set sebagai active school (jika belum di-set)
        if (registeredSchools.length == 1 &&
            schoolProvider.activeSchoolId == null) {
          final singleSchoolId = registeredSchools.keys.first;
          // Gunakan addPostFrameCallback agar tidak memodifikasi state saat build
          WidgetsBinding.instance.addPostFrameCallback((_) {
            context.read<SchoolProvider>().setActiveSchool(singleSchoolId);
          });
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // 4. Jika > 1 sekolah dan belum memilih sekolah, tampilkan SchoolSelectionScreen
        if (schoolProvider.activeSchoolId == null) {
          return SchoolSelectionScreen(userMapping: userMapping);
        }

        // 5. Jika sudah memilih sekolah (atau 1 sekolah ter-set otomatis), masuk ke Dashboard
        return const DashboardScreen();
      },
    );
  }
}
