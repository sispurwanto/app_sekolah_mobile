import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/models/payment.dart';
import '../../../core/models/invoice.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../core/providers/school_provider.dart';
import '../../../core/providers/user_provider.dart';
import '../services/payment_service.dart';
import '../../../core/widgets/empty_state_widget.dart';
import '../services/invoice_service.dart';
import '../../master_data/services/academic_year_service.dart';
import '../../../core/utils/snackbar_utils.dart';
import '../../../core/utils/dialog_utils.dart';

class PaymentValidationScreen extends StatefulWidget {
  const PaymentValidationScreen({super.key});

  @override
  State<PaymentValidationScreen> createState() =>
      _PaymentValidationScreenState();
}

class _PaymentValidationScreenState extends State<PaymentValidationScreen> {
  final _paymentService = PaymentService();
  final _invoiceService = InvoiceService();

  Future<void> _handleAction(
    BuildContext context,
    String schoolId,
    Payment payment,
    bool isApprove,
  ) async {
    final approverName = context.read<UserProvider>().userMapping?.name ?? 'Admin';

    final confirm = await DialogUtils.showConfirmationDialog(
      title: isApprove ? 'Setujui Pembayaran' : 'Tolak Pembayaran',
      content: isApprove
          ? 'Anda yakin uang sudah masuk ke rekening untuk tagihan ${payment.invoiceTitle} sebesar ${CurrencyUtils.formatRp(payment.amount)}?\n\nMetode: ${payment.method}\nReferensi: ${payment.referenceNote.isEmpty ? "-" : payment.referenceNote}'
          : 'Yakin ingin menolak pembayaran ini?',
      confirmText: isApprove ? 'Setujui' : 'Tolak',
      isDestructive: !isApprove,
    );

    if (confirm != true) return;

    try {
      if (isApprove) {
        // We need the Invoice object to approve. Since we don't store the whole object in Payment,
        // we can fetch it first or we could construct a dummy one just with IDs.
        // Wait, PaymentService needs the Invoice to know its current paidAmount.
        // Let's fetch it from InvoiceService.
        // Wait, we don't have a direct `getInvoiceById` in InvoiceService.
        // We will fetch it manually here or add a method.
        // For simplicity, let's just do a direct Firebase call or add `getInvoice` to `InvoiceService`.
        // Actually, Payment has classId, studentId, invoiceId, academicYearId.
        
        if (payment.invoiceIds != null && payment.invoiceIds!.isNotEmpty) {
          // Bulk Payment: No need to fetch single invoice, PaymentService handles it
          await _paymentService.approvePayment(schoolId, payment, null, approverName);
          SnackbarUtils.showSnackbar('Pembayaran disetujui');
        } else {
          // Single Payment
          final invoiceDoc = await FirebaseFirestore.instance
              .collection('schools')
              .doc(schoolId)
              .collection('transactions_year')
              .doc(payment.academicYearId)
              .collection('invoices')
              .doc(payment.studentId)
              .collection('invoice_data')
              .doc(payment.invoiceId)
              .get();

          if (!invoiceDoc.exists) {
            SnackbarUtils.showErrorSnackbar(
              'Data tagihan asli tidak ditemukan.',
            );
            return;
          }

          final invoice = Invoice.fromFirestore(invoiceDoc);
          await _paymentService.approvePayment(schoolId, payment, invoice, approverName);
          SnackbarUtils.showSnackbar('Pembayaran disetujui');
        }
      } else {
        await _paymentService.rejectPayment(schoolId, payment);
        SnackbarUtils.showSnackbar('Pembayaran ditolak');
      }
    } catch (e) {
      SnackbarUtils.showErrorSnackbar('Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final schoolId = context.watch<SchoolProvider>().activeSchoolId ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('Validasi Transfer Wali')),
      body: FutureBuilder(
        future: AcademicYearService().getActiveAcademicYear(schoolId),
        builder: (context, yearSnapshot) {
          if (yearSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final activeYear = yearSnapshot.data;
          if (activeYear == null)
            return const Center(
              child: Text('Tahun Ajaran Aktif tidak ditemukan.'),
            );

          return StreamBuilder<List<Payment>>(
            stream: _paymentService.getPendingPayments(schoolId, activeYear.id),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final payments = snapshot.data ?? [];
              if (payments.isEmpty) {
                return const EmptyStateWidget(
                  icon: Icons.check_circle_outline,
                  title: 'Semua Lunas',
                  subtitle: 'Tidak ada pembayaran tertunda.',
                );
              }

              return ListView.builder(
                itemCount: payments.length,
                itemBuilder: (context, index) {
                  final payment = payments[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: ListTile(
                      title: Text(
                        '${payment.studentName} - ${payment.invoiceTitle}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: RichText(
                        text: TextSpan(
                          style: DefaultTextStyle.of(
                            context,
                          ).style.copyWith(height: 1.5),
                          children: [
                            if (payment.invoiceTitles != null &&
                                payment.invoiceTitles!.isNotEmpty)
                              TextSpan(
                                text:
                                    'Rincian: ${payment.invoiceTitles!.join(", ")}\n',
                                style: const TextStyle(
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            TextSpan(
                              text:
                                  'Nominal: ${CurrencyUtils.formatRp(payment.amount)}\nMetode: ${payment.method} | ',
                            ),
                            const TextSpan(
                              text: 'Catatan: ',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            TextSpan(
                              text: payment.referenceNote.isEmpty
                                  ? "-"
                                  : payment.referenceNote,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                          ],
                        ),
                      ),
                      isThreeLine: true,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.red),
                            onPressed: () => _handleAction(
                              context,
                              schoolId,
                              payment,
                              false,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.check, color: Colors.green),
                            onPressed: () =>
                                _handleAction(context, schoolId, payment, true),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
