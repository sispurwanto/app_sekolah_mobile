import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../student_management/screens/student_list_screen.dart';
import '../teacher_schedule_screen.dart';
import '../../../grades/screens/teacher_grade_input_screen.dart';
import '../../../../core/providers/school_provider.dart';
import '../../../../core/providers/user_provider.dart';
import '../../../master_data/services/academic_year_service.dart';
import '../../../../core/models/class_schedule.dart';
import '../../../master_data/services/schedule_service.dart';

class GuruDashboardView extends StatelessWidget {
  const GuruDashboardView({super.key});

  @override
  Widget build(BuildContext context) {
    final userName = context.watch<UserProvider>().userMapping?.name ?? 'Guru / Wali Kelas';

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Jadwal Mengajar Hari Ini',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _buildTodaySchedule(context),
          const SizedBox(height: 24),
          Text(
            'Menu $userName',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              SizedBox(
                width: 100,
                child: _buildMenuCard(
                  context,
                  title: 'Seluruh Jadwal',
                  icon: Icons.calendar_month,
                  color: Colors.blue,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => TeacherScheduleScreen()),
                    );
                  },
                ),
              ),
              SizedBox(
                width: 100,
                child: _buildMenuCard(
                  context,
                  title: 'Data Siswa',
                  icon: Icons.people,
                  color: Colors.green,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const StudentListScreen()),
                    );
                  },
                ),
              ),
              SizedBox(
                width: 100,
                child: _buildMenuCard(
                  context,
                  title: 'Input Nilai',
                  icon: Icons.edit_note,
                  color: Colors.orange,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const TeacherGradeInputScreen()),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTodaySchedule(BuildContext context) {
    final schoolId = context.watch<SchoolProvider>().activeSchoolId;
    final teacherId = FirebaseAuth.instance.currentUser?.uid;

    if (schoolId == null || teacherId == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text('Sekolah belum dipilih.'),
        ),
      );
    }

    final int todayWeekday = DateTime.now().weekday; // 1 = Senin, 7 = Minggu

    return FutureBuilder(
      future: AcademicYearService().getActiveAcademicYear(schoolId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final yearId = snapshot.data?.id;
        if (yearId == null) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('Tahun Ajaran belum aktif.'),
            ),
          );
        }

        return StreamBuilder<List<ClassSchedule>>(
          stream: ScheduleService().getSchedulesByTeacher(schoolId, yearId, teacherId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return const Text('Gagal memuat jadwal');
            }

            final schedules = snapshot.data ?? [];
            final todaySchedules = schedules.where((s) => s.dayOfWeek == todayWeekday).toList();

            double totalHoursNum = 0;
            for (var s in schedules) {
              try {
                final startParts = s.startTime.split(':');
                final endParts = s.endTime.split(':');
                if (startParts.length >= 2 && endParts.length >= 2) {
                  final startMin = int.parse(startParts[0]) * 60 + int.parse(startParts[1]);
                  final endMin = int.parse(endParts[0]) * 60 + int.parse(endParts[1]);
                  if (endMin > startMin) {
                    totalHoursNum += (endMin - startMin) / 60.0;
                  }
                }
              } catch (_) {}
            }
            String formattedHours = totalHoursNum.toStringAsFixed(1);
            if (formattedHours.endsWith('.0')) {
              formattedHours = formattedHours.substring(0, formattedHours.length - 2);
            }

            if (todaySchedules.isEmpty) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildWeeklyHoursInfo(formattedHours),
                  const SizedBox(height: 12),
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          Icon(Icons.event_available, color: Colors.green),
                          SizedBox(width: 12),
                          Expanded(child: Text('Anda tidak ada jadwal mengajar hari ini.')),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildWeeklyHoursInfo(formattedHours),
                const SizedBox(height: 12),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: todaySchedules.length,
                  itemBuilder: (context, index) {
                    final schedule = todaySchedules[index];
                    return Card(
                      elevation: 2,
                      margin: const EdgeInsets.only(bottom: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                          child: Icon(Icons.access_time, color: Theme.of(context).primaryColor),
                        ),
                        title: Text(
                          schedule.subjectName,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text('Kelas: ${schedule.className}'),
                        trailing: Text(
                          '${schedule.startTime}\n-\n${schedule.endTime}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    );
                  },
                ),
              ],
            );
          },
        );
      }
    );
  }

  Widget _buildWeeklyHoursInfo(String totalHours) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
          const SizedBox(width: 8),
          Text(
            'Total Mengajar: $totalHours Jam/Pekan',
            style: TextStyle(
              color: Colors.blue.shade900,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuCard(BuildContext context, {required String title, required IconData icon, required Color color, required VoidCallback onTap}) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 8.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 32, color: color),
              const SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
