import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../core/models/fee_template.dart';
import '../../../core/providers/school_provider.dart';
import '../services/fee_template_service.dart';
import '../../invoices/services/invoice_service.dart';
import '../../master_data/services/academic_year_service.dart';
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
  bool _isGenerating = false;

  Future<void> _handleBulkGenerate(BuildContext context, String schoolId, FeeTemplate template) async {
    final activeYear = await AcademicYearService().getActiveAcademicYear(schoolId);
    if (activeYear == null) {
      SnackbarUtils.showErrorSnackbar('Tidak ada Tahun Ajaran aktif.');
      return;
    }

    final targetMsg = (template.classId != null && template.classId!.isNotEmpty)
        ? 'kelas ${template.classId}'
        : 'SEMUA KELAS';

    final confirm = await DialogUtils.showConfirmationDialog(
      title: 'Generate Tagihan Massal',
      content: 'Generate tagihan "${template.title}" untuk siswa di $targetMsg pada tahun ajaran ${activeYear.name}?\n\nIni mungkin membutuhkan waktu beberapa saat.',
      confirmText: 'Generate',
    );

    if (confirm == true) {
      setState(() => _isGenerating = true);
      try {
        await InvoiceService().generateInvoicesForTemplate(
          schoolId: schoolId,
          academicYearId: activeYear.id,
          template: template,
        );
        SnackbarUtils.showSnackbar('Tagihan massal berhasil di-generate!');
      } catch (e) {
        SnackbarUtils.showErrorSnackbar('Gagal: $e');
      } finally {
        if (mounted) setState(() => _isGenerating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final schoolId = context.watch<SchoolProvider>().activeSchoolId ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Master Tagihan'),
      ),
      body: StreamBuilder<List<FeeTemplate>>(
        stream: _service.getFeeTemplates(schoolId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final templates = snapshot.data ?? [];

          if (templates.isEmpty) {
            return const Center(child: Text('Belum ada data Master Tagihan.'));
          }

          return ListView.builder(
            itemCount: templates.length,
            itemBuilder: (context, index) {
              final template = templates[index];
              final targetClass = (template.classId != null && template.classId!.isNotEmpty)
                  ? 'Target: Kelas ${template.classId}'
                  : 'Target: Semua Kelas';

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  title: Text(template.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('Nominal: ${CurrencyUtils.formatRp(template.amount)}\n$targetClass'),
                  isThreeLine: true,
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'edit') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => FeeTemplateFormScreen(template: template),
                          ),
                        );
                      } else if (value == 'generate') {
                        _handleBulkGenerate(context, schoolId, template);
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Text('Edit Master Tagihan'),
                      ),
                      const PopupMenuItem(
                        value: 'generate',
                        child: Text('Generate Tagihan Massal'),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      bottomNavigationBar: _isGenerating
          ? const LinearProgressIndicator()
          : null,
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
