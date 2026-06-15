import 'package:flutter/material.dart';

class TeacherReportScreen extends StatelessWidget {
  const TeacherReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cetak Rapor')),
      body: const Center(
        child: Text(
          'Modul Pembuatan & Cetak Raport sedang dalam pengembangan.\n(Nantinya akan menarik data dari StudentGrades secara otomatis)',
        ),
      ),
    );
  }
}
