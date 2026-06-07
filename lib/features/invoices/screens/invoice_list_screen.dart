import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/models/invoice.dart';
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

class _InvoiceListScreenState extends State<InvoiceListScreen> {
  final InvoiceService _invoiceService = InvoiceService();
  final Set<String> _selectedInvoiceIds = {};
  final List<Invoice> _selectedInvoices = [];

  void _toggleSelection(Invoice invoice) {
    setState(() {
      if (_selectedInvoiceIds.contains(invoice.id)) {
        _selectedInvoiceIds.remove(invoice.id);
        _selectedInvoices.removeWhere((i) => i.id == invoice.id);
      } else {
        // Enforce same student selection
        if (_selectedInvoices.isNotEmpty && _selectedInvoices.first.studentId != invoice.studentId) {
          SnackbarUtils.showErrorSnackbar('Pembayaran kolektif hanya bisa untuk tagihan dari siswa yang sama');
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
    final role = context.read<UserProvider>().userMapping?.registeredSchools[schoolId] ?? 'WALI';
    
    // BENDAHARA, ADMIN, SUPER_ADMIN can add and edit invoices
    final canManageInvoices = ['BENDAHARA', 'ADMIN', 'SUPER_ADMIN'].contains(role);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.studentId != null ? 'Tagihan Siswa' : 'Daftar Semua Tagihan'),
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
            return const Center(child: Text('Tahun Ajaran Aktif tidak ditemukan.'));
          }

          // If showing for specific student, make sure class is provided
          if (widget.studentId != null && (widget.classId == null || widget.classId!.isEmpty)) {
            return const Center(child: Text('Data Kelas Siswa tidak lengkap untuk mengambil tagihan.'));
          }

          return StreamBuilder<List<Invoice>>(
            stream: widget.studentId != null 
                ? _invoiceService.getStudentInvoices(schoolId, yearIdToUse, widget.classId!, widget.studentId!)
                : _invoiceService.getAllInvoices(schoolId, yearIdToUse),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }

              final invoices = snapshot.data ?? [];

              if (invoices.isEmpty) {
                return const Center(child: Text('Belum ada data tagihan.'));
              }

              return ListView.builder(
                itemCount: invoices.length,
                itemBuilder: (context, index) {
                  final invoice = invoices[index];
                  final isSelected = _selectedInvoiceIds.contains(invoice.id);
                  final isSelectable = invoice.status != 'PAID';

                  return Card(
                    color: isSelected ? Colors.blue.shade50 : null,
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: ListTile(
                      leading: isSelectable 
                          ? Checkbox(
                              value: isSelected,
                              onChanged: (val) {
                                _toggleSelection(invoice);
                              },
                            )
                          : const Icon(Icons.check_circle, color: Colors.green),
                      title: Text(invoice.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: RichText(
                        text: TextSpan(
                          style: DefaultTextStyle.of(context).style.copyWith(height: 1.5),
                          children: [
                            TextSpan(text: 'Siswa: ${invoice.studentName}\nTotal: ${CurrencyUtils.formatRp(invoice.amount)} | Dibayar: ${CurrencyUtils.formatRp(invoice.paidAmount)}\nStatus: '),
                            TextSpan(
                              text: invoice.status,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: invoice.status == 'PAID' ? Colors.green : (invoice.status == 'UNPAID' ? Colors.red : Colors.orange),
                              ),
                            ),
                          ],
                        ),
                      ),
                      isThreeLine: true,
                      onTap: isSelectable ? () => _toggleSelection(invoice) : null,
                      trailing: PopupMenuButton<String>(
                        onSelected: (value) {
                          if (value == 'edit') {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => InvoiceFormScreen(invoice: invoice)),
                            );
                          } else if (value == 'pay') {
                            showDialog(
                              context: context,
                              builder: (context) => PaymentDialog(invoice: invoice),
                            );
                          } else if (value == 'view_payments') {
                            showDialog(
                              context: context,
                              builder: (context) => PaymentHistoryDialog(invoice: invoice),
                            );
                          }
                        },
                        itemBuilder: (context) => [
                          if (invoice.status != 'PAID' && _selectedInvoiceIds.isEmpty)
                            PopupMenuItem(
                              value: 'pay',
                              child: Text(canManageInvoices ? 'Terima Pembayaran' : 'Bayar via Transfer'),
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
            },
          );
        }
      ),
      floatingActionButton: _selectedInvoiceIds.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: () async {
                final success = await showDialog<bool>(
                  context: context,
                  builder: (context) => BulkPaymentDialog(invoices: _selectedInvoices),
                );
                if (success == true) {
                  _clearSelection();
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
                        builder: (context) => InvoiceFormScreen(
                          studentId: widget.studentId,
                        ),
                      ),
                    );
                  },
                  child: const Icon(Icons.add),
                )
              : null),
    );
  }
}
