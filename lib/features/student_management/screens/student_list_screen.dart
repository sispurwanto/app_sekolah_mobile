import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/models/student.dart';
import '../../../core/providers/school_provider.dart';
import '../services/student_service.dart';
import '../../master_data/services/class_service.dart';
import '../../../core/models/app_class.dart';
import '../../invoices/services/invoice_service.dart';
import '../../invoices/screens/invoice_list_screen.dart';
import '../../../core/utils/snackbar_utils.dart';
import '../../../core/utils/dialog_utils.dart';
import 'student_form_screen.dart';

class StudentListScreen extends StatefulWidget {
  const StudentListScreen({super.key});

  @override
  State<StudentListScreen> createState() => _StudentListScreenState();
}

class _StudentListScreenState extends State<StudentListScreen> {
  final StudentService _studentService = StudentService();
  final ClassService _classService = ClassService();
  bool _isGenerating = false;
  String _selectedClassFilter = '';

  Future<void> _handleGenerateInvoice(BuildContext context, String schoolId, Student student) async {
    if (student.academicYearId.isEmpty || student.classId.isEmpty) {
      SnackbarUtils.showErrorSnackbar('Siswa belum memiliki Kelas atau Tahun Ajaran aktif');
      return;
    }

    final confirm = await DialogUtils.showConfirmationDialog(
      title: 'Generate Tagihan',
      content: 'Generate tagihan untuk ${student.name} (Kelas: ${student.classId}) berdasarkan Master Tagihan?',
      confirmText: 'Generate',
    );

    if (confirm == true) {
      setState(() => _isGenerating = true);
      try {
        await InvoiceService().generateInvoicesForStudent(
          schoolId: schoolId,
          academicYearId: student.academicYearId,
          classId: student.classId,
          studentId: student.id,
          studentName: student.name,
        );
        SnackbarUtils.showSnackbar('Tagihan berhasil di-generate!');
      } catch (e) {
        SnackbarUtils.showErrorSnackbar('Gagal: $e');
      } finally {
        if (mounted) setState(() => _isGenerating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final schoolId = context.watch<SchoolProvider>().activeSchoolId ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manajemen Siswa'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60.0),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: StreamBuilder<List<AppClass>>(
              stream: _classService.getClasses(schoolId),
              builder: (context, snapshot) {
                final classes = snapshot.data ?? [];
                return DropdownButtonFormField<String>(
                  value: _selectedClassFilter.isEmpty ? null : _selectedClassFilter,
                  decoration: InputDecoration(
                    fillColor: Colors.white,
                    filled: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    hintText: 'Filter berdasarkan Kelas (Menampilkan max 100 jika kosong)',
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Semua Kelas (Max 100)')),
                    ...classes.map((c) => DropdownMenuItem(
                          value: c.id,
                          child: Text(c.name),
                        )),
                  ],
                  onChanged: (val) {
                    setState(() {
                      _selectedClassFilter = val ?? '';
                    });
                  },
                );
              },
            ),
          ),
        ),
      ),
      body: StreamBuilder<List<Student>>(
        stream: _studentService.getStudentsByClass(schoolId, _selectedClassFilter),
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
                  subtitle: Text(
                    'NIS: ${student.nis} | Kelas: ${student.classId.isNotEmpty ? student.classId : "-"}\n'
                    'Wali: ${student.guardianName.isNotEmpty ? student.guardianName : (student.guardianId.isNotEmpty ? student.guardianId : "-")}'
                  ),
                  isThreeLine: true,
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'edit') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => StudentFormScreen(student: student),
                          ),
                        );
                      } else if (value == 'generate') {
                        _handleGenerateInvoice(context, schoolId, student);
                      } else if (value == 'view_invoices') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => InvoiceListScreen(
                              studentId: student.id,
                              academicYearId: student.academicYearId.isNotEmpty ? student.academicYearId : null,
                              classId: student.classId.isNotEmpty ? student.classId : null,
                            ),
                          ),
                        );
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Text('Edit Siswa'),
                      ),
                      const PopupMenuItem(
                        value: 'generate',
                        child: Text('Generate Tagihan'),
                      ),
                      const PopupMenuItem(
                        value: 'view_invoices',
                        child: Text('Lihat Tagihan'),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      // Loading Overlay
      bottomNavigationBar: _isGenerating
          ? const LinearProgressIndicator()
          : null,
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
