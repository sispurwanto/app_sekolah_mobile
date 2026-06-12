import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/providers/school_provider.dart';
import '../../../../core/models/app_class.dart';
import '../../../../core/models/student.dart';
import '../../../../core/models/subject_master.dart';
import '../../master_data/services/class_service.dart';
import '../../master_data/services/subject_service.dart';
import '../../master_data/services/academic_year_service.dart';
import '../../student_management/services/student_service.dart';
import '../services/grade_service.dart';
import '../../../../core/utils/snackbar_utils.dart';

class TeacherGradeInputScreen extends StatefulWidget {
  const TeacherGradeInputScreen({super.key});

  @override
  State<TeacherGradeInputScreen> createState() => _TeacherGradeInputScreenState();
}

class _TeacherGradeInputScreenState extends State<TeacherGradeInputScreen> {
  final ClassService _classService = ClassService();
  final SubjectService _subjectService = SubjectService();
  final StudentService _studentService = StudentService();
  final GradeService _gradeService = GradeService();

  String? _selectedClassId;
  String? _selectedSubjectId;
  String? _selectedSubjectName;
  String _gradeType = 'Tugas 1';
  DateTime _selectedDate = DateTime.now();

  List<Student> _students = [];
  bool _isLoadingStudents = false;
  bool _isSaving = false;

  final Map<String, Map<String, TextEditingController>> _controllers = {};

  final List<String> _gradeTypes = [
    'Tugas 1', 'Tugas 2', 'Tugas 3', 'Tugas 4',
    'Ulangan Harian 1', 'Ulangan Harian 2', 'Ulangan Harian 3',
    'UTS', 'UAS'
  ];

  Future<void> _fetchStudents(String schoolId) async {
    if (_selectedClassId == null) return;
    setState(() {
      _isLoadingStudents = true;
      _controllers.clear();
    });

    try {
      final snapshot = await _studentService.fetchStudentsByClass(schoolId, _selectedClassId!);
      setState(() {
        _students = snapshot;
        for (var s in _students) {
          _controllers[s.id] = {
            'score': TextEditingController(),
            'notes': TextEditingController(),
          };
        }
      });
    } catch (e) {
      SnackbarUtils.showErrorSnackbar('Gagal memuat daftar siswa');
    } finally {
      setState(() {
        _isLoadingStudents = false;
      });
    }
  }

