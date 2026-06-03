import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/school_provider.dart';
import '../../../core/providers/user_provider.dart';
import '../../../core/utils/dialog_utils.dart';
import '../../auth/services/auth_service.dart';
import '../../school_management/screens/school_list_screen.dart';
import '../../user_management/screens/user_list_screen.dart';
import '../../invoices/screens/invoice_list_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  void _handleLogout(BuildContext context) async {
    final shouldLogout = await DialogUtils.showConfirmationDialog(
      title: 'Konfirmasi Logout',
      content: 'Apakah Anda yakin ingin keluar dari aplikasi?',
      confirmText: 'Logout',
      isDestructive: true,
    );

    if (shouldLogout == true && context.mounted) {
      context.read<SchoolProvider>().clearActiveSchool();
      context.read<UserProvider>().clearUserMapping();
      context.read<AuthService>().signOut();
    }
  }

  @override
  Widget build(BuildContext context) {
    final schoolId = context.watch<SchoolProvider>().activeSchoolId ?? '';
    final userMapping = context.watch<UserProvider>().userMapping;
    final role = userMapping?.registeredSchools[schoolId] ?? 'UNKNOWN';

    return Scaffold(
      appBar: AppBar(
        title: Text('Dashboard - $schoolId'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _handleLogout(context),
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            UserAccountsDrawerHeader(
              accountName: Text(userMapping?.name ?? 'Loading...'),
              accountEmail: Text('${userMapping?.email} | Role: $role'),
              currentAccountPicture: const CircleAvatar(
                backgroundColor: Colors.white,
                child: Icon(Icons.person, size: 40, color: Colors.blue),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.dashboard),
              title: const Text('Beranda'),
              onTap: () => Navigator.pop(context),
            ),
            
            // Menu khusus SUPER_ADMIN
            if (role == 'SUPER_ADMIN')
              ListTile(
                leading: const Icon(Icons.business),
                title: const Text('Manajemen Sekolah'),
                onTap: () {
                  Navigator.pop(context); // Close drawer
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SchoolListScreen(),
                    ),
                  );
                },
              ),

            // Menu untuk SUPER_ADMIN dan ADMIN
            if (role == 'SUPER_ADMIN' || role == 'ADMIN')
              ListTile(
                leading: const Icon(Icons.people),
                title: const Text('Manajemen User'),
                onTap: () {
                  Navigator.pop(context); // Close drawer
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => UserListScreen(),
                    ),
                  );
                },
              ),
              
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Logout', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _handleLogout(context);
              },
            ),
          ],
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Welcome to Dashboard!', style: TextStyle(fontSize: 24)),
            const SizedBox(height: 16),
            Text('Active School ID: $schoolId', style: const TextStyle(fontWeight: FontWeight.bold)),
            Text('Your Role: $role', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => InvoiceListScreen(),
                  ),
                );
              },
              child: const Text('Lihat Tagihan'),
            ),
          ],
        ),
      ),
    );
  }
}

