import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import '../../../core/models/payment.dart';
import '../../../core/models/invoice.dart';
import '../../../core/models/savings.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../core/utils/snackbar_utils.dart';

class ExportService {
  final currencyFormat = NumberFormat.currency(
    locale: 'id',
    symbol: 'Rp ',
    decimalDigits: 0,
  );
  final dateFormat = DateFormat('dd MMM yyyy');

  // EXPORT PDF GABUNGAN
  Future<void> exportCombinedFinancialPdf(
    BuildContext context,
    List<Payment> payments,
    List<Invoice> arrears,
    DateTime start,
    DateTime end,
  ) async {
    final pdf = pw.Document();

    double totalIncome = payments.fold(0, (sum, p) => sum + p.amount);
    double totalArrears = arrears.fold(
      0,
      (sum, inv) => sum + (inv.amount - inv.paidAmount),
    );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context ctx) {
          return [
            pw.Header(
              level: 0,
              child: pw.Text(
                'Laporan Pembayaran',
                style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.Text(
              'Periode: ${dateFormat.format(start)} - ${dateFormat.format(end)}',
            ),
            pw.SizedBox(height: 20),

            // Lunas Section
            pw.Text(
              'Siswa Membayar (${payments.length} Pembayaran)',
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.green,
              ),
            ),
            pw.Text('Total Pembayaran: ${CurrencyUtils.formatRp(totalIncome)}'),
            pw.SizedBox(height: 10),
            if (payments.isNotEmpty)
              pw.TableHelper.fromTextArray(
                context: ctx,
                headers: [
                  'Tanggal',
                  'Siswa',
                  'Kelas',
                  'Keterangan',
                  'Nominal',
                  'Metode',
                ],
                data: payments
                    .map(
                      (p) => [
                        p.createdAt != null
                            ? dateFormat.format(p.createdAt!)
                            : '-',
                        p.studentName,
                        p.classId,
                        p.invoiceTitle.isNotEmpty
                            ? p.invoiceTitle
                            : 'Pembayaran',
                        CurrencyUtils.formatRp(p.amount),
                        p.method,
                      ],
                    )
                    .toList(),
              )
            else
              pw.Text('Tidak ada data pembayaran.'),

            pw.SizedBox(height: 30),

            // Tidak Bayar Section
            pw.Text(
              'Siswa Tidak Bayar (${arrears.length} Siswa)',
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.red,
              ),
            ),
            pw.Text('Total Tunggakan: ${CurrencyUtils.formatRp(totalArrears)}'),
            pw.SizedBox(height: 10),
            if (arrears.isNotEmpty)
              pw.TableHelper.fromTextArray(
                context: ctx,
                headers: [
                  'Jatuh Tempo',
                  'Siswa',
                  'Kelas',
                  'Tagihan',
                  'Sisa Tunggakan',
                  'Status',
                ],
                data: arrears
                    .map(
                      (inv) => [
                        inv.dueDate != null
                            ? dateFormat.format(inv.dueDate!)
                            : '-',
                        inv.studentName,
                        inv.classId,
                        inv.title,
                        CurrencyUtils.formatRp(inv.amount - inv.paidAmount),
                        inv.status,
                      ],
                    )
                    .toList(),
              )
            else
              pw.Text('Tidak ada data siswa tidak bayar.'),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name:
          'Laporan_Pembayaran_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf',
    );
  }

