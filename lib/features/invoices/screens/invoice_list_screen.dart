import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/models/invoice.dart';
import 'package:intl/intl.dart';
import '../../../core/providers/school_provider.dart';
import '../../../core/providers/user_provider.dart';
import '../../../core/utils/currency_utils.dart';
import '../services/invoice_service.dart';
import '../../master_data/services/academic_year_service.dart';
import '../../../core/models/academic_year.dart';
import 'invoice_form_screen.dart';
import 'payment_dialog.dart';
import 'payment_history_dialog.dart';
import 'bulk_payment_dialog.dart';
import '../../../core/utils/snackbar_utils.dart';
import '../../../core/widgets/empty_state_widget.dart';

class InvoiceListScreen extends StatefulWidget {
  final String? studentId;
  final String? academicYearId;
  final String? classId;

  const InvoiceListScreen({
    super.key,
    this.studentId,
    this.academicYearId,
    this.classId,
  });

  @override
  State<InvoiceListScreen> createState() => _InvoiceListScreenState();
}

class _InvoiceListScreenState extends State<InvoiceListScreen>
    with SingleTickerProviderStateMixin {
  final InvoiceService _invoiceService = InvoiceService();
  late TabController _tabController;
  final Set<String> _selectedInvoiceIds = {};
  final List<Invoice> _selectedInvoices = [];
  String _filterStatus = 'SEMUA'; // SEMUA, BELUM LUNAS, LUNAS
  Future<List<Invoice>>? _invoicesFuture;
  String _currentSchoolId = '';
  String _currentYearId = '';

  Future<List<Invoice>>? _unpaidFuture;
  Future<List<Invoice>>? _paidFuture;
  bool _showAllUnpaid = false;
  bool _showAllPaid = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.index == 1 &&
          _paidFuture == null &&
          widget.studentId != null) {
        _loadPaid();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // We will initialize _invoicesFuture after AcademicYear is loaded.
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _loadUnpaid() {
    setState(() {
      _unpaidFuture = _invoiceService.fetchStudentInvoicesPaginated(
        _currentSchoolId,
        _currentYearId,
        widget.classId!,
        widget.studentId!,
        isPaid: false,
        limitCount: _showAllUnpaid ? null : 2,
      );
    });
  }

  void _loadPaid() {
    setState(() {
      _paidFuture = _invoiceService.fetchStudentInvoicesPaginated(
        _currentSchoolId,
        _currentYearId,
        widget.classId!,
        widget.studentId!,
        isPaid: true,
        limitCount: _showAllPaid ? null : 2,
      );
    });
  }

  void _loadInvoices(String schoolId, String yearIdToUse) {
    setState(() {
      _currentSchoolId = schoolId;
      _currentYearId = yearIdToUse;
      if (widget.studentId != null) {
        _loadUnpaid();
        if (_tabController.index == 1 || _paidFuture != null) {
          _loadPaid();
        }
      } else {
        _invoicesFuture = _invoiceService.fetchAllInvoices(
          schoolId,
          yearIdToUse,
        );
      }
    });
  }

  void _toggleSelection(Invoice invoice) {
    setState(() {
      if (_selectedInvoiceIds.contains(invoice.id)) {
        _selectedInvoiceIds.remove(invoice.id);
        _selectedInvoices.removeWhere((i) => i.id == invoice.id);
      } else {
        // Enforce same student selection
        if (_selectedInvoices.isNotEmpty &&
            _selectedInvoices.first.studentId != invoice.studentId) {
          SnackbarUtils.showErrorSnackbar(
            'Pembayaran kolektif hanya bisa untuk tagihan dari siswa yang sama',
          );
          return;
        }
        _selectedInvoiceIds.add(invoice.id);
        _selectedInvoices.add(invoice);
      }
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedInvoiceIds.clear();
      _selectedInvoices.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final schoolId = context.watch<SchoolProvider>().activeSchoolId ?? '';
    final role =
        context.read<UserProvider>().userMapping?.registeredSchools[schoolId] ??
        'WALI';

    // BENDAHARA, ADMIN, SUPER_ADMIN can add and edit invoices
    final canManageInvoices = [
      'BENDAHARA',
      'ADMIN',
      'SUPER_ADMIN',
    ].contains(role);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.studentId != null ? 'Tagihan Siswa' : 'Daftar Semua Tagihan',
        ),
        bottom: widget.studentId != null
            ? TabBar(
                controller: _tabController,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                indicatorColor: Colors.white,
                tabs: const [
                  Tab(text: 'Belum Lunas'),
                  Tab(text: 'Lunas'),
                ],
              )
            : null,
        actions: [
          if (_selectedInvoiceIds.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: _clearSelection,
              tooltip: 'Batal Pilih',
            ),
        ],
      ),
      body: FutureBuilder<AcademicYear?>(
        future: AcademicYearService().getActiveAcademicYear(schoolId),
        builder: (context, yearSnapshot) {
          if (yearSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final activeYear = yearSnapshot.data;

          final yearIdToUse = widget.academicYearId ?? activeYear?.id;

          if (yearIdToUse == null || yearIdToUse.isEmpty) {
            return const Center(
              child: Text('Tahun Ajaran Aktif tidak ditemukan.'),
            );
          }

          // If showing for specific student, make sure class is provided
          if (widget.studentId != null &&
              (widget.classId == null || widget.classId!.isEmpty)) {
            return const Center(
              child: Text(
                'Data Kelas Siswa tidak lengkap untuk mengambil tagihan.',
              ),
            );
          }

          if (widget.studentId != null) {
            if (_unpaidFuture == null || _currentYearId != yearIdToUse) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _loadInvoices(schoolId, yearIdToUse);
              });
              return const Center(child: CircularProgressIndicator());
            }

            return TabBarView(
              controller: _tabController,
              children: [
                _buildTabContent(
                  future: _unpaidFuture!,
                  showAll: _showAllUnpaid,
                  onShowAll: () {
                    setState(() {
                      _showAllUnpaid = true;
                      _loadUnpaid();
                    });
                  },
                  canManageInvoices: canManageInvoices,
                  schoolId: schoolId,
                  yearIdToUse: yearIdToUse,
                ),
                _paidFuture == null
                    ? const Center(child: CircularProgressIndicator())
                    : _buildTabContent(
                        future: _paidFuture!,
                        showAll: _showAllPaid,
                        onShowAll: () {
                          setState(() {
                            _showAllPaid = true;
                            _loadPaid();
                          });
                        },
                        canManageInvoices: canManageInvoices,
                        schoolId: schoolId,
                        yearIdToUse: yearIdToUse,
                      ),
              ],
            );
          }

          if (_invoicesFuture == null || _currentYearId != yearIdToUse) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _loadInvoices(schoolId, yearIdToUse);
            });
            return const Center(child: CircularProgressIndicator());
          }

          return RefreshIndicator(
            onRefresh: () async {
              _loadInvoices(schoolId, yearIdToUse);
              await _invoicesFuture;
            },
            child: FutureBuilder<List<Invoice>>(
              future: _invoicesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final invoices = snapshot.data ?? [];

                var filteredInvoices = invoices;
                if (_filterStatus == 'BELUM LUNAS') {
                  filteredInvoices = invoices
                      .where((i) => i.status != 'PAID')
                      .toList();
                } else if (_filterStatus == 'LUNAS') {
                  filteredInvoices = invoices
                      .where((i) => i.status == 'PAID')
                      .toList();
                }

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(value: 'SEMUA', label: Text('Semua')),
                          ButtonSegment(
                            value: 'BELUM LUNAS',
                            label: Text('Tunggakan'),
                          ),
                          ButtonSegment(value: 'LUNAS', label: Text('Lunas')),
                        ],
                        selected: {_filterStatus},
                        onSelectionChanged: (Set<String> newSelection) {
                          setState(() {
                            _filterStatus = newSelection.first;
                            _clearSelection(); // Clear selection when filter changes
                          });
                        },
                      ),
                    ),
                    if (filteredInvoices.isEmpty)
                      const Expanded(
                        child: EmptyStateWidget(
                          icon: Icons.receipt_long,
                          title: 'Tidak ada tagihan',
                          subtitle:
                              'Tidak ada tagihan yang sesuai dengan filter ini.',
                        ),
                      )
                    else
                      Expanded(
                        child: _buildInvoiceList(
                          filteredInvoices,
                          canManageInvoices,
                        ),
                      ),
                  ],
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: _selectedInvoiceIds.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: () async {
                final success = await showDialog<bool>(
                  context: context,
                  builder: (context) =>
                      BulkPaymentDialog(invoices: _selectedInvoices),
                );
                if (success == true) {
                  _clearSelection();
                  if (widget.studentId != null) {
                    _loadUnpaid();
                    _loadPaid();
                  } else {
                    _loadInvoices(_currentSchoolId, _currentYearId);
                  }
                }
              },
              icon: const Icon(Icons.payment),
              label: Text('Bayar Terpilih (${_selectedInvoiceIds.length})'),
            )
          : (canManageInvoices
                ? FloatingActionButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              InvoiceFormScreen(studentId: widget.studentId),
                        ),
                      ).then((_) {
                        if (widget.studentId != null) {
                          _loadUnpaid();
                        } else {
                          _loadInvoices(_currentSchoolId, _currentYearId);
                        }
                      });
                    },
                    child: const Icon(Icons.add),
                  )
                : null),
    );
  }

  Widget _buildTabContent({
    required Future<List<Invoice>> future,
    required bool showAll,
    required VoidCallback onShowAll,
    required bool canManageInvoices,
    required String schoolId,
    required String yearIdToUse,
  }) {
    return RefreshIndicator(
      onRefresh: () async {
        _loadInvoices(schoolId, yearIdToUse);
        await future;
      },
      child: FutureBuilder<List<Invoice>>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final invoices = snapshot.data ?? [];

          return Column(
            children: [
              Expanded(
                child: invoices.isEmpty
                    ? const EmptyStateWidget(
                        icon: Icons.receipt_long,
                        title: 'Tidak ada tagihan',
                      )
                    : _buildInvoiceList(invoices, canManageInvoices),
              ),
              if (!showAll && invoices.length == 2)
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: TextButton(
                    onPressed: onShowAll,
                    child: const Text('Lihat Semua'),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildInvoiceList(List<Invoice> invoices, bool canManageInvoices) {
    return ListView.builder(
      itemCount: invoices.length,
      itemBuilder: (context, index) {
        final invoice = invoices[index];
        final isSelected = _selectedInvoiceIds.contains(invoice.id);
        final isSelectable = invoice.status != 'PAID';
        final dueStr = invoice.dueDate != null
            ? DateFormat('dd/MM/yy').format(invoice.dueDate!)
            : '-';
        final isOverdue =
            invoice.dueDate != null &&
            invoice.dueDate!.isBefore(DateTime.now());
        final dueColor = isOverdue && invoice.status != 'PAID'
            ? Colors.red
            : null;

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? Colors.blue.shade50 : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? Colors.blue.shade300 : Colors.grey.shade200,
              width: isSelected ? 1.5 : 1.0,
            ),
            boxShadow: [
              if (!isSelected)
                BoxShadow(
                  color: Colors.black.withAlpha(10),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
            ],
          ),
          child: ListTile(
            leading: isSelectable
                ? Checkbox(
                    value: isSelected,
                    onChanged: (val) {
                      _toggleSelection(invoice);
                    },
                  )
                : const Icon(Icons.check_circle, color: Colors.green),
            title: Text(
              invoice.title,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.person, size: 16, color: Colors.grey.shade600),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          invoice.studentName,
                          style: TextStyle(
                            color: Colors.grey.shade800,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Total Tagihan',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              CurrencyUtils.formatRp(invoice.amount),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        height: 30,
                        width: 1,
                        color: Colors.grey.shade300,
                        margin: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Telah Dibayar',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              CurrencyUtils.formatRp(invoice.paidAmount),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: invoice.status == 'PAID'
                              ? Colors.green.shade50
                              : (invoice.status == 'UNPAID'
                                  ? Colors.red.shade50
                                  : Colors.orange.shade50),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: invoice.status == 'PAID'
                                ? Colors.green.shade200
                                : (invoice.status == 'UNPAID'
                                    ? Colors.red.shade200
                                    : Colors.orange.shade200),
                          ),
                        ),
                        child: Text(
                          invoice.status,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: invoice.status == 'PAID'
                                ? Colors.green.shade700
                                : (invoice.status == 'UNPAID'
                                    ? Colors.red.shade700
                                    : Colors.orange.shade700),
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          Icon(
                            Icons.calendar_today,
                            size: 14,
                            color: dueColor ?? Colors.grey.shade600,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            dueStr,
                            style: TextStyle(
                              fontSize: 12,
                              color: dueColor ?? Colors.grey.shade700,
                              fontWeight: isOverdue && invoice.status != 'PAID'
                                  ? FontWeight.bold
                                  : null,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            onTap: isSelectable ? () => _toggleSelection(invoice) : null,
            trailing: PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'edit') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => InvoiceFormScreen(invoice: invoice),
                    ),
                  ).then(
                    (_) => _loadInvoices(_currentSchoolId, _currentYearId),
                  );
                } else if (value == 'pay') {
                  showDialog(
                    context: context,
                    builder: (context) => PaymentDialog(invoice: invoice),
                  ).then(
                    (_) => _loadInvoices(_currentSchoolId, _currentYearId),
                  );
                } else if (value == 'view_payments') {
                  showDialog(
                    context: context,
                    builder: (context) =>
                        PaymentHistoryDialog(invoice: invoice),
                  );
                }
              },
              itemBuilder: (context) => [
                if (invoice.status != 'PAID' && _selectedInvoiceIds.isEmpty)
                  PopupMenuItem(
                    value: 'pay',
                    child: Text(
                      canManageInvoices
                          ? 'Terima Pembayaran'
                          : 'Bayar via Transfer',
                    ),
                  ),
                if (invoice.paidAmount > 0)
                  const PopupMenuItem(
                    value: 'view_payments',
                    child: Text('Riwayat Pembayaran'),
                  ),
                if (canManageInvoices && invoice.status != 'PAID')
                  const PopupMenuItem(
                    value: 'edit',
                    child: Text('Edit Tagihan'),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
