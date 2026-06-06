import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/school_provider.dart';
import '../../../core/providers/user_provider.dart';
import '../../../core/utils/dialog_utils.dart';
import '../../auth/services/auth_service.dart';
import '../../school_management/screens/school_list_screen.dart';
import '../../user_management/screens/user_list_screen.dart';
import '../../invoices/screens/invoice_list_screen.dart';
import '../../student_management/screens/student_list_screen.dart';
import '../../master_data/screens/class_list_screen.dart';
import '../../master_data/screens/academic_year_list_screen.dart';
import '../../master_data/screens/fee_template_list_screen.dart';
import 'widgets/wali_dashboard_view.dart';
import 'widgets/bendahara_dashboard_view.dart';
import 'widgets/guru_dashboard_view.dart';

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
            
            // Tombol Ganti Sekolah (jika user punya lebih dari 1 sekolah)
            if ((userMapping?.registeredSchools.length ?? 0) > 1)
              ListTile(
                leading: const Icon(Icons.swap_horiz),
                title: const Text('Ganti Sekolah'),
                onTap: () {
                  Navigator.pop(context);
                  context.read<SchoolProvider>().clearActiveSchool();
                },
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

            // Menu untuk SUPER_ADMIN dan ADMIN dikelompokkan ke Data Master
            if (role == 'SUPER_ADMIN' || role == 'ADMIN')
              ExpansionTile(
                leading: const Icon(Icons.storage),
                title: const Text('Data Master'),
                children: [
                  ListTile(
                    leading: const Icon(Icons.face),
                    title: const Text('Manajemen Siswa'),
                    contentPadding: const EdgeInsets.only(left: 40),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => StudentListScreen(),
                        ),
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.class_),
                    title: const Text('Data Kelas'),
                    contentPadding: const EdgeInsets.only(left: 40),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ClassListScreen(),
                        ),
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.calendar_month),
                    title: const Text('Tahun Ajaran'),
                    contentPadding: const EdgeInsets.only(left: 40),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AcademicYearListScreen(),
                        ),
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.request_quote),
                    title: const Text('Master Tagihan'),
                    contentPadding: const EdgeInsets.only(left: 40),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => FeeTemplateListScreen(),
                        ),
                      );
                    },
                  ),
                ],
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
      body: _buildDashboardBody(role, schoolId, context),
    );
  }

  Widget _buildDashboardBody(String role, String schoolId, BuildContext context) {
    if (role == 'WALI') return const WaliDashboardView();
    if (role == 'GURU') return const GuruDashboardView();
    if (role == 'BENDAHARA' || role == 'ADMIN' || role == 'SUPER_ADMIN') {
      return SingleChildScrollView(
        child: Column(
          children: [
            const BendaharaDashboardView(),
            const Divider(),
            Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Text('Active School ID: $schoolId', style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text('Your Role: $role', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('Welcome to Dashboard!', style: TextStyle(fontSize: 24)),
          const SizedBox(height: 16),
          Text('Active School ID: $schoolId', style: const TextStyle(fontWeight: FontWeight.bold)),
          Text('Your Role: $role', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
        ],
      ),
    );
  }
}

