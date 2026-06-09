import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/models/student.dart';
import '../../../core/providers/school_provider.dart';
import '../../../core/providers/user_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/student_service.dart';
import '../../savings/screens/savings_screen.dart';
import '../../master_data/services/class_service.dart';
import '../../../core/models/app_class.dart';
import '../../../core/models/invoice.dart';
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
  String _statusFilter = 'ACTIVE';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _handleGenerateInvoice(BuildContext context, String schoolId, Student student) async {
    if (student.status != 'ACTIVE') {
      SnackbarUtils.showErrorSnackbar('Tagihan hanya bisa dibuat untuk siswa aktif');
      return;
    }
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

          final allStudents = snapshot.data ?? [];
          
          final allCount = allStudents.length;
          final activeCount = allStudents.where((s) => s.status == 'ACTIVE').length;
          final inactiveCount = allStudents.where((s) => s.status == 'INACTIVE').length;
          final gradCount = allStudents.where((s) => s.status == 'GRADUATED').length;

          var students = allStudents;
          
          if (_statusFilter != 'SEMUA') {
            students = students.where((s) => s.status == _statusFilter).toList();
          }

          if (_searchQuery.isNotEmpty) {
            students = students.where((s) {
              return s.name.toLowerCase().contains(_searchQuery) || 
                     s.nis.toLowerCase().contains(_searchQuery);
            }).toList();
          }

          // Sort by class_id first, then by name
          students.sort((a, b) {
            int classComp = a.classId.compareTo(b.classId);
            if (classComp != 0) return classComp;
            return a.name.toLowerCase().compareTo(b.name.toLowerCase());
          });

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: SegmentedButton<String>(
                  segments: [
                    ButtonSegment(value: 'SEMUA', label: Text('Semua ($allCount)', style: const TextStyle(fontSize: 10))),
                    ButtonSegment(value: 'ACTIVE', label: Text('Aktif ($activeCount)', style: const TextStyle(fontSize: 10))),
                    ButtonSegment(value: 'INACTIVE', label: Text('Nonaktif ($inactiveCount)', style: const TextStyle(fontSize: 10))),
                    ButtonSegment(value: 'GRADUATED', label: Text('Lulus ($gradCount)', style: const TextStyle(fontSize: 10))),
                  ],
                  selected: {_statusFilter},
                  onSelectionChanged: (Set<String> newSelection) {
                    setState(() {
                      _statusFilter = newSelection.first;
                    });
                  },
                ),
              ),
              Expanded(
                child: students.isEmpty 
                  ? const Center(child: Text('Belum ada data siswa.'))
                  : ListView.builder(
                    itemCount: students.length,
                    itemBuilder: (context, index) {
                      final student = students[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: StreamBuilder<List<Invoice>>(
                  stream: (student.academicYearId.isNotEmpty && student.classId.isNotEmpty) 
                      ? InvoiceService().getStudentInvoices(schoolId, student.academicYearId, student.classId, student.id)
                      : Stream.value([]),
                  builder: (context, invSnapshot) {
                    final invoices = invSnapshot.data ?? [];
                    int total = invoices.length;
                    int paid = invoices.where((i) => i.status == 'PAID').length;
                    int partial = invoices.where((i) => i.status == 'PARTIAL').length;
                    int unpaid = invoices.where((i) => i.status == 'UNPAID').length;

                    return ListTile(
                      leading: CircleAvatar(
                        child: Text(student.gender == 'L' ? 'L' : 'P'),
                      ),
                      title: Text(student.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text('NIS: ${student.nis} | Kelas: ${student.classId.isNotEmpty ? student.classId : "-"}'),
                          const SizedBox(height: 8),
                          if (total == 0)
                            const Text('Belum ada tagihan', style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic))
                          else
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  _buildStatItem('Tagihan', total.toString(), Colors.black87),
                                  _buildStatItem('Lunas', paid.toString(), Colors.green),
                                  _buildStatItem('Sebagian', partial.toString(), Colors.orange),
                                  _buildStatItem('Tunggak', unpaid.toString(), Colors.red),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            // Action Buttons
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  _buildActionButton(context, Icons.receipt_long, 'Tagihan', () {
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
                                  }, Colors.blue),
                                  // const SizedBox(width: 8),
                                  // _buildActionButton(context, Icons.assignment, 'Ulangan', () {
                                  //   SnackbarUtils.showErrorSnackbar('Modul Ulangan sedang dalam pengembangan');
                                  // }, Colors.green),
                                  // const SizedBox(width: 8),
                                  // _buildActionButton(context, Icons.library_books, 'Raport', () {
                                  //   SnackbarUtils.showErrorSnackbar('Modul Raport sedang dalam pengembangan');
                                  // }, Colors.orange),
                                  // const SizedBox(width: 8),
                                  // _buildActionButton(context, Icons.fact_check, 'Absensi', () {
                                  //   SnackbarUtils.showErrorSnackbar('Modul Absensi sedang dalam pengembangan');
                                  // }, Colors.purple),
                                  const SizedBox(width: 8),
                                  _buildActionButton(context, Icons.account_balance_wallet, 'Tabungan', () {
                                    Navigator.push(
                                      context, 
                                      MaterialPageRoute(
                                        builder: (c) => SavingsScreen(
                                          studentId: student.id,
                                          studentName: student.name,
                                          classId: student.classId,
                                        ),
                                      ),
                                    );
                                  }, Colors.teal),
                                ],
                              ),
                            ),
                        ],
                      ),
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
                          }
                        },
                        itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                          const PopupMenuItem<String>(
                            value: 'edit',
                            child: ListTile(
                              leading: Icon(Icons.edit),
                              title: Text('Edit Siswa'),
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                          const PopupMenuItem<String>(
                            value: 'generate',
                            child: ListTile(
                              leading: Icon(Icons.add_card),
                              title: Text('Generate Tagihan'),
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                ),
              );
            },
          ),
              )
            ],
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

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  Widget _buildActionButton(BuildContext context, IconData icon, String label, VoidCallback onTap, Color color) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 10)),
          ],
        ),
      ),
    );
  }
}
