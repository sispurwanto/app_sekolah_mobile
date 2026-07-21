# app_sekolah

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

### 1. File Konfigurasi JSON / ENV
Kita akan membuat folder `config/` di luar folder `lib/` yang berisi 3 file:
- `config/dev.json` (Untuk Development)
- `config/staging.json` (Untuk Staging/Testing)
- `config/prod.json` (Untuk Production/Rilis)

File-file ini akan dimasukkan ke dalam `.gitignore` agar tidak tersimpan di repositori Git (jika Anda menggunakan GitHub/GitLab).

### 2. Kelas Environment (lib/core/env/env_config.dart)
Kita akan membuat kelas utilitas `EnvConfig` yang bertugas membaca variabel ini dari hasil kompilasi menggunakan `String.fromEnvironment`.

### 3. Mengubah Konfigurasi Firebase (lib/firebase_options.dart)
Kita akan memodifikasi inisialisasi Firebase di `main.dart` agar tidak lagi menggunakan hardcode dari `firebase_options.dart`. Sebaliknya, kita akan menyuntikkan (inject) konfigurasi berdasarkan environment yang sedang berjalan.

### 4. Custom Entry Points (Opsional tapi Direkomendasikan)
Agar lebih mudah saat proses *build* atau *run* di VSCode, kita bisa membuat konfigurasi launch, atau cukup menjalankan command terminal seperti:
`flutter run --dart-define-from-file=config/dev.json`

Build : flutter build apk --dart-define-from-file=config/prod.json --obfuscate --split-debug-info=build/app/outputs/symbols

## Verification Plan
1. Membuat `config/dev.json` berisi Firebase keys development yang ada sekarang.
2. Menghapus hardcode API key di `firebase_options.dart`.
3. Menjalankan aplikasi dengan flag `--dart-define-from-file` dan memastikan fitur Login dan Pilih Sekolah tetap berfungsi normal (menandakan koneksi Firebase berhasil)