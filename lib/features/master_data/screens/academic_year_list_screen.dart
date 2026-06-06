import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/models/academic_year.dart';
import '../../../core/providers/school_provider.dart';
import '../services/academic_year_service.dart';
import 'academic_year_form_screen.dart';

class AcademicYearListScreen extends StatelessWidget {
  AcademicYearListScreen({super.key});

  final AcademicYearService _service = AcademicYearService();

  @override
  Widget build(BuildContext context) {
    final schoolId = context.watch<SchoolProvider>().activeSchoolId ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tahun Ajaran'),
      ),
      body: StreamBuilder<List<AcademicYear>>(
        stream: _service.getAcademicYears(schoolId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final years = snapshot.data ?? [];

          if (years.isEmpty) {
            return const Center(child: Text('Belum ada data Tahun Ajaran.'));
          }

          return ListView.builder(
            itemCount: years.length,
            itemBuilder: (context, index) {
              final year = years[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  title: Text(year.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(year.isActive ? 'Status: Aktif' : 'Status: Tidak Aktif'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (year.isActive)
                        const Icon(Icons.check_circle, color: Colors.green),
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => AcademicYearFormScreen(academicYear: year),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AcademicYearFormScreen(),
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
