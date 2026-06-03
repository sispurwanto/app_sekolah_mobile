import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/models/app_user.dart';
import '../../../core/providers/school_provider.dart';
import '../services/user_management_service.dart';
import '../../../core/utils/snackbar_utils.dart';

class UserFormScreen extends StatefulWidget {
  final AppUser? user;

  const UserFormScreen({super.key, this.user});

  @override
  State<UserFormScreen> createState() => _UserFormScreenState();
}

class _UserFormScreenState extends State<UserFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _userService = UserManagementService();

  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _passwordController;

  String _role = 'WALI';
  bool _isActive = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user?.name ?? '');
    _emailController = TextEditingController(text: widget.user?.email ?? '');
    _passwordController = TextEditingController(); // Empty for new, or hidden for existing

    if (widget.user != null) {
      _role = widget.user!.role;
      _isActive = widget.user!.isActive;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final schoolId = context.read<SchoolProvider>().activeSchoolId!;

    try {
      if (widget.user == null) {
        // Create new user
        if (_passwordController.text.length < 6) {
          throw Exception('Password minimal 6 karakter');
        }

        await _userService.addUser(
          schoolId: schoolId,
          name: _nameController.text.trim(),
          email: _emailController.text.trim(),
          password: _passwordController.text,
          role: _role,
        );
        SnackbarUtils.showSnackbar('User berhasil ditambahkan');
      } else {
        // Update existing user (can't update email easily here without re-auth, so we only update name, role, status)
        final updatedUser = AppUser(
          id: widget.user!.id,
          name: _nameController.text.trim(),
          email: widget.user!.email, // Keep old email
          role: _role,
          isActive: _isActive,
        );

        await _userService.updateUser(
          schoolId: schoolId,
          user: updatedUser,
        );
        SnackbarUtils.showSnackbar('User berhasil diperbarui');
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
    final isEditing = widget.user != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit User' : 'Tambah User'),
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
                      decoration: const InputDecoration(labelText: 'Nama Lengkap *'),
                      validator: (v) => v!.isEmpty ? 'Wajib diisi' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _emailController,
                      decoration: const InputDecoration(labelText: 'Email *'),
                      keyboardType: TextInputType.emailAddress,
                      enabled: !isEditing, // Disable email edit for existing user for now
                      validator: (v) => v!.isEmpty ? 'Wajib diisi' : null,
                    ),
                    const SizedBox(height: 16),
                    if (!isEditing) // Only show password for new user
                      TextFormField(
                        controller: _passwordController,
                        decoration: const InputDecoration(labelText: 'Password Sementara *'),
                        obscureText: true,
                        validator: (v) => v!.isEmpty ? 'Wajib diisi' : null,
                      ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _role,
                      decoration: const InputDecoration(labelText: 'Role'),
                      items: ['SUPER_ADMIN', 'ADMIN', 'BENDAHARA', 'GURU', 'WALI']
                          .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                          .toList(),
                      onChanged: (v) => setState(() => _role = v!),
                    ),
                    if (isEditing) ...[
                      const SizedBox(height: 16),
                      SwitchListTile(
                        title: const Text('Status Aktif'),
                        value: _isActive,
                        onChanged: (v) => setState(() => _isActive = v),
                      ),
                    ],
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
