import 'package:flutter/material.dart';

class ManualBookScreen extends StatelessWidget {
  const ManualBookScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Buku Panduan'),
        backgroundColor: Colors.green.shade800,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('Alur Implementasi Aplikasi (Wajib Berurutan)'),
            const SizedBox(height: 8),
            const Text(
              'Untuk memastikan seluruh siklus sistem berjalan lancar tanpa error, pengguna diwajibkan menginput data master secara berurutan sesuai alur berikut:',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 24),

            _buildPhaseTitle('FASE 1: PERSIAPAN DATA MASTER'),
            const SizedBox(height: 12),
            _buildStepCard(
              number: '1',
              title: 'Tahun Ajaran Aktif (Admin)',
              content:
                  'Masuk ke menu Tahun Ajaran -> Tambah Data -> Set status ke "Aktif". Seluruh transaksi terikat pada tahun ajaran ini.',
            ),
            _buildStepCard(
              number: '2',
              title: 'Manajemen Pengguna (Admin)',
              content:
                  'Tambahkan akun login dan hak akses staf sekolah (Admin, Bendahara, Kepsek, Guru, Wali).',
            ),
            _buildStepCard(
              number: '3',
              title: 'Master Data Kelas (Admin)',
              content:
                  'Tambahkan kelas dan pilih wali kelas dari daftar pengguna (Guru/Wali).',
            ),
            _buildStepCard(
              number: '4',
              title: 'Master Mata Pelajaran (Admin)',
              content: 'Daftarkan katalog mata pelajaran yang akan diajarkan.',
            ),
            _buildStepCard(
              number: '5',
              title: 'Jadwal Pelajaran (Admin)',
              content:
                  'Susun jadwal berdasarkan Kelas, Hari, Jam Mulai-Selesai, Pelajaran, dan Guru pengajar.',
            ),
            _buildStepCard(
              number: '6',
              title: 'Kegiatan Siswa (Admin)',
              content:
                  'Tambahkan daftar kegiatan (Ekskul, LDKS, dll) yang diikuti siswa.',
            ),
            _buildStepCard(
              number: '7',
              title: 'Master Tagihan (Admin)',
              content:
                  'Definisikan template biaya tagihan wajib (Uang Pangkal, Uang Daftar Ulang, SPP, Uang Seragam, dll).',
            ),
            _buildStepCard(
              number: '8',
              title: 'Data Siswa (Admin)',
              content:
                  'Masukkan data siswa (Pilih status Active) dan daftarkan ke kelas aktif.',
            ),

            const SizedBox(height: 24),
            _buildPhaseTitle('FASE 2: TRANSAKSI HARIAN'),
            const SizedBox(height: 12),

            _buildInfoBlock(
              icon: Icons.receipt_long,
              title: 'A. Sistem Tagihan (Invoicing)',
              content:
                  '1. Via Master Tagihan: Bisa di-generate secara kolektif ke semua siswa yang masuk kriteria kategori master tagihan tersebut.\n'
                  '2. Via Data Siswa: Pada tiap profil siswa, bisa di-generate tagihan otomatis untuk siswa tersebut (mengambil semua master tagihan yang sesuai).\n'
                  '3. Tagihan Manual: Di halaman Tagihan Siswa, Anda bisa membuat tagihan baru yang spesifik/khusus untuk siswa tersebut.',
            ),
            _buildInfoBlock(
              icon: Icons.payments,
              title: 'B. Transaksi & Pembayaran',
              content:
                  'Terdapat 2 jalur pembayaran:\n'
                  '1. Via Transfer Wali Murid: Konfirmasi dilakukan dengan mencatat asal Bank, A/n, dan No. Referensi (saat ini belum bisa upload bukti transfer) lalu menunggu validasi.\n'
                  '2. Via Kasir (Bendahara): Pembayaran langsung terverifikasi otomatis.\n\n'
                  'Metode Pelunasan (berlaku untuk kedua jalur di atas):\n'
                  '• Bayar Satuan: Melalui menu titik tiga di samping tagihan. Sistem mendukung bayar Parsial (dicicil) maupun Lunas.\n'
                  '• Bayar Sekaligus: Melalui checklist beberapa tagihan sekaligus. Sistem mewajibkan pembayaran LUNAS sesuai total akumulasi semua tagihan yang dicentang tersebut.',
            ),
            _buildInfoBlock(
              icon: Icons.domain_verification,
              title: 'C. Validasi Pembayaran',
              content:
                  'Bendahara memiliki menu khusus "Validasi Pembayaran" di Dashboard. Pada menu ini, Bendahara bertugas memverifikasi konfirmasi transfer dari Wali Murid dengan mengklik "Setujui" jika dana sudah masuk, atau "Tolak" jika tidak valid. Tagihan baru akan terhitung Lunas/Tercicil setelah disetujui.',
            ),
            _buildInfoBlock(
              icon: Icons.account_balance_wallet,
              title: 'D. Transaksi Tabungan',
              content:
                  'Akses profil siswa melalui menu Data Siswa (atau Kasir), lalu buka tab "Tabungan". Di sana Anda dapat mencatat riwayat Setor Tunai (menambah saldo) maupun Tarik Tunai (mengurangi saldo) secara real-time.',
            ),
            _buildInfoBlock(
              icon: Icons.local_activity,
              title: 'E. Input Kegiatan Siswa',
              content:
                  'Guru atau Admin dapat mencatat partisipasi dan absensi kegiatan ekstrakurikuler/harian siswa melalui menu "Kegiatan Siswa" untuk memantau keaktifan non-akademik.',
            ),
            _buildInfoBlock(
              icon: Icons.edit_document,
              title: 'F. Penilaian Akademik',
              content:
                  'Guru masuk ke menu "Input Nilai", pilih kelas dan mata pelajaran yang diajarkan, lalu input nilai siswa (Tugas, UTS, UAS).',
            ),
            _buildInfoBlock(
              icon: Icons.analytics,
              title: 'G. Laporan & Monitoring',
              content:
                  'Pantau arus kas di "Laporan Pembayaran", riwayat saldo di "Laporan Tabungan", dan total jam mengajar mingguan secara otomatis di Dasbor Guru.',
            ),

            const SizedBox(height: 40),
            Center(
              child: Text(
                'ApSekolah v1.0',
                style: TextStyle(color: Colors.grey.shade500),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
    );
  }

  Widget _buildPhaseTitle(String title) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.flag, color: Colors.green.shade700, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.green.shade900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepCard({
    required String number,
    required String title,
    required String content,
  }) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: Colors.green.shade600,
              child: Text(
                number,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    content,
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoBlock({
    required IconData icon,
    required String title,
    required String content,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Colors.orange.shade700, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  content,
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
