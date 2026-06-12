import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/models/academic_year.dart';
import '../../../core/providers/school_provider.dart';
import '../services/academic_year_service.dart';
import '../../../core/utils/snackbar_utils.dart';
import '../../../core/utils/dialog_utils.dart';

class AcademicYearFormScreen extends StatefulWidget {
  final AcademicYear? academicYear;

  const AcademicYearFormScreen({super.key, this.academicYear});

  @override
  State<AcademicYearFormScreen> createState() => _AcademicYearFormScreenState();
}

class _AcademicYearFormScreenState extends State<AcademicYearFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _service = AcademicYearService();

  late TextEditingController _idController;
  late TextEditingController _nameController;
  bool _isActive = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _idController = TextEditingController(text: widget.academicYear?.id ?? '');
    _nameController = TextEditingController(
      text: widget.academicYear?.name ?? '',
    );
    _isActive = widget.academicYear?.isActive ?? false;
  }

  @override
  void dispose() {
    _idController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final schoolId = context.read<SchoolProvider>().activeSchoolId!;

    final year = AcademicYear(
      id: widget.academicYear == null
          ? _idController.text.trim()
          : widget.academicYear!.id,
      name: _nameController.text.trim(),
      isActive: _isActive,
    );

    try {
      if (widget.academicYear == null) {
        await _service.addAcademicYear(schoolId, year);
        SnackbarUtils.showSnackbar('Tahun Ajaran berhasil ditambahkan');
      } else {
        await _service.updateAcademicYear(schoolId, year);
        SnackbarUtils.showSnackbar('Tahun Ajaran berhasil diperbarui');
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      SnackbarUtils.showErrorSnackbar('Error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _delete() async {
    if (widget.academicYear == null) return;

    final schoolId = context.read<SchoolProvider>().activeSchoolId!;

    final confirm = await DialogUtils.showConfirmationDialog(
      title: 'Hapus Tahun Ajaran',
      content: 'Yakin ingin menghapus tahun ajaran ini?',
      confirmText: 'Hapus',
      isDestructive: true,
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        await _service.deleteAcademicYear(schoolId, widget.academicYear!.id);
        SnackbarUtils.showSnackbar('Tahun Ajaran dihapus');
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
    final isEditing = widget.academicYear != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Tahun Ajaran' : 'Tambah Tahun Ajaran'),
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
                        labelText: 'ID Tahun Ajaran *',
                        helperText:
                            'Bisa diisi misal: "2026", "2026-1". Tidak bisa diubah setelah dibuat.',
                      ),
                      readOnly: isEditing,
                      validator: (v) => v!.isEmpty ? 'Wajib diisi' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Nama Tahun Ajaran *',
                      ),
                      validator: (v) => v!.isEmpty ? 'Wajib diisi' : null,
                    ),
                    const SizedBox(height: 16),
                    SwitchListTile(
                      title: const Text('Status Aktif'),
                      subtitle: const Text('Tahun ajaran ini sedang berjalan'),
                      value: _isActive,
                      onChanged: (val) {
                        setState(() {
                          _isActive = val;
                        });
                      },
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
