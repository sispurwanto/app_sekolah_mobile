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
import '../../../core/utils/snackbar_utils.dart';
import '../services/export_service.dart';

class FinancialReportScreen extends StatefulWidget {
  const FinancialReportScreen({Key? key}) : super(key: key);

  @override
  State<FinancialReportScreen> createState() => _FinancialReportScreenState();
}

class _FinancialReportScreenState extends State<FinancialReportScreen>
    with SingleTickerProviderStateMixin {
  final PaymentService _paymentService = PaymentService();
  final InvoiceService _invoiceService = InvoiceService();
  final AcademicYearService _academicYearService = AcademicYearService();
  final ExportService _exportService = ExportService();

  String? _selectedAcademicYearId;
  List<AcademicYear> _academicYears = [];
  bool _isLoadingYears = true;

  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();

  late TabController _tabController;
  Future<({List<Payment> payments, List<Invoice> arrears})>? _summaryFuture;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAcademicYears();
    });
  }

  Future<void> _loadAcademicYears() async {
    // School ID is needed to load years. We can get it from context via read.
    final schoolId = context.read<SchoolProvider>().activeSchoolId;
    if (schoolId == null) return;

    try {
      final yearsStream = _academicYearService.getAcademicYears(schoolId);
      final years = await yearsStream.first;
      final activeYear = years.firstWhere(
        (y) => y.isActive,
        orElse: () => years.first,
      );

      setState(() {
        _academicYears = years;
        if (years.isNotEmpty) {
          _selectedAcademicYearId = activeYear.id;
          _loadData(schoolId);
        }
        _isLoadingYears = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingYears = false;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _loadData(String schoolId) {
    if (_selectedAcademicYearId == null) return;
    setState(() {
      _summaryFuture = _invoiceService.getFinancialSummaryByDateRange(
        schoolId,
        _selectedAcademicYearId!,
        _startDate,
        _endDate,
      );
    });
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
      if (picked.end.difference(picked.start).inDays > 30) {
        SnackbarUtils.showErrorSnackbar(
          'Rentang laporan maksimal 30 hari. Silakan pilih ulang.',
        );
        return;
      }

      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      final schoolId = context.read<SchoolProvider>().activeSchoolId;
      if (schoolId != null) {
        _loadData(schoolId);
      }
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
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Laporan Pembayaran'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Pembayaran (Lunas)'),
            Tab(text: 'Tidak Bayar'),
          ],
        ),
      ),
      body: Column(
        children: [
          _buildFilterHeader(context),
          Expanded(
            child: _summaryFuture == null
                ? const Center(child: Text('Pilih Tahun Ajaran'))
                : FutureBuilder<
                    ({List<Payment> payments, List<Invoice> arrears})
                  >(
                    future: _summaryFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError) {
                        return Center(
                          child: Text('Terjadi kesalahan: ${snapshot.error}'),
                        );
                      }

                      final data = snapshot.data;
                      if (data == null) return const SizedBox.shrink();

                      return Column(
                        children: [
                          if (data.payments.isNotEmpty ||
                              data.arrears.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16.0,
                                vertical: 8.0,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  TextButton.icon(
                                    icon: const Icon(
                                      Icons.picture_as_pdf,
                                      color: Colors.blue,
                                    ),
                                    label: const Text(
                                      'Export PDF',
                                      style: TextStyle(color: Colors.blue),
                                    ),
                                    onPressed: () => _exportService
                                        .exportCombinedFinancialPdf(
                                          context,
                                          data.payments,
                                          data.arrears,
                                          _startDate,
                                          _endDate,
                                        ),
                                  ),
                                  TextButton.icon(
                                    icon: const Icon(
                                      Icons.table_chart,
                                      color: Colors.blue,
                                    ),
                                    label: const Text(
                                      'Export Excel',
                                      style: TextStyle(color: Colors.blue),
                                    ),
                                    onPressed: () => _exportService
                                        .exportCombinedFinancialExcel(
                                          context,
                                          data.payments,
                                          data.arrears,
                                          _startDate,
                                          _endDate,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          Expanded(
                            child: TabBarView(
                              controller: _tabController,
                              children: [
                                _buildIncomeTab(data.payments),
                                _buildArrearsTab(data.arrears),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
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
              const Text(
                'Tahun Ajaran: ',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
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
                      final schoolId = context
                          .read<SchoolProvider>()
                          .activeSchoolId;
                      if (schoolId != null) {
                        _loadData(schoolId);
                      }
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
                    const Text(
                      'Periode Laporan:',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${dateFormat.format(_startDate)} - ${dateFormat.format(_endDate)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
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

  Widget _buildIncomeTab(List<Payment> payments) {
    final double totalIncome = payments.fold(
      0,
      (sum, item) => sum + item.amount,
    );

    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        _buildSummaryCard(
          'Total Pembayaran',
          totalIncome,
          Colors.green,
          subtitle: 'dari ${payments.length} pembayaran',
        ),
        if (payments.isNotEmpty)
          ...payments
              .map(
                (p) => ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  title: Text(
                    p.studentName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.invoiceTitle.isNotEmpty
                              ? p.invoiceTitle
                              : 'Pembayaran',
                        ),
                        if (p.invoiceTitles != null && p.invoiceTitles!.length > 1)
                          Padding(
                            padding: const EdgeInsets.only(top: 4.0, left: 4.0, bottom: 2.0),
                            child: Text(
                              '- ${p.invoiceTitles!.join('\n- ')}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.blueGrey.shade600,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        const SizedBox(height: 4),
                        Text(
                          '${p.createdAt != null ? DateFormat('dd/MM/yy HH:mm').format(p.createdAt!) : '-'} • Penerima: ${p.approvedByName ?? '-'}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  trailing: Text(
                    CurrencyUtils.formatRp(p.amount),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ),
              )
              .toList(),
      ],
    );
  }

  Widget _buildArrearsTab(List<Invoice> arrears) {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        _buildSummaryCard(
          'Total Siswa Tidak Bayar',
          0,
          Colors.red,
          customValue: '${arrears.length} Siswa',
        ),
        if (arrears.isNotEmpty)
          ...arrears
              .map(
                (a) => ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  title: Text(
                    a.studentName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text('Belum ada pembayaran periode ini'),
                  trailing: const Text(
                    'Tidak Bayar',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                ),
              )
              .toList(),
      ],
    );
  }

  Widget _buildSummaryCard(
    String title,
    double amount,
    Color color, {
    String? customValue,
    String? subtitle,
  }) {
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
        child: Column(
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(fontSize: 14, color: color.withOpacity(0.8)),
              ),
            ],
            const SizedBox(height: 12),
            Text(
              customValue ?? CurrencyUtils.formatRp(amount),
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: color,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
