import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../../core/models/savings.dart';
import '../../../../core/utils/currency_utils.dart';
import '../../../../core/utils/snackbar_utils.dart';
import '../../../../core/utils/currency_input_formatter.dart';
import '../../../../core/providers/school_provider.dart';
import '../../../../core/providers/user_provider.dart';
import '../services/savings_service.dart';

class SavingsScreen extends StatefulWidget {
  final String studentId;
  final String studentName;
  final String classId;

  const SavingsScreen({
    super.key,
    required this.studentId,
    required this.studentName,
    required this.classId,
  });

  @override
  State<SavingsScreen> createState() => _SavingsScreenState();
}

class _SavingsScreenState extends State<SavingsScreen> {
  final SavingsService _savingsService = SavingsService();

  void _showTransactionDialog(BuildContext context, String schoolId, String type, double currentBalance) {
    final amountController = TextEditingController();
    final noteController = TextEditingController();
    final isDeposit = type == 'DEPOSIT';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isDeposit ? 'Nabung (Setor)' : 'Tarik Tunai'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amountController,
              decoration: InputDecoration(
                labelText: 'Nominal (Rp)',
                prefixIcon: const Icon(Icons.payments),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [CurrencyInputFormatter()],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: noteController,
              decoration: InputDecoration(
                labelText: 'Keterangan (Opsional)',
                prefixIcon: const Icon(Icons.note),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: isDeposit ? Colors.green : Colors.red),
            onPressed: () async {
              final amountStr = amountController.text.replaceAll(RegExp(r'[^0-9]'), '');
              final amount = double.tryParse(amountStr) ?? 0.0;

              if (amount <= 0) {
                SnackbarUtils.showErrorSnackbar('Nominal tidak valid.');
                return;
              }

              if (!isDeposit && amount > currentBalance) {
                SnackbarUtils.showErrorSnackbar('Saldo tidak mencukupi.');
                return;
              }

              Navigator.pop(context);
              try {
                await _savingsService.addTransaction(
                  schoolId: schoolId,
                  studentId: widget.studentId,
                  studentName: widget.studentName,
                  classId: widget.classId,
                  type: type,
                  amount: amount,
                  note: noteController.text,
                  date: DateTime.now(),
                );
                SnackbarUtils.showSnackbar('Transaksi berhasil dicatat.');
              } catch (e) {
                SnackbarUtils.showErrorSnackbar('Gagal: $e');
              }
            },
            child: Text('Simpan', style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showActionOptions(BuildContext context, String schoolId, double currentBalance) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildActionItem(
                context: context,
                icon: Icons.add_circle,
                color: Colors.green,
                label: 'Nabung',
                onTap: () {
                  Navigator.pop(context);
                  _showTransactionDialog(context, schoolId, 'DEPOSIT', currentBalance);
                },
              ),
              _buildActionItem(
                context: context,
                icon: Icons.remove_circle,
                color: Colors.red,
                label: 'Tarik Tunai',
                onTap: () {
                  Navigator.pop(context);
                  _showTransactionDialog(context, schoolId, 'WITHDRAWAL', currentBalance);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionItem({required BuildContext context, required IconData icon, required Color color, required String label, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: color.withValues(alpha: 0.1),
              child: Icon(icon, color: color, size: 36),
            ),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final schoolId = context.watch<SchoolProvider>().activeSchoolId ?? '';
    final userMapping = context.watch<UserProvider>().userMapping;
    final role = userMapping?.registeredSchools[schoolId];
    final isWali = role == 'WALI';

    return Scaffold(
      appBar: AppBar(
        title: Text('Tabungan - ${widget.studentName}'),
        elevation: 0,
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Header / Summary Card
          StreamBuilder<SavingsSummary?>(
            stream: _savingsService.getSavingsSummaryStream(schoolId, widget.studentId),
            builder: (context, snapshot) {
              final summary = snapshot.data ?? SavingsSummary(
                studentId: widget.studentId,
                studentName: widget.studentName,
                classId: widget.classId,
              );

              return Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF2E7D32), Color(0xFF4CAF50)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)),
                ),
                child: Column(
                  children: [
                    const Text('Total Saldo Saat Ini', style: TextStyle(color: Colors.white70, fontSize: 16)),
                    const SizedBox(height: 8),
                    Text(
                      CurrencyUtils.formatRp(summary.balance),
                      style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildSummaryStat('Total Nabung', summary.totalDeposit, Colors.greenAccent),
                        _buildSummaryStat('Total Penarikan', summary.totalWithdrawal, Colors.redAccent),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
          // Transactions List
          Expanded(
            child: StreamBuilder<List<SavingsTransaction>>(
              stream: _savingsService.getTransactionsStream(schoolId, widget.studentId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final transactions = snapshot.data ?? [];
                if (transactions.isEmpty) {
                  return const Center(
                    child: Text('Belum ada riwayat transaksi.', style: TextStyle(color: Colors.grey)),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: transactions.length,
                  itemBuilder: (context, index) {
                    final t = transactions[index];
                    final isDeposit = t.type == 'DEPOSIT';
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isDeposit ? Colors.green.shade50 : Colors.red.shade50,
                          child: Icon(
                            isDeposit ? Icons.arrow_downward : Icons.arrow_upward,
                            color: isDeposit ? Colors.green : Colors.red,
                          ),
                        ),
                        title: Text(isDeposit ? 'Setor Tabungan' : 'Tarik Tunai', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(DateFormat('dd MMM yyyy, HH:mm').format(t.date), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                            if (t.note.isNotEmpty) Text(t.note, style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
                          ],
                        ),
                        trailing: Text(
                          '${isDeposit ? '+' : '-'} ${CurrencyUtils.formatRp(t.amount)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isDeposit ? Colors.green : Colors.red,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: isWali ? null : StreamBuilder<SavingsSummary?>(
        stream: _savingsService.getSavingsSummaryStream(schoolId, widget.studentId),
        builder: (context, snapshot) {
          final balance = snapshot.data?.balance ?? 0.0;
          return FloatingActionButton.extended(
            onPressed: () => _showActionOptions(context, schoolId, balance),
            icon: const Icon(Icons.account_balance_wallet),
            label: const Text('Transaksi', style: TextStyle(color: Colors.white)),
            backgroundColor: const Color(0xFF2E7D32),
            foregroundColor: Colors.white,
          );
        },
      ),
    );
  }

  Widget _buildSummaryStat(String label, double amount, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        const SizedBox(height: 4),
        Text(
          CurrencyUtils.formatRp(amount),
          style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
