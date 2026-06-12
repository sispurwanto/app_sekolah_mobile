import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/providers/school_provider.dart';
import '../../../../core/models/class_schedule.dart';
import '../../master_data/services/schedule_service.dart';
import '../../master_data/services/academic_year_service.dart';
import '../../../../core/widgets/empty_state_widget.dart';

class TeacherScheduleScreen extends StatelessWidget {
  final ScheduleService _scheduleService = ScheduleService();

  TeacherScheduleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final schoolId = context.watch<SchoolProvider>().activeSchoolId;
    final teacherId = FirebaseAuth.instance.currentUser?.uid;

    if (schoolId == null || teacherId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Jadwal Mengajar')),
        body: const Center(child: Text('Data tidak lengkap')),
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
            appBar: AppBar(title: const Text('Jadwal Mengajar')),
            body: const Center(child: Text('Tahun Ajaran belum aktif')),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Jadwal Mengajar Saya'),
          ),
          body: StreamBuilder<List<ClassSchedule>>(
            stream: _scheduleService.getSchedulesByTeacher(schoolId, yearId, teacherId),
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
                  title: 'Tidak Ada Jadwal',
                  subtitle: 'Anda belum memiliki jadwal mengajar.',
                );
              }

              Map<int, List<ClassSchedule>> grouped = {};
              for (var s in schedules) {
                if (!grouped.containsKey(s.dayOfWeek)) {
                  grouped[s.dayOfWeek] = [];
                }
                grouped[s.dayOfWeek]!.add(s);
              }

              final sortedDays = grouped.keys.toList()..sort();

              return ListView.builder(
                itemCount: sortedDays.length,
                itemBuilder: (context, index) {
                  final dayOfWeek = sortedDays[index];
                  final daySchedules = grouped[dayOfWeek]!;
                  final dayName = daySchedules.first.dayName;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        color: Colors.grey.withValues(alpha: 0.2),
                        child: Text(
                          dayName,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ),
                      ...daySchedules.map((schedule) => ListTile(
                            leading: const Icon(Icons.access_time, color: Colors.blue),
                            title: Text(schedule.subjectName, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('Kelas: ${schedule.className}'),
                            trailing: Text(
                              '${schedule.startTime} - ${schedule.endTime}',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                            ),
                          )),
                      const Divider(height: 1),
                    ],
                  );
                },
              );
            },
          ),
        );
      }
    );
  }
}
