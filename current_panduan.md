# Buku Panduan Penggunaan Aplikasi Sekolah (Manual Book)

**Alur Implementasi Aplikasi Sekolah (Dari Nol hingga Siap Transaksi)**

Untuk memastikan seluruh siklus sistem berjalan lancar tanpa *error*, pengguna **diwajibkan** untuk mengikuti proses instalasi dengan benar, lalu menginput data secara berurutan sesuai alur berikut. Alur ini penting karena data yang diinput pada proses akhir bergantung pada ketersediaan data di proses awal.

---

## FASE 0: INSTALASI APLIKASI (ANDROID)

Mengingat aplikasi saat ini belum dipublikasikan secara resmi di Google Play Store, penginstalan harus dilakukan secara manual menggunakan file **.apk**.

1. **Terima File APK**: Pastikan Anda telah menerima file installer berformat `.apk` (misal: `AplikasiSekolah.apk`) dari pihak administrator via WhatsApp, Email, atau link Google Drive.
2. **Download File**: Unduh file APK tersebut ke dalam penyimpanan HP Android Anda.
3. **Buka File**: Buka file APK yang sudah diunduh. Jika muncul peringatan keamanan *"Install unknown apps"* (Instal aplikasi dari sumber tidak dikenal), klik **Settings / Pengaturan**.
4. **Izinkan Instalasi**: Aktifkan *toggle* atau centang pada opsi *"Allow from this source"* (Izinkan dari sumber ini) untuk memberikan izin instalasi.
5. **Install**: Kembali ke layar instalasi, lalu klik **Install**.
6. **Buka Aplikasi**: Setelah selesai, klik **Open** untuk membuka aplikasi. Aplikasi kini siap digunakan untuk tahap selanjutnya.

---

## FASE 1: PERSIAPAN DATA MASTER (Wajib Berurutan)

### 1. Tahun Ajaran Aktif (Admin)
Masuk ke menu Tahun Ajaran -> Tambah Data -> Set status ke "Aktif". Seluruh transaksi terikat pada tahun ajaran ini.

### 2. Manajemen Pengguna (Admin)
Tambahkan akun login dan hak akses staf sekolah (Admin, Bendahara, Kepsek, Guru, Wali).

### 3. Master Data Kelas (Admin)
Tambahkan kelas dan pilih wali kelas dari daftar pengguna (Guru/Wali).

### 4. Master Mata Pelajaran (Admin)
Daftarkan katalog mata pelajaran yang akan diajarkan.

### 5. Jadwal Pelajaran (Admin)
Susun jadwal berdasarkan Kelas, Hari, Jam Mulai-Selesai, Pelajaran, dan Guru pengajar.

### 6. Kegiatan Siswa (Admin)
Tambahkan daftar kegiatan (Ekskul, LDKS, dll) yang diikuti siswa.

### 7. Master Tagihan (Admin)
Definisikan template biaya tagihan wajib (Uang Pangkal, Uang Daftar Ulang, SPP, Uang Seragam, dll).

### 8. Data Siswa (Admin)
Masukkan data siswa (Pilih status Active) dan daftarkan ke kelas aktif. Siswa yang lulus atau keluar dapat diubah statusnya menjadi Lulus/Mutasi, dan sistem akan memisahkannya secara otomatis agar tidak muncul di laporan kelas aktif.

---

## FASE 2: TRANSAKSI HARIAN

Setelah Fase 1 selesai secara utuh, barulah sistem bisa digunakan untuk memproses transaksi.

### A. Sistem Tagihan (Invoicing)
1. **Log Distribusi Tagihan (Massal)**: Melalui menu *Dashboard Bendahara -> Distribusi Tagihan*, Bendahara dapat menerbitkan *Master Tagihan* secara massal ke seluruh kelas secara otomatis. Sistem akan mencatat riwayat pendistribusian ini ke dalam Log Distribusi. *(Catatan: Sistem sangat aman. Jika kelas tujuan sudah memiliki tagihan tersebut, sistem akan melewatkannya sehingga mencegah terjadinya tagihan ganda tanpa menghasilkan riwayat log kosong).*
2. **Tagihan Manual**: Di halaman Tagihan Siswa, Anda bisa membuat tagihan baru yang spesifik/khusus untuk siswa tersebut secara eceran.