  // EXPORT EXCEL GABUNGAN
  Future<void> exportCombinedFinancialExcel(
    BuildContext context,
    List<Payment> payments,
    List<Invoice> arrears,
    DateTime start,
    DateTime end,
  ) async {
    try {
      var excel = Excel.createExcel();
      var sheet = excel['Laporan'];
      excel.setDefaultSheet('Laporan');

      sheet.appendRow([TextCellValue('Laporan Pembayaran')]);
      sheet.appendRow([
        TextCellValue(
          'Periode: ${dateFormat.format(start)} - ${dateFormat.format(end)}',
        ),
      ]);
      sheet.appendRow([TextCellValue('')]);

      // Pembayaran
      double totalIncome = payments.fold(0, (sum, p) => sum + p.amount);
      sheet.appendRow([
        TextCellValue('Siswa Membayar (${payments.length} Pembayaran)'),
      ]);
      sheet.appendRow([
        TextCellValue(
          'Total Pembayaran: ${CurrencyUtils.formatRp(totalIncome)}',
        ),
      ]);
      sheet.appendRow([
        TextCellValue('Tanggal'),
        TextCellValue('Siswa'),
        TextCellValue('Kelas'),
        TextCellValue('Keterangan'),
        TextCellValue('Nominal'),
        TextCellValue('Metode'),
      ]);

      for (var p in payments) {
        sheet.appendRow([
          TextCellValue(
            p.createdAt != null ? dateFormat.format(p.createdAt!) : '-',
          ),
          TextCellValue(p.studentName),
          TextCellValue(p.classId),
          TextCellValue(
            p.invoiceTitle.isNotEmpty ? p.invoiceTitle : 'Pembayaran',
          ),
          DoubleCellValue(p.amount),
          TextCellValue(p.method),
        ]);
      }

      sheet.appendRow([TextCellValue('')]);
      sheet.appendRow([TextCellValue('')]);

      // Tunggakan
      double totalArrears = arrears.fold(
        0,
        (sum, inv) => sum + (inv.amount - inv.paidAmount),
      );
      sheet.appendRow([
        TextCellValue('Siswa Tidak Bayar (${arrears.length} Siswa)'),
      ]);
      sheet.appendRow([
        TextCellValue(
          'Total Tunggakan: ${CurrencyUtils.formatRp(totalArrears)}',
        ),
      ]);
      sheet.appendRow([
        TextCellValue('Jatuh Tempo'),
        TextCellValue('Siswa'),
        TextCellValue('Kelas'),
        TextCellValue('Tagihan'),
        TextCellValue('Sisa Tunggakan'),
        TextCellValue('Status'),
      ]);

      for (var inv in arrears) {
        sheet.appendRow([
          TextCellValue(
            inv.dueDate != null ? dateFormat.format(inv.dueDate!) : '-',
          ),
          TextCellValue(inv.studentName),
          TextCellValue(inv.classId),
          TextCellValue(inv.title),
          DoubleCellValue(inv.amount - inv.paidAmount),
          TextCellValue(inv.status),
        ]);
      }

      var fileBytes = excel.save();
      if (fileBytes != null) {
        final directory = await getApplicationDocumentsDirectory();
        final path =
            '${directory.path}/Laporan_Pembayaran_${DateFormat('yyyyMMdd').format(DateTime.now())}.xlsx';
        File(path)
          ..createSync(recursive: true)
          ..writeAsBytesSync(fileBytes);

        if (context.mounted) {
          SnackbarUtils.showSnackbar('Membuka file Excel...');
          // ignore: deprecated_member_use
          await Share.shareXFiles([XFile(path)], text: 'Laporan Pembayaran');
        }
      }
    } catch (e) {
      if (context.mounted) {
        SnackbarUtils.showErrorSnackbar('Gagal export Excel: $e');
      }
    }
  }

