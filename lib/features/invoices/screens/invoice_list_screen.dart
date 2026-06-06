import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/models/invoice.dart';
import '../../../core/providers/school_provider.dart';
import '../../../core/providers/user_provider.dart';
import '../services/invoice_service.dart';
import '../../master_data/services/academic_year_service.dart';
import '../../../core/models/academic_year.dart';
import 'invoice_form_screen.dart';

class InvoiceListScreen extends StatelessWidget {
  final String? studentId;
  final String? academicYearId;
  final String? classId;

  InvoiceListScreen({
    super.key, 
    this.studentId, 
    this.academicYearId, 
    this.classId,
  });

  final InvoiceService _invoiceService = InvoiceService();

  @override
  Widget build(BuildContext context) {
    final schoolId = context.watch<SchoolProvider>().activeSchoolId ?? '';
    final role = context.read<UserProvider>().userMapping?.registeredSchools[schoolId] ?? 'WALI';
    
    // BENDAHARA, ADMIN, SUPER_ADMIN can add and edit invoices
    final canManageInvoices = ['BENDAHARA', 'ADMIN', 'SUPER_ADMIN'].contains(role);

    return Scaffold(
      appBar: AppBar(
        title: Text(studentId != null ? 'Tagihan Siswa' : 'Daftar Semua Tagihan'),
      ),
      body: FutureBuilder<AcademicYear?>(
        future: AcademicYearService().getActiveAcademicYear(schoolId),
        builder: (context, yearSnapshot) {
          if (yearSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          final activeYear = yearSnapshot.data;
          
          final yearIdToUse = academicYearId ?? activeYear?.id;

          if (yearIdToUse == null || yearIdToUse.isEmpty) {
            return const Center(child: Text('Tahun Ajaran Aktif tidak ditemukan.'));
          }

          // If showing for specific student, make sure class is provided
          if (studentId != null && (classId == null || classId!.isEmpty)) {
            return const Center(child: Text('Data Kelas Siswa tidak lengkap untuk mengambil tagihan.'));
          }

          return StreamBuilder<List<Invoice>>(
            stream: studentId != null 
                ? _invoiceService.getStudentInvoices(schoolId, yearIdToUse, classId!, studentId!)
                : _invoiceService.getAllInvoices(schoolId, yearIdToUse),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }

              final invoices = snapshot.data ?? [];

              if (invoices.isEmpty) {
                return const Center(child: Text('Belum ada data tagihan.'));
              }

              return ListView.builder(
                itemCount: invoices.length,
                itemBuilder: (context, index) {
                  final invoice = invoices[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: ListTile(
                      title: Text(invoice.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(
                        'Siswa: ${invoice.studentName}\nTotal: Rp ${invoice.amount.toStringAsFixed(0)} | Dibayar: Rp ${invoice.paidAmount.toStringAsFixed(0)}\nStatus: ${invoice.status}',
                      ),
                      isThreeLine: true,
                      trailing: canManageInvoices
                          ? IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => InvoiceFormScreen(invoice: invoice),
                                  ),
                                );
                              },
                            )
                          : null,
                    ),
                  );
                },
              );
            },
          );
        }
      ),
      floatingActionButton: canManageInvoices
          ? FloatingActionButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const InvoiceFormScreen(),
                  ),
                );
              },
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}
