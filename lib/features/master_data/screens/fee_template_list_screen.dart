import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/models/fee_template.dart';
import '../../../core/providers/school_provider.dart';
import '../services/fee_template_service.dart';
import 'fee_template_form_screen.dart';

class FeeTemplateListScreen extends StatelessWidget {
  FeeTemplateListScreen({super.key});

  final FeeTemplateService _service = FeeTemplateService();

  @override
  Widget build(BuildContext context) {
    final schoolId = context.watch<SchoolProvider>().activeSchoolId ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Master Tagihan'),
      ),
      body: StreamBuilder<List<FeeTemplate>>(
        stream: _service.getFeeTemplates(schoolId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final templates = snapshot.data ?? [];

          if (templates.isEmpty) {
            return const Center(child: Text('Belum ada data Master Tagihan.'));
          }

          return ListView.builder(
            itemCount: templates.length,
            itemBuilder: (context, index) {
              final template = templates[index];
              final targetClass = (template.classId != null && template.classId!.isNotEmpty)
                  ? 'Target: Kelas ${template.classId}'
                  : 'Target: Semua Kelas';

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  title: Text(template.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('Nominal: Rp ${template.amount.toStringAsFixed(0)}\n$targetClass'),
                  isThreeLine: true,
                  trailing: IconButton(
                    icon: const Icon(Icons.edit, color: Colors.blue),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => FeeTemplateFormScreen(template: template),
                        ),
                      );
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const FeeTemplateFormScreen(),
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
