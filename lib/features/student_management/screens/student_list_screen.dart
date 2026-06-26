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
import '../../activities/screens/student_activity_screen.dart';
import '../../grades/screens/parent_grade_screen.dart';
import '../../../core/utils/snackbar_utils.dart';
import '../../../core/utils/dialog_utils.dart';
import 'student_form_screen.dart';
import '../../../core/widgets/empty_state_widget.dart';

class StudentListScreen extends StatefulWidget {
  final bool activeOnly;

  const StudentListScreen({super.key, this.activeOnly = true});

  @override
  State<StudentListScreen> createState() => _StudentListScreenState();
}

class _StudentListScreenState extends State<StudentListScreen> {
  final StudentService _studentService = StudentService();
  final ClassService _classService = ClassService();
  bool _isGenerating = false;
  String _selectedClassFilter = '';
  late String _statusFilter;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  Future<List<Student>>? _studentsFuture;

  @override
  void initState() {
    super.initState();
    _statusFilter = widget.activeOnly ? 'ACTIVE' : 'INACTIVE';
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_studentsFuture == null) {
      _loadStudents();
    }
  }

  void _loadStudents() {
    final schoolId = context.read<SchoolProvider>().activeSchoolId ?? '';
    
    if (widget.activeOnly && _selectedClassFilter.isEmpty) {
      setState(() {
        _studentsFuture = null;
      });
      return;
    }

    setState(() {
      _studentsFuture = _studentService.fetchStudentsByClass(
        schoolId,
        _selectedClassFilter,
        statusFilter: _statusFilter,
      );
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    final schoolId = context.watch<SchoolProvider>().activeSchoolId ?? '';
    final role =
        context.read<UserProvider>().userMapping?.registeredSchools[schoolId] ??
        'WALI';
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final isGuru = role == 'GURU';

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.activeOnly ? 'Daftar Siswa' : 'Siswa Lulus / Nonaktif',
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(
            120.0,
          ), // Increased height for two fields
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: Column(
              children: [
                // Pencarian Text
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    fillColor: Colors.white,
                    filled: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
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
                  stream: _classService.getClasses(
                    schoolId,
                    teacherId: isGuru ? uid : null,
                  ),
                  builder: (context, snapshot) {
                    final classes = snapshot.data ?? [];

                    // Auto-select first class for GURU if none selected
                    if (isGuru &&
                        _selectedClassFilter.isEmpty &&
                        classes.isNotEmpty) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) {
                          setState(() {
                            _selectedClassFilter = classes.first.id;
                            _loadStudents();
                          });
                        }
                      });
                    }

                    return DropdownButtonFormField<String>(
                      value: _selectedClassFilter.isEmpty
                          ? ''
                          : _selectedClassFilter,
                      decoration: InputDecoration(
                        fillColor: Colors.white,
                        filled: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        hintText: 'Pilih Kelas',
                      ),
                      items: [
                        if (!widget.activeOnly)
                          const DropdownMenuItem(
                            value: '',
                            child: Text('Semua Kelas (Max 500)'),
                          ),
                        if (widget.activeOnly)
                          const DropdownMenuItem(
                            value: '',
                            child: Text('Pilih Kelas...'),
                          ),
                        ...classes.map(
                          (c) => DropdownMenuItem(
                            value: c.id,
                            child: Text(c.name),
                          ),
                        ),
                      ],
                      onChanged: (val) {
                        setState(() {
                          _selectedClassFilter = val ?? '';
                          _loadStudents();
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
      body: RefreshIndicator(
        onRefresh: () async {
          _loadStudents();
          if (_studentsFuture != null) await _studentsFuture;
        },
        child: _studentsFuture == null 
            ? const EmptyStateWidget(
                icon: Icons.class_,
                title: 'Silakan Pilih Kelas',
                subtitle: 'Pilih kelas dari dropdown di atas untuk menampilkan data siswa.',
              )
            : FutureBuilder<List<Student>>(
          future: _studentsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }

            final allStudents = snapshot.data ?? [];

            var students = allStudents;

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
                if (!widget.activeOnly)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 8.0,
                    ),
                    child: SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(
                          value: 'INACTIVE',
                          label: Text(
                            'Nonaktif',
                            style: TextStyle(fontSize: 10),
                          ),
                        ),
                        ButtonSegment(
                          value: 'GRADUATED',
                          label: Text('Lulus', style: TextStyle(fontSize: 10)),
                        ),
                      ],
                      selected: {_statusFilter},
                      onSelectionChanged: (Set<String> newSelection) {
                        setState(() {
                          _statusFilter = newSelection.first;
                          _loadStudents();
                        });
                      },
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 8.0,
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Total Siswa: ${students.length}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: students.isEmpty
                      ? const EmptyStateWidget(
                          icon: Icons.group_off,
                          title: 'Belum ada data siswa',
                          subtitle:
                              'Silakan tambah data siswa atau ubah filter pencarian.',
                        )
                      : ListView.builder(
                          itemCount: students.length,
                          itemBuilder: (context, index) {
                            final student = students[index];
                            return Card(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: student.gender == 'L'
                                      ? Colors.blue.withOpacity(0.1)
                                      : Colors.pink.withOpacity(0.1),
                                  child: Icon(
                                    student.gender == 'L'
                                        ? Icons.face
                                        : Icons.face_3,
                                    color: student.gender == 'L'
                                        ? Colors.blue
                                        : Colors.pink,
                                  ),
                                ),
                                title: Text(
                                  student.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 4),
                                    Text(
                                      'NIS: ${student.nis} | Kelas: ${student.classId.isNotEmpty ? student.classId : "-"}',
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Ortu: ${student.guardianName.isNotEmpty ? student.guardianName : "-"} | HP: ${student.phone.isNotEmpty ? student.phone : "-"}',
                                    ),
                                    // Invoice stats removed to save reads
                                    const SizedBox(height: 12),
                                    // Action Buttons
                                    SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      child: Row(
                                        children: [
                                          if (!isGuru &&
                                              role != 'KEPALA_SEKOLAH') ...[
                                            _buildActionButton(
                                              context,
                                              Icons.receipt_long,
                                              'Tagihan',
                                              () {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (context) =>
                                                        InvoiceListScreen(
                                                          studentId: student.id,
                                                          academicYearId: null,
                                                          classId:
                                                              student
                                                                  .classId
                                                                  .isNotEmpty
                                                              ? student.classId
                                                              : null,
                                                        ),
                                                  ),
                                                );
                                              },
                                              Colors.blue,
                                            ),
                                            const SizedBox(width: 8),
                                            _buildActionButton(
                                              context,
                                              Icons.account_balance_wallet,
                                              'Tabungan',
                                              () {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (c) =>
                                                        SavingsScreen(
                                                          studentId: student.id,
                                                          studentName:
                                                              student.name,
                                                          classId:
                                                              student.classId,
                                                        ),
                                                  ),
                                                );
                                              },
                                              Colors.teal,
                                            ),
                                          ],
                                          if (role != 'BENDAHARA') ...[
                                            _buildActionButton(
                                              context,
                                              Icons.local_activity,
                                              'Kegiatan',
                                              () {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (context) =>
                                                        StudentActivityScreen(
                                                          student: student,
                                                        ),
                                                  ),
                                                );
                                              },
                                              Colors.orange,
                                            ),
                                            const SizedBox(width: 8),
                                            _buildActionButton(
                                              context,
                                              Icons.edit_note,
                                              'Nilai',
                                              () {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (context) =>
                                                        ParentGradeScreen(
                                                          studentId: student.id,
                                                          studentName:
                                                              student.name,
                                                        ),
                                                  ),
                                                );
                                              },
                                              Colors.purple,
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                trailing: PopupMenuButton<String>(
                                  onSelected: (value) async {
                                    if (value == 'edit') {
                                      final result = await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              StudentFormScreen(
                                                student: student,
                                              ),
                                        ),
                                      );
                                      if (result == true) {
                                        _loadStudents();
                                      }
                                    } else if (value == 'kegiatan') {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              StudentActivityScreen(
                                                student: student,
                                              ),
                                        ),
                                      );
                                    }
                                  },
                                  itemBuilder: (BuildContext context) =>
                                      <PopupMenuEntry<String>>[
                                        if (!isGuru &&
                                            role != 'KEPALA_SEKOLAH') ...[
                                          const PopupMenuItem<String>(
                                            value: 'edit',
                                            child: ListTile(
                                              leading: Icon(Icons.edit),
                                              title: Text('Edit Siswa'),
                                              contentPadding: EdgeInsets.zero,
                                            ),
                                          ),
                                        ],
                                        if (role != 'BENDAHARA')
                                          const PopupMenuItem<String>(
                                            value: 'kegiatan',
                                            child: ListTile(
                                              leading: Icon(
                                                Icons.local_activity,
                                              ),
                                              title: Text('Kegiatan Siswa'),
                                              contentPadding: EdgeInsets.zero,
                                            ),
                                          ),
                                      ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        ),
      ),
      // Loading Overlay
      bottomNavigationBar: _isGenerating
          ? const LinearProgressIndicator()
          : null,
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const StudentFormScreen()),
          );
          if (result == true) {
            _loadStudents();
          }
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
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton(
    BuildContext context,
    IconData icon,
    String label,
    VoidCallback onTap,
    Color color,
  ) {
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
