import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/models/student.dart';
import '../../../core/providers/school_provider.dart';
import '../services/student_service.dart';
import '../../../core/utils/snackbar_utils.dart';
import '../../../core/utils/dialog_utils.dart';
import '../../user_management/services/user_management_service.dart';
import '../../../core/models/app_user.dart';
import '../../master_data/services/class_service.dart';
import '../../../core/models/app_class.dart';
import '../../master_data/services/academic_year_service.dart';
import '../../invoices/services/invoice_service.dart';
import '../../../core/models/academic_year.dart';
import '../../../core/components/custom_button.dart';

class StudentFormScreen extends StatefulWidget {
  final Student? student;

  const StudentFormScreen({super.key, this.student});

  @override
  State<StudentFormScreen> createState() => _StudentFormScreenState();
}

class _StudentFormScreenState extends State<StudentFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _studentService = StudentService();
  final _userService = UserManagementService();
  final _classService = ClassService();
  final _academicYearService = AcademicYearService();

  late TextEditingController _nisController;
  late TextEditingController _nisnController;
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _addressController;
  late TextEditingController _parentNameController;

  String? _selectedGuardianId;
  String? _selectedGuardianName;
  String? _selectedClassId;
  String? _selectedAcademicYearId;

  String _gender = 'L';
  String _status = 'ACTIVE';
  DateTime _birthDate = DateTime.now();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nisController = TextEditingController(text: widget.student?.nis ?? '');
    _nisnController = TextEditingController(text: widget.student?.nisn ?? '');
    _nameController = TextEditingController(text: widget.student?.name ?? '');
    _phoneController = TextEditingController(text: widget.student?.phone ?? '');
    _addressController = TextEditingController(
      text: widget.student?.address ?? '',
    );
    _parentNameController = TextEditingController(
      text: widget.student?.guardianName ?? '',
    );

    final guardianId = widget.student?.guardianId ?? '';
    _selectedGuardianId = guardianId.isNotEmpty ? guardianId : null;

    final classId = widget.student?.classId ?? '';
    _selectedClassId = classId.isNotEmpty ? classId : null;

    final ayId = widget.student?.academicYearId ?? '';
    _selectedAcademicYearId = ayId.isNotEmpty ? ayId : null;

    if (widget.student != null) {
      _gender = widget.student!.gender;
      _status = widget.student!.status;
      _birthDate = widget.student!.birthDate;
    }
  }

  @override
  void dispose() {
    _nisController.dispose();
    _nisnController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _parentNameController.dispose();
    super.dispose();
  }

  void _pickBirthDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate,
      firstDate: DateTime(1990),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _birthDate = picked);
    }
  }

  void _save() async {
    if (!_formKey.currentState!.validate()) return;

    final schoolId = context.read<SchoolProvider>().activeSchoolId!;

    // Check for class change warning
    final isEditing = widget.student != null;
    final oldClassId = widget.student?.classId ?? '';
    final newClassId = _selectedClassId ?? '';
    final studentId = _nisController.text.trim();

    if (isEditing && oldClassId.isNotEmpty && newClassId.isNotEmpty && oldClassId != newClassId) {
      setState(() => _isLoading = true);
      final hasUnpaidInvoices = await InvoiceService().hasUnpaidInvoices(schoolId, studentId);
      setState(() => _isLoading = false);

      if (hasUnpaidInvoices) {
        if (!mounted) return;
        final confirm = await DialogUtils.showConfirmationDialog(
          title: 'Informasi Pindah Kelas',
          content: 'Siswa ini masih memiliki tagihan yang BELUM LUNAS. Dengan sistem terbaru, seluruh riwayat tagihan akan otomatis mengikuti profil siswa ini ke kelas yang baru.\n\nLanjutkan pindah kelas?',
          confirmText: 'Lanjutkan',
          cancelText: 'Batal',
        );
        if (confirm != true) return;
      }
    }

    setState(() => _isLoading = true);

    final student = Student(
      id: studentId, // Use NIS as Document ID
      nis: _nisController.text.trim(),
      nisn: _nisnController.text.trim(),
      name: _nameController.text.trim(),
      phone: _phoneController.text.trim(),
      address: _addressController.text.trim(),
      gender: _gender,
      birthDate: _birthDate,
      classId: _selectedClassId ?? '',
      guardianId: _selectedGuardianId ?? '',
      guardianName: _parentNameController.text.trim(),
      academicYearId: _selectedAcademicYearId ?? '',
      status: _status,
    );

    try {
      if (widget.student == null) {
        await _studentService.addStudent(schoolId, student);
        SnackbarUtils.showSnackbar('Siswa berhasil ditambahkan');
      } else {
        await _studentService.updateStudent(schoolId, student);
        SnackbarUtils.showSnackbar('Siswa berhasil diperbarui');
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      SnackbarUtils.showErrorSnackbar('Error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _delete() async {
    if (widget.student == null) return;

    final schoolId = context.read<SchoolProvider>().activeSchoolId!;

    final confirm = await DialogUtils.showConfirmationDialog(
      title: 'Hapus Siswa',
      content: 'Yakin ingin menghapus siswa ini?',
      confirmText: 'Hapus',
      isDestructive: true,
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        await _studentService.deleteStudent(
          schoolId,
          widget.student!.id,
          widget.student!.guardianId,
        );
        SnackbarUtils.showSnackbar('Siswa dihapus');
        if (mounted) Navigator.pop(context, true);
      } catch (e) {
        SnackbarUtils.showErrorSnackbar('Gagal menghapus: $e');
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.student != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Siswa' : 'Tambah Siswa'),
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
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Nama Lengkap *',
                      ),
                      validator: (v) => v!.isEmpty ? 'Wajib diisi' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _nisController,
                      decoration: const InputDecoration(
                        labelText: 'NIS *',
                        helperText:
                            'NIS akan menjadi ID Data (Tidak bisa diubah)',
                      ),
                      readOnly: isEditing,
                      validator: (v) => v!.isEmpty ? 'Wajib diisi' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _nisnController,
                      decoration: const InputDecoration(labelText: 'NISN'),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _gender,
                      decoration: const InputDecoration(
                        labelText: 'Jenis Kelamin',
                      ),
                      items: const [
                        DropdownMenuItem(value: 'L', child: Text('Laki-laki')),
                        DropdownMenuItem(value: 'P', child: Text('Perempuan')),
                      ],
                      onChanged: (v) => setState(() => _gender = v!),
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Tanggal Lahir'),
                      subtitle: Text(
                        '${_birthDate.day}/${_birthDate.month}/${_birthDate.year}',
                      ),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: _pickBirthDate,
                    ),
                    const SizedBox(height: 16),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _parentNameController,
                      decoration: const InputDecoration(
                        labelText: 'Nama Orang Tua / Wali',
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _phoneController,
                      decoration: const InputDecoration(
                        labelText: 'No. Telepon / HP',
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _addressController,
                      decoration: const InputDecoration(
                        labelText: 'Alamat Lengkap',
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 16),
                    StreamBuilder<List<AppClass>>(
                      stream: _classService.getClasses(
                        context.read<SchoolProvider>().activeSchoolId!,
                      ),
                      builder: (context, snapshot) {
                        List<AppClass> classes = [];
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8.0),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                                SizedBox(width: 16),
                                Text('Memuat data Kelas...'),
                              ],
                            ),
                          );
                        }

                        if (snapshot.hasData) {
                          classes = snapshot.data!;
                        }

                        if (_selectedClassId != null &&
                            !classes.any((c) => c.id == _selectedClassId)) {
                          if (snapshot.connectionState ==
                                  ConnectionState.active &&
                              classes.isNotEmpty) {
                            bool found = false;
                            for (var c in classes) {
                              if (c.id == _selectedClassId) found = true;
                            }
                            if (!found) {
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (mounted)
                                  setState(() => _selectedClassId = null);
                              });
                            }
                          }
                        }

                        return DropdownButtonFormField<String>(
                          value: _selectedClassId,
                          decoration: const InputDecoration(
                            labelText: 'Pilih Kelas',
                          ),
                          items: [
                            const DropdownMenuItem<String>(
                              value: null,
                              child: Text('Pilih Kelas (Wajib)'),
                            ),
                            ...classes.map(
                              (c) => DropdownMenuItem(
                                value: c.id,
                                child: Text(c.name),
                              ),
                            ),
                          ],
                          validator: (val) {
                            if (val == null || val.isEmpty) {
                              return 'Kelas wajib dipilih';
                            }
                            return null;
                          },
                          onChanged: (v) =>
                              setState(() => _selectedClassId = v),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    StreamBuilder<List<AcademicYear>>(
                      stream: _academicYearService.getAcademicYears(
                        context.read<SchoolProvider>().activeSchoolId!,
                      ),
                      builder: (context, snapshot) {
                        List<AcademicYear> years = [];
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8.0),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                                SizedBox(width: 16),
                                Text('Memuat data Tahun Ajaran...'),
                              ],
                            ),
                          );
                        }

                        if (snapshot.hasData) {
                          years = snapshot.data!;
                        }

                        if (_selectedAcademicYearId != null &&
                            !years.any(
                              (y) => y.id == _selectedAcademicYearId,
                            )) {
                          if (snapshot.connectionState ==
                                  ConnectionState.active &&
                              years.isNotEmpty) {
                            bool found = false;
                            for (var y in years) {
                              if (y.id == _selectedAcademicYearId) found = true;
                            }
                            if (!found) {
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (mounted)
                                  setState(
                                    () => _selectedAcademicYearId = null,
                                  );
                              });
                            }
                          }
                        }

                        return DropdownButtonFormField<String>(
                          value: _selectedAcademicYearId,
                          decoration: const InputDecoration(
                            labelText: 'Pilih Tahun Ajaran',
                          ),
                          items: [
                            const DropdownMenuItem<String>(
                              value: null,
                              child: Text('Tidak ada / Belum ditentukan'),
                            ),
                            ...years.map(
                              (y) => DropdownMenuItem(
                                value: y.id,
                                child: Text(
                                  '${y.name}${y.isActive ? " (Aktif)" : ""}',
                                ),
                              ),
                            ),
                          ],
                          onChanged: (v) =>
                              setState(() => _selectedAcademicYearId = v),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    StreamBuilder<List<AppUser>>(
                      stream: _userService.getUsers(
                        context.read<SchoolProvider>().activeSchoolId!,
                      ),
                      builder: (context, snapshot) {
                        List<AppUser> walis = [];
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8.0),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                                SizedBox(width: 16),
                                Text('Memuat data Wali...'),
                              ],
                            ),
                          );
                        }

                        if (snapshot.hasData) {
                          walis = snapshot.data!
                              .where((u) => u.role == 'WALI')
                              .toList();
                        }
                        if (_selectedGuardianId != null &&
                            !walis.any((w) => w.id == _selectedGuardianId)) {
                          // If current guardian is not in the list (e.g. not loaded yet), we keep it but it might cause issues.
                          // It's safe to just let it be if it matches, or null if it doesn't match and list is loaded
                          if (snapshot.connectionState ==
                                  ConnectionState.active &&
                              walis.isNotEmpty) {
                            // Let's not auto-null it just in case they are deleted, but DropdownButton requires value to be in items or null.
                            bool found = false;
                            for (var w in walis) {
                              if (w.id == _selectedGuardianId) found = true;
                            }
                            if (!found) {
                              // To prevent crash, if the assigned WALI is no longer a WALI, we add a dummy or set to null
                              // For simplicity, set to null
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (mounted)
                                  setState(() => _selectedGuardianId = null);
                              });
                            }
                          }
                        }

                        return DropdownButtonFormField<String>(
                          value: _selectedGuardianId,
                          decoration: const InputDecoration(
                            labelText: 'Pilih Wali Murid (Opsional)',
                            helperText: 'Wali dapat melihat tagihan anak ini',
                          ),
                          items: [
                            const DropdownMenuItem<String>(
                              value: null,
                              child: Text('Tidak ada / Belum ditentukan'),
                            ),
                            ...walis.map(
                              (w) => DropdownMenuItem(
                                value: w.id,
                                child: Text('${w.name} (${w.email})'),
                              ),
                            ),
                          ],
                          onChanged: (v) {
                            setState(() {
                              _selectedGuardianId = v;
                              if (v != null) {
                                final selectedWali = walis.firstWhere(
                                  (w) => w.id == v,
                                );
                                _parentNameController.text = selectedWali.name;
                              }
                            });
                          },
                        );
                      },
                    ),
                    if (widget.student != null) ...[
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: _status,
                        decoration: const InputDecoration(labelText: 'Status'),
                        items: ['ACTIVE', 'INACTIVE', 'GRADUATED']
                            .map(
                              (s) => DropdownMenuItem(value: s, child: Text(s)),
                            )
                            .toList(),
                        onChanged: (v) => setState(() => _status = v!),
                      ),
                    ],
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
