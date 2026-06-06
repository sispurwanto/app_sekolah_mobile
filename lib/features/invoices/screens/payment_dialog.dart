import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/models/invoice.dart';
import '../../../core/models/payment.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../core/providers/school_provider.dart';
import '../../../core/providers/user_provider.dart';
import '../services/payment_service.dart';
import '../../../core/utils/snackbar_utils.dart';

class PaymentDialog extends StatefulWidget {
  final Invoice invoice;

  const PaymentDialog({super.key, required this.invoice});

  @override
  State<PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<PaymentDialog> {
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  final _paymentService = PaymentService();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final remaining = widget.invoice.amount - widget.invoice.paidAmount;
    _amountController.text = remaining.toStringAsFixed(0);
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _submitPayment(String role, String schoolId) async {
    final amountText = _amountController.text.replaceAll(RegExp(r'[^0-9]'), '');
    final amount = double.tryParse(amountText) ?? 0.0;
    
    if (amount <= 0) {
      SnackbarUtils.showErrorSnackbar('Nominal pembayaran tidak valid');
      return;
    }

    final remaining = widget.invoice.amount - widget.invoice.paidAmount;
    if (amount > remaining) {
      SnackbarUtils.showErrorSnackbar('Nominal melebihi sisa tagihan');
      return;
    }

    setState(() => _isLoading = true);

    // If role is BENDAHARA/ADMIN, method = CASH, status = APPROVED
    // If role is WALI, method = TRANSFER, status = PENDING
    final isBendahara = ['BENDAHARA', 'ADMIN', 'SUPER_ADMIN'].contains(role);
    final method = isBendahara ? 'CASH' : 'TRANSFER';
    final status = isBendahara ? 'APPROVED' : 'PENDING';

    final payment = Payment(
      id: '', // Auto ID
      invoiceId: widget.invoice.id,
      invoiceTitle: widget.invoice.title,
      studentId: widget.invoice.studentId,
      studentName: widget.invoice.studentName,
      classId: widget.invoice.classId,
      amount: amount,
      method: method,
      status: status,
      referenceNote: _noteController.text.trim(),
      schoolId: schoolId,
      academicYearId: widget.invoice.academicYearId,
    );

    try {
      await _paymentService.createPayment(schoolId, payment, widget.invoice);
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
    
    final remaining = widget.invoice.amount - widget.invoice.paidAmount;

    return AlertDialog(
      title: Text(isBendahara ? 'Penerimaan Kasir' : 'Konfirmasi Transfer'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tagihan: ${widget.invoice.title}'),
            Text('Sisa Pembayaran: ${CurrencyUtils.formatRp(remaining)}', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(
              controller: _amountController,
              decoration: const InputDecoration(
                labelText: 'Nominal Bayar (Rp)',
                helperText: 'Bisa diedit jika ingin membayar sebagian/cicilan',
                helperStyle: TextStyle(color: Colors.blue),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            if (!isBendahara)
              TextField(
                controller: _noteController,
                decoration: const InputDecoration(
                  labelText: 'Nama Pengirim / Bank / No Ref',
                  helperText: 'Agar Bendahara mudah mengecek mutasi',
                ),
                maxLines: 2,
              )
            else
              TextField(
                controller: _noteController,
                decoration: const InputDecoration(
                  labelText: 'Catatan Kasir (Opsional)',
                ),
              ),
          ],
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
