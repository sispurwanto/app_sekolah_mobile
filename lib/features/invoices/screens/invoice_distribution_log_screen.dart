import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/school_provider.dart';
import '../../master_data/services/academic_year_service.dart';
import '../../../core/models/academic_year.dart';
import '../../../core/widgets/empty_state_widget.dart';
import '../services/invoice_service.dart';
import 'bulk_invoice_generation_dialog.dart';

class InvoiceDistributionLogScreen extends StatefulWidget {
  const InvoiceDistributionLogScreen({super.key});

  @override
  State<InvoiceDistributionLogScreen> createState() =>
      _InvoiceDistributionLogScreenState();
}

class _InvoiceDistributionLogScreenState
    extends State<InvoiceDistributionLogScreen> {
  final InvoiceService _invoiceService = InvoiceService();

  @override
  Widget build(BuildContext context) {
    final schoolId = context.watch<SchoolProvider>().activeSchoolId ?? '';
    return Scaffold(
      appBar: AppBar(
        title: const Text('Log Distribusi Tagihan'),
      ),
      body: schoolId.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : FutureBuilder<AcademicYear?>(
              future: AcademicYearService().getActiveAcademicYear(schoolId),
              builder: (context, yearSnapshot) {
                if (yearSnapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                final activeYear = yearSnapshot.data;
                if (activeYear == null) {
                  return const EmptyStateWidget(
                    icon: Icons.date_range,
                    title: 'Tahun Ajaran Belum Diatur',
                    subtitle: 'Harap aktifkan tahun ajaran terlebih dahulu.',
                  );
                }

                return StreamBuilder<QuerySnapshot>(
                  stream: _invoiceService.getDistributionLogs(schoolId, activeYear.id),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final logs = snapshot.data?.docs ?? [];

                if (logs.isEmpty) {
                  return const EmptyStateWidget(
                    icon: Icons.history,
                    title: 'Belum ada log distribusi',
                    subtitle:
                        'Riwayat pembuatan tagihan massal akan muncul di sini.',
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 80, top: 16),
                  itemCount: logs.length,
                  itemBuilder: (context, index) {
                    final data = logs[index].data() as Map<String, dynamic>;
                    final templateName = data['template_name'] ?? '-';
                    final targetClass = data['target_class'] ?? '-';
                    final distributedCount = data['distributed_count'] ?? 0;
                    
                    final createdAt = data['created_at'] as Timestamp?;
                    final dateStr = createdAt != null
                        ? DateFormat('dd MMM yyyy, HH:mm').format(createdAt.toDate())
                        : '-';

                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.blue.shade100,
                          child: Icon(Icons.send_to_mobile, color: Colors.blue.shade700),
                        ),
                        title: Text(
                          templateName,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text('Target: $targetClass'),
                            Text('Dikirim ke: $distributedCount Siswa'),
                            Text(
                              dateStr,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                        isThreeLine: true,
                        onTap: () {
                          // Tampilkan detail siswa yang terdistribusi
                          _showDetailDialog(context, data);
                        },
                      ),
                    );
                  },
                );
              },
            );
          },
        ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => BulkInvoiceGenerationDialog(
              onSuccess: () {
                // Not necessary to reload since we use StreamBuilder
              },
            ),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Distribusi Tagihan'),
      ),
    );
  }

  void _showDetailDialog(BuildContext context, Map<String, dynamic> logData) {
    final templateName = logData['template_name'] ?? '-';
    final dataArray = logData['data'] as List<dynamic>? ?? [];

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Detail: $templateName'),
          content: SizedBox(
            width: double.maxFinite,
            child: dataArray.isEmpty
                ? const Text('Tidak ada rincian data siswa.')
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: dataArray.length,
                    separatorBuilder: (context, index) => const Divider(),
                    itemBuilder: (context, index) {
                      final item = dataArray[index] as Map<String, dynamic>;
                      final siswa = item['siswa'] as Map<String, dynamic>? ?? {};
                      final nama = siswa['name'] ?? '-';
                      final count = item['jml_item'] ?? 0;
                      
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        leading: const Icon(Icons.person, size: 20),
                        title: Text(nama),
                        trailing: Text(
                          '$count Tagihan',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Tutup'),
            ),
          ],
        );
      },
    );
  }
}
