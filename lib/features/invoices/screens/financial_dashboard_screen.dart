import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/providers/school_provider.dart';
import '../../../core/providers/user_provider.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../core/utils/snackbar_utils.dart';
import '../../master_data/services/academic_year_service.dart';
import '../services/invoice_service.dart';
import '../../../core/models/academic_year.dart';

class FinancialDashboardScreen extends StatefulWidget {
  const FinancialDashboardScreen({super.key});

  @override
  State<FinancialDashboardScreen> createState() =>
      _FinancialDashboardScreenState();
}

class _FinancialDashboardScreenState extends State<FinancialDashboardScreen> {
  final _academicYearService = AcademicYearService();
  final _invoiceService = InvoiceService();

  List<AcademicYear> _years = [];
  String? _selectedYearId;
  bool _isLoadingYears = false;
  bool _isRecalculating = false;

  @override
  void initState() {
    super.initState();
    _loadYears();
  }

  Future<void> _loadYears() async {
    setState(() => _isLoadingYears = true);
    try {
      final schoolId = context.read<SchoolProvider>().activeSchoolId!;
      final years = await _academicYearService.getAcademicYears(schoolId).first;
      setState(() {
        _years = years;
        if (years.isNotEmpty) {
          _selectedYearId = years.firstWhere((y) => y.isActive, orElse: () => years.first).id;
        }
      });
    } catch (e) {
      SnackbarUtils.showErrorSnackbar('Gagal memuat tahun ajaran: $e');
    } finally {
      if (mounted) setState(() => _isLoadingYears = false);
    }
  }

  Future<void> _recalculateSync() async {
    final schoolId = context.read<SchoolProvider>().activeSchoolId!;
    if (schoolId.isEmpty || _selectedYearId == null) return;

    setState(() => _isRecalculating = true);
    try {
      await _invoiceService.recalculateSummaries(schoolId, _selectedYearId!);
      SnackbarUtils.showSnackbar('Sinkronisasi ringkasan berhasil!');
    } catch (e) {
      SnackbarUtils.showErrorSnackbar('Gagal sinkronisasi: $e');
    } finally {
      if (mounted) setState(() => _isRecalculating = false);
    }
  }

  Widget _buildSummaryCard(String title, num count, num amount, Color color, IconData icon) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: color.withOpacity(0.1),
              child: Icon(icon, color: color, size: 30),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w600, fontSize: 14)),
                  const SizedBox(height: 4),
                  Text(
                    CurrencyUtils.formatRp(amount.toDouble()),
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: color),
                  ),
                  const SizedBox(height: 4),
                  Text('${count.toInt()} Tagihan', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final schoolId = context.watch<SchoolProvider>().activeSchoolId ?? '';
    final role = context.watch<UserProvider>().userMapping?.registeredSchools[schoolId] ?? '';
    final canRecalculate = role == 'SUPER_ADMIN' || role == 'ADMIN';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard Keuangan'),
        actions: [
          if (canRecalculate && _selectedYearId != null)
            IconButton(
              icon: _isRecalculating 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.sync),
              tooltip: 'Sinkronisasi Ulang (Recalculate)',
              onPressed: _isRecalculating ? null : _recalculateSync,
            ),
        ],
      ),
      body: _isLoadingYears
          ? const Center(child: CircularProgressIndicator())
          : _years.isEmpty
              ? const Center(child: Text('Tidak ada tahun ajaran ditemukan.'))
              : Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16.0),
                      color: Colors.white,
                      child: DropdownButtonFormField<String>(
                        decoration: const InputDecoration(
                          labelText: 'Tahun Ajaran',
                          border: OutlineInputBorder(),
                        ),
                        value: _selectedYearId,
                        items: _years.map((y) {
                          return DropdownMenuItem(
                            value: y.id,
                            child: Text(y.name + (y.isActive ? ' (Aktif)' : '')),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedYearId = val);
                        },
                      ),
                    ),
                    Expanded(
                      child: _selectedYearId == null
                          ? const SizedBox()
                          : StreamBuilder<DocumentSnapshot>(
                              stream: FirebaseFirestore.instance
                                  .collection('schools')
                                  .doc(schoolId)
                                  .collection('transactions_year')
                                  .doc(_selectedYearId)
                                  .collection('invoice_summary')
                                  .doc('global')
                                  .snapshots(),
                              builder: (context, snapshot) {
                                if (snapshot.connectionState == ConnectionState.waiting) {
                                  return const Center(child: CircularProgressIndicator());
                                }
                                
                                final data = snapshot.data?.data() as Map<String, dynamic>? ?? {};
                                
                                final unpaidCount = data['unpaid_count'] ?? 0;
                                final unpaidAmount = data['unpaid_amount'] ?? 0;
                                final partialCount = data['partial_count'] ?? 0;
                                final partialAmount = data['partial_amount'] ?? 0;
                                final paidCount = data['paid_count'] ?? 0;
                                final paidAmount = data['paid_amount'] ?? 0;

                                return RefreshIndicator(
                                  onRefresh: _recalculateSync,
                                  child: ListView(
                                    padding: const EdgeInsets.all(16.0),
                                    children: [
                                      _buildSummaryCard(
                                        'TOTAL BELUM DIBAYAR (UNPAID)',
                                        unpaidCount,
                                        unpaidAmount,
                                        Colors.red,
                                        Icons.warning_amber_rounded,
                                      ),
                                      const SizedBox(height: 12),
                                      _buildSummaryCard(
                                        'TOTAL CICILAN (PARTIAL)',
                                        partialCount,
                                        partialAmount,
                                        Colors.orange,
                                        Icons.pie_chart_outline,
                                      ),
                                      const SizedBox(height: 12),
                                      _buildSummaryCard(
                                        'TOTAL LUNAS (PAID)',
                                        paidCount,
                                        paidAmount,
                                        Colors.green,
                                        Icons.check_circle_outline,
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
    );
  }
}
