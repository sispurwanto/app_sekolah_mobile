import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/models/student.dart';
import '../../../core/providers/school_provider.dart';
import '../services/student_service.dart';
import 'student_form_screen.dart';

class StudentListScreen extends StatelessWidget {
  StudentListScreen({super.key});

  final StudentService _studentService = StudentService();

  @override
  Widget build(BuildContext context) {
    final schoolId = context.watch<SchoolProvider>().activeSchoolId ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manajemen Siswa'),
      ),
      body: StreamBuilder<List<Student>>(
        stream: _studentService.getStudents(schoolId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final students = snapshot.data ?? [];

          if (students.isEmpty) {
            return const Center(child: Text('Belum ada data siswa.'));
          }

          return ListView.builder(
            itemCount: students.length,
            itemBuilder: (context, index) {
              final student = students[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    child: Text(student.gender == 'L' ? 'L' : 'P'),
                  ),
                  title: Text(student.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('NIS: ${student.nis} | Kelas: ${student.classId}\nWali: ${student.guardianId.isNotEmpty ? student.guardianId : "-"}'),
                  isThreeLine: true,
                  trailing: IconButton(
                    icon: const Icon(Icons.edit, color: Colors.blue),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => StudentFormScreen(student: student),
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
            MaterialPageRoute(
              builder: (context) => const StudentFormScreen(),
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
