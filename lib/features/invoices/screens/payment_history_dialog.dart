import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../core/models/payment.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../core/models/invoice.dart';
import '../../../core/providers/school_provider.dart';
import '../services/payment_service.dart';

class PaymentHistoryDialog extends StatelessWidget {
  final Invoice invoice;

  const PaymentHistoryDialog({super.key, required this.invoice});

  @override
  Widget build(BuildContext context) {
    final schoolId = context.watch<SchoolProvider>().activeSchoolId ?? '';
    final paymentService = PaymentService();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.all(16),
        constraints: const BoxConstraints(maxHeight: 500, maxWidth: 400),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Riwayat Pembayaran',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              invoice.title,
              style: const TextStyle(color: Colors.grey),
            ),
            const Divider(),
            Expanded(
              child: StreamBuilder<List<Payment>>(
                stream: paymentService.getPaymentsForInvoice(schoolId, invoice.academicYearId, invoice.id),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }

                  final payments = snapshot.data ?? [];

                  if (payments.isEmpty) {
                    return const Center(child: Text('Belum ada data pembayaran.'));
                  }

                  return ListView.builder(
                    itemCount: payments.length,
                    itemBuilder: (context, index) {
                      final payment = payments[index];
                      final dateStr = payment.createdAt != null
                          ? DateFormat('dd MMM yyyy HH:mm').format(payment.createdAt!)
                          : '-';

                      Color statusColor;
                      switch (payment.status) {
                        case 'APPROVED':
                          statusColor = Colors.green;
                          break;
                        case 'REJECTED':
                          statusColor = Colors.red;
                          break;
                        case 'PENDING':
                          statusColor = Colors.orange;
                          break;
                        default:
                          statusColor = Colors.grey;
                      }

                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        child: ListTile(
                          title: Text(CurrencyUtils.formatRp(payment.amount)),
                          subtitle: Text(
                            'Metode: ${payment.method}\nCatatan: ${payment.referenceNote.isEmpty ? "-" : payment.referenceNote}\nTanggal: $dateStr',
                          ),
                          isThreeLine: true,
                          trailing: Text(
                            payment.status,
                            style: TextStyle(
                              color: statusColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Tutup'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
