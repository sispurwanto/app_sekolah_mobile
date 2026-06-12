import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/providers/school_provider.dart';
import '../../../../core/models/app_user.dart';
import '../../../student_management/services/student_service.dart';
import '../../../../core/models/student.dart';
import '../../../invoices/screens/invoice_list_screen.dart';
import '../../../activities/screens/student_activity_screen.dart';
import '../../../../core/utils/snackbar_utils.dart';
import '../../../savings/screens/savings_screen.dart';
import '../../../grades/screens/parent_grade_screen.dart';
import '../../../grades/screens/parent_report_screen.dart';

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
          return const Center(
            child: Text('Anda belum memiliki data anak terdaftar.'),
          );
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
                      if (studentSnapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const ListTile(
                          title: Text('Memuat data anak...'),
                        );
                      }

                      final student = studentSnapshot.data;
                      if (student == null) return const SizedBox.shrink();

                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            children: [
                              ListTile(
                                leading: const CircleAvatar(
                                  child: Icon(Icons.face),
                                ),
                                title: Text(
                                  student.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Text(
                                  'Kelas: ${student.classId} | NIS: ${student.nis}',
                                ),
                              ),
                              const Divider(),
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: [
                                    _buildActionButton(
                                      context,
                                      Icons.receipt_long,
                                      'Tagihan',
                                      () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (c) => InvoiceListScreen(
                                              studentId: childId,
                                              academicYearId:
                                                  null, // Will automatically use active year in InvoiceListScreen
                                              classId: student.classId,
                                            ),
                                          ),
                                        );
                                      },
                                      Colors.blue,
                                    ),
                                    const SizedBox(width: 8),
                                    _buildActionButton(
                                      context,
                                      Icons.account_balance_wallet,
                                      'Tabungan',
                                      () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (c) => SavingsScreen(
                                              studentId: childId,
                                              studentName: student.name,
                                              classId: student.classId,
                                            ),
                                          ),
                                        );
                                      },
                                      Colors.teal,
                                    ),
                                    const SizedBox(width: 8),
                                    _buildActionButton(
                                      context,
                                      Icons.local_activity,
                                      'Kegiatan',
                                      () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (c) =>
                                                StudentActivityScreen(
                                                  student: student,
                                                  isReadOnly: true,
                                                ),
                                          ),
                                        );
                                      },
                                      Colors.orange,
                                    ),
                                    const SizedBox(width: 8),
                                    _buildActionButton(
                                      context,
                                      Icons.assignment,
                                      'Nilai',
                                      () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (c) => ParentGradeScreen(
                                              studentId: childId,
                                              studentName: student.name,
                                            ),
                                          ),
                                        );
                                      },
                                      Colors.green,
                                    ),
                                    const SizedBox(width: 8),
                                    _buildActionButton(
                                      context,
                                      Icons.library_books,
                                      'Raport',
                                      () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (c) => ParentReportScreen(
                                              studentId: childId,
                                              studentName: student.name,
                                            ),
                                          ),
                                        );
                                      },
                                      Colors.orange,
                                    ),
                                    // const SizedBox(width: 8),
                                    // _buildActionButton(context, Icons.fact_check, 'Absensi', () {
                                    //   SnackbarUtils.showErrorSnackbar('Modul Absensi sedang dalam pengembangan');
                                    // }, Colors.purple),
                                  ],
                                ),
                              ),
                            ],
                          ),
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

  Widget _buildActionButton(
    BuildContext context,
    IconData icon,
    String label,
    VoidCallback onTap,
    Color color,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 10)),
          ],
        ),
      ),
    );
  }
}
