import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../core/models/fee_template.dart';
import '../../../core/providers/school_provider.dart';
import '../../../core/widgets/empty_state_widget.dart';
import '../services/fee_template_service.dart';
import '../../invoices/services/invoice_service.dart';
import '../../master_data/services/academic_year_service.dart';
import '../../../core/models/academic_year.dart';
import '../../../core/utils/snackbar_utils.dart';
import '../../../core/utils/dialog_utils.dart';
import 'fee_template_form_screen.dart';

class FeeTemplateListScreen extends StatefulWidget {
  const FeeTemplateListScreen({super.key});

  @override
  State<FeeTemplateListScreen> createState() => _FeeTemplateListScreenState();
}

class _FeeTemplateListScreenState extends State<FeeTemplateListScreen> {
  final FeeTemplateService _service = FeeTemplateService();

  @override
  Widget build(BuildContext context) {
    final schoolId = context.watch<SchoolProvider>().activeSchoolId ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('Master Tagihan')),
      body: FutureBuilder<AcademicYear?>(
        future: AcademicYearService().getActiveAcademicYear(schoolId),
        builder: (context, yearSnapshot) {
          if (yearSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final activeYear = yearSnapshot.data;
          if (activeYear == null) {
            return const Center(child: Text('Tahun Ajaran aktif belum diatur.'));
          }

          return StreamBuilder<List<FeeTemplate>>(
            stream: _service.getFeeTemplates(schoolId, activeYear.id),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }

              final templates = snapshot.data ?? [];

              if (templates.isEmpty) {
                return const EmptyStateWidget(
                  icon: Icons.account_balance_wallet_outlined,
                  title: 'Belum ada Master Tagihan',
                  subtitle: 'Tambahkan tagihan baru menggunakan tombol di bawah.',
                );
              }

              return ListView.builder(
                itemCount: templates.length,
                itemBuilder: (context, index) {
                  final template = templates[index];
                  final targetClass =
                      (template.classId != null && template.classId!.isNotEmpty)
                      ? 'Target: Kelas ${template.classId}'
                      : 'Target: Semua Kelas';

                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: ListTile(
                      title: Text(
                        template.title,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        'Nominal: ${CurrencyUtils.formatRp(template.amount)}\n$targetClass',
                      ),
                      isThreeLine: true,
                      trailing: PopupMenuButton<String>(
                        onSelected: (value) {
                          if (value == 'edit') {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    FeeTemplateFormScreen(template: template),
                              ),
                            );
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'edit',
                            child: Text('Edit Master Tagihan'),
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
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const FeeTemplateFormScreen(),
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
