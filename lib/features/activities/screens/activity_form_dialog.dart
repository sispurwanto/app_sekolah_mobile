import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../../core/models/student.dart';
import '../../../../core/models/student_activity.dart';
import '../../../../core/models/activity_master.dart';
import '../services/student_activity_service.dart';
import '../../master_data/services/activity_master_service.dart';
import '../../../../core/providers/user_provider.dart';
import '../../../../core/utils/snackbar_utils.dart';

class ActivityFormDialog extends StatefulWidget {
  final String schoolId;
  final String academicYearId;
  final Student student;
  final ActivityEntry? existingEntry;

  const ActivityFormDialog({
    super.key,
    required this.schoolId,
    required this.academicYearId,
    required this.student,
    this.existingEntry,
  });

  @override
  State<ActivityFormDialog> createState() => _ActivityFormDialogState();
}

class _ActivityFormDialogState extends State<ActivityFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _keteranganController = TextEditingController();
  
  final StudentActivityService _studentActivityService = StudentActivityService();
  final ActivityMasterService _activityMasterService = ActivityMasterService();
  
  List<ActivityMaster> _masterActivities = [];
  String? _selectedActivityName;
  String _selectedStatus = 'Baik';
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;

  late final List<String> _statusOptions;

  @override
  void initState() {
    super.initState();
    _statusOptions = const String.fromEnvironment('ACTIVITY_STATUSES', defaultValue: 'Baik,Cukup,Kurang,Buruk')
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    _selectedStatus = _statusOptions.isNotEmpty ? _statusOptions.first : 'Baik';
    _loadMasterActivities();

    if (widget.existingEntry != null) {
      _selectedActivityName = widget.existingEntry!.name;
      _selectedStatus = widget.existingEntry!.status;
      _keteranganController.text = widget.existingEntry!.keterangan;
      try {
        _selectedDate = DateTime.parse(widget.existingEntry!.tgl);
      } catch (e) {
        _selectedDate = DateTime.now();
      }
    }
  }

  Future<void> _loadMasterActivities() async {
    try {
      final stream = _activityMasterService.getActivities(widget.schoolId);
      final list = await stream.first;
      if (!mounted) return;
      setState(() {
        _masterActivities = list;
        if (_selectedActivityName == null && list.isNotEmpty) {
          _selectedActivityName = list.first.nameActivity;
        } else if (_selectedActivityName != null) {
          final exists = list.any((e) => e.nameActivity == _selectedActivityName);
          if (!exists) {
            _masterActivities.insert(0, ActivityMaster(idActivity: 'temp', nameActivity: _selectedActivityName!));
          }
        }
      });
    } catch (e) {
      // Handle error quietly
    }
  }

  @override
  void dispose() {
    _keteranganController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null && picked != _selectedDate) {
      if (!context.mounted) return;
      final TimeOfDay? timePicked = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_selectedDate),
      );
      
      if (timePicked != null) {
        setState(() {
          _selectedDate = DateTime(
            picked.year,
            picked.month,
            picked.day,
            timePicked.hour,
            timePicked.minute,
          );
        });
      } else {
        setState(() {
          _selectedDate = picked;
        });
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedActivityName == null) {
      SnackbarUtils.showErrorSnackbar('Pilih nama kegiatan terlebih dahulu');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final userProvider = context.read<UserProvider>();
      final currentUserName = userProvider.userMapping?.name ?? 'Unknown Teacher';

      final newEntry = ActivityEntry(
        tgl: _selectedDate.toIso8601String(),
        name: _selectedActivityName!,
        keterangan: _keteranganController.text.trim(),
        status: _selectedStatus,
        namaGuru: widget.existingEntry?.namaGuru ?? currentUserName,
      );

      if (widget.existingEntry == null) {
        await _studentActivityService.addActivityEntry(
          widget.schoolId,
          widget.academicYearId,
          widget.student.id,
          widget.student.name,
          newEntry,
        );
        SnackbarUtils.showSnackbar('Kegiatan berhasil ditambahkan');
      } else {
        await _studentActivityService.updateActivityEntry(
          widget.schoolId,
          widget.academicYearId,
          widget.student.id,
          widget.existingEntry!,
          newEntry,
        );
        SnackbarUtils.showSnackbar('Kegiatan berhasil diperbarui');
      }

      if (mounted) Navigator.pop(context);
    } catch (e) {
      SnackbarUtils.showErrorSnackbar('Gagal menyimpan kegiatan: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existingEntry != null;
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      titlePadding: const EdgeInsets.all(0),
      title: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(
          color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Row(
          children: [
            Icon(isEdit ? Icons.edit_note : Icons.add_circle_outline, color: Theme.of(context).primaryColor),
            const SizedBox(width: 12),
            Text(
              isEdit ? 'Edit Kegiatan' : 'Tambah Kegiatan',
              style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.9,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: Colors.blue.withValues(alpha: 0.1),
                    child: const Icon(Icons.calendar_today, color: Colors.blue),
                  ),
                  title: const Text('Waktu Kegiatan'),
                  subtitle: Text(DateFormat('dd MMM yyyy, HH:mm').format(_selectedDate)),
                  onTap: () => _selectDate(context),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                const SizedBox(height: 20),
                DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    labelText: 'Nama Kegiatan',
                    prefixIcon: const Icon(Icons.local_activity_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: Colors.grey.withValues(alpha: 0.05),
                  ),
                  initialValue: _selectedActivityName,
                  items: _masterActivities.map((e) {
                    return DropdownMenuItem(
                      value: e.nameActivity,
                      child: Text(e.nameActivity),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedActivityName = val;
                    });
                  },
                  validator: (val) => val == null ? 'Pilih kegiatan' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _keteranganController,
                  decoration: InputDecoration(
                    labelText: 'Keterangan',
                    prefixIcon: const Icon(Icons.description_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: Colors.grey.withValues(alpha: 0.05),
                  ),
                  maxLines: 3,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Keterangan harus diisi';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    labelText: 'Status',
                    prefixIcon: const Icon(Icons.flaky),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: Colors.grey.withValues(alpha: 0.05),
                  ),
                  initialValue: _selectedStatus,
                  items: _statusOptions.map((e) {
                    return DropdownMenuItem(
                      value: e,
                      child: Text(e),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedStatus = val!;
                    });
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      actionsPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          style: TextButton.styleFrom(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: const Text('Batal'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _submit,
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
          child: _isLoading 
            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) 
            : const Text('Simpan'),
        ),
      ],
    );
  }
}
