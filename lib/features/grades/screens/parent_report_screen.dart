import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/providers/school_provider.dart';
import '../../master_data/services/academic_year_service.dart';
import '../../../../core/models/student_report.dart';
import '../services/report_service.dart';
import '../../../../core/widgets/empty_state_widget.dart';

class ParentReportScreen extends StatelessWidget {
  final String studentId;
  final String studentName;
  final ReportService _reportService = ReportService();

  ParentReportScreen({
    super.key,
    required this.studentId,
    required this.studentName,
  });

  @override
  Widget build(BuildContext context) {
    final schoolId = context.watch<SchoolProvider>().activeSchoolId;

    if (schoolId == null) {
      return Scaffold(
        appBar: AppBar(title: Text('Raport $studentName')),
        body: const Center(child: Text('Sekolah belum aktif')),
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
            appBar: AppBar(title: Text('Raport $studentName')),
            body: const Center(child: Text('Tahun Ajaran belum aktif')),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Text('Raport $studentName'),
          ),
          body: StreamBuilder<StudentReport>(
            stream: _reportService.getStudentReport(schoolId, yearId, studentId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('Terjadi kesalahan: ${snapshot.error}'));
              }

              final studentReport = snapshot.data;

              if (studentReport == null || studentReport.semesters.isEmpty) {
                return const EmptyStateWidget(
                  icon: Icons.library_books,
                  title: 'Belum Ada Raport',
                  subtitle: 'Raport untuk tahun ajaran ini belum diterbitkan.',
                );
              }

              return ListView(
                children: studentReport.semesters.entries.map((entry) {
                  final semester = entry.key;
                  final report = entry.value;

                  if (!report.isPublished) {
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: ListTile(
                        leading: const Icon(Icons.lock, color: Colors.grey),
                        title: Text('Semester $semester'),
                        subtitle: const Text('Belum diterbitkan'),
                      ),
                    );
                  }

                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: ExpansionTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.blue.withValues(alpha: 0.1),
                        child: const Icon(Icons.verified, color: Colors.blue),
                      ),
                      title: Text('Semester $semester', style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('Diterbitkan: ${report.datePublished}'),
                      children: [
                        if (report.teacherNotes.isNotEmpty)
                          ListTile(
                            leading: const Icon(Icons.comment),
                            title: const Text('Catatan Wali Kelas'),
                            subtitle: Text(report.teacherNotes, style: const TextStyle(fontStyle: FontStyle.italic)),
                          ),
                        const Divider(),
                        const ListTile(
                          title: Text('Nilai Mata Pelajaran', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                        ...report.subjects.map((sub) => ListTile(
                          dense: true,
                          title: Text(sub.subjectName),
                          trailing: Text('${sub.score} (${sub.predicate})', style: const TextStyle(fontWeight: FontWeight.bold)),
                        )),
                        const Divider(),
                        const ListTile(
                          title: Text('Kehadiran', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildAttendanceStat('Sakit', report.attendance.sick, Colors.orange),
                              _buildAttendanceStat('Izin', report.attendance.permission, Colors.blue),
                              _buildAttendanceStat('Alpa', report.attendance.absent, Colors.red),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
        );
      }
    );
  }

  Widget _buildAttendanceStat(String label, int value, Color color) {
    return Column(
      children: [
        Text(value.toString(), style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: const TextStyle(color: Colors.grey)),
      ],
    );
  }
}
