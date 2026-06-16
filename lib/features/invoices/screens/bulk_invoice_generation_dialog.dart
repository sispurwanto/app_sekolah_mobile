import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/school_provider.dart';
import '../../../core/utils/snackbar_utils.dart';
import '../../../core/utils/dialog_utils.dart';
import '../../../core/models/fee_template.dart';
import '../../master_data/services/fee_template_service.dart';
import '../../master_data/services/academic_year_service.dart';
import '../services/invoice_service.dart';

class BulkInvoiceGenerationDialog extends StatefulWidget {
  final VoidCallback onSuccess;
  const BulkInvoiceGenerationDialog({super.key, required this.onSuccess});

  @override
  State<BulkInvoiceGenerationDialog> createState() =>
      _BulkInvoiceGenerationDialogState();
}

class _BulkInvoiceGenerationDialogState
    extends State<BulkInvoiceGenerationDialog> {
  final FeeTemplateService _feeTemplateService = FeeTemplateService();
  String? _selectedTemplateId;
  FeeTemplate? _selectedTemplate;
  bool _isGenerating = false;

  Future<void> _handleGenerate() async {
    if (_selectedTemplate == null) return;

    final schoolId = context.read<SchoolProvider>().activeSchoolId!;
    final activeYear = await AcademicYearService().getActiveAcademicYear(
      schoolId,
    );

    if (activeYear == null) {
      SnackbarUtils.showErrorSnackbar('Tidak ada Tahun Ajaran aktif.');
      return;
    }

    final targetMsg = (_selectedTemplate!.classId != null &&
            _selectedTemplate!.classId!.isNotEmpty)
        ? 'kelas ${_selectedTemplate!.classId}'
        : 'SEMUA KELAS';

    final confirm = await DialogUtils.showConfirmationDialog(
      title: 'Konfirmasi Penerbitan',
      content:
          'Terbitkan tagihan "${_selectedTemplate!.title}" untuk siswa di $targetMsg pada tahun ajaran ${activeYear.name}?\n\nTagihan yang sudah ada untuk siswa yang sama tidak akan tertimpa.',
      confirmText: 'Terbitkan',
    );

    if (confirm == true) {
      setState(() => _isGenerating = true);
      try {
        final generatedCount = await InvoiceService().generateInvoicesForTemplate(
          schoolId: schoolId,
          academicYearId: activeYear.id,
          template: _selectedTemplate!,
        );

        if (generatedCount > 0) {
          SnackbarUtils.showSnackbar('Tagihan massal berhasil diterbitkan ke $generatedCount siswa!');
        } else {
          SnackbarUtils.showErrorSnackbar('Gagal menerbitkan: Semua siswa sudah memiliki tagihan ini!');
        }

        if (mounted) {
          Navigator.pop(context);
          widget.onSuccess();
        }
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

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.library_add_check, color: Colors.green),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Terbitkan Tagihan Massal',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Pilih Master Tagihan yang ingin diterbitkan ke seluruh siswa terkait:',
              style: TextStyle(fontSize: 14, color: Colors.black87),
            ),
            const SizedBox(height: 16),
            StreamBuilder<List<FeeTemplate>>(
              stream: _feeTemplateService.getFeeTemplates(schoolId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError || !snapshot.hasData) {
                  return const Text('Gagal memuat Master Tagihan');
                }

                final templates = snapshot.data!;
                if (templates.isEmpty) {
                  return const Text('Belum ada Master Tagihan yang dibuat.');
                }

                return DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'Pilih Master Tagihan',
                    border: OutlineInputBorder(),
                  ),
                  value: _selectedTemplateId,
                  isExpanded: true,
                  items: templates.map((template) {
                    final target = (template.classId != null &&
                            template.classId!.isNotEmpty)
                        ? 'Khusus Kelas ${template.classId}'
                        : 'Semua Kelas';
                    return DropdownMenuItem<String>(
                      value: template.id,
                      child: Text('${template.title} ($target)'),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedTemplateId = val;
                      _selectedTemplate = templates.firstWhere((t) => t.id == val);
                    });
                  },
                );
              },
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isGenerating || _selectedTemplate == null
                    ? null
                    : _handleGenerate,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isGenerating
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Terbitkan Sekarang',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
