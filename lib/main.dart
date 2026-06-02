import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
// import 'firebase_options.dart'; // TODO: Uncomment setelah menjalankan flutterfire configure

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // TODO: Jalankan 'flutterfire configure' di terminal untuk men-generate file firebase_options.dart
  // await Firebase.initializeApp(
  //   options: DefaultFirebaseOptions.currentPlatform,
  // );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Placeholder for Providers
        Provider<String>(create: (_) => "dummy_provider"), 
      ],
      child: MaterialApp(
        title: 'App Sekolah',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          useMaterial3: true,
        ),
        home: const AuthWrapper(),
      ),
    );
  }
}

/// AuthWrapper bertugas mengecek status login dari Firebase Auth.
/// Jika belum login -> Tampilkan halaman Login.
/// Jika sudah login -> Cek GlobalUserMapping. Jika punya > 1 sekolah, tampilkan halaman Pilih Sekolah.
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Loading...')),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Mengecek Status Autentikasi...'),
          ],
        ),
      ),
    );
  }
}
