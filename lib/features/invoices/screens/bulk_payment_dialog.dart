import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/models/invoice.dart';
import '../../../core/models/payment.dart';
import '../../../core/providers/school_provider.dart';
import '../../../core/providers/user_provider.dart';
import '../../../core/utils/currency_utils.dart';
import '../services/payment_service.dart';
import '../../../core/utils/snackbar_utils.dart';
import '../../school_management/services/school_service.dart';
import '../../../core/models/school.dart';

class BulkPaymentDialog extends StatefulWidget {
  final List<Invoice> invoices;

  const BulkPaymentDialog({super.key, required this.invoices});

  @override
  State<BulkPaymentDialog> createState() => _BulkPaymentDialogState();
}

class _BulkPaymentDialogState extends State<BulkPaymentDialog> {
  final _noteController = TextEditingController();
  final _paymentService = PaymentService();
  bool _isLoading = false;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  void _submitPayment(String role, String schoolId) async {
    setState(() => _isLoading = true);

    final isBendahara = ['BENDAHARA', 'ADMIN', 'SUPER_ADMIN'].contains(role);
    final method = isBendahara ? 'CASH' : 'TRANSFER';
    final status = isBendahara ? 'APPROVED' : 'PENDING';

    final totalRemaining = widget.invoices.fold<double>(
      0, 
      (sum, inv) => sum + (inv.amount - inv.paidAmount)
    );

    final payment = Payment(
      id: '', // Auto ID
      invoiceId: 'MULTIPLE',
      invoiceTitle: 'Pembayaran Kolektif (${widget.invoices.length} Tagihan)',
      invoiceIds: widget.invoices.map((e) => e.id).toList(),
      invoiceTitles: widget.invoices.map((e) => e.title).toList(),
      invoiceAmounts: widget.invoices.map((e) => e.amount - e.paidAmount).toList(),
      studentId: widget.invoices.first.studentId,
      studentName: widget.invoices.first.studentName,
      classId: widget.invoices.first.classId,
      amount: totalRemaining,
      method: method,
      status: status,
      referenceNote: _noteController.text.trim(),
      schoolId: schoolId,
      academicYearId: widget.invoices.first.academicYearId,
    );

    try {
      await _paymentService.createBulkPayment(schoolId, payment, widget.invoices);
      SnackbarUtils.showSnackbar(isBendahara ? 'Pembayaran berhasil dicatat' : 'Bukti transfer berhasil dikirim. Menunggu validasi Bendahara.');
      if (mounted) Navigator.pop(context, true); // true indicates success
    } catch (e) {
      SnackbarUtils.showErrorSnackbar('Error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final schoolId = context.watch<SchoolProvider>().activeSchoolId ?? '';
    final role = context.read<UserProvider>().userMapping?.registeredSchools[schoolId] ?? 'WALI';
    final isBendahara = ['BENDAHARA', 'ADMIN', 'SUPER_ADMIN'].contains(role);
    
    final totalRemaining = widget.invoices.fold<double>(
      0, 
      (sum, inv) => sum + (inv.amount - inv.paidAmount)
    );

    return AlertDialog(
      title: Text(isBendahara ? 'Penerimaan Kasir Kolektif' : 'Konfirmasi Transfer Kolektif'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Daftar Tagihan:', style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ...widget.invoices.map((inv) => Padding(
                padding: const EdgeInsets.only(bottom: 4.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: Text('- ${inv.title}')),
                    Text(CurrencyUtils.formatRp(inv.amount - inv.paidAmount)),
                  ],
                ),
              )),
              const Divider(height: 24, thickness: 2),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total Pembayaran:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text(CurrencyUtils.formatRp(totalRemaining), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blue)),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                '*Pembayaran kolektif harus dilunasi penuh sesuai total.',
                style: TextStyle(color: Colors.red, fontSize: 12, fontStyle: FontStyle.italic),
              ),
              const SizedBox(height: 16),
              if (!isBendahara) ...[
                FutureBuilder<School?>(
                  future: SchoolService().getSchool(schoolId),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData || snapshot.data == null) return const SizedBox();
                    final school = snapshot.data!;
                    if (school.bankAccountNumber == null || school.bankAccountNumber!.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.only(bottom: 16.0),
                        child: Text('Informasi rekening sekolah belum diatur.', style: TextStyle(color: Colors.red)),
                      );
                    }
                    return Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Silakan Transfer ke:', style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text('Bank: ${school.bankName ?? "-"}'),
                          Text('No. Rekening: ${school.bankAccountNumber}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          Text('A/N: ${school.bankAccountName ?? "-"}'),
                        ],
                      ),
                    );
                  },
                ),
                TextField(
                  controller: _noteController,
                  decoration: const InputDecoration(
                    labelText: 'Nama Pengirim / Bank / No Ref',
                    helperText: 'Agar Bendahara mudah mengecek mutasi',
                  ),
                  maxLines: 2,
                ),
              ] else
                TextField(
                  controller: _noteController,
                  decoration: const InputDecoration(
                    labelText: 'Catatan Kasir (Opsional)',
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : () => _submitPayment(role, schoolId),
          child: _isLoading 
            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
            : Text(isBendahara ? 'Bayar Tunai' : 'Kirim Bukti'),
        ),
      ],
    );
  }
}