  // EXPORT PDF PEMASUKAN
  Future<void> exportIncomePdf(
    BuildContext context,
    List<Payment> payments,
    DateTime start,
    DateTime end,
  ) async {
    final pdf = pw.Document();

    double total = payments.fold(0, (sum, p) => sum + p.amount);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context ctx) {
          return [
            pw.Header(
              level: 0,
              child: pw.Text(
                'Laporan Pemasukan',
                style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.Text(
              'Periode: ${dateFormat.format(start)} - ${dateFormat.format(end)}',
            ),
            pw.Text(
              'Total Pemasukan: ${CurrencyUtils.formatRp(total)}',
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 20),
            pw.TableHelper.fromTextArray(
              context: ctx,
              headers: ['Tanggal', 'Siswa', 'Kelas', 'Nominal', 'Metode'],
              data: payments
                  .map(
                    (p) => [
                      p.createdAt != null
                          ? dateFormat.format(p.createdAt!)
                          : '-',
                      p.studentName,
                      p.classId,
                      CurrencyUtils.formatRp(p.amount),
                      p.method,
                    ],
                  )
                  .toList(),
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name:
          'Laporan_Pemasukan_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf',
    );
  }

  // EXPORT EXCEL PEMASUKAN
  Future<void> exportIncomeExcel(
    BuildContext context,
    List<Payment> payments,
    DateTime start,
    DateTime end,
  ) async {
    try {
      var excel = Excel.createExcel();
      var sheet = excel['Pemasukan'];
      excel.setDefaultSheet('Pemasukan');

      sheet.appendRow([TextCellValue('Laporan Pemasukan')]);
      sheet.appendRow([
        TextCellValue(
          'Periode: ${dateFormat.format(start)} - ${dateFormat.format(end)}',
        ),
      ]);
      sheet.appendRow([TextCellValue('')]);

      sheet.appendRow([
        TextCellValue('Tanggal'),
        TextCellValue('Siswa'),
        TextCellValue('Kelas'),
        TextCellValue('Nominal'),
        TextCellValue('Metode'),
      ]);

      for (var p in payments) {
        sheet.appendRow([
          TextCellValue(
            p.createdAt != null ? dateFormat.format(p.createdAt!) : '-',
          ),
          TextCellValue(p.studentName),
          TextCellValue(p.classId),
          DoubleCellValue(p.amount),
          TextCellValue(p.method),
        ]);
      }

      var fileBytes = excel.save();
      if (fileBytes != null) {
        final directory = await getApplicationDocumentsDirectory();
        final path =
            '${directory.path}/Laporan_Pemasukan_${DateFormat('yyyyMMdd').format(DateTime.now())}.xlsx';
        File(path)
          ..createSync(recursive: true)
          ..writeAsBytesSync(fileBytes);

        if (context.mounted) {
          SnackbarUtils.showSnackbar('Membuka file Excel...');
          await Share.shareXFiles([XFile(path)], text: 'Laporan Pemasukan');
        }
      }
    } catch (e) {
      if (context.mounted) {
        SnackbarUtils.showErrorSnackbar('Gagal export Excel: $e');
      }
    }
  }

  // EXPORT PDF TUNGGAKAN
  Future<void> exportArrearsPdf(
    BuildContext context,
    List<Invoice> invoices,
    DateTime start,
    DateTime end,
  ) async {
    final pdf = pw.Document();

    double total = invoices.fold(
      0,
      (sum, inv) => sum + (inv.amount - inv.paidAmount),
    );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context ctx) {
          return [
            pw.Header(
              level: 0,
              child: pw.Text(
                'Laporan Tunggakan',
                style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.Text(
              'Tenggat Waktu: ${dateFormat.format(start)} - ${dateFormat.format(end)}',
            ),
            pw.Text(
              'Total Tunggakan: ${CurrencyUtils.formatRp(total)}',
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.red,
              ),
            ),
            pw.SizedBox(height: 20),
            pw.TableHelper.fromTextArray(
              context: ctx,
              headers: [
                'Jatuh Tempo',
                'Siswa',
                'Kelas',
                'Tagihan',
                'Sisa Tunggakan',
                'Status',
              ],
              data: invoices
                  .map(
                    (inv) => [
                      inv.dueDate != null
                          ? dateFormat.format(inv.dueDate!)
                          : '-',
                      inv.studentName,
                      inv.classId,
                      inv.title,
                      CurrencyUtils.formatRp(inv.amount - inv.paidAmount),
                      inv.status,
                    ],
                  )
                  .toList(),
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name:
          'Laporan_Tunggakan_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf',
    );
  }

  // EXPORT EXCEL TUNGGAKAN
  Future<void> exportArrearsExcel(
    BuildContext context,
    List<Invoice> invoices,
    DateTime start,
    DateTime end,
  ) async {
    try {
      var excel = Excel.createExcel();
      var sheet = excel['Tunggakan'];
      excel.setDefaultSheet('Tunggakan');

      sheet.appendRow([TextCellValue('Laporan Tunggakan')]);
      sheet.appendRow([
        TextCellValue(
          'Tenggat Waktu: ${dateFormat.format(start)} - ${dateFormat.format(end)}',
        ),
      ]);
      sheet.appendRow([TextCellValue('')]);

      sheet.appendRow([
        TextCellValue('Jatuh Tempo'),
        TextCellValue('Siswa'),
        TextCellValue('Kelas'),
        TextCellValue('Judul Tagihan'),
        TextCellValue('Sisa Tunggakan'),
        TextCellValue('Status'),
      ]);

      for (var inv in invoices) {
        sheet.appendRow([
          TextCellValue(
            inv.dueDate != null ? dateFormat.format(inv.dueDate!) : '-',
          ),
          TextCellValue(inv.studentName),
          TextCellValue(inv.classId),
          TextCellValue(inv.title),
          DoubleCellValue(inv.amount - inv.paidAmount),
          TextCellValue(inv.status),
        ]);
      }

      var fileBytes = excel.save();
      if (fileBytes != null) {
        final directory = await getApplicationDocumentsDirectory();
        final path =
            '${directory.path}/Laporan_Tunggakan_${DateFormat('yyyyMMdd').format(DateTime.now())}.xlsx';
        File(path)
          ..createSync(recursive: true)
          ..writeAsBytesSync(fileBytes);

        if (context.mounted) {
          SnackbarUtils.showSnackbar('Membuka file Excel...');
          await Share.shareXFiles([XFile(path)], text: 'Laporan Tunggakan');
        }
      }
    } catch (e) {
      if (context.mounted) {
        SnackbarUtils.showErrorSnackbar('Gagal export Excel: $e');
      }
    }
  }

  // EXPORT PDF TABUNGAN
  Future<void> exportSavingsPdf(
    BuildContext context,
    List<SavingsSummary> summaries,
  ) async {
    final pdf = pw.Document();

    double total = summaries.fold(0, (sum, s) => sum + s.balance);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context ctx) {
          return [
            pw.Header(
              level: 0,
              child: pw.Text(
                'Laporan Tabungan Siswa',
                style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.Text('Tanggal Cetak: ${dateFormat.format(DateTime.now())}'),
            pw.Text(
              'Total Tabungan: ${CurrencyUtils.formatRp(total)}',
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.green,
              ),
            ),
            pw.SizedBox(height: 20),
            pw.TableHelper.fromTextArray(
              context: ctx,
              headers: [
                'Nama Siswa',
                'Kelas',
                'Total Nabung',
                'Total Tarik',
                'Saldo Akhir',
              ],
              data: summaries
                  .map(
                    (s) => [
                      s.studentName,
                      s.classId,
                      CurrencyUtils.formatRp(s.totalDeposit),
                      CurrencyUtils.formatRp(s.totalWithdrawal),
                      CurrencyUtils.formatRp(s.balance),
                    ],
                  )
                  .toList(),
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name:
          'Laporan_Tabungan_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf',
    );
  }

  // EXPORT EXCEL TABUNGAN
  Future<void> exportSavingsExcel(
    BuildContext context,
    List<SavingsSummary> summaries,
  ) async {
    try {
      var excel = Excel.createExcel();
      var sheet = excel['Tabungan'];
      excel.setDefaultSheet('Tabungan');

      sheet.appendRow([TextCellValue('Laporan Tabungan Siswa')]);
      sheet.appendRow([
        TextCellValue('Tanggal Cetak: ${dateFormat.format(DateTime.now())}'),
      ]);
      sheet.appendRow([TextCellValue('')]);

      sheet.appendRow([
        TextCellValue('Nama Siswa'),
        TextCellValue('Kelas'),
        TextCellValue('Total Nabung'),
        TextCellValue('Total Tarik'),
        TextCellValue('Saldo Akhir'),
      ]);

      for (var s in summaries) {
        sheet.appendRow([
          TextCellValue(s.studentName),
          TextCellValue(s.classId),
          DoubleCellValue(s.totalDeposit),
          DoubleCellValue(s.totalWithdrawal),
          DoubleCellValue(s.balance),
        ]);
      }

      var fileBytes = excel.save();
      if (fileBytes != null) {
        final directory = await getApplicationDocumentsDirectory();
        final path =
            '${directory.path}/Laporan_Tabungan_${DateFormat('yyyyMMdd').format(DateTime.now())}.xlsx';
        File(path)
          ..createSync(recursive: true)
          ..writeAsBytesSync(fileBytes);

        if (context.mounted) {
          SnackbarUtils.showSnackbar('Membuka file Excel...');
          await Share.shareXFiles([XFile(path)], text: 'Laporan Tabungan');
        }
      }
    } catch (e) {
      if (context.mounted) {
        SnackbarUtils.showErrorSnackbar('Gagal export Excel: $e');
      }
    }
  }
}
