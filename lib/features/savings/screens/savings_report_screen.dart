import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/models/savings.dart';
import '../../../../core/utils/currency_utils.dart';
import '../../../../core/providers/school_provider.dart';
import '../../reports/services/export_service.dart';
import '../services/savings_service.dart';

class SavingsReportScreen extends StatefulWidget {
  const SavingsReportScreen({super.key});

  @override
  State<SavingsReportScreen> createState() => _SavingsReportScreenState();
}

class _SavingsReportScreenState extends State<SavingsReportScreen> {
  final SavingsService _savingsService = SavingsService();
  String _searchQuery = '';
  late Stream<List<SavingsSummary>> _summariesStream;
  String _currentSchoolId = '';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final schoolId = context.watch<SchoolProvider>().activeSchoolId ?? '';
    if (schoolId != _currentSchoolId) {
      _currentSchoolId = schoolId;
      _summariesStream = _savingsService.getAllSavingsSummaries(schoolId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<SavingsSummary>>(
      stream: _summariesStream,
      builder: (context, snapshot) {
        final allSummaries = snapshot.data ?? [];
        final double totalBalance = allSummaries.fold(0.0, (sum, item) => sum + item.balance);

        var filteredSummaries = allSummaries;
        if (_searchQuery.isNotEmpty) {
          filteredSummaries = allSummaries.where((s) {
            return s.studentName.toLowerCase().contains(_searchQuery.toLowerCase()) || 
                   s.classId.toLowerCase().contains(_searchQuery.toLowerCase());
          }).toList();
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Laporan Tabungan Siswa'),
            backgroundColor: const Color(0xFF2E7D32),
            foregroundColor: Colors.white,
            actions: [
              IconButton(
                icon: const Icon(Icons.picture_as_pdf),
                onPressed: () => ExportService().exportSavingsPdf(context, filteredSummaries),
                tooltip: 'Export PDF',
              ),
              IconButton(
                icon: const Icon(Icons.table_chart),
                onPressed: () => ExportService().exportSavingsExcel(context, filteredSummaries),
                tooltip: 'Export Excel',
              ),
            ],
          ),
          body: snapshot.connectionState == ConnectionState.waiting
              ? const Center(child: CircularProgressIndicator())
              : snapshot.hasError
                  ? Center(child: Text('Error: ${snapshot.error}'))
                  : Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF2E7D32), Color(0xFF4CAF50)],
                  ),
                  borderRadius: BorderRadius.only(bottomLeft: Radius.circular(20), bottomRight: Radius.circular(20)),
                ),
                child: Column(
                  children: [
                    const Text('Total Tabungan Seluruh Siswa', style: TextStyle(color: Colors.white70, fontSize: 14)),
                    const SizedBox(height: 8),
                    Text(
                      CurrencyUtils.formatRp(totalBalance),
                      style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text('${allSummaries.length} Siswa Menabung', style: const TextStyle(color: Colors.white, fontSize: 14)),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: TextField(
                  decoration: InputDecoration(
                    labelText: 'Cari Nama Siswa atau Kelas',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val;
                    });
                  },
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filteredSummaries.length,
                  itemBuilder: (context, index) {
                    final summary = filteredSummaries[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.green.shade50,
                          child: const Icon(Icons.account_balance_wallet, color: Colors.green),
                        ),
                        title: Text(summary.studentName, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('Kelas: ${summary.classId}'),
                        trailing: Text(
                          CurrencyUtils.formatRp(summary.balance),
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 16),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ), // Closes Column (body)
        ); // Closes Scaffold
      }, // Closes builder
    ); // Closes StreamBuilder
  }
}
