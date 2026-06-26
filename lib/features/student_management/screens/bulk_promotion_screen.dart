import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/providers/school_provider.dart';
import '../../../core/models/app_class.dart';
import '../../../core/models/student.dart';
import '../../../core/models/app_user.dart';
import '../../../core/utils/snackbar_utils.dart';
import '../../../core/utils/dialog_utils.dart';
import '../../master_data/services/class_service.dart';
import '../services/student_service.dart';
import '../../user_management/services/user_management_service.dart';
import '../../../core/components/custom_button.dart';

class BulkPromotionScreen extends StatefulWidget {
  const BulkPromotionScreen({super.key});

  @override
  State<BulkPromotionScreen> createState() => _BulkPromotionScreenState();
}

class _BulkPromotionScreenState extends State<BulkPromotionScreen> {
  final _classService = ClassService();
  final _studentService = StudentService();
  final _userService = UserManagementService();

  List<AppClass> _sourceClasses = [];
  List<AppClass> _destinationClasses = [];
  String? _selectedSourceClassId;
  String? _selectedDestinationClassId;
  bool _isGraduation = false;

  List<Student> _students = [];
  final Set<String> _selectedStudentIds = {};
  bool _isLoading = false;
  bool _isFetchingStudents = false;
  
  AppUser? _currentUserData;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    try {
      final schoolId = context.read<SchoolProvider>().activeSchoolId!;
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('schools')
            .doc(schoolId)
            .collection('users')
            .doc(user.uid)
            .get();
        if (userDoc.exists) {
          _currentUserData = AppUser.fromFirestore(userDoc);
        }
      }

