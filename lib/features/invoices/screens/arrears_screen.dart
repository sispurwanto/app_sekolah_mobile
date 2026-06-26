import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/providers/school_provider.dart';
import '../../../core/models/academic_year.dart';
import '../../../core/models/app_class.dart';
import '../../../core/models/invoice.dart';
import '../../../core/utils/snackbar_utils.dart';
import '../../../core/utils/currency_utils.dart';
import '../../master_data/services/academic_year_service.dart';
import '../../master_data/services/class_service.dart';
import '../services/invoice_service.dart';
import '../screens/payment_dialog.dart';

class ArrearsScreen extends StatefulWidget {
  const ArrearsScreen({super.key});

  @override
  State<ArrearsScreen> createState() => _ArrearsScreenState();
}

class _ArrearsScreenState extends State<ArrearsScreen> {
  final _academicYearService = AcademicYearService();
  final _classService = ClassService();
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  List<AcademicYear> _pastYears = [];
  String? _selectedYearId;
  bool _isLoadingYears = false;

  List<AppClass> _classes = [];
  bool _isLoadingClasses = false;

  // Cache for unpaid invoices per class
  // Map of classId -> List of Maps containing student info and invoice
  final Map<String, List<Map<String, dynamic>>> _classArrearsCache = {};
  final Map<String, bool> _isLoadingArrears = {};

  @override
  void initState() {
    super.initState();
    _loadPastYears();
  }

  Future<void> _loadPastYears() async {
    setState(() => _isLoadingYears = true);
    try {
      final schoolId = context.read<SchoolProvider>().activeSchoolId!;
      final years = await _academicYearService.getAcademicYears(schoolId).first;
      setState(() {
        _pastYears = years.where((y) => !y.isActive).toList();
      });
    } catch (e) {
      SnackbarUtils.showErrorSnackbar('Gagal memuat tahun ajaran: $e');
    } finally {
      if (mounted) setState(() => _isLoadingYears = false);
    }
  }

  Future<void> _loadClassesForYear(String yearId) async {
    setState(() {
      _selectedYearId = yearId;
      _isLoadingClasses = true;
      _classes = [];
      _classArrearsCache.clear();
      _isLoadingArrears.clear();
    });

    try {
      final schoolId = context.read<SchoolProvider>().activeSchoolId!;
      // Get all classes in the school. Note: we might only want classes that exist in that year.
      // But standard approach is to list all classes and check if they have arrears.
      final classes = await _classService.getClasses(schoolId).first;
      setState(() {
        _classes = classes;
      });
    } catch (e) {
      SnackbarUtils.showErrorSnackbar('Gagal memuat kelas: $e');
    } finally {
      if (mounted) setState(() => _isLoadingClasses = false);
    }
  }

