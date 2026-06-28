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
import '../../../master_data/services/academic_year_service.dart';

class WaliDashboardView extends StatefulWidget {
  const WaliDashboardView({super.key});

  @override
  State<WaliDashboardView> createState() => _WaliDashboardViewState();
}

class _WaliDashboardViewState extends State<WaliDashboardView> {
  String? _activeYearId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadActiveYear();
  }

  Future<void> _loadActiveYear() async {
    final schoolId = context.read<SchoolProvider>().activeSchoolId ?? '';
    if (schoolId.isEmpty) return;
    final activeYear = await AcademicYearService().getActiveAcademicYear(schoolId);
    if (mounted && activeYear != null) {
      setState(() {
        _activeYearId = activeYear.id;
      });
    }
  }

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
                              if (_activeYearId != null)
                                StreamBuilder<DocumentSnapshot>(
                                  stream: FirebaseFirestore.instance
                                      .collection('schools')
                                      .doc(schoolId)
                                      .collection('transactions_year')
                                      .doc(_activeYearId)
                                      .collection('invoices')
                                      .doc(childId)
                                      .snapshots(),
                                  builder: (context, sumSnap) {
                                    if (!sumSnap.hasData || !sumSnap.data!.exists) {
                                      return const SizedBox.shrink();
                                    }
                                    final summary = sumSnap.data!.data() as Map<String, dynamic>;
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 12.0),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                                        decoration: BoxDecoration(
                                          color: Colors.grey.withOpacity(0.05),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: Colors.grey.withOpacity(0.2)),
                                        ),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: _buildStatItem('LUNAS', '${summary['paid_count'] ?? 0}', Colors.green),
                                            ),
                                            Expanded(
                                              child: _buildStatItem('DIANGSUR', '${summary['partial_count'] ?? 0}', Colors.orange),
                                            ),
                                            Expanded(
                                              child: _buildStatItem('BELUM LUNAS', '${summary['unpaid_count'] ?? 0}', Colors.red),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              const Divider(height: 1),
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
                                              academicYearId: null,
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

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            style: const TextStyle(fontSize: 10, color: Colors.grey),
            maxLines: 1,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
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
