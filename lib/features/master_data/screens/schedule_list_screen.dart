import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/providers/school_provider.dart';
import '../../../../core/models/class_schedule.dart';
import '../../../../core/models/app_class.dart';
import '../../../../core/models/app_user.dart';
import '../../../../core/models/subject_master.dart';
import '../services/schedule_service.dart';
import '../services/class_service.dart';
import '../services/subject_service.dart';
import '../services/academic_year_service.dart';
import '../../user_management/services/user_management_service.dart';
import '../../../../core/utils/dialog_utils.dart';
import '../../../../core/utils/snackbar_utils.dart';
import '../../../../core/widgets/empty_state_widget.dart';

class ScheduleListScreen extends StatefulWidget {
  const ScheduleListScreen({super.key});

  @override
  State<ScheduleListScreen> createState() => _ScheduleListScreenState();
}

class _ScheduleListScreenState extends State<ScheduleListScreen> {
  final ClassService _classService = ClassService();
  final ScheduleService _scheduleService = ScheduleService();

  String? _selectedClassId;
  AppClass? _selectedClass;

  @override
  Widget build(BuildContext context) {
    final schoolId = context.watch<SchoolProvider>().activeSchoolId;

    if (schoolId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Jadwal Pelajaran')),
        body: const Center(child: Text('Sekolah belum dipilih')),
      );
    }

