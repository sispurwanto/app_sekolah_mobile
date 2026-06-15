import 'package:flutter/material.dart';
import 'invoice_form_screen.dart';
import 'bulk_invoice_generation_dialog.dart';

class InvoiceGenerationSheet extends StatelessWidget {
  final VoidCallback onRefresh;

  const InvoiceGenerationSheet({
    super.key,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Buat Tagihan Baru',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.group, color: Colors.green.shade700),
            ),
            title: const Text('Tagihan Kolektif (Massal)'),
            subtitle: const Text('Buat tagihan untuk satu kelas atau semua siswa berdasarkan Master Tagihan.'),
            onTap: () {
              Navigator.pop(context);
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => BulkInvoiceGenerationDialog(
                  onSuccess: onRefresh,
                ),
              );
            },
          ),
          const Divider(),
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.person, color: Colors.blue.shade700),
            ),
            title: const Text('Tagihan Personal (1 Siswa)'),
            subtitle: const Text('Buat tagihan khusus secara manual untuk satu siswa tertentu.'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const InvoiceFormScreen(),
                ),
              ).then((_) {
                onRefresh();
              });
            },
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
