import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/models/invoice.dart';
import '../../../core/providers/school_provider.dart';
import '../services/invoice_service.dart';
import '../../master_data/services/academic_year_service.dart';
import '../../student_management/services/student_service.dart';
import '../../../core/utils/snackbar_utils.dart';
import '../../../core/utils/currency_input_formatter.dart';
import 'package:intl/intl.dart';
import '../../../core/utils/dialog_utils.dart';
import '../../../core/components/custom_button.dart';

class InvoiceFormScreen extends StatefulWidget {
  final Invoice? invoice;
  final String? studentId;

  const InvoiceFormScreen({super.key, this.invoice, this.studentId});

  @override
  State<InvoiceFormScreen> createState() => _InvoiceFormScreenState();
}

class _InvoiceFormScreenState extends State<InvoiceFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _invoiceService = InvoiceService();

  late TextEditingController _studentNameController;
  late TextEditingController _studentIdController;
  late TextEditingController _titleController;
  late TextEditingController _amountController;

  String _status = 'UNPAID';
  DateTime _dueDate = DateTime.now().add(const Duration(days: 30));
  bool _isLoading = false;
  bool _isStudentLocked = false;

  @override
  void initState() {
    super.initState();
    _studentNameController = TextEditingController(text: widget.invoice?.studentName ?? '');
    _studentIdController = TextEditingController(text: widget.invoice?.studentId ?? widget.studentId ?? '');
    _titleController = TextEditingController(text: widget.invoice?.title ?? '');
    _amountController = TextEditingController();
    if (widget.invoice != null) {
      final formatter = NumberFormat.currency(locale: 'id_ID', symbol: '', decimalDigits: 0);
      _amountController.text = formatter.format(widget.invoice!.amount).trim();
    }

    if (widget.invoice != null) {
      _status = widget.invoice!.status;
      _dueDate = widget.invoice!.dueDate;
      _isStudentLocked = true;
    } else if (widget.studentId != null) {
      _isStudentLocked = true;
      _loadStudentData(widget.studentId!);
    }
  }

  Future<void> _loadStudentData(String studentId) async {
    setState(() => _isLoading = true);
    try {
      final schoolId = context.read<SchoolProvider>().activeSchoolId!;
      final student = await StudentService().getStudentById(schoolId, studentId);
      if (student != null) {
        _studentNameController.text = student.name;
      }
    } catch (e) {
      // Ignore
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _studentNameController.dispose();
    _studentIdController.dispose();
    _titleController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  void _pickDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );
    if (picked != null) {
      setState(() => _dueDate = picked);
    }
  }

  void _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final schoolId = context.read<SchoolProvider>().activeSchoolId!;

    try {
      // Fetch Active Academic Year
      final activeYear = await AcademicYearService().getActiveAcademicYear(schoolId);
      if (activeYear == null) {
        throw Exception('Tidak ada Tahun Ajaran yang Aktif! Silakan aktifkan di Master Data.');
      }

      final studentId = _studentIdController.text.trim();
      if (studentId.isEmpty) {
        throw Exception('ID Siswa wajib diisi untuk mencari data kelas.');
      }

      // Fetch Student Data to get Class ID
      final student = await StudentService().getStudentById(schoolId, studentId);
      if (student == null) {
        throw Exception('Siswa dengan ID $studentId tidak ditemukan.');
      }
      if (student.classId.isEmpty) {
        throw Exception('Siswa ini belum dimasukkan ke dalam Kelas mana pun.');
      }

      final invoice = Invoice(
        id: widget.invoice?.id ?? '',
        studentId: studentId,
        studentName: student.name, // Auto override with real name
        title: _titleController.text.trim(),
        amount: double.tryParse(_amountController.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0.0,
        status: _status,
        dueDate: _dueDate,
        schoolId: schoolId,
        academicYearId: activeYear.id,
        classId: student.classId,
        createdAt: widget.invoice?.createdAt,
      );

      if (widget.invoice == null) {
        await _invoiceService.addInvoice(schoolId, invoice);
        SnackbarUtils.showSnackbar('Tagihan berhasil dibuat');
      } else {
        await _invoiceService.updateInvoice(schoolId, invoice);
        SnackbarUtils.showSnackbar('Tagihan berhasil diperbarui');
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      SnackbarUtils.showErrorSnackbar('Error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _delete() async {
    if (widget.invoice == null) return;
    
    final schoolId = context.read<SchoolProvider>().activeSchoolId!;

    final confirm = await DialogUtils.showConfirmationDialog(
      title: 'Hapus Tagihan',
      content: 'Yakin ingin menghapus tagihan ini?',
      confirmText: 'Hapus',
      isDestructive: true,
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        await _invoiceService.deleteInvoice(
          schoolId,
          widget.invoice!.academicYearId,
          widget.invoice!.classId,
          widget.invoice!.studentId,
          widget.invoice!.id,
        );
        SnackbarUtils.showSnackbar('Tagihan dihapus');
        if (mounted) Navigator.pop(context);
      } catch (e) {
        SnackbarUtils.showErrorSnackbar('Gagal menghapus: $e');
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.invoice != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Tagihan' : 'Buat Tagihan'),
        actions: [
          if (isEditing)
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: _delete,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(labelText: 'Judul Tagihan (misal: SPP Juli 2026) *'),
                      validator: (v) => v!.isEmpty ? 'Wajib diisi' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _studentIdController,
                      decoration: const InputDecoration(labelText: 'ID Siswa (NIS) *'),
                      readOnly: _isStudentLocked,
                      validator: (v) => v!.isEmpty ? 'Wajib diisi' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _studentNameController,
                      decoration: const InputDecoration(labelText: 'Nama Siswa *', helperText: 'Otomatis tersimpan berdasarkan NIS'),
                      readOnly: _isStudentLocked,
                      validator: (v) => v!.isEmpty ? 'Wajib diisi' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _amountController,
                      decoration: const InputDecoration(labelText: 'Nominal (Rp) *'),
                      keyboardType: TextInputType.number,
                      inputFormatters: [CurrencyInputFormatter()],
                      validator: (v) => v!.isEmpty ? 'Wajib diisi' : null,
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Jatuh Tempo'),
                      subtitle: Text('${_dueDate.day}/${_dueDate.month}/${_dueDate.year}'),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: _pickDueDate,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _status,
                      decoration: const InputDecoration(labelText: 'Status'),
                      items: ['UNPAID', 'PARTIAL', 'PAID']
                          .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                          .toList(),
                      onChanged: (v) => setState(() => _status = v!),
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      child: CustomButton(
                        text: 'Simpan',
                        onPressed: _save,
                        isLoading: _isLoading,
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