  Future<void> _loadArrearsForClass(String classId) async {
    if (_classArrearsCache.containsKey(classId)) return; // Already loaded

    setState(() => _isLoadingArrears[classId] = true);
    
    try {
      final schoolId = context.read<SchoolProvider>().activeSchoolId!;
      
      // Get all students in this class for this year
      final studentsSnapshot = await _db
          .collection('schools')
          .doc(schoolId)
          .collection('transactions_year')
          .doc(_selectedYearId!)
          .collection('invoices')
          .doc(classId)
          .collection('invoices_class_data')
          .get();

      List<Map<String, dynamic>> allArrears = [];

      for (var studentDoc in studentsSnapshot.docs) {
        final studentId = studentDoc.id;
        
        // Fetch unpaid invoices for this student
        final invoicesSnapshot = await _db
            .collection('schools')
            .doc(schoolId)
            .collection('transactions_year')
            .doc(_selectedYearId!)
            .collection('invoices')
            .doc(classId)
            .collection('invoices_class_data')
            .doc(studentId)
            .collection('invoice_data')
            .where('status', isNotEqualTo: 'PAID')
            .get();

        for (var invoiceDoc in invoicesSnapshot.docs) {
          final invoice = Invoice.fromFirestore(invoiceDoc);
          allArrears.add({
            'studentId': studentId,
            'studentName': invoice.studentName,
            'invoice': invoice,
          });
        }
      }
      
      // Sort by student name
      allArrears.sort((a, b) => (a['studentName'] as String).compareTo(b['studentName'] as String));

      if (mounted) {
        setState(() {
          _classArrearsCache[classId] = allArrears;
        });
      }
    } catch (e) {
      SnackbarUtils.showErrorSnackbar('Gagal memuat tagihan untuk kelas ini: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingArrears[classId] = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tunggakan Lintas Tahun'),
      ),
      body: Padding(
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
                    const Text('Pilih Tahun Ajaran Lewat', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 8),
                    _isLoadingYears
                        ? const CircularProgressIndicator()
                        : DropdownButtonFormField<String>(
                            decoration: const InputDecoration(
                              labelText: 'Tahun Ajaran',
                              border: OutlineInputBorder(),
                            ),
                            value: _selectedYearId,
                            items: _pastYears.map((y) {
                              return DropdownMenuItem(
                                value: y.id,
                                child: Text(y.name),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) _loadClassesForYear(val);
                            },
                          ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _selectedYearId == null
                  ? const Center(
                      child: Text('Silakan pilih tahun ajaran terlebih dahulu', style: TextStyle(color: Colors.grey)),
                    )
                  : _isLoadingClasses
                      ? const Center(child: CircularProgressIndicator())
                      : _classes.isEmpty
                          ? const Center(
                              child: Text('Tidak ada kelas ditemukan', style: TextStyle(color: Colors.grey)),
                            )
                          : ListView.builder(
                              itemCount: _classes.length,
                              itemBuilder: (context, index) {
                                final classData = _classes[index];
                                final isArrearsLoading = _isLoadingArrears[classData.id] ?? false;
                                final arrears = _classArrearsCache[classData.id];

                                return Card(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  child: ExpansionTile(
                                    title: Text('${classData.name} (${classData.level})', style: const TextStyle(fontWeight: FontWeight.bold)),
                                    subtitle: arrears != null 
                                        ? Text('${arrears.length} tagihan belum lunas', style: TextStyle(color: arrears.isNotEmpty ? Colors.red : Colors.green))
                                        : const Text('Klik untuk melihat tagihan'),
                                    onExpansionChanged: (expanded) {
                                      if (expanded) {
                                        _loadArrearsForClass(classData.id);
                                      }
                                    },
                                    children: [
                                      if (isArrearsLoading)
                                        const Padding(
                                          padding: EdgeInsets.all(16.0),
                                          child: Center(child: CircularProgressIndicator()),
                                        )
                                      else if (arrears != null && arrears.isEmpty)
                                        const Padding(
                                          padding: EdgeInsets.all(16.0),
                                          child: Text('Tidak ada tunggakan di kelas ini', style: TextStyle(color: Colors.green)),
                                        )
                                      else if (arrears != null)
                                        ListView.separated(
                                          shrinkWrap: true,
                                          physics: const NeverScrollableScrollPhysics(),
                                          itemCount: arrears.length,
                                          separatorBuilder: (context, idx) => const Divider(height: 1),
                                          itemBuilder: (context, idx) {
                                            final item = arrears[idx];
                                            final invoice = item['invoice'] as Invoice;
                                            return ListTile(
                                              title: Text(invoice.studentName),
                                              subtitle: Text(invoice.title),
                                              trailing: Column(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                crossAxisAlignment: CrossAxisAlignment.end,
                                                children: [
                                                  Text(
                                                    CurrencyUtils.formatRp(invoice.amount),
                                                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
                                                  ),
                                                  Text(
                                                    invoice.status,
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: invoice.status == 'PARTIAL' ? Colors.orange : Colors.red,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              onTap: () async {
                                                await showDialog(
                                                  context: context,
                                                  builder: (context) => PaymentDialog(
                                                    invoice: invoice,
                                                  ),
                                                );
                                                // Refresh after returning
                                                setState(() {
                                                  _classArrearsCache.remove(classData.id);
                                                });
                                                _loadArrearsForClass(classData.id);
                                              },
                                            );
                                          },
                                        ),
                                    ],
                                  ),
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }
}