  Future<void> _saveGrades(String schoolId, String yearId) async {
    if (_selectedClassId == null || _selectedSubjectId == null) {
      SnackbarUtils.showErrorSnackbar('Pilih Kelas dan Mata Pelajaran');
      return;
    }

    List<Map<String, dynamic>> studentDataList = [];
    bool hasInput = false;

    for (var s in _students) {
      final scoreText = _controllers[s.id]!['score']!.text;
      final notesText = _controllers[s.id]!['notes']!.text;

      if (scoreText.trim().isNotEmpty) {
        hasInput = true;
        studentDataList.add({
          'id': s.id,
          'name': s.name,
          'score': double.tryParse(scoreText) ?? 0.0,
          'notes': notesText,
        });
      }
    }

    if (!hasInput) {
      SnackbarUtils.showErrorSnackbar('Belum ada nilai yang diinput');
      return;
    }

    setState(() => _isSaving = true);

    try {
      final dateStr = "${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}";
      
      await _gradeService.addBulkGrades(
        schoolId: schoolId,
        yearId: yearId,
        subjectId: _selectedSubjectId!,
        subjectName: _selectedSubjectName!,
        gradeType: _gradeType,
        dateStr: dateStr,
        studentGradesData: studentDataList,
      );

      SnackbarUtils.showSnackbar('Berhasil menyimpan nilai untuk ${studentDataList.length} siswa');
      Navigator.pop(context);
    } catch (e) {
      SnackbarUtils.showErrorSnackbar('Gagal menyimpan nilai: $e');
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    for (var map in _controllers.values) {
      map['score']?.dispose();
      map['notes']?.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final schoolId = context.watch<SchoolProvider>().activeSchoolId;

    if (schoolId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Input Nilai')),
        body: const Center(child: Text('Sekolah belum dipilih')),
      );
    }

    return FutureBuilder(
      future: AcademicYearService().getActiveAcademicYear(schoolId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        
        final activeYear = snapshot.data;
        if (activeYear == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Input Nilai')),
            body: const Center(child: Text('Tahun Ajaran belum aktif')),
          );
        }

        final yearId = activeYear.id;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Input Nilai Kelas'),
            actions: [
              if (_students.isNotEmpty)
                TextButton.icon(
                  onPressed: _isSaving ? null : () => _saveGrades(schoolId, yearId),
                  icon: _isSaving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.save, color: Colors.white),
                  label: const Text('Simpan', style: TextStyle(color: Colors.white)),
                ),
            ],
          ),
          body: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                color: Colors.white,
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: StreamBuilder<List<AppClass>>(
                            stream: _classService.getClasses(schoolId),
                            builder: (context, snapshot) {
                              final classes = snapshot.data ?? [];
                              return DropdownButtonFormField<String>(
                                isExpanded: true,
                                decoration: const InputDecoration(labelText: 'Kelas', border: OutlineInputBorder()),
                                value: _selectedClassId,
                                items: classes.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name, overflow: TextOverflow.ellipsis))).toList(),
                                onChanged: (val) {
                                  setState(() {
                                    _selectedClassId = val;
                                  });
                                  _fetchStudents(schoolId);
                                },
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: StreamBuilder<List<SubjectMaster>>(
                            stream: _subjectService.getSubjects(schoolId),
                            builder: (context, snapshot) {
                              final subjects = snapshot.data ?? [];
                              return DropdownButtonFormField<String>(
                                isExpanded: true,
                                decoration: const InputDecoration(labelText: 'Mata Pelajaran', border: OutlineInputBorder()),
                                value: _selectedSubjectId,
                                items: subjects.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name, overflow: TextOverflow.ellipsis))).toList(),
                                onChanged: (val) {
                                  setState(() {
                                    _selectedSubjectId = val;
                                    _selectedSubjectName = subjects.firstWhere((s) => s.id == val).name;
                                  });
                                },
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            isExpanded: true,
                            decoration: const InputDecoration(labelText: 'Jenis Penilaian', border: OutlineInputBorder()),
                            value: _gradeType,
                            items: _gradeTypes.map((t) => DropdownMenuItem(value: t, child: Text(t, overflow: TextOverflow.ellipsis))).toList(),
                            onChanged: (val) => setState(() => _gradeType = val!),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final date = await showDatePicker(
                                context: context,
                                initialDate: _selectedDate,
                                firstDate: DateTime(2000),
                                lastDate: DateTime(2100),
                              );
                              if (date != null) setState(() => _selectedDate = date);
                            },
                            child: InputDecorator(
                              decoration: const InputDecoration(labelText: 'Tanggal', border: OutlineInputBorder()),
                              child: Text("${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}"),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: _isLoadingStudents
                    ? const Center(child: CircularProgressIndicator())
                    : _students.isEmpty
                        ? const Center(child: Text('Pilih kelas untuk melihat daftar siswa'))
                        : ListView.builder(
                            itemCount: _students.length,
                            itemBuilder: (context, index) {
                              final student = _students[index];
                              return Card(
                                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Row(
                                    children: [
                                      CircleAvatar(child: Text('${index + 1}')),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        flex: 2,
                                        child: Text(student.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                      ),
                                      Expanded(
                                        flex: 1,
                                        child: TextField(
                                          controller: _controllers[student.id]!['score'],
                                          keyboardType: TextInputType.number,
                                          decoration: const InputDecoration(
                                            labelText: 'Nilai',
                                            isDense: true,
                                            border: OutlineInputBorder(),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        flex: 2,
                                        child: TextField(
                                          controller: _controllers[student.id]!['notes'],
                                          decoration: const InputDecoration(
                                            labelText: 'Catatan',
                                            isDense: true,
                                            border: OutlineInputBorder(),
                                          ),
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
          ),
        );
      }
    );
  }
}