### B. Transaksi & Pembayaran
Terdapat 2 jalur pembayaran:
1. **Via Transfer Wali Murid**: Konfirmasi dilakukan dengan mencatat asal Bank, A/n, dan No. Referensi (saat ini belum bisa upload bukti transfer) lalu menunggu validasi.
2. **Via Kasir (Bendahara)**: Pembayaran langsung terverifikasi otomatis.

Metode Pelunasan (berlaku untuk kedua jalur di atas):
- **Bayar Satuan**: Melalui menu titik tiga di samping tagihan. Sistem mendukung bayar Parsial (dicicil) maupun Lunas.
- **Bayar Sekaligus**: Melalui checklist beberapa tagihan sekaligus. Sistem mewajibkan pembayaran LUNAS sesuai total akumulasi semua tagihan yang dicentang tersebut.

### C. Validasi Pembayaran
Bendahara memiliki menu khusus "Validasi Pembayaran" di Dashboard. Pada menu ini, Bendahara bertugas memverifikasi konfirmasi transfer dari Wali Murid dengan mengklik "Setujui" jika dana sudah masuk, atau "Tolak" jika tidak valid. Tagihan baru akan terhitung Lunas/Tercicil setelah disetujui.

### D. Transaksi Tabungan
Akses profil siswa melalui menu Data Siswa (atau Kasir), lalu buka tab "Tabungan". Di sana Anda dapat mencatat riwayat Setor Tunai (menambah saldo) maupun Tarik Tunai (mengurangi saldo) secara real-time.

### E. Input Kegiatan Siswa
Guru atau Admin dapat mencatat partisipasi dan absensi kegiatan ekstrakurikuler/harian siswa melalui menu "Kegiatan Siswa" untuk memantau keaktifan non-akademik.

---

## FASE 3: AKADEMIK (MODUL GURU)

Menu spesifik yang hanya tersedia di akses Guru/Wali Kelas.

### 1. Dasbor Guru Terintegrasi
Guru kini memiliki *Dashboard* khusus yang terdiri dari deretan menu utama (Seluruh Jadwal, Data Siswa, dan Input Nilai) yang responsif dan dirancang proporsional (4 kolom layar).

### 2. Jadwal Mengajar & Total Jam
Melalui menu **Seluruh Jadwal**, Guru bisa melihat daftar hari mengajar lengkap berserta nama kelas dan jam pelajaran. Di bagian paling atas, sistem secara otomatis menghitung *Total Mengajar: ... Jam/Pekan* berdasarkan selisih jam mulai hingga jam selesai di jadwal sistem.

### 3. Input Nilai Cerdas
Melalui menu **Input Nilai**, Guru tinggal memilih Kelas dan Mata Pelajaran yang diajarkan (otomatis ditarik dari Master Jadwal Pelajaran). Sistem hanya akan menampilkan siswa yang benar-benar masih *Aktif* di kelas tersebut, sehingga Guru tidak akan kerepotan menilai siswa yang sudah mutasi atau lulus.

---

## FASE 4: LAPORAN & MONITORING

Pantau seluruh metrik operasional dan keuangan sekolah secara lengkap.
- **Laporan Pembayaran**: Melihat arus kas masuk dan piutang/tunggakan pembayaran yang belum terlunasi.
- **Laporan Tabungan**: Monitoring riwayat saldo ditarik dan disetor seluruh siswa.
- **Laporan Rapor/Nilai**: Monitoring seluruh nilai mata pelajaran (UTS, UAS, Tugas) yang diinput oleh masing-masing wali kelas.
