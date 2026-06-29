import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../../../../core/providers/school_provider.dart';
import '../../../../core/utils/snackbar_utils.dart';
import '../../services/student_import_service.dart';
import '../../../master_data/services/academic_year_service.dart';
import '../../../master_data/services/class_service.dart';
import '../../../../core/models/app_class.dart';

class StudentImportDialog extends StatefulWidget {
  const StudentImportDialog({super.key});

  @override
  State<StudentImportDialog> createState() => _StudentImportDialogState();
}

class _StudentImportDialogState extends State<StudentImportDialog> {
  String? _selectedClass;
  bool _isLoading = false;
  final StudentImportService _importService = StudentImportService();

  Future<void> _downloadTemplate() async {
    setState(() => _isLoading = true);
    try {
      await _importService.generateTemplate();
    } catch (e) {
      if (mounted) SnackbarUtils.showErrorSnackbar('Gagal mendownload template: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickAndImportFile() async {
    if (_selectedClass == null || _selectedClass!.isEmpty) {
      SnackbarUtils.showErrorSnackbar('Silakan pilih kelas terlebih dahulu!');
      return;
    }

    final schoolId = context.read<SchoolProvider>().activeSchoolId ?? '';

    if (schoolId.isEmpty) {
      SnackbarUtils.showErrorSnackbar('Data sekolah tidak ditemukan.');
      return;
    }

    setState(() => _isLoading = true);
    final activeYear = await AcademicYearService().getActiveAcademicYear(schoolId);
    if (activeYear == null) {
      setState(() => _isLoading = false);
      if (mounted) SnackbarUtils.showErrorSnackbar('Tahun Ajaran Aktif tidak ditemukan.');
      return;
    }
    
    final activeYearId = activeYear.id;
    setState(() => _isLoading = false); // Resume normal state to let user pick file

    FilePickerResult? result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
    );

    if (result != null && result.files.single.path != null) {
      setState(() => _isLoading = true);
      try {
        final res = await _importService.importStudents(
          schoolId,
          activeYearId,
          _selectedClass!,
          result.files.single.path!,
        );
        if (mounted) {
          SnackbarUtils.showSnackbar(
            'Import selesai. Berhasil: ${res['success']}, Dilewati: ${res['skipped']} (NIS sudah ada/data tidak valid).',
          );
          Navigator.pop(context, true); // true indicates success
        }
      } catch (e) {
        if (mounted) SnackbarUtils.showErrorSnackbar('Gagal import data: $e');
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final schoolId = context.read<SchoolProvider>().activeSchoolId ?? '';
    return AlertDialog(
      title: const Text('Import Data Siswa (Excel)'),
      content: _isLoading
          ? const SizedBox(
              height: 100,
              child: Center(child: CircularProgressIndicator()),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '1. Pilih Kelas Tujuan:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                StreamBuilder<List<AppClass>>(
                  stream: ClassService().getClasses(schoolId),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const CircularProgressIndicator();
                    }
                    if (snapshot.hasError) {
                      return Text('Error: ${snapshot.error}');
                    }
                    final classes = snapshot.data ?? [];
                    if (classes.isEmpty) {
                      return const Text('Belum ada kelas.');
                    }
                    return DropdownButtonFormField<String>(
                      value: _selectedClass,
                      hint: const Text('Pilih Kelas...'),
                      items: classes.map<DropdownMenuItem<String>>((AppClass c) {
                        return DropdownMenuItem<String>(
                          value: c.id,
                          child: Text(c.name),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setState(() {
                          _selectedClass = val;
                        });
                      },
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
                const Text(
                  '2. Download Template:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  icon: const Icon(Icons.download),
                  label: const Text('Download Template .xlsx'),
                  onPressed: _downloadTemplate,
                ),
                const SizedBox(height: 16),
                const Text(
                  '3. Upload File:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Pastikan NIS dan Nama tidak kosong. Jika NIS sudah terdaftar, data akan otomatis dilewati.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        ElevatedButton.icon(
          icon: const Icon(Icons.upload_file),
          label: const Text('Upload & Proses'),
          onPressed: _isLoading ? null : _pickAndImportFile,
        ),
      ],
    );
  }
}