    return FutureBuilder(
      future: AcademicYearService().getActiveAcademicYear(schoolId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        
        final yearId = snapshot.data?.id;
        if (yearId == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Jadwal Pelajaran')),
            body: const Center(child: Text('Tahun Ajaran belum aktif')),
          );
        }

        return Scaffold(
      appBar: AppBar(title: const Text('Jadwal Pelajaran')),
      body: Column(
        children: [
          // Filter Kelas
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Row(
              children: [
                const Icon(Icons.class_),
                const SizedBox(width: 16),
                Expanded(
                  child: StreamBuilder<List<AppClass>>(
                    stream: _classService.getClasses(schoolId),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Text('Memuat kelas...');
                      }
                      final classes = snapshot.data!;
                      if (classes.isEmpty) {
                        return const Text('Belum ada kelas');
                      }

                      // Auto select first class if none selected
                      if (_selectedClassId == null && classes.isNotEmpty) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          setState(() {
                            _selectedClassId = classes.first.id;
                            _selectedClass = classes.first;
                          });
                        });
                      }

                      return DropdownButton<String>(
                        value: _selectedClassId,
                        isExpanded: true,
                        hint: const Text('Pilih Kelas'),
                        items: classes.map((c) {
                          return DropdownMenuItem(
                            value: c.id,
                            child: Text(c.name),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setState(() {
                            _selectedClassId = val;
                            _selectedClass = classes.firstWhere(
                              (c) => c.id == val,
                            );
                          });
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // List Jadwal
          Expanded(
            child: _selectedClassId == null
                ? const EmptyStateWidget(
                    icon: Icons.search,
                    title: 'Pilih Kelas',
                    subtitle:
                        'Pilih kelas terlebih dahulu untuk melihat jadwal',
                  )
                : StreamBuilder<List<ClassSchedule>>(
                    stream: _scheduleService.getSchedulesByClass(
                      schoolId,
                      yearId,
                      _selectedClassId!,
                    ),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError) {
                        return Center(child: Text('Error: ${snapshot.error}'));
                      }

                      final schedules = snapshot.data ?? [];

                      if (schedules.isEmpty) {
                        return const EmptyStateWidget(
                          icon: Icons.calendar_month,
                          title: 'Jadwal Kosong',
                          subtitle: 'Belum ada jadwal untuk kelas ini.',
                        );
                      }

                      return ListView.builder(
                        itemCount: schedules.length,
                        itemBuilder: (context, index) {
                          final schedule = schedules[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Theme.of(
                                  context,
                                ).primaryColor.withValues(alpha: 0.1),
                                child: Text(
                                  schedule.dayName.substring(0, 3),
                                  style: TextStyle(
                                    color: Theme.of(context).primaryColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              title: Text(
                                schedule.subjectName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Guru: ${schedule.teacherName}'),
                                  Text(
                                    'Jam: ${schedule.startTime} - ${schedule.endTime}',
                                  ),
                                ],
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(
                                      Icons.edit,
                                      color: Colors.blue,
                                    ),
                                    onPressed: () => _showScheduleForm(
                                      context,
                                      schoolId,
                                      yearId,
                                      schedule: schedule,
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete,
                                      color: Colors.red,
                                    ),
                                    onPressed: () => _confirmDelete(
                                      context,
                                      schoolId,
                                      yearId,
                                      schedule,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: _selectedClassId == null
          ? null
          : FloatingActionButton(
              onPressed: () => _showScheduleForm(context, schoolId, yearId),
              child: const Icon(Icons.add),
            ),
    );
      }
    );
  }

  void _showScheduleForm(
    BuildContext context,
    String schoolId,
    String yearId, {
    ClassSchedule? schedule,
  }) {
    showDialog(
      context: context,
      builder: (context) => ScheduleFormDialog(
        schoolId: schoolId,
        yearId: yearId,
        classId: _selectedClassId!,
        className: _selectedClass!.name,
        existingSchedule: schedule,
      ),
    );
  }

  void _confirmDelete(BuildContext context, String schoolId, String yearId, ClassSchedule schedule) async {
    final confirmed = await DialogUtils.showConfirmationDialog(
      title: 'Hapus Jadwal',
      content: 'Yakin ingin menghapus jadwal ${schedule.subjectName}?',
    );
    if (confirmed == true) {
      try {
        await _scheduleService.deleteSchedule(schoolId, yearId, schedule.id);
        SnackbarUtils.showSnackbar('Jadwal berhasil dihapus');
      } catch (e) {
        SnackbarUtils.showErrorSnackbar('Gagal menghapus: $e');
      }
    }
  }
}

class ScheduleFormDialog extends StatefulWidget {
  final String schoolId;
  final String yearId;
  final String classId;
  final String className;
  final ClassSchedule? existingSchedule;

  const ScheduleFormDialog({
    super.key,
    required this.schoolId,
    required this.yearId,
    required this.classId,
    required this.className,
    this.existingSchedule,
  });

  @override
  State<ScheduleFormDialog> createState() => _ScheduleFormDialogState();
}

class _ScheduleFormDialogState extends State<ScheduleFormDialog> {
  final _formKey = GlobalKey<FormState>();

  final SubjectService _subjectService = SubjectService();
  final UserManagementService _userService = UserManagementService();
  final ScheduleService _scheduleService = ScheduleService();

  bool _isLoading = false;

  String? _selectedSubjectId;
  String? _selectedSubjectName;
  String? _selectedTeacherId;
  String? _selectedTeacherName;
  int _selectedDay = 1;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;

  List<SubjectMaster> _subjects = [];
  List<AppUser> _teachers = [];

  final List<Map<String, dynamic>> _days = [
    {'val': 1, 'name': 'Senin'},
    {'val': 2, 'name': 'Selasa'},
    {'val': 3, 'name': 'Rabu'},
    {'val': 4, 'name': 'Kamis'},
    {'val': 5, 'name': 'Jumat'},
    {'val': 6, 'name': 'Sabtu'},
    {'val': 7, 'name': 'Minggu'},
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
    if (widget.existingSchedule != null) {
      _selectedSubjectId = widget.existingSchedule!.subjectId;
      _selectedSubjectName = widget.existingSchedule!.subjectName;
      _selectedTeacherId = widget.existingSchedule!.teacherId;
      _selectedTeacherName = widget.existingSchedule!.teacherName;
      _selectedDay = widget.existingSchedule!.dayOfWeek;
      _startTime = _parseTime(widget.existingSchedule!.startTime);
      _endTime = _parseTime(widget.existingSchedule!.endTime);
    }
  }

  TimeOfDay _parseTime(String timeString) {
    try {
      final parts = timeString.split(':');
      return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    } catch (_) {
      return const TimeOfDay(hour: 7, minute: 0);
    }
  }

  String _formatTime(TimeOfDay time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final subjectsStream = await _subjectService
          .getSubjects(widget.schoolId)
          .first;
      final teachers = await _userService.getUsersByRole(
        widget.schoolId,
        'GURU',
      );
      setState(() {
        _subjects = subjectsStream;
        _teachers = teachers;
      });
    } catch (e) {
      SnackbarUtils.showErrorSnackbar('Gagal memuat data pendukung');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _selectTime(bool isStart) async {
    final initialTime = isStart
        ? (_startTime ?? const TimeOfDay(hour: 7, minute: 0))
        : (_endTime ?? const TimeOfDay(hour: 8, minute: 30));

    final selected = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        );
      },
    );

    if (selected != null) {
      setState(() {
        if (isStart) {
          _startTime = selected;
        } else {
          _endTime = selected;
        }
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedSubjectId == null ||
        _selectedTeacherId == null ||
        _startTime == null ||
        _endTime == null) {
      SnackbarUtils.showErrorSnackbar('Lengkapi semua data jadwal');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final schedule = ClassSchedule(
        id: widget.existingSchedule?.id ?? '',
        classId: widget.classId,
        className: widget.className,
        subjectId: _selectedSubjectId!,
        subjectName: _selectedSubjectName!,
        teacherId: _selectedTeacherId!,
        teacherName: _selectedTeacherName!,
        dayOfWeek: _selectedDay,
        startTime: _formatTime(_startTime!),
        endTime: _formatTime(_endTime!),
      );

      if (widget.existingSchedule == null) {
        await _scheduleService.addSchedule(
          widget.schoolId,
          widget.yearId,
          schedule,
        );
        SnackbarUtils.showSnackbar('Jadwal ditambahkan');
      } else {
        await _scheduleService.updateSchedule(
          widget.schoolId,
          widget.yearId,
          schedule,
        );
        SnackbarUtils.showSnackbar('Jadwal diperbarui');
      }

      if (mounted) Navigator.pop(context);
    } catch (e) {
      SnackbarUtils.showErrorSnackbar('Gagal menyimpan jadwal: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existingSchedule != null;

    if (_isLoading && _subjects.isEmpty) {
      return const AlertDialog(
        content: SizedBox(
          height: 100,
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      titlePadding: const EdgeInsets.all(0),
      title: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(
          color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Row(
          children: [
            Icon(
              isEdit ? Icons.edit_calendar : Icons.add_alarm,
              color: Theme.of(context).primaryColor,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                isEdit ? 'Edit Jadwal' : 'Tambah Jadwal',
                style: TextStyle(
                  color: Theme.of(context).primaryColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.9,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Info Kelas
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Kelas: ${widget.className}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 16),

                // Mata Pelajaran
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'Mata Pelajaran',
                    prefixIcon: const Icon(Icons.menu_book),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  value: _selectedSubjectId,
                  items: _subjects
                      .map(
                        (s) => DropdownMenuItem(
                          value: s.id,
                          child: Text(
                            s.name,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedSubjectId = val;
                      _selectedSubjectName = _subjects
                          .firstWhere((s) => s.id == val)
                          .name;
                    });
                  },
                  validator: (val) =>
                      val == null ? 'Pilih mata pelajaran' : null,
                ),
                const SizedBox(height: 16),

                // Guru
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'Guru Pengajar',
                    prefixIcon: const Icon(Icons.person),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  value: _selectedTeacherId,
                  items: _teachers
                      .map(
                        (t) => DropdownMenuItem(
                          value: t.id,
                          child: Text(
                            t.name,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedTeacherId = val;
                      _selectedTeacherName = _teachers
                          .firstWhere((t) => t.id == val)
                          .name;
                    });
                  },
                  validator: (val) => val == null ? 'Pilih guru' : null,
                ),
                const SizedBox(height: 16),

                // Hari
                DropdownButtonFormField<int>(
                  decoration: InputDecoration(
                    labelText: 'Hari',
                    prefixIcon: const Icon(Icons.calendar_today),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  value: _selectedDay,
                  items: _days
                      .map(
                        (d) => DropdownMenuItem<int>(
                          value: d['val'],
                          child: Text(d['name']),
                        ),
                      )
                      .toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedDay = val!;
                    });
                  },
                ),
                const SizedBox(height: 16),

                // Waktu
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => _selectTime(true),
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: 'Jam Mulai',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            _startTime != null
                                ? _formatTime(_startTime!)
                                : 'Pilih Jam',
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: InkWell(
                        onTap: () => _selectTime(false),
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: 'Jam Selesai',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            _endTime != null
                                ? _formatTime(_endTime!)
                                : 'Pilih Jam',
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      actionsPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          style: TextButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Text('Batal'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _submit,
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Simpan'),
        ),
      ],
    );
  }
}
