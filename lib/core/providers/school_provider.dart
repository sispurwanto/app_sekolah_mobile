import 'package:flutter/material.dart';

class SchoolProvider extends ChangeNotifier {
  String? _activeSchoolId;

  String? get activeSchoolId => _activeSchoolId;

  void setActiveSchool(String schoolId) {
    _activeSchoolId = schoolId;
    notifyListeners();
  }

  void clearActiveSchool() {
    _activeSchoolId = null;
    notifyListeners();
  }
}
