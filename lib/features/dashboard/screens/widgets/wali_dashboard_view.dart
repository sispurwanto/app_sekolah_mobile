import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/providers/school_provider.dart';
import '../../../../core/models/app_user.dart';
import '../../../student_management/services/student_service.dart';
import '../../../../core/models/student.dart';
import '../../../invoices/screens/invoice_list_screen.dart';

class WaliDashboardView extends StatelessWidget {
  const WaliDashboardView({super.key});

  @override
  Widget build(BuildContext context) {
    final schoolId = context.watch<SchoolProvider>().activeSchoolId ?? '';
    final user = FirebaseAuth.instance.currentUser;

    if (user == null || schoolId.isEmpty) return const SizedBox.shrink();

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('schools')
          .doc(schoolId)
          .collection('users')
          .doc(user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError || !snapshot.hasData || !snapshot.data!.exists) {
          return const Center(child: Text('Data Wali tidak ditemukan'));
        }

        final appUser = AppUser.fromFirestore(snapshot.data!);
        final childrensMap = appUser.childrens;

        if (childrensMap.isEmpty) {
          return const Center(child: Text('Anda belum memiliki data anak terdaftar.'));
        }

        final childIds = childrensMap.keys.toList();
        final studentService = StudentService();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Daftar Anak Anda',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: childIds.length,
                itemBuilder: (context, index) {
                  final childId = childIds[index];
                  return StreamBuilder<Student?>(
                    stream: studentService.getStudentStream(schoolId, childId),
                    builder: (context, studentSnapshot) {
                      if (studentSnapshot.connectionState == ConnectionState.waiting) {
                        return const ListTile(title: Text('Memuat data anak...'));
                      }
                      
                      final student = studentSnapshot.data;
                      if (student == null) return const SizedBox.shrink();

                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: ListTile(
                          leading: const CircleAvatar(child: Icon(Icons.face)),
                          title: Text(student.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('Kelas: ${student.classId} | NIS: ${student.nis}'),
                          trailing: const Icon(Icons.arrow_forward_ios),
                          onTap: () {
                            Navigator.push(
                              context, 
                              MaterialPageRoute(
                                builder: (c) => InvoiceListScreen(
                                  studentId: childId,
                                  academicYearId: null, // Will automatically use active year in InvoiceListScreen
                                  classId: student.classId,
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
