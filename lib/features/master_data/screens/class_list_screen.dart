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
                elevation: 3,
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.class_,
                          color: Theme.of(context).primaryColor,
                          size: 32,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              appClass.name,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Wali: ${appClass.teacherName ?? "Belum Ditentukan"}',
                              style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w500),
                            ),
                            if (appClass.description.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                appClass.description,
                                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              'Tk. ${appClass.level}',
                              style: TextStyle(
                                color: Colors.blue.shade800,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.blue),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ClassFormScreen(appClass: appClass),
                                ),
                              );
                            },
                          ),
                        ],
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
            MaterialPageRoute(builder: (context) => const ClassFormScreen()),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
