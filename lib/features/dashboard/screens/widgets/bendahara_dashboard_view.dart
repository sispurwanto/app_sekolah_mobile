import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../student_management/screens/student_list_screen.dart';
import '../../../invoices/screens/payment_validation_screen.dart';
import '../../../savings/screens/savings_report_screen.dart';
import '../../../reports/screens/financial_report_screen.dart';
import '../../../invoices/screens/invoice_distribution_log_screen.dart';
import '../../../invoices/screens/financial_dashboard_screen.dart';
import '../../../../core/providers/school_provider.dart';
import '../../../master_data/services/academic_year_service.dart';

class BendaharaDashboardView extends StatefulWidget {
  final String role;
  const BendaharaDashboardView({super.key, required this.role});

  @override
  State<BendaharaDashboardView> createState() => _BendaharaDashboardViewState();
}

class _BendaharaDashboardViewState extends State<BendaharaDashboardView> {
  String? _activeYearId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadActiveYear();
  }

  Future<void> _loadActiveYear() async {
    final schoolId = context.read<SchoolProvider>().activeSchoolId ?? '';
    if (schoolId.isEmpty) return;
    final activeYear = await AcademicYearService().getActiveAcademicYear(schoolId);
    if (mounted && activeYear != null) {
      setState(() {
        _activeYearId = activeYear.id;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final schoolId = context.watch<SchoolProvider>().activeSchoolId ?? '';

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
              _buildMenuCard(
                context,
                title: widget.role == 'BENDAHARA' ? 'Kasir' : 'Data Siswa',
                icon: widget.role == 'BENDAHARA' ? Icons.point_of_sale : Icons.people,
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
              if (widget.role != 'KEPALA_SEKOLAH')
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
                  badgeStream: (schoolId.isNotEmpty && _activeYearId != null)
                      ? FirebaseFirestore.instance
                          .collection('schools')
                          .doc(schoolId)
                          .collection('transactions_year')
                          .doc(_activeYearId)
                          .collection('payments')
                          .where('status', isEqualTo: 'PENDING')
                          .snapshots()
                      : null,
                ),
              _buildMenuCard(
                context,
                title: 'Dashboard Keuangan',
                icon: Icons.dashboard,
                color: Colors.redAccent,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const FinancialDashboardScreen(),
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
              _buildMenuCard(
                context,
                title: 'Distribusi Tagihan',
                icon: Icons.send_to_mobile,
                color: Colors.teal,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const InvoiceDistributionLogScreen(),
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
    Stream<QuerySnapshot>? badgeStream,
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
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(icon, size: 32, color: color),
                  if (badgeStream != null)
                    Positioned(
                      right: -8,
                      top: -8,
                      child: StreamBuilder<QuerySnapshot>(
                        stream: badgeStream,
                        builder: (context, snapshot) {
                          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                            return const SizedBox.shrink();
                          }
                          final count = snapshot.data!.docs.length;
                          return Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              count > 99 ? '99+' : count.toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
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
