import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/providers/school_provider.dart';
import '../../../../core/models/activity_master.dart';
import '../services/activity_master_service.dart';
import '../../../../core/utils/dialog_utils.dart';
import '../../../../core/utils/snackbar_utils.dart';
import '../../../../core/widgets/empty_state_widget.dart';

class ActivityMasterListScreen extends StatelessWidget {
  final ActivityMasterService _activityService = ActivityMasterService();

  ActivityMasterListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final schoolId = context.watch<SchoolProvider>().activeSchoolId;

    if (schoolId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Master Data Kegiatan')),
        body: const Center(child: Text('Sekolah belum dipilih')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Master Data Kegiatan Siswa'),
      ),
      body: StreamBuilder<List<ActivityMaster>>(
        stream: _activityService.getActivities(schoolId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Terjadi kesalahan: ${snapshot.error}'));
          }

          final activities = snapshot.data ?? [];

          if (activities.isEmpty) {
            return const EmptyStateWidget(
              icon: Icons.local_activity_outlined,
              title: 'Belum ada Master Kegiatan',
              subtitle: 'Tambahkan data master kegiatan melalui tombol di bawah.',
            );
          }

          return ListView.builder(
            itemCount: activities.length,
            itemBuilder: (context, index) {
              final activity = activities[index];
              return ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Colors.orangeAccent,
                  child: Icon(Icons.local_activity, color: Colors.white),
                ),
                title: Text(activity.nameActivity, style: const TextStyle(fontWeight: FontWeight.bold)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      onPressed: () => _showActivityForm(context, schoolId, activity: activity),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _confirmDelete(context, schoolId, activity),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showActivityForm(context, schoolId),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showActivityForm(BuildContext context, String schoolId, {ActivityMaster? activity}) {
    showDialog(
      context: context,
      builder: (context) => _ActivityMasterFormDialog(
        schoolId: schoolId,
        activity: activity,
        activityService: _activityService,
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, String schoolId, ActivityMaster activity) async {
    final confirm = await DialogUtils.showConfirmationDialog(
      title: 'Hapus Kegiatan',
      content: 'Apakah Anda yakin ingin menghapus kegiatan "${activity.nameActivity}"?',
      confirmText: 'Hapus',
      isDestructive: true,
    );

    if (confirm == true && context.mounted) {
      try {
        await _activityService.deleteActivity(schoolId, activity.idActivity);
        SnackbarUtils.showSnackbar('Kegiatan berhasil dihapus');
      } catch (e) {
        SnackbarUtils.showErrorSnackbar('Gagal menghapus kegiatan: $e');
      }
    }
  }
}

class _ActivityMasterFormDialog extends StatefulWidget {
  final String schoolId;
  final ActivityMaster? activity;
  final ActivityMasterService activityService;

  const _ActivityMasterFormDialog({
    required this.schoolId,
    this.activity,
    required this.activityService,
  });

  @override
  State<_ActivityMasterFormDialog> createState() => _ActivityMasterFormDialogState();
}

class _ActivityMasterFormDialogState extends State<_ActivityMasterFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.activity != null) {
      _nameController.text = widget.activity!.nameActivity;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final newActivity = ActivityMaster(
        idActivity: widget.activity?.idActivity ?? '',
        nameActivity: _nameController.text.trim(),
      );

      if (widget.activity == null) {
        await widget.activityService.addActivity(widget.schoolId, newActivity);
        SnackbarUtils.showSnackbar('Kegiatan berhasil ditambahkan');
      } else {
        await widget.activityService.updateActivity(widget.schoolId, newActivity);
        SnackbarUtils.showSnackbar('Kegiatan berhasil diperbarui');
      }

      if (mounted) Navigator.pop(context);
    } catch (e) {
      SnackbarUtils.showErrorSnackbar('Gagal menyimpan kegiatan: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.activity == null ? 'Tambah Kegiatan' : 'Edit Kegiatan'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Nama Kegiatan',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Nama kegiatan harus diisi';
                }
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _submit,
          child: _isLoading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Simpan'),
        ),
      ],
    );
  }
}
