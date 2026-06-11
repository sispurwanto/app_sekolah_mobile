import 'package:flutter/material.dart';
import '../../../student_management/screens/student_list_screen.dart';
import '../../../invoices/screens/payment_validation_screen.dart';
import '../../../savings/screens/savings_report_screen.dart';
import '../../../reports/screens/financial_report_screen.dart';

class BendaharaDashboardView extends StatelessWidget {
  final String role;
  const BendaharaDashboardView({super.key, required this.role});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Menu',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.85,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              if (role != 'KEPALA_SEKOLAH')
                _buildMenuCard(
                  context,
                  title: 'Kasir (Cari Siswa)',
                  icon: Icons.point_of_sale,
                  color: Colors.blue,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const StudentListScreen(),
                      ),
                    );
                  },
                ),
              if (role == 'KEPALA_SEKOLAH')
                _buildMenuCard(
                  context,
                  title: 'Data Siswa',
                  icon: Icons.people,
                  color: Colors.blue,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const StudentListScreen(),
                      ),
                    );
                  },
                ),
              if (role != 'KEPALA_SEKOLAH')
                _buildMenuCard(
                  context,
                  title: 'Validasi Pembayaran',
                  icon: Icons.domain_verification,
                  color: Colors.orange,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const PaymentValidationScreen(),
                      ),
                    );
                  },
                ),
              _buildMenuCard(
                context,
                title: 'Laporan Tabungan',
                icon: Icons.account_balance_wallet,
                color: Colors.green,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const SavingsReportScreen(),
                    ),
                  );
                },
              ),
              _buildMenuCard(
                context,
                title: 'Laporan Pembayaran',
                icon: Icons.analytics,
                color: Colors.purple,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const FinancialReportScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMenuCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 32, color: color),
              const SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
