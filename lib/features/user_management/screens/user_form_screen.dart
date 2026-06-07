import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/models/app_user.dart';
import '../../../core/providers/school_provider.dart';
import '../../../core/providers/user_provider.dart';
import '../services/user_management_service.dart';
import '../../student_management/services/student_service.dart';
import '../../../core/models/student.dart';
import '../../../core/utils/snackbar_utils.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/components/custom_button.dart';

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
  List<String> _availableRoles = [];
  bool _isActive = true;
  bool _isLoading = false;
  bool _obscurePassword = true;

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

    final schoolId = context.read<SchoolProvider>().activeSchoolId ?? '';
    final currentUserRole = context.read<UserProvider>().userMapping?.registeredSchools[schoolId] ?? '';

    _availableRoles = ['ADMIN', 'KEPALA_SEKOLAH', 'BENDAHARA', 'GURU', 'WALI', 'SISWA'];
    if (currentUserRole == 'SUPER_ADMIN') {
      _availableRoles.insert(0, 'SUPER_ADMIN');
    }

    if (!_availableRoles.contains(_role)) {
      _role = _availableRoles.first;
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
          childrens: widget.user!.childrens, // Preserve childrens
          createdAt: widget.user!.createdAt, // Preserve created time
          createdBy: widget.user!.createdBy,
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

  Widget _buildChildrenList(String schoolId) {
    if (widget.user == null || widget.user!.childrens.isEmpty) {
      return const SizedBox.shrink();
    }

    final childrenIds = widget.user!.childrens.keys.toList();
    final studentService = StudentService();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8.0),
          child: Text(
            'Daftar Anak (Read-Only)',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
        ...childrenIds.map((studentId) {
          return FutureBuilder<Student?>(
            future: studentService.getStudentById(schoolId, studentId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const ListTile(
                  leading: CircularProgressIndicator(),
                  title: Text('Memuat data anak...'),
                );
              }
              if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
                return ListTile(
                  leading: const Icon(Icons.person_off),
                  title: Text('ID: $studentId'),
                  subtitle: const Text('Data siswa tidak ditemukan'),
                );
              }
              final student = snapshot.data!;
              return ListTile(
                leading: const Icon(Icons.person),
                title: Text(student.name),
                subtitle: Text('NIS: ${student.nis} | Kelas: ${student.classId}'),
              );
            },
          );
        }),
      ],
    );
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
                        decoration: InputDecoration(
                          labelText: 'Password Sementara *',
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword ? Icons.visibility_off : Icons.visibility,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                          ),
                        ),
                        obscureText: _obscurePassword,
                        validator: (v) => v!.isEmpty ? 'Wajib diisi' : null,
                      ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _role,
                      decoration: const InputDecoration(labelText: 'Role'),
                      items: _availableRoles
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
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: CustomButton(
                            text: 'Kirim Link Reset Password',
                            icon: Icons.lock_reset,
                            isSecondary: true,
                            onPressed: () async {
                              try {
                                await FirebaseAuth.instance.sendPasswordResetEmail(email: widget.user!.email);
                                if (mounted) {
                                  SnackbarUtils.showSnackbar('Link reset password telah dikirim ke ${widget.user!.email}');
                                }
                              } catch (e) {
                                if (mounted) {
                                  SnackbarUtils.showErrorSnackbar('Gagal mengirim link: $e');
                                }
                              }
                            },
                          ),
                        ),
                        if (_role == 'WALI' || _role == 'SISWA') ...[
                          const SizedBox(height: 16),
                          _buildChildrenList(context.read<SchoolProvider>().activeSchoolId ?? ''),
                        ],
                      ],
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
