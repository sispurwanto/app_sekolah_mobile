import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/models/app_class.dart';
import '../../../core/providers/school_provider.dart';
import '../services/class_service.dart';
import 'class_form_screen.dart';
import '../../../core/widgets/empty_state_widget.dart';

class ClassListScreen extends StatelessWidget {
  ClassListScreen({super.key});

  final ClassService _service = ClassService();

  @override
  Widget build(BuildContext context) {
    final schoolId = context.watch<SchoolProvider>().activeSchoolId ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('Data Kelas')),
      body: StreamBuilder<List<AppClass>>(
        stream: _service.getClasses(schoolId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final classes = snapshot.data ?? [];

          if (classes.isEmpty) {
            return const EmptyStateWidget(
              icon: Icons.class_outlined,
              title: 'Belum ada data Kelas',
              subtitle: 'Tambahkan kelas melalui menu di bawah.',
            );
          }

          return ListView.builder(
            itemCount: classes.length,
            itemBuilder: (context, index) {
              final appClass = classes[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  title: Text(
                    appClass.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    'Tingkat: ${appClass.level}\n'
                    'Wali Kelas: ${appClass.teacherName ?? "Belum Ditentukan"}\n'
                    '${appClass.description}',
                  ),
                  isThreeLine: true,
                  trailing: IconButton(
                    icon: const Icon(Icons.edit, color: Colors.blue),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              ClassFormScreen(appClass: appClass),
                        ),
                      );
                    },
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
            MaterialPageRoute(builder: (context) => const ClassFormScreen()),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
