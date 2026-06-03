import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/models/app_user.dart';
import '../../../core/providers/school_provider.dart';
import '../services/user_management_service.dart';
import 'user_form_screen.dart';

class UserListScreen extends StatelessWidget {
  UserListScreen({super.key});

  final UserManagementService _userService = UserManagementService();

  @override
  Widget build(BuildContext context) {
    final schoolId = context.watch<SchoolProvider>().activeSchoolId ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manajemen User'),
      ),
      body: StreamBuilder<List<AppUser>>(
        stream: _userService.getUsers(schoolId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final users = snapshot.data ?? [];

          if (users.isEmpty) {
            return const Center(child: Text('Belum ada user di sekolah ini.'));
          }

          return ListView.builder(
            itemCount: users.length,
            itemBuilder: (context, index) {
              final user = users[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  leading: CircleAvatar(child: Text(user.role[0])),
                  title: Text(user.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('${user.email}\nRole: ${user.role} | Status: ${user.isActive ? "Aktif" : "Non-Aktif"}'),
                  isThreeLine: true,
                  trailing: IconButton(
                    icon: const Icon(Icons.edit, color: Colors.blue),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => UserFormScreen(user: user),
                        ),
                      );
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const UserFormScreen(),
            ),
          );
        },
        child: const Icon(Icons.person_add),
      ),
    );
  }
}
