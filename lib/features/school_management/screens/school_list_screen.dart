import 'package:flutter/material.dart';
import '../../../core/models/school.dart';
import '../services/school_service.dart';
import 'school_form_screen.dart';
import '../../../core/utils/dialog_utils.dart';
import '../../../core/utils/snackbar_utils.dart';

class SchoolListScreen extends StatelessWidget {
  SchoolListScreen({super.key});

  final SchoolService _schoolService = SchoolService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manajemen Sekolah'),
      ),
      body: StreamBuilder<List<School>>(
        stream: _schoolService.getSchools(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final schools = snapshot.data ?? [];

          if (schools.isEmpty) {
            return const Center(child: Text('Belum ada data sekolah.'));
          }

          return ListView.builder(
            itemCount: schools.length,
            itemBuilder: (context, index) {
              final school = schools[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  title: Text(school.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('${school.id}\nStatus: ${school.status} | Package: ${school.package}'),
                  isThreeLine: true,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => SchoolFormScreen(school: school),
                            ),
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () async {
                          final confirm = await DialogUtils.showConfirmationDialog(
                            title: 'Hapus Sekolah',
                            content: 'Yakin ingin menghapus ${school.name}?',
                            confirmText: 'Hapus',
                            isDestructive: true,
                          );
                          if (confirm == true) {
                            try {
                              await _schoolService.deleteSchool(school.id);
                              SnackbarUtils.showSnackbar('Sekolah berhasil dihapus');
                            } catch (e) {
                              SnackbarUtils.showErrorSnackbar('Gagal menghapus: $e');
                            }
                          }
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
              builder: (context) => const SchoolFormScreen(),
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
