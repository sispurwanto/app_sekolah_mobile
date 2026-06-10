import 'package:flutter/material.dart';

class ManualBookScreen extends StatelessWidget {
  const ManualBookScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Buku Panduan'),
        backgroundColor: Colors.blue.shade800,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 16.0),
            child: Text(
              'Panduan Penggunaan Aplikasi',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
          ),

          _buildAccordion(
            icon: Icons.admin_panel_settings,
            title: '1. Manajemen Pengguna & Hak Akses',
            content:
                'Aplikasi ini mendukung berbagai tingkat hak akses (Role):\n'
                '• Super Admin & Admin: Memiliki akses penuh ke semua fitur dan pengaturan sekolah.\n'
                '• Kepala Sekolah: Dapat melihat semua laporan, keuangan, dan data tanpa bisa mengubah pengaturan utama.\n'
                '• Bendahara: Bertanggung jawab atas tagihan, penerimaan pembayaran, dan memvalidasi setoran tabungan.\n'
                '• Guru: Dapat melihat data siswa di kelas yang diajarnya dan absensi/nilai (jika modul diaktifkan).\n'
                '• Wali / Orang Tua: Dapat melihat daftar tagihan, riwayat pembayaran, dan riwayat tabungan untuk anaknya saja.',
          ),

          _buildAccordion(
            icon: Icons.dataset,
            title: '2. Master Data',
            content:
                'Master data adalah data inti yang harus disiapkan sebelum menggunakan fitur transaksi:\n'
                '• Tahun Ajaran: Buat periode tahun ajaran (contoh: 2026/2027) dan tandai yang sedang aktif.\n'
                '• Data Kelas: Tambahkan nama-nama kelas (contoh: Kelas 1A, Kelas 2B) dan tentukan Wali Kelasnya.\n'
                '• Master Tagihan: Buat templat tarif biaya (contoh: SPP Bulanan Rp100.000, Uang Gedung Rp500.000) yang nanti akan digunakan saat membuat tagihan massal.',
          ),

          _buildAccordion(
            icon: Icons.people,
            title: '3. Manajemen Siswa',
            content:
                'Pada menu ini Anda dapat mendata seluruh siswa:\n'
                '• Saat menambahkan siswa, isi informasi seperti NIS, Nama, Kelas, dan Tahun Ajaran.\n'
                '• Pusat Transaksi: Untuk mempermudah penggunaan aplikasi, semua transaksi (Tagihan dan Tabungan) diakses langsung dari Daftar Siswa. Cukup cari nama siswa, lalu klik tombol "Tagihan" atau "Tabungan" pada profil mereka.\n'
                '• Anda dapat menautkan akun "Wali Murid" (jika sudah terdaftar di menu User) agar orang tua tersebut bisa login dan melihat data anaknya.\n'
                '• Pastikan data "Nama Orang Tua / Wali" dan "No. HP" diisi untuk mempermudah komunikasi dan identifikasi laporan.',
          ),

          _buildAccordion(
            icon: Icons.receipt_long,
            title: '4. Tagihan (Invoice)',
            content:
                'Fitur Tagihan digunakan untuk menagih biaya sekolah kepada siswa:\n'
                '• Buat Tagihan Massal: Gunakan tombol + di menu Tagihan untuk men-*generate* tagihan per kelas secara otomatis. Pilih Kelas, Tahun Ajaran, dan Master Tagihan (Templat Tarif).\n'
                '• Status Tagihan: UNPAID (Belum Bayar), PARTIAL (Bayar Sebagian/Mencicil), dan PAID (Lunas).\n',
          ),

          _buildAccordion(
            icon: Icons.payment,
            title: '5. Pembayaran (Payment)',
            content:
                'Untuk melunasi tagihan yang sudah dibuat:\n'
                '• Buka daftar Tagihan, pilih tagihan yang ingin dibayar, lalu klik tombol "Bayar".\n'
                '• Masukkan jumlah nominal yang dibayar (bisa dibayar lunas atau dicicil sebagian).\n'
                '• Validasi: Bendahara memiliki menu "Validasi Pembayaran" untuk memverifikasi pembayaran yang mungkin dilakukan melalui transfer agar statusnya disahkan.',
          ),

          _buildAccordion(
            icon: Icons.account_balance_wallet,
            title: '6. Tabungan Siswa',
            content:
                'Modul ini membantu sekolah mencatat uang tabungan harian siswa:\n'
                '• Setor & Tarik: Cari nama siswa di menu Tabungan, lalu pilih aksi Setor Tunai (Deposit) atau Tarik Tunai (Withdrawal).\n'
                '• Transaksi Real-time: Setiap penyetoran dan penarikan akan langsung memotong/menambah Saldo Saat Ini milik siswa.\n'
                '• Riwayat: Di bagian bawah profil siswa, terdapat daftar 30 hari terakhir dari transaksi tabungannya.',
          ),

          _buildAccordion(
            icon: Icons.analytics,
            title: '7. Laporan (Reports)',
            content:
                'Semua transaksi terekap otomatis di menu Laporan:\n'
                '• Laporan Keuangan: Membandingkan total Pemasukan (Pembayaran Lunas/Sebagian) dengan Tunggakan (Tagihan yang belum dibayar) pada rentang waktu tertentu.\n'
                '• Laporan Tabungan: Menampilkan daftar lengkap saldo tabungan seluruh siswa, yang memfilter hanya siswa bersaldo lebih dari 0.\n'
                '• Export Data: Anda dapat mengunduh laporan-laporan ini ke dalam bentuk Excel maupun PDF untuk dicetak atau diarsip.',
          ),

          const SizedBox(height: 40),
          Center(
            child: Text(
              'Versi Aplikasi 1.0.0\nTim IT Support',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccordion({
    required IconData icon,
    required String title,
    required String content,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: Colors.blue.shade50,
          child: Icon(icon, color: Colors.blue.shade800),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(),
          const SizedBox(height: 8),
          Text(content, style: const TextStyle(height: 1.5, fontSize: 14)),
        ],
      ),
    );
  }
}
