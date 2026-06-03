import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/school_provider.dart';
import '../../../core/models/global_user_mapping.dart';
import '../../auth/services/auth_service.dart';

class SchoolSelectionScreen extends StatelessWidget {
  final GlobalUserMapping userMapping;

  const SchoolSelectionScreen({super.key, required this.userMapping});

  @override
  Widget build(BuildContext context) {
    final schools = userMapping.registeredSchools.keys.toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pilih Sekolah'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              context.read<AuthService>().signOut();
            },
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: schools.length,
        itemBuilder: (context, index) {
          final schoolId = schools[index];
          final role = userMapping.registeredSchools[schoolId];

          return ListTile(
            leading: const CircleAvatar(child: Icon(Icons.school)),
            title: Text(schoolId),
            subtitle: Text('Role: $role'),
            onTap: () {
              // Set active school and navigate automatically because AuthWrapper will rebuild
              context.read<SchoolProvider>().setActiveSchool(schoolId);
            },
          );
        },
      ),
    );
  }
}