      _classService.getClasses(schoolId).listen((classes) {
        if (!mounted) return;
        setState(() {
          _destinationClasses = classes;
          if (_currentUserData?.role == 'GURU') {
            _sourceClasses = classes.where((c) => c.teacherId == user?.uid).toList();
          } else {
            _sourceClasses = classes;
          }

          if (_selectedSourceClassId != null && !_sourceClasses.any((c) => c.id == _selectedSourceClassId)) {
            _selectedSourceClassId = null;
            _students = [];
            _selectedStudentIds.clear();
          }
          
          if (_selectedDestinationClassId != null && !_destinationClasses.any((c) => c.id == _selectedDestinationClassId)) {
            _selectedDestinationClassId = null;
          }
        });
      });
    } catch (e) {
      SnackbarUtils.showErrorSnackbar('Gagal memuat data kelas: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchStudents() async {
    if (_selectedSourceClassId == null) return;

    setState(() {
      _isFetchingStudents = true;
      _students = [];
      _selectedStudentIds.clear();
    });

    try {
      final schoolId = context.read<SchoolProvider>().activeSchoolId!;
      final fetchedStudents = await _studentService.fetchStudentsByClass(
        schoolId,
        _selectedSourceClassId!,
        statusFilter: 'ACTIVE',
      );
      
      setState(() {
        _students = fetchedStudents;
        for (var student in _students) {
          _selectedStudentIds.add(student.id);
        }
      });
    } catch (e) {
      SnackbarUtils.showErrorSnackbar('Gagal memuat siswa: $e');
    } finally {
      if (mounted) setState(() => _isFetchingStudents = false);
    }
  }

  void _toggleSelectAll(bool? value) {
    setState(() {
      if (value == true) {
        for (var student in _students) {
          _selectedStudentIds.add(student.id);
        }
      } else {
        _selectedStudentIds.clear();
      }
    });
  }

  Future<void> _processPromotion() async {
    if (_selectedStudentIds.isEmpty) {
      SnackbarUtils.showErrorSnackbar('Pilih minimal satu siswa.');
      return;
    }

    if (!_isGraduation && _selectedDestinationClassId == null) {
      SnackbarUtils.showErrorSnackbar('Pilih kelas tujuan atau centang opsi Luluskan Siswa.');
      return;
    }

    if (!_isGraduation && _selectedSourceClassId == _selectedDestinationClassId) {
      SnackbarUtils.showErrorSnackbar('Kelas tujuan tidak boleh sama dengan kelas asal.');
      return;
    }

    final confirm = await DialogUtils.showConfirmationDialog(
      title: 'Konfirmasi ${_isGraduation ? 'Kelulusan' : 'Kenaikan Kelas'}',
      content: 'Anda akan memproses ${_selectedStudentIds.length} siswa. Proses ini akan memperbarui data kelas mereka.\n\nLanjutkan?',
      confirmText: 'Proses Sekarang',
      cancelText: 'Batal',
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    final schoolId = context.read<SchoolProvider>().activeSchoolId!;

    try {
      int successCount = 0;
      for (var student in _students) {
        if (_selectedStudentIds.contains(student.id)) {
          final updatedStudent = Student(
            id: student.id,
            nis: student.nis,
            nisn: student.nisn,
            name: student.name,
            phone: student.phone,
            address: student.address,
            gender: student.gender,
            birthDate: student.birthDate,
            classId: _isGraduation ? '' : _selectedDestinationClassId!,
            guardianId: student.guardianId,
            guardianName: student.guardianName,
            academicYearId: student.academicYearId,
            status: _isGraduation ? 'GRADUATED' : 'ACTIVE',
          );

          await _studentService.updateStudent(schoolId, updatedStudent);
          successCount++;
        }
      }
      
      SnackbarUtils.showSnackbar('Berhasil memproses $successCount siswa!');
      _fetchStudents();
    } catch (e) {
      SnackbarUtils.showErrorSnackbar('Terjadi kesalahan saat memproses: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kenaikan Kelas Massal'),
      ),
      body: _isLoading && _sourceClasses.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Kelas Asal', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            decoration: const InputDecoration(
                              labelText: 'Pilih Kelas Asal',
                              border: OutlineInputBorder(),
                            ),
                            value: _selectedSourceClassId,
                            items: _sourceClasses.map((c) {
                              return DropdownMenuItem(
                                value: c.id,
                                child: Text('${c.name} (${c.level})'),
                              );
                            }).toList(),
                            onChanged: (val) {
                              setState(() {
                                _selectedSourceClassId = val;
                                if (_selectedDestinationClassId == val) {
                                  _selectedDestinationClassId = null;
                                }
                              });
                              _fetchStudents();
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: Card(
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Row(
                              children: [
                                const Text('Daftar Siswa', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                const Spacer(),
                                if (_students.isNotEmpty)
                                  Row(
                                    children: [
                                      const Text('Pilih Semua'),
                                      Checkbox(
                                        value: _selectedStudentIds.length == _students.length && _students.isNotEmpty,
                                        onChanged: _toggleSelectAll,
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                          const Divider(height: 1),
                          Expanded(
                            child: _isFetchingStudents
                                ? const Center(child: CircularProgressIndicator())
                                : _students.isEmpty
                                    ? Center(
                                        child: Text(
                                          _selectedSourceClassId == null
                                              ? 'Pilih kelas asal terlebih dahulu'
                                              : 'Tidak ada siswa aktif di kelas ini',
                                          style: const TextStyle(color: Colors.grey),
                                        ),
                                      )
                                    : ListView.separated(
                                        itemCount: _students.length,
                                        separatorBuilder: (context, index) => const Divider(height: 1),
                                        itemBuilder: (context, index) {
                                          final student = _students[index];
                                          final isSelected = _selectedStudentIds.contains(student.id);
                                          return CheckboxListTile(
                                            title: Text(student.name),
                                            subtitle: Text('NIS: ${student.nis}'),
                                            value: isSelected,
                                            onChanged: (val) {
                                              setState(() {
                                                if (val == true) {
                                                  _selectedStudentIds.add(student.id);
                                                } else {
                                                  _selectedStudentIds.remove(student.id);
                                                }
                                              });
                                            },
                                          );
                                        },
                                      ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text('Tujuan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              const Spacer(),
                              Row(
                                children: [
                                  const Text('Luluskan Siswa?'),
                                  Switch(
                                    value: _isGraduation,
                                    onChanged: (val) {
                                      setState(() {
                                        _isGraduation = val;
                                        if (val) _selectedDestinationClassId = null;
                                      });
                                    },
                                  ),
                                ],
                              )
                            ],
                          ),
                          if (!_isGraduation) ...[
                            const SizedBox(height: 8),
                            DropdownButtonFormField<String>(
                              decoration: const InputDecoration(
                                labelText: 'Pilih Kelas Tujuan',
                                border: OutlineInputBorder(),
                              ),
                              value: _selectedDestinationClassId,
                              items: _destinationClasses
                                  .where((c) => c.id != _selectedSourceClassId)
                                  .map((c) {
                                return DropdownMenuItem(
                                  value: c.id,
                                  child: Text('${c.name} (${c.level})'),
                                );
                              }).toList(),
                              onChanged: (val) {
                                setState(() {
                                  _selectedDestinationClassId = val;
                                });
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  CustomButton(
                    text: 'Proses ${_selectedStudentIds.length} Siswa',
                    onPressed: _isLoading || _selectedStudentIds.isEmpty ? null : _processPromotion,
                    isLoading: _isLoading,
                  ),
                ],
              ),
            ),
    );
  }
}
