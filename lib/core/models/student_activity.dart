import 'package:cloud_firestore/cloud_firestore.dart';

class ActivityEntry {
  final String tgl; // ISO8601 string or specific date format
  final String name; // name_activity from Master
  final String keterangan;
  final String status;
  final String namaGuru; // email of the teacher

  ActivityEntry({
    required this.tgl,
    required this.name,
    required this.keterangan,
    required this.status,
    required this.namaGuru,
  });

  factory ActivityEntry.fromMap(Map<String, dynamic> map) {
    return ActivityEntry(
      tgl: map['tgl'] ?? '',
      name: map['name'] ?? '',
      keterangan: map['keterangan'] ?? '',
      status: map['status'] ?? '',
      namaGuru: map['nama_guru'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'tgl': tgl,
      'name': name,
      'keterangan': keterangan,
      'status': status,
      'nama_guru': namaGuru,
    };
  }
}

class StudentActivity {
  final String idSiswa;
  final String nameSiswa;
  final List<ActivityEntry> data;

  StudentActivity({
    required this.idSiswa,
    required this.nameSiswa,
    required this.data,
  });

  factory StudentActivity.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic>? firestoreData = doc.data() as Map<String, dynamic>?;
    
    if (firestoreData == null) {
      return StudentActivity(idSiswa: doc.id, nameSiswa: '', data: []);
    }

    var list = firestoreData['data'] as List<dynamic>? ?? [];
    List<ActivityEntry> dataList = list.map((i) => ActivityEntry.fromMap(i as Map<String, dynamic>)).toList();

    return StudentActivity(
      idSiswa: firestoreData['id_siswa'] ?? doc.id,
      nameSiswa: firestoreData['name_siswa'] ?? '',
      data: dataList,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id_siswa': idSiswa,
      'name_siswa': nameSiswa,
      'data': data.map((e) => e.toMap()).toList(),
    };
  }
}
