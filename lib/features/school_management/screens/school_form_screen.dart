import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/models/school.dart';
import '../services/school_service.dart';
import '../../../core/utils/snackbar_utils.dart';
import '../../../core/components/custom_button.dart';
import '../../../core/providers/user_provider.dart';
import '../../../core/providers/school_provider.dart';

class SchoolFormScreen extends StatefulWidget {
  final School? school;

  const SchoolFormScreen({super.key, this.school});

  @override
  State<SchoolFormScreen> createState() => _SchoolFormScreenState();
}

class _SchoolFormScreenState extends State<SchoolFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _schoolService = SchoolService();

  late TextEditingController _nameController;
  late TextEditingController _addressController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  late TextEditingController _studentLimitController;
  late TextEditingController _bankNameController;
  late TextEditingController _bankAccountNumberController;
  late TextEditingController _bankAccountNameController;

  String _status = 'ACTIVE';
  String _package = 'BASIC';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.school?.name ?? '');
    _addressController = TextEditingController(text: widget.school?.address ?? '');
    _phoneController = TextEditingController(text: widget.school?.phone ?? '');
    _emailController = TextEditingController(text: widget.school?.email ?? '');
    _studentLimitController = TextEditingController(text: widget.school?.studentLimit.toString() ?? '100');
    _bankNameController = TextEditingController(text: widget.school?.bankName ?? '');
    _bankAccountNumberController = TextEditingController(text: widget.school?.bankAccountNumber ?? '');
    _bankAccountNameController = TextEditingController(text: widget.school?.bankAccountName ?? '');
    
    if (widget.school != null) {
      _status = widget.school!.status;
      _package = widget.school!.package;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _studentLimitController.dispose();
    _bankNameController.dispose();
    _bankAccountNumberController.dispose();
    _bankAccountNameController.dispose();
    super.dispose();
  }

  void _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    String schoolId;
    if (widget.school == null) {
      schoolId = _nameController.text.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_');
    } else {
      schoolId = widget.school!.id;
    }

    final school = School(
      id: schoolId,
      name: _nameController.text.trim(),
      address: _addressController.text.trim(),
      phone: _phoneController.text.trim(),
      email: _emailController.text.trim(),
      status: _status,
      package: _package,
      studentLimit: int.tryParse(_studentLimitController.text) ?? 100,
      bankName: _bankNameController.text.trim().isEmpty ? null : _bankNameController.text.trim(),
      bankAccountNumber: _bankAccountNumberController.text.trim().isEmpty ? null : _bankAccountNumberController.text.trim(),
      bankAccountName: _bankAccountNameController.text.trim().isEmpty ? null : _bankAccountNameController.text.trim(),
      createdAt: widget.school?.createdAt, // SchoolService will use serverTimestamp if null
    );

    try {
      if (widget.school == null) {
        await _schoolService.addSchool(school);
        SnackbarUtils.showSnackbar('Sekolah berhasil ditambahkan');
      } else {
        await _schoolService.updateSchool(school);
        SnackbarUtils.showSnackbar('Sekolah berhasil diperbarui');
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      SnackbarUtils.showErrorSnackbar('Error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.school != null;
    
    final activeSchoolId = context.watch<SchoolProvider>().activeSchoolId ?? '';
    final targetSchoolId = widget.school?.id ?? activeSchoolId;
    final role = context.watch<UserProvider>().userMapping?.registeredSchools[targetSchoolId] ?? '';
    final isSuperAdmin = role == 'SUPER_ADMIN';

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Sekolah' : 'Tambah Sekolah'),
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
                      controller: _nameController,
                      decoration: const InputDecoration(labelText: 'Nama Sekolah *'),
                      validator: (v) => v!.isEmpty ? 'Wajib diisi' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _addressController,
                      decoration: const InputDecoration(labelText: 'Alamat'),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _phoneController,
                      decoration: const InputDecoration(labelText: 'Telepon'),
                      keyboardType: TextInputType.phone,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _emailController,
                      decoration: const InputDecoration(labelText: 'Email'),
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _studentLimitController,
                      decoration: const InputDecoration(labelText: 'Batas Siswa'),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    ),
                    const Divider(height: 32),
                    const Text('Informasi Rekening Sekolah', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _bankNameController,
                      decoration: const InputDecoration(labelText: 'Nama Bank (misal: BCA, BNI)'),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _bankAccountNumberController,
                      decoration: const InputDecoration(labelText: 'Nomor Rekening'),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _bankAccountNameController,
                      decoration: const InputDecoration(labelText: 'Atas Nama (A/N)'),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _status,
                      decoration: const InputDecoration(labelText: 'Status'),
                      items: ['ACTIVE', 'INACTIVE']
                          .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                          .toList(),
                      onChanged: isSuperAdmin ? (v) => setState(() => _status = v!) : null,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _package,
                      decoration: const InputDecoration(labelText: 'Paket'),
                      items: ['BASIC', 'PREMIUM', 'PRO']
                          .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                          .toList(),
                      onChanged: isSuperAdmin ? (v) => setState(() => _package = v!) : null,
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      child: CustomButton(
                        text: 'Simpan',
                        onPressed: _save,
                        isLoading: _isLoading,
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
