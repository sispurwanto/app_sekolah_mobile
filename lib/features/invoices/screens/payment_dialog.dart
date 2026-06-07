import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/models/invoice.dart';
import '../../../core/models/payment.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../core/providers/school_provider.dart';
import '../../../core/providers/user_provider.dart';
import '../services/payment_service.dart';
import '../../../core/utils/snackbar_utils.dart';
import '../../school_management/services/school_service.dart';
import '../../../core/models/school.dart';
import '../../../core/components/custom_dialog.dart';
import '../../../core/components/custom_text_field.dart';
import '../../../core/components/custom_button.dart';

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
      invoiceIds: [widget.invoice.id],
      invoiceTitles: [widget.invoice.title],
      invoiceAmounts: [amount],
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

    return CustomDialog(
      headerIcon: Icons.payment,
      title: isBendahara ? 'Penerimaan Kasir' : 'Konfirmasi Transfer',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50, 
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade100),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.invoice.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 4),
                Text('Sisa Tagihan: ${CurrencyUtils.formatRp(remaining)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue, fontSize: 16)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          CustomTextField(
            controller: _amountController,
            labelText: 'Nominal Bayar (Rp)',
            helperText: 'Bisa diedit jika ingin membayar sebagian/cicilan',
            keyboardType: TextInputType.number,
          ),
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
            CustomTextField(
              controller: _noteController,
              labelText: 'Nama Pengirim / Bank / No Ref',
              helperText: 'Agar Bendahara mudah mengecek mutasi',
              maxLines: 2,
            ),
          ] else
            CustomTextField(
              controller: _noteController,
              labelText: 'Catatan Kasir (Opsional)',
            ),
        ],
      ),
      actions: [
        CustomButton(
          text: 'Batal',
          onPressed: () => Navigator.pop(context),
          isSecondary: true,
        ),
        const SizedBox(width: 8),
        CustomButton(
          text: isBendahara ? 'Bayar Tunai' : 'Kirim Bukti',
          onPressed: () => _submitPayment(role, schoolId),
          isLoading: _isLoading,
        ),
      ],
    );
  }
}
