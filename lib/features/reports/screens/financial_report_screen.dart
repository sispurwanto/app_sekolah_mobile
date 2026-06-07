import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../core/providers/school_provider.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../core/models/payment.dart';
import '../../../core/models/invoice.dart';
import '../../invoices/services/payment_service.dart';
import '../../invoices/services/invoice_service.dart';
import '../../../core/models/academic_year.dart';
import '../../master_data/services/academic_year_service.dart';
import '../services/export_service.dart';

class FinancialReportScreen extends StatefulWidget {
  const FinancialReportScreen({Key? key}) : super(key: key);

  @override
  State<FinancialReportScreen> createState() => _FinancialReportScreenState();
}

class _FinancialReportScreenState extends State<FinancialReportScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final PaymentService _paymentService = PaymentService();
  final InvoiceService _invoiceService = InvoiceService();
  final AcademicYearService _academicYearService = AcademicYearService();
  final ExportService _exportService = ExportService();

  String? _selectedAcademicYearId;
  List<AcademicYear> _academicYears = [];
  bool _isLoadingYears = true;

  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadAcademicYears();
  }

  Future<void> _loadAcademicYears() async {
    // School ID is needed to load years. We can get it from context via read.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final schoolId = context.read<SchoolProvider>().activeSchoolId;
      if (schoolId == null) return;

      try {
        final yearsStream = _academicYearService.getAcademicYears(schoolId);
        final years = await yearsStream.first;
        final activeYear = years.firstWhere((y) => y.isActive, orElse: () => years.first);
        
        setState(() {
          _academicYears = years;
          if (years.isNotEmpty) {
            _selectedAcademicYearId = activeYear.id;
          }
          _isLoadingYears = false;
        });
      } catch (e) {
        setState(() {
          _isLoadingYears = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _selectDateRange(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Theme.of(context).primaryColor,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final schoolId = context.watch<SchoolProvider>().activeSchoolId;

    if (schoolId == null) {
      return const Scaffold(
        body: Center(child: Text('Tidak ada sekolah yang aktif')),
      );
    }

    if (_isLoadingYears) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Laporan Keuangan'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Pemasukan (Lunas)'),
            Tab(text: 'Tunggakan (Piutang)'),
          ],
        ),
      ),
      body: Column(
        children: [
          _buildFilterHeader(context),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildIncomeTab(schoolId),
                _buildArrearsTab(schoolId),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterHeader(BuildContext context) {
    final dateFormat = DateFormat('dd MMM yyyy');
    return Container(
      padding: const EdgeInsets.all(16.0),
      color: Colors.grey.shade100,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Tahun Ajaran: ', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: _selectedAcademicYearId,
                  items: _academicYears.map((y) {
                    return DropdownMenuItem(
                      value: y.id,
                      child: Text(y.name + (y.isActive ? ' (Aktif)' : '')),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _selectedAcademicYearId = val;
                      });
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Periode Laporan:', style: TextStyle(color: Colors.grey, fontSize: 12)),
                    const SizedBox(height: 4),
                    Text(
                      '${dateFormat.format(_startDate)} - ${dateFormat.format(_endDate)}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _selectDateRange(context),
                icon: const Icon(Icons.date_range),
                label: const Text('Ubah'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIncomeTab(String schoolId) {
    if (_selectedAcademicYearId == null) return const Center(child: Text('Pilih Tahun Ajaran'));

    return FutureBuilder<List<Payment>>(
      future: _paymentService.getApprovedPaymentsByDateRange(schoolId, _selectedAcademicYearId!, _startDate, _endDate),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Terjadi kesalahan: ${snapshot.error}'));
        }

        final payments = snapshot.data ?? [];
        final double totalIncome = payments.fold(0, (sum, item) => sum + item.amount);

        return Column(
          children: [
            _buildSummaryCard('Total Pemasukan', totalIncome, Colors.green),
            if (payments.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      icon: const Icon(Icons.picture_as_pdf, color: Colors.red),
                      label: const Text('PDF', style: TextStyle(color: Colors.red)),
                      onPressed: () => _exportService.exportIncomePdf(context, payments, _startDate, _endDate),
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.table_chart, color: Colors.green),
                      label: const Text('Excel', style: TextStyle(color: Colors.green)),
                      onPressed: () => _exportService.exportIncomeExcel(context, payments, _startDate, _endDate),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: payments.isEmpty
                  ? const Center(child: Text('Tidak ada pemasukan di periode ini.'))
                  : ListView.builder(
                      itemCount: payments.length,
                      itemBuilder: (context, index) {
                        final p = payments[index];
                        final dateStr = p.createdAt != null ? DateFormat('dd/MM/yy HH:mm').format(p.createdAt!) : '-';
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.green.shade100,
                            child: const Icon(Icons.attach_money, color: Colors.green),
                          ),
                          title: Text(p.studentName),
                          subtitle: Text('${p.invoiceTitle}\n$dateStr'),
                          trailing: Text(
                            CurrencyUtils.formatRp(p.amount),
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                          ),
                          isThreeLine: true,
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildArrearsTab(String schoolId) {
    if (_selectedAcademicYearId == null) return const Center(child: Text('Pilih Tahun Ajaran'));

    return FutureBuilder<List<Invoice>>(
      future: _invoiceService.getArrearsByDateRange(schoolId, _selectedAcademicYearId!, _startDate, _endDate),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Terjadi kesalahan: ${snapshot.error}'));
        }

        final invoices = snapshot.data ?? [];
        final double totalArrears = invoices.fold(0, (sum, item) => sum + (item.amount - item.paidAmount));

        return Column(
          children: [
            _buildSummaryCard('Total Tunggakan', totalArrears, Colors.red),
            if (invoices.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      icon: const Icon(Icons.picture_as_pdf, color: Colors.red),
                      label: const Text('PDF', style: TextStyle(color: Colors.red)),
                      onPressed: () => _exportService.exportArrearsPdf(context, invoices, _startDate, _endDate),
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.table_chart, color: Colors.green),
                      label: const Text('Excel', style: TextStyle(color: Colors.green)),
                      onPressed: () => _exportService.exportArrearsExcel(context, invoices, _startDate, _endDate),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: invoices.isEmpty
                  ? const Center(child: Text('Tidak ada tunggakan jatuh tempo di periode ini.'))
                  : ListView.builder(
                      itemCount: invoices.length,
                      itemBuilder: (context, index) {
                        final inv = invoices[index];
                        final dueStr = inv.dueDate != null ? DateFormat('dd/MM/yy').format(inv.dueDate!) : '-';
                        final isOverdue = inv.dueDate != null && inv.dueDate!.isBefore(DateTime.now());
                        final dueColor = isOverdue ? Colors.red : Colors.grey.shade700;
                        final double sisa = inv.amount - inv.paidAmount;
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.red.shade100,
                            child: const Icon(Icons.warning, color: Colors.red),
                          ),
                          title: Text(
                            inv.studentName,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: RichText(
                            text: TextSpan(
                              style: DefaultTextStyle.of(context).style,
                              children: [
                                TextSpan(text: '${inv.title}\nJatuh Tempo: '),
                                TextSpan(
                                  text: dueStr,
                                  style: TextStyle(color: dueColor, fontWeight: isOverdue ? FontWeight.bold : null),
                                ),
                              ],
                            ),
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                CurrencyUtils.formatRp(sisa),
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
                              ),
                              Text(inv.status, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                            ],
                          ),
                          isThreeLine: true,
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSummaryCard(String title, double amount, Color color) {
    return Card(
      margin: const EdgeInsets.all(16.0),
      color: color.withOpacity(0.1),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color.withOpacity(0.5), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
            ),
            Text(
              CurrencyUtils.formatRp(amount),
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color),
            ),
          ],
        ),
      ),
    );
  }
}
