import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/providers/user_provider.dart';
import '../services/user_management_service.dart';
import '../../../core/utils/snackbar_utils.dart';
import '../../../core/components/custom_button.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _userService = UserManagementService();

  bool _isLoading = false;
  String _email = '';

  @override
  void initState() {
    super.initState();
    // Use addPostFrameCallback or read directly in initState
    final userMapping = context.read<UserProvider>().userMapping;
    if (userMapping != null) {
      _nameController.text = userMapping.name;
      _email = userMapping.email;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;

    final userProvider = context.read<UserProvider>();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final userMapping = userProvider.userMapping;

    if (uid == null || userMapping == null) {
      SnackbarUtils.showErrorSnackbar('Sesi tidak valid.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _userService.updateUserProfile(
        uid: uid,
        newName: _nameController.text.trim(),
        registeredSchools: userMapping.registeredSchools,
      );
      
      // Update local provider manually or let the stream handle it if it listens
      // To be safe, we can trigger an auth check in main if needed, but the user mapping stream 
      // in main.dart should automatically pick up the change since it's listening to global_users_mapping.
      
      SnackbarUtils.showSnackbar('Profil berhasil diperbarui!');
    } catch (e) {
      SnackbarUtils.showErrorSnackbar('Gagal memperbarui profil: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resetPassword() async {
    if (_email.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: _email);
      if (mounted) {
        SnackbarUtils.showSnackbar('Link reset password telah dikirim ke $_email');
      }
    } catch (e) {
      if (mounted) {
        SnackbarUtils.showErrorSnackbar('Gagal mengirim link: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil Saya'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const CircleAvatar(
                radius: 40,
                child: Icon(Icons.person, size: 40),
              ),
              const SizedBox(height: 24),
              TextFormField(
                initialValue: _email,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
                enabled: false, // Read-only
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nama Lengkap *',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => v == null || v.isEmpty ? 'Wajib diisi' : null,
              ),
              const SizedBox(height: 24),
              CustomButton(
                text: 'Simpan Profil',
                onPressed: _updateProfile,
                isLoading: _isLoading,
                icon: Icons.save,
              ),
              const SizedBox(height: 32),
              const Divider(),
              const SizedBox(height: 16),
              const Text(
                'Keamanan',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              CustomButton(
                text: 'Kirim Link Reset Password',
                onPressed: _resetPassword,
                isLoading: _isLoading,
                icon: Icons.lock_reset,
                isSecondary: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
