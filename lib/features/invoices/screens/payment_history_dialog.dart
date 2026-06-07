import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../core/models/payment.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../core/models/invoice.dart';
import '../../../core/providers/school_provider.dart';
import '../services/payment_service.dart';
import '../../../core/components/custom_dialog.dart';
import '../../../core/components/custom_button.dart';

class PaymentHistoryDialog extends StatelessWidget {
  final Invoice invoice;

  const PaymentHistoryDialog({super.key, required this.invoice});

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: Colors.grey),
        const SizedBox(width: 4),
        Expanded(
          child: Text('$label: $value', style: const TextStyle(color: Colors.black87, fontSize: 13)),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final schoolId = context.watch<SchoolProvider>().activeSchoolId ?? '';
    final paymentService = PaymentService();

    return CustomDialog(
      headerIcon: Icons.history,
      title: 'Riwayat Pembayaran',
      content: SizedBox(
        height: 400,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
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

                      final isBulk = payment.invoiceIds != null && payment.invoiceIds!.length > 1;
                      final titles = payment.invoiceTitles ?? [];
                      final amounts = payment.invoiceAmounts ?? [];

                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    CurrencyUtils.formatRp(payment.amount),
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: statusColor.withAlpha((255 * 0.1).toInt()),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: statusColor),
                                    ),
                                    child: Text(
                                      payment.status,
                                      style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12),
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(height: 16),
                              _buildDetailRow(Icons.payment, 'Metode', payment.method),
                              const SizedBox(height: 4),
                              _buildDetailRow(Icons.calendar_today, 'Tanggal', dateStr),
                              if (payment.referenceNote.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                _buildDetailRow(Icons.note, 'Catatan', payment.referenceNote),
                              ],
                              if (isBulk) ...[
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade50,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: Colors.blue.shade200),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Row(
                                        children: [
                                          Icon(Icons.collections_bookmark, size: 14, color: Colors.blue),
                                          SizedBox(width: 4),
                                          Text('Rincian Kolektif:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue, fontSize: 13)),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      ...List.generate(titles.length, (i) {
                                        return Padding(
                                          padding: const EdgeInsets.only(bottom: 4),
                                          child: Row(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const Text('• ', style: TextStyle(color: Colors.blue)),
                                              Expanded(
                                                child: Text(
                                                  '${titles[i]} ${i < amounts.length ? "(${CurrencyUtils.formatRp(amounts[i])})" : ""}',
                                                  style: const TextStyle(fontSize: 12, color: Colors.black87),
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      }),
                                    ],
                                  ),
                                ),
                              ]
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        CustomButton(
          text: 'Tutup',
          onPressed: () => Navigator.pop(context),
          isSecondary: true,
        ),
      ],
    );
  }
}
