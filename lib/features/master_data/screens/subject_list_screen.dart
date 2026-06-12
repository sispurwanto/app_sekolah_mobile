import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/providers/school_provider.dart';
import '../../../../core/models/subject_master.dart';
import '../services/subject_service.dart';
import '../../../../core/utils/dialog_utils.dart';
import '../../../../core/utils/snackbar_utils.dart';
import '../../../../core/widgets/empty_state_widget.dart';

class SubjectListScreen extends StatelessWidget {
  final SubjectService _subjectService = SubjectService();

  SubjectListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final schoolId = context.watch<SchoolProvider>().activeSchoolId;

    if (schoolId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Master Mata Pelajaran')),
        body: const Center(child: Text('Sekolah belum dipilih')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Master Mata Pelajaran')),
      body: StreamBuilder<List<SubjectMaster>>(
        stream: _subjectService.getSubjects(schoolId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Terjadi kesalahan: ${snapshot.error}'));
          }

          final subjects = snapshot.data ?? [];

          if (subjects.isEmpty) {
            return const EmptyStateWidget(
              icon: Icons.menu_book_outlined,
              title: 'Belum ada Mata Pelajaran',
              subtitle: 'Tambahkan mata pelajaran menggunakan tombol di bawah.',
            );
          }

          return ListView.builder(
            itemCount: subjects.length,
            itemBuilder: (context, index) {
              final subject = subjects[index];
              return ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Colors.blueAccent,
                  child: Icon(Icons.menu_book, color: Colors.white),
                ),
                title: Text(
                  subject.name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  subject.code.isNotEmpty
                      ? 'Kode: ${subject.code}'
                      : 'Tanpa Kode',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      onPressed: () =>
                          _showSubjectForm(context, schoolId, subject: subject),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () =>
                          _confirmDelete(context, schoolId, subject),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showSubjectForm(context, schoolId),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showSubjectForm(
    BuildContext context,
    String schoolId, {
    SubjectMaster? subject,
  }) {
    showDialog(
      context: context,
      builder: (context) =>
          SubjectFormDialog(schoolId: schoolId, existingSubject: subject),
    );
  }

  void _confirmDelete(BuildContext context, String schoolId, SubjectMaster subject) async {
    final confirmed = await DialogUtils.showConfirmationDialog(
      title: 'Hapus Mata Pelajaran',
      content: 'Yakin ingin menghapus ${subject.name}?',
    );
    if (confirmed == true) {
      try {
        await _subjectService.deleteSubject(schoolId, subject.id);
        SnackbarUtils.showSnackbar('Mata pelajaran dihapus');
      } catch (e) {
        SnackbarUtils.showErrorSnackbar('Gagal menghapus: $e');
      }
    }
  }
}

class SubjectFormDialog extends StatefulWidget {
  final String schoolId;
  final SubjectMaster? existingSubject;

  const SubjectFormDialog({
    super.key,
    required this.schoolId,
    this.existingSubject,
  });

  @override
  State<SubjectFormDialog> createState() => _SubjectFormDialogState();
}

class _SubjectFormDialogState extends State<SubjectFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _codeController = TextEditingController();
  final _descController = TextEditingController();

  final SubjectService _subjectService = SubjectService();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.existingSubject != null) {
      _nameController.text = widget.existingSubject!.name;
      _codeController.text = widget.existingSubject!.code;
      _descController.text = widget.existingSubject!.description;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final subject = SubjectMaster(
        id: widget.existingSubject?.id ?? '',
        name: _nameController.text.trim(),
        code: _codeController.text.trim(),
        description: _descController.text.trim(),
      );

      if (widget.existingSubject == null) {
        await _subjectService.addSubject(widget.schoolId, subject);
        SnackbarUtils.showSnackbar('Mata pelajaran ditambahkan');
      } else {
        await _subjectService.updateSubject(widget.schoolId, subject);
        SnackbarUtils.showSnackbar('Mata pelajaran diperbarui');
      }

      if (mounted) Navigator.pop(context);
    } catch (e) {
      SnackbarUtils.showErrorSnackbar('Gagal menyimpan: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existingSubject != null;
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
              isEdit ? Icons.edit_note : Icons.add_circle_outline,
              color: Theme.of(context).primaryColor,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                isEdit ? 'Edit Mata Pelajaran' : 'Tambah Mata Pelajaran',
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
                const SizedBox(height: 8),
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'Nama Mata Pelajaran',
                    prefixIcon: const Icon(Icons.menu_book),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.grey.withValues(alpha: 0.05),
                  ),
                  validator: (val) => val == null || val.trim().isEmpty
                      ? 'Nama harus diisi'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _codeController,
                  decoration: InputDecoration(
                    labelText: 'Kode (Opsional)',
                    prefixIcon: const Icon(Icons.code),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.grey.withValues(alpha: 0.05),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _descController,
                  decoration: InputDecoration(
                    labelText: 'Keterangan (Opsional)',
                    prefixIcon: const Icon(Icons.description_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.grey.withValues(alpha: 0.05),
                  ),
                  maxLines: 2,
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
