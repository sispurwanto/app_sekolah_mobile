import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/providers/school_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/models/student.dart';
import '../../../../core/models/class_schedule.dart';
import '../../../../core/models/academic_year.dart';
import '../../master_data/services/schedule_service.dart';
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
  final ScheduleService _scheduleService = ScheduleService();
  final StudentService _studentService = StudentService();
  final GradeService _gradeService = GradeService();
  final AcademicYearService _academicYearService = AcademicYearService();

  String? _selectedAcademicYearId;
  String? _activeAcademicYearId;
  List<AcademicYear> _academicYears = [];
  bool _isLoadingYears = true;

  String? _selectedClassId;
  String? _selectedSubjectId;
  String? _selectedSubjectName;
  String? _currentTeacherName;
  late List<String> _gradeTypes;
  late String _gradeType;
  DateTime _selectedDate = DateTime.now();

  List<Student> _students = [];
  bool _isLoadingStudents = false;
  bool _isSaving = false;

  final Map<String, Map<String, TextEditingController>> _controllers = {};

  @override
  void initState() {
    super.initState();
    _gradeTypes = const String.fromEnvironment(
      'GRADE_TYPES',
      defaultValue: 'Tugas 1,Tugas 2,Tugas 3,Tugas 4,Ulangan Harian 1,Ulangan Harian 2,Ulangan Harian 3,UTS,UAS',
    ).split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    
    _gradeType = _gradeTypes.isNotEmpty ? _gradeTypes.first : 'Tugas 1';
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    final schoolId = context.read<SchoolProvider>().activeSchoolId;
    if (schoolId == null) {
      if (mounted) setState(() => _isLoadingYears = false);
      return;
    }

    try {
      final years = await _academicYearService.getAcademicYears(schoolId).first;
      if (years.isNotEmpty) {
        final activeYear = years.firstWhere((y) => y.isActive, orElse: () => years.first);
        if (mounted) {
          setState(() {
            _academicYears = years;
            _activeAcademicYearId = activeYear.id;
            _selectedAcademicYearId = activeYear.id;
            _isLoadingYears = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoadingYears = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingYears = false);
    }
  }

  Future<void> _fetchStudents(String schoolId, String yearId) async {
    if (_selectedClassId == null) return;
    setState(() {
      _isLoadingStudents = true;
      _controllers.clear();
    });

    try {
      final snapshot = await _studentService.fetchStudentsByClass(schoolId, _selectedClassId!, statusFilter: 'ACTIVE');
      _students = snapshot;
      for (var s in _students) {
        _controllers[s.id] = {
          'score': TextEditingController(),
          'notes': TextEditingController(),
        };
      }
      
      if (_selectedSubjectId != null) {
        await _fetchExistingGrades(schoolId, yearId);
      }
      
      setState(() {});
    } catch (e) {
      SnackbarUtils.showErrorSnackbar('Gagal memuat daftar siswa');
    } finally {
      setState(() {
        _isLoadingStudents = false;
      });
    }
  }

  Future<void> _fetchExistingGrades(String schoolId, String yearId) async {
    if (_selectedSubjectId == null || _students.isEmpty) return;

    try {
      for (var s in _students) {
        final doc = await FirebaseFirestore.instance
            .collection('schools')
            .doc(schoolId)
            .collection('transactions_year')
            .doc(yearId)
            .collection('student_grades')
            .doc(s.id)
            .get();
            
        if (doc.exists) {
          final data = doc.data() as Map<String, dynamic>;
          if (data['grades'] != null && data['grades'][_selectedSubjectId] != null) {
             final scores = data['grades'][_selectedSubjectId]['scores'] as List<dynamic>? ?? [];
             final matchingScore = scores.firstWhere(
               (element) => element['type'] == _gradeType, 
               orElse: () => null
             );
             if (matchingScore != null) {
               double scoreVal = (matchingScore['score'] ?? 0).toDouble();
               _controllers[s.id]!['score']!.text = scoreVal == scoreVal.toInt() ? scoreVal.toInt().toString() : scoreVal.toString();
               _controllers[s.id]!['notes']!.text = matchingScore['notes']?.toString() ?? '';
             } else {
               _controllers[s.id]!['score']!.clear();
               _controllers[s.id]!['notes']!.clear();
             }
          } else {
             _controllers[s.id]!['score']!.clear();
             _controllers[s.id]!['notes']!.clear();
          }
        } else {
          _controllers[s.id]!['score']!.clear();
          _controllers[s.id]!['notes']!.clear();
        }
      }
      setState(() {});
    } catch (e) {
       // Ignore error
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
        teacherName: _currentTeacherName ?? FirebaseAuth.instance.currentUser?.displayName ?? 'Guru',
        gradeType: _gradeType,
        dateStr: dateStr,
        studentGradesData: studentDataList,
      );

      if (!mounted) return;

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

    if (_isLoadingYears) {
      return Scaffold(
        appBar: AppBar(title: const Text('Input Nilai')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_academicYears.isEmpty || _selectedAcademicYearId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Input Nilai')),
        body: const Center(child: Text('Tahun Ajaran belum tersedia')),
      );
    }

    final yearId = _selectedAcademicYearId!;
    final canEdit = _selectedAcademicYearId == _activeAcademicYearId;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Input Nilai Kelas'),
        actions: [
          if (_students.isNotEmpty && canEdit)
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
                DropdownButtonFormField<String>(
                  value: _selectedAcademicYearId,
                  decoration: const InputDecoration(
                    labelText: 'Tahun Ajaran',
                    border: OutlineInputBorder(),
                  ),
                  items: _academicYears.map((ay) {
                    return DropdownMenuItem(
                      value: ay.id,
                      child: Text('${ay.name} ${ay.isActive ? "(Aktif)" : ""}'),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _selectedAcademicYearId = val;
                        _selectedClassId = null;
                        _selectedSubjectId = null;
                        _selectedSubjectName = null;
                        _students.clear();
                      });
                    }
                  },
                ),
                const SizedBox(height: 16),
                Builder(
                  builder: (context) {
                    final teacherId = FirebaseAuth.instance.currentUser?.uid;
                    if (teacherId == null) return const Text('Guru tidak terautentikasi');

                    return StreamBuilder<List<ClassSchedule>>(
                      stream: _scheduleService.getSchedulesByTeacher(schoolId, yearId, teacherId),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        
                        final schedules = snapshot.data ?? [];
                        
                        if (schedules.isNotEmpty) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (mounted && _currentTeacherName != schedules.first.teacherName) {
                              setState(() {
                                _currentTeacherName = schedules.first.teacherName;
                              });
                            }
                          });
                        }
                        
                        // Ekstrak Kelas Unik
                        final Map<String, String> uniqueClasses = {};
                        for (var s in schedules) {
                          uniqueClasses[s.classId] = s.className;
                        }
                        final classItems = uniqueClasses.entries
                            .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value, overflow: TextOverflow.ellipsis)))
                            .toList();

                        // Ekstrak Mapel Unik berdasar kelas terpilih
                        final Map<String, String> uniqueSubjects = {};
                        if (_selectedClassId != null && uniqueClasses.containsKey(_selectedClassId)) {
                          for (var s in schedules.where((s) => s.classId == _selectedClassId)) {
                            uniqueSubjects[s.subjectId] = s.subjectName;
                          }
                        }
                        final subjectItems = uniqueSubjects.entries
                            .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value, overflow: TextOverflow.ellipsis)))
                            .toList();

                        return Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                isExpanded: true,
                                decoration: const InputDecoration(labelText: 'Kelas (Jadwal)', border: OutlineInputBorder()),
                                value: uniqueClasses.containsKey(_selectedClassId) ? _selectedClassId : null,
                                items: classItems,
                                onChanged: (val) {
                                  setState(() {
                                    _selectedClassId = val;
                                    _selectedSubjectId = null; 
                                    _selectedSubjectName = null;
                                  });
                                  _fetchStudents(schoolId, yearId);
                                },
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                isExpanded: true,
                                decoration: const InputDecoration(labelText: 'Mata Pelajaran (Jadwal)', border: OutlineInputBorder()),
                                value: uniqueSubjects.containsKey(_selectedSubjectId) ? _selectedSubjectId : null,
                                items: subjectItems,
                                onChanged: (val) {
                                  setState(() {
                                    _selectedSubjectId = val;
                                    _selectedSubjectName = uniqueSubjects[val];
                                  });
                                  _fetchExistingGrades(schoolId, yearId);
                                },
                              ),
                            ),
                          ],
                        );
                      }
                    );
                  }
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
                        onChanged: (val) {
                          setState(() => _gradeType = val!);
                          _fetchExistingGrades(schoolId, yearId);
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: InkWell(
                        onTap: canEdit ? () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: _selectedDate,
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                          );
                          if (date != null) setState(() => _selectedDate = date);
                        } : null,
                        child: InputDecorator(
                          decoration: const InputDecoration(labelText: 'Tanggal', border: OutlineInputBorder()),
                          child: Text("${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}"),
                        ),
                      ),
                    ),
                  ],
                ),
                if (!canEdit)
                  const Padding(
                    padding: EdgeInsets.only(top: 16.0),
                    child: Text(
                      'Mode Baca-Saja: Nilai di tahun ajaran ini tidak dapat diedit.',
                      style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                    ),
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
                                    flex: 3,
                                    child: Text(student.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    flex: 2,
                                    child: TextField(
                                      controller: _controllers[student.id]!['score'],
                                      enabled: canEdit,
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      inputFormatters: [
                                        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                                      ],
                                      decoration: const InputDecoration(
                                        labelText: 'Nilai',
                                        isDense: true,
                                        border: OutlineInputBorder(),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    flex: 3,
                                    child: TextField(
                                      controller: _controllers[student.id]!['notes'],
                                      enabled: canEdit,
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
}
