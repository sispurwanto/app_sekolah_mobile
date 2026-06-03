import 'package:flutter/material.dart';
import '../models/global_user_mapping.dart';

class UserProvider extends ChangeNotifier {
  GlobalUserMapping? _userMapping;

  GlobalUserMapping? get userMapping => _userMapping;

  void setUserMapping(GlobalUserMapping mapping) {
    _userMapping = mapping;
    // We use addPostFrameCallback or allow delayed notification if needed,
    // but typically notifyListeners is fine if called outside build.
    notifyListeners();
  }

  void clearUserMapping() {
    _userMapping = null;
    notifyListeners();
  }
}
