import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/providers/school_provider.dart';
import '../../../../core/models/academic_year.dart';
import '../../master_data/services/academic_year_service.dart';
import '../../../../core/models/student_report.dart';
import '../services/report_service.dart';
import '../../../../core/widgets/empty_state_widget.dart';

class ParentReportScreen extends StatefulWidget {
  final String studentId;
  final String studentName;

  const ParentReportScreen({
    super.key,
    required this.studentId,
    required this.studentName,
  });

  @override
  State<ParentReportScreen> createState() => _ParentReportScreenState();
}

class _ParentReportScreenState extends State<ParentReportScreen> {
  final ReportService _reportService = ReportService();
  final AcademicYearService _academicYearService = AcademicYearService();

  String? _selectedAcademicYearId;
  List<AcademicYear> _academicYears = [];
  bool _isLoadingYears = true;

  @override
  void initState() {
    super.initState();
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

  @override
  Widget build(BuildContext context) {
    final schoolId = context.watch<SchoolProvider>().activeSchoolId;

    if (schoolId == null) {
      return Scaffold(
        appBar: AppBar(title: Text('Raport ${widget.studentName}')),
        body: const Center(child: Text('Sekolah belum aktif')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Raport ${widget.studentName}'),
      ),
      body: _isLoadingYears
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (_academicYears.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: DropdownButtonFormField<String>(
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
                          setState(() => _selectedAcademicYearId = val);
                        }
                      },
                    ),
                  ),
                Expanded(
                  child: _selectedAcademicYearId == null
                      ? const Center(child: Text('Tahun Ajaran belum tersedia'))
                      : StreamBuilder<StudentReport>(
                          stream: _reportService.getStudentReport(schoolId, _selectedAcademicYearId!, widget.studentId),
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
                ),
              ],
            ),
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
