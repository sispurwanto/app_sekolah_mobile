import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/models/student.dart';
import '../../../core/providers/school_provider.dart';
import '../../../core/providers/user_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

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
    final role = context.read<UserProvider>().userMapping?.registeredSchools[schoolId] ?? 'WALI';
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final isGuru = role == 'GURU';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manajemen Siswa'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(120.0), // Increased height for two fields
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Column(
              children: [
                // Pencarian Text
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    fillColor: Colors.white,
                    filled: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    hintText: 'Cari nama atau NIS siswa...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                  ),
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val.toLowerCase();
                    });
                  },
                ),
                const SizedBox(height: 8),
                // Filter Kelas
                StreamBuilder<List<AppClass>>(
                  stream: _classService.getClasses(schoolId, teacherId: isGuru ? uid : null),
                  builder: (context, snapshot) {
                    final classes = snapshot.data ?? [];
                    
                    // Auto-select first class for GURU if none selected
                    if (isGuru && _selectedClassFilter.isEmpty && classes.isNotEmpty) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) setState(() => _selectedClassFilter = classes.first.id);
                      });
                    }

                    return DropdownButtonFormField<String>(
                      value: _selectedClassFilter.isEmpty ? null : _selectedClassFilter,
                      decoration: InputDecoration(
                        fillColor: Colors.white,
                        filled: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        hintText: 'Filter berdasarkan Kelas (Max 100)',
                      ),
                      items: [
                        if (!isGuru)
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
              ],
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

          var students = snapshot.data ?? [];

          if (_searchQuery.isNotEmpty) {
            students = students.where((s) {
              return s.name.toLowerCase().contains(_searchQuery) || 
                     s.nis.toLowerCase().contains(_searchQuery);
            }).toList();
          }

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
