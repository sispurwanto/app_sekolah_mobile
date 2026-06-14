import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/providers/school_provider.dart';
import '../../master_data/services/academic_year_service.dart';
import '../../../../core/models/student_grade.dart';
import '../services/grade_service.dart';
import '../../../../core/widgets/empty_state_widget.dart';

class ParentGradeScreen extends StatelessWidget {
  final String studentId;
  final String studentName;
  final GradeService _gradeService = GradeService();

  ParentGradeScreen({
    super.key,
    required this.studentId,
    required this.studentName,
  });

  @override
  Widget build(BuildContext context) {
    final schoolId = context.watch<SchoolProvider>().activeSchoolId;

    if (schoolId == null) {
      return Scaffold(
        appBar: AppBar(title: Text('Nilai $studentName')),
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
            appBar: AppBar(title: Text('Nilai $studentName')),
            body: const Center(child: Text('Tahun Ajaran belum aktif')),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Text('Nilai $studentName'),
          ),
          body: StreamBuilder<StudentGrade>(
            stream: _gradeService.getStudentGrades(schoolId, yearId, studentId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('Terjadi kesalahan: ${snapshot.error}'));
              }

              final studentGrade = snapshot.data;

              if (studentGrade == null || studentGrade.grades.isEmpty) {
                return const EmptyStateWidget(
                  icon: Icons.edit_note,
                  title: 'Belum Ada Nilai',
                  subtitle: 'Anak Anda belum menerima nilai apapun di tahun ajaran ini.',
                );
              }

              final subjects = studentGrade.grades.values.toList();
              subjects.sort((a, b) => a.subjectName.compareTo(b.subjectName));

              return ListView.builder(
                itemCount: subjects.length,
                itemBuilder: (context, index) {
                  final subject = subjects[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: ExpansionTile(
                      leading: CircleAvatar(
                        backgroundColor: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                        child: const Icon(Icons.book),
                      ),
                      title: Text(subject.subjectName, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Guru: ${subject.teacherName}'),
                          Text('${subject.scores.length} data nilai'),
                        ],
                      ),
                      children: subject.scores.map((score) {
                        return ListTile(
                          dense: true,
                          title: Text(score.type, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Tanggal: ${score.date}'),
                              if (score.notes.isNotEmpty) Text('Catatan: ${score.notes}', style: const TextStyle(fontStyle: FontStyle.italic)),
                            ],
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: score.score >= 75 ? Colors.green.withValues(alpha: 0.2) : Colors.red.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              score.score == score.score.toInt() ? score.score.toInt().toString() : score.score.toString(),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: score.score >= 75 ? Colors.green[800] : Colors.red[800],
                                fontSize: 16,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
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
