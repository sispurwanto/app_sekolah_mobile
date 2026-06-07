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
import '../../../core/utils/currency_utils.dart';
import '../../../core/utils/snackbar_utils.dart';

class ExportService {
  final currencyFormat = NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0);
  final dateFormat = DateFormat('dd MMM yyyy');

  // EXPORT PDF PEMASUKAN
  Future<void> exportIncomePdf(BuildContext context, List<Payment> payments, DateTime start, DateTime end) async {
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
              child: pw.Text('Laporan Pemasukan', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
            ),
            pw.Text('Periode: ${dateFormat.format(start)} - ${dateFormat.format(end)}'),
            pw.Text('Total Pemasukan: ${CurrencyUtils.formatRp(total)}', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 20),
            pw.TableHelper.fromTextArray(
              context: ctx,
              headers: ['Tanggal', 'Siswa', 'Kelas', 'Nominal', 'Metode'],
              data: payments.map((p) => [
                p.createdAt != null ? dateFormat.format(p.createdAt!) : '-',
                p.studentName,
                p.classId,
                CurrencyUtils.formatRp(p.amount),
                p.method,
              ]).toList(),
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Laporan_Pemasukan_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf',
    );
  }

  // EXPORT EXCEL PEMASUKAN
  Future<void> exportIncomeExcel(BuildContext context, List<Payment> payments, DateTime start, DateTime end) async {
    try {
      var excel = Excel.createExcel();
      var sheet = excel['Pemasukan'];
      excel.setDefaultSheet('Pemasukan');

      sheet.appendRow([TextCellValue('Laporan Pemasukan')]);
      sheet.appendRow([TextCellValue('Periode: ${dateFormat.format(start)} - ${dateFormat.format(end)}')]);
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
          TextCellValue(p.createdAt != null ? dateFormat.format(p.createdAt!) : '-'),
          TextCellValue(p.studentName),
          TextCellValue(p.classId),
          DoubleCellValue(p.amount),
          TextCellValue(p.method),
        ]);
      }

      var fileBytes = excel.save();
      if (fileBytes != null) {
        final directory = await getApplicationDocumentsDirectory();
        final path = '${directory.path}/Laporan_Pemasukan_${DateFormat('yyyyMMdd').format(DateTime.now())}.xlsx';
        File(path)
          ..createSync(recursive: true)
          ..writeAsBytesSync(fileBytes);
        
        if (context.mounted) {
          SnackbarUtils.showSnackbar('Excel disimpan di: $path');
        }
      }
    } catch (e) {
      if (context.mounted) {
        SnackbarUtils.showErrorSnackbar('Gagal export Excel: $e');
      }
    }
  }

  // EXPORT PDF TUNGGAKAN
  Future<void> exportArrearsPdf(BuildContext context, List<Invoice> invoices, DateTime start, DateTime end) async {
    final pdf = pw.Document();

    double total = invoices.fold(0, (sum, inv) => sum + (inv.amount - inv.paidAmount));

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context ctx) {
          return [
            pw.Header(
              level: 0,
              child: pw.Text('Laporan Tunggakan', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
            ),
            pw.Text('Tenggat Waktu: ${dateFormat.format(start)} - ${dateFormat.format(end)}'),
            pw.Text('Total Tunggakan: ${CurrencyUtils.formatRp(total)}', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.red)),
            pw.SizedBox(height: 20),
            pw.TableHelper.fromTextArray(
              context: ctx,
              headers: ['Jatuh Tempo', 'Siswa', 'Kelas', 'Tagihan', 'Sisa Tunggakan', 'Status'],
              data: invoices.map((inv) => [
                inv.dueDate != null ? dateFormat.format(inv.dueDate!) : '-',
                inv.studentName,
                inv.classId,
                inv.title,
                CurrencyUtils.formatRp(inv.amount - inv.paidAmount),
                inv.status,
              ]).toList(),
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Laporan_Tunggakan_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf',
    );
  }

  // EXPORT EXCEL TUNGGAKAN
  Future<void> exportArrearsExcel(BuildContext context, List<Invoice> invoices, DateTime start, DateTime end) async {
    try {
      var excel = Excel.createExcel();
      var sheet = excel['Tunggakan'];
      excel.setDefaultSheet('Tunggakan');

      sheet.appendRow([TextCellValue('Laporan Tunggakan')]);
      sheet.appendRow([TextCellValue('Tenggat Waktu: ${dateFormat.format(start)} - ${dateFormat.format(end)}')]);
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
          TextCellValue(inv.dueDate != null ? dateFormat.format(inv.dueDate!) : '-'),
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
        final path = '${directory.path}/Laporan_Tunggakan_${DateFormat('yyyyMMdd').format(DateTime.now())}.xlsx';
        File(path)
          ..createSync(recursive: true)
          ..writeAsBytesSync(fileBytes);
        
        if (context.mounted) {
          SnackbarUtils.showSnackbar('Excel disimpan di: $path');
        }
      }
    } catch (e) {
      if (context.mounted) {
        SnackbarUtils.showErrorSnackbar('Gagal export Excel: $e');
      }
    }
  }
}
