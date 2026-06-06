import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/models/fee_template.dart';
import '../../../core/models/app_class.dart';
import '../../../core/providers/school_provider.dart';
import '../services/fee_template_service.dart';
import '../services/class_service.dart';
import '../../../core/utils/snackbar_utils.dart';
import '../../../core/utils/dialog_utils.dart';

class FeeTemplateFormScreen extends StatefulWidget {
  final FeeTemplate? template;

  const FeeTemplateFormScreen({super.key, this.template});

  @override
  State<FeeTemplateFormScreen> createState() => _FeeTemplateFormScreenState();
}

class _FeeTemplateFormScreenState extends State<FeeTemplateFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _service = FeeTemplateService();
  final _classService = ClassService();

  late TextEditingController _idController;
  late TextEditingController _titleController;
  late TextEditingController _amountController;
  String? _classId;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _idController = TextEditingController(text: widget.template?.id ?? '');
    _titleController = TextEditingController(text: widget.template?.title ?? '');
    _amountController = TextEditingController(text: widget.template?.amount.toStringAsFixed(0) ?? '');
    _classId = widget.template?.classId;
  }

  @override
  void dispose() {
    _idController.dispose();
    _titleController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  void _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final schoolId = context.read<SchoolProvider>().activeSchoolId!;

    final template = FeeTemplate(
      id: _idController.text.trim(),
      title: _titleController.text.trim(),
      amount: double.tryParse(_amountController.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0.0,
      classId: _classId,
    );

    try {
      if (widget.template == null) {
        await _service.addFeeTemplate(schoolId, template);
        SnackbarUtils.showSnackbar('Master Tagihan berhasil ditambahkan');
      } else {
        await _service.updateFeeTemplate(schoolId, template);
        SnackbarUtils.showSnackbar('Master Tagihan berhasil diperbarui');
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      SnackbarUtils.showErrorSnackbar('Error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _delete() async {
    if (widget.template == null) return;
    
    final schoolId = context.read<SchoolProvider>().activeSchoolId!;

    final confirm = await DialogUtils.showConfirmationDialog(
      title: 'Hapus Master Tagihan',
      content: 'Yakin ingin menghapus tagihan ini?',
      confirmText: 'Hapus',
      isDestructive: true,
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        await _service.deleteFeeTemplate(schoolId, widget.template!.id);
        SnackbarUtils.showSnackbar('Master Tagihan dihapus');
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
    final isEditing = widget.template != null;
    final schoolId = context.watch<SchoolProvider>().activeSchoolId ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Master Tagihan' : 'Tambah Master Tagihan'),
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
                        labelText: 'ID Tagihan (Misal: SPP-KLS1) *',
                        helperText: 'Tidak bisa diedit setelah disimpan.',
                      ),
                      readOnly: isEditing,
                      validator: (v) => v!.isEmpty ? 'Wajib diisi' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(labelText: 'Nama Tagihan *'),
                      validator: (v) => v!.isEmpty ? 'Wajib diisi' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _amountController,
                      decoration: const InputDecoration(labelText: 'Nominal (Rp) *'),
                      keyboardType: TextInputType.number,
                      validator: (v) => v!.isEmpty ? 'Wajib diisi' : null,
                    ),
                    const SizedBox(height: 16),
                    StreamBuilder<List<AppClass>>(
                      stream: _classService.getClasses(schoolId),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const CircularProgressIndicator();
                        }
                        
                        final classes = snapshot.data ?? [];
                        
                        // Ensure _classId still exists in the list if it was set previously
                        if (_classId != null && _classId!.isNotEmpty && !classes.any((c) => c.id == _classId)) {
                          _classId = null;
                        }

                        return DropdownButtonFormField<String?>(
                          value: _classId,
                          decoration: const InputDecoration(
                            labelText: 'Target Kelas',
                            helperText: 'Pilih kelas atau biarkan kosong jika berlaku untuk semua siswa.',
                          ),
                          items: [
                            const DropdownMenuItem<String?>(
                              value: null,
                              child: Text('Semua Kelas'),
                            ),
                            ...classes.map((c) => DropdownMenuItem(
                              value: c.id,
                              child: Text(c.name),
                            ))
                          ],
                          onChanged: (val) {
                            setState(() {
                              _classId = val;
                            });
                          },
                        );
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
