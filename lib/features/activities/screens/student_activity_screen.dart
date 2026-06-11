import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../../core/providers/school_provider.dart';
import '../../../../core/models/student.dart';
import '../../../../core/models/student_activity.dart';
import '../services/student_activity_service.dart';
import 'activity_form_dialog.dart';
import '../../../../core/utils/dialog_utils.dart';
import '../../../../core/utils/snackbar_utils.dart';
import '../../../../core/widgets/empty_state_widget.dart';

class StudentActivityScreen extends StatelessWidget {
  final Student student;
  final bool isReadOnly;

  final StudentActivityService _activityService = StudentActivityService();

  StudentActivityScreen({
    super.key,
    required this.student,
    this.isReadOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    final schoolId = context.watch<SchoolProvider>().activeSchoolId;
    final academicYearId = student.academicYearId;

    if (schoolId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Kegiatan Siswa')),
        body: const Center(child: Text('Sekolah belum dipilih')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text('Kegiatan: ${student.name}')),
      body: StreamBuilder<StudentActivity>(
        stream: _activityService.getStudentActivity(
          schoolId,
          academicYearId,
          student.id,
        ),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Terjadi kesalahan: ${snapshot.error}'));
          }

          final studentActivity = snapshot.data;
          final activities = studentActivity?.data ?? [];

          activities.sort((a, b) => b.tgl.compareTo(a.tgl));

          if (activities.isEmpty) {
            return EmptyStateWidget(
              icon: Icons.local_activity_outlined,
              title: 'Belum ada data kegiatan',
              subtitle: isReadOnly 
                  ? 'Belum ada catatan kegiatan untuk siswa ini.' 
                  : 'Tambahkan data kegiatan siswa melalui tombol di bawah.',
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: activities.length,
            itemBuilder: (context, index) {
              final activity = activities[index];
              return Card(
                elevation: 2,
                margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              activity.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _getStatusColor(
                                activity.status,
                              ).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              activity.status,
                              style: TextStyle(
                                color: _getStatusColor(activity.status),
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(activity.keterangan),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _formatDate(activity.tgl),
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            'Guru: ${activity.namaGuru}',
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      if (!isReadOnly) ...[
                        const Divider(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton.icon(
                              onPressed: () => _showActivityForm(
                                context,
                                schoolId,
                                academicYearId,
                                activity: activity,
                              ),
                              icon: const Icon(Icons.edit, size: 16),
                              label: const Text('Edit'),
                            ),
                            TextButton.icon(
                              onPressed: () => _confirmDelete(
                                context,
                                schoolId,
                                academicYearId,
                                activity,
                              ),
                              icon: const Icon(
                                Icons.delete,
                                size: 16,
                                color: Colors.red,
                              ),
                              label: const Text(
                                'Hapus',
                                style: TextStyle(color: Colors.red),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: isReadOnly
          ? null
          : FloatingActionButton(
              onPressed: () =>
                  _showActivityForm(context, schoolId, academicYearId),
              child: const Icon(Icons.add),
            ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      // case 'hadir':
      // case 'selesai':
      case 'baik':
        return Colors.green;
      // case 'izin':
      case 'cukup':
        return Colors.blue;
      // case 'sakit':
      case 'kurang':
        return Colors.orange;
      // case 'alpha':
      case 'buruk':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _formatDate(String isoString) {
    try {
      final date = DateTime.parse(isoString);
      return DateFormat('dd MMM yyyy, HH:mm').format(date);
    } catch (e) {
      return isoString;
    }
  }

  void _showActivityForm(
    BuildContext context,
    String schoolId,
    String academicYearId, {
    ActivityEntry? activity,
  }) {
    showDialog(
      context: context,
      builder: (context) => ActivityFormDialog(
        schoolId: schoolId,
        academicYearId: academicYearId,
        student: student,
        existingEntry: activity,
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    String schoolId,
    String academicYearId,
    ActivityEntry activity,
  ) async {
    final confirm = await DialogUtils.showConfirmationDialog(
      title: 'Hapus Kegiatan',
      content: 'Apakah Anda yakin ingin menghapus catatan kegiatan ini?',
      confirmText: 'Hapus',
      isDestructive: true,
    );

    if (confirm == true && context.mounted) {
      try {
        await _activityService.removeActivityEntry(
          schoolId,
          academicYearId,
          student.id,
          activity,
        );
        SnackbarUtils.showSnackbar('Kegiatan berhasil dihapus');
      } catch (e) {
        SnackbarUtils.showErrorSnackbar('Gagal menghapus kegiatan: $e');
      }
    }
  }
}
