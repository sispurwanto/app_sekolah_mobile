import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/models/app_class.dart';
import '../../../core/providers/school_provider.dart';
import '../services/class_service.dart';
import '../../../core/utils/snackbar_utils.dart';
import '../../../core/utils/dialog_utils.dart';

class ClassFormScreen extends StatefulWidget {
  final AppClass? appClass;

  const ClassFormScreen({super.key, this.appClass});

  @override
  State<ClassFormScreen> createState() => _ClassFormScreenState();
}

class _ClassFormScreenState extends State<ClassFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _service = ClassService();

  late TextEditingController _idController;
  late TextEditingController _nameController;
  late TextEditingController _levelController;
  late TextEditingController _descriptionController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _idController = TextEditingController(text: widget.appClass?.id ?? '');
    _nameController = TextEditingController(text: widget.appClass?.name ?? '');
    _levelController = TextEditingController(text: widget.appClass?.level ?? '');
    _descriptionController = TextEditingController(text: widget.appClass?.description ?? '');
  }

  @override
  void dispose() {
    _idController.dispose();
    _nameController.dispose();
    _levelController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final schoolId = context.read<SchoolProvider>().activeSchoolId!;

    final appClass = AppClass(
      id: widget.appClass == null ? _idController.text.trim() : widget.appClass!.id,
      name: _nameController.text.trim(),
      level: _levelController.text.trim(),
      description: _descriptionController.text.trim(),
    );

    try {
      if (widget.appClass == null) {
        await _service.addClass(schoolId, appClass);
        SnackbarUtils.showSnackbar('Kelas berhasil ditambahkan');
      } else {
        await _service.updateClass(schoolId, appClass);
        SnackbarUtils.showSnackbar('Kelas berhasil diperbarui');
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      SnackbarUtils.showErrorSnackbar('Error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _delete() async {
    if (widget.appClass == null) return;
    
    final schoolId = context.read<SchoolProvider>().activeSchoolId!;

    final confirm = await DialogUtils.showConfirmationDialog(
      title: 'Hapus Kelas',
      content: 'Yakin ingin menghapus kelas ini?',
      confirmText: 'Hapus',
      isDestructive: true,
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        await _service.deleteClass(schoolId, widget.appClass!.id);
        SnackbarUtils.showSnackbar('Kelas dihapus');
        if (mounted) Navigator.pop(context);
      } catch (e) {
        SnackbarUtils.showErrorSnackbar('Gagal menghapus: $e');
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.appClass != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Kelas' : 'Tambah Kelas'),
        actions: [
          if (isEditing)
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: _delete,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _idController,
                      decoration: const InputDecoration(
                        labelText: 'ID Kelas *',
                        helperText: 'ID akan menjadi Key/Data Utama. Tidak bisa diubah setelah dibuat.',
                      ),
                      readOnly: isEditing,
                      validator: (v) => v!.isEmpty ? 'Wajib diisi' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(labelText: 'Nama Kelas *'),
                      validator: (v) => v!.isEmpty ? 'Wajib diisi' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _levelController,
                      decoration: const InputDecoration(
                        labelText: 'Tingkat *',
                        helperText: 'Misal: "1", "10", atau "VII"',
                      ),
                      validator: (v) => v!.isEmpty ? 'Wajib diisi' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(labelText: 'Deskripsi / Catatan'),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _save,
                        child: const Text('Simpan'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
