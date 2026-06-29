import 'dart:io';
import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/models/student.dart';

class StudentImportService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> generateTemplate() async {
    var excel = Excel.createExcel();
    Sheet sheetObject = excel['Sheet1'];

    // Header
    List<CellValue> dataList = [
      TextCellValue('NIS'),
      TextCellValue('Nama'),
      TextCellValue('NISN'),
      TextCellValue('Jenis Kelamin (L/P)')
    ];
    sheetObject.insertRowIterables(dataList, 0);

    // Dummy data
    sheetObject.insertRowIterables([
      TextCellValue('12345'),
      TextCellValue('Budi Santoso'),
      TextCellValue('0012345678'),
      TextCellValue('L')
    ], 1);
    sheetObject.insertRowIterables([
      TextCellValue('12346'),
      TextCellValue('Siti Aminah'),
      TextCellValue('0012345679'),
      TextCellValue('P')
    ], 2);

    // Save
    var fileBytes = excel.save();
    if (fileBytes != null) {
      // Use FilePicker to save the file directly to the user's chosen folder (e.g. Downloads)
      await FilePicker.saveFile(
        dialogTitle: 'Simpan Template Import Siswa',
        fileName: 'Template_Import_Siswa.xlsx',
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
        bytes: Uint8List.fromList(fileBytes),
      );
    }
  }

  Future<Map<String, dynamic>> importStudents(
    String schoolId,
    String academicYearId,
    String classId,
    String filePath,
  ) async {
    var bytes = File(filePath).readAsBytesSync();
    var excel = Excel.decodeBytes(bytes);

    int successCount = 0;
    int skippedCount = 0;
    final batch = _db.batch();
    final uid = FirebaseAuth.instance.currentUser?.uid;

    for (var table in excel.tables.keys) {
      var sheet = excel.tables[table]!;
      for (var i = 1; i < sheet.maxRows; i++) { // Skip header at index 0
        var row = sheet.row(i);
        if (row.isEmpty) continue;
        
        // Cek jika baris kosong semua (menghindari error baca baris kosong dari excel)
        bool isEmptyRow = true;
        for (var cell in row) {
          if (cell != null && cell.value != null && cell.value.toString().trim().isNotEmpty) {
            isEmptyRow = false;
            break;
          }
        }
        if (isEmptyRow) continue;

        String nis = row.isNotEmpty && row[0]?.value != null ? row[0]!.value.toString().trim() : '';
        String name = row.length > 1 && row[1]?.value != null ? row[1]!.value.toString().trim() : '';
        String nisn = row.length > 2 && row[2]?.value != null ? row[2]!.value.toString().trim() : '';
        String gender = row.length > 3 && row[3]?.value != null ? row[3]!.value.toString().trim().toUpperCase() : 'L';

        if (nis.isEmpty || name.isEmpty) {
          skippedCount++;
          continue; // Wajib ada NIS dan Nama
        }
        
        if (gender != 'L' && gender != 'P') {
           gender = 'L'; // Default
        }

        // Check if NIS exists
        final studentDoc = await _db
            .collection('schools')
            .doc(schoolId)
            .collection('students')
            .doc(nis)
            .get();

        if (studentDoc.exists) {
          skippedCount++; // Skip if NIS already exists
          continue;
        }

        final student = Student(
          id: nis, // Use NIS as ID
          nis: nis,
          nisn: nisn,
          name: name,
          gender: gender,
          birthDate: DateTime.now(), // Default birth date
          classId: classId,
          guardianId: '', // Blank initially
          academicYearId: academicYearId,
          status: 'ACTIVE',
        );

        final studentRef = _db
            .collection('schools')
            .doc(schoolId)
            .collection('students')
            .doc(nis);

        final studentData = student.toMap();
        studentData['created_at'] = FieldValue.serverTimestamp();
        studentData['created_by'] = uid;
        studentData['updated_at'] = FieldValue.serverTimestamp();
        studentData['updated_by'] = uid;

        batch.set(studentRef, studentData);
        successCount++;
      }
    }

    if (successCount > 0) {
      await batch.commit();
    }

    return {
      'success': successCount,
      'skipped': skippedCount,
    };
  }
}
