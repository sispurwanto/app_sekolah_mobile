import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/models/invoice.dart';
import '../../../core/providers/school_provider.dart';
import '../../../core/providers/user_provider.dart';
import '../services/invoice_service.dart';
import 'invoice_form_screen.dart';

class InvoiceListScreen extends StatelessWidget {
  InvoiceListScreen({super.key});

  final InvoiceService _invoiceService = InvoiceService();

  @override
  Widget build(BuildContext context) {
    final schoolId = context.watch<SchoolProvider>().activeSchoolId ?? '';
    final role = context.read<UserProvider>().userMapping?.registeredSchools[schoolId] ?? 'WALI';
    
    // BENDAHARA, ADMIN, SUPER_ADMIN can add and edit invoices
    final canManageInvoices = ['BENDAHARA', 'ADMIN', 'SUPER_ADMIN'].contains(role);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Daftar Tagihan'),
      ),
      body: StreamBuilder<List<Invoice>>(
        stream: _invoiceService.getInvoices(schoolId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final invoices = snapshot.data ?? [];

          // TODO: If role == WALI, filter invoices by student_id
          // For now, it shows all.

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
                    'Siswa: ${invoice.studentName}\nTotal: Rp ${invoice.amount.toStringAsFixed(0)} | Status: ${invoice.status}',
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
