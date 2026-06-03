import 'package:flutter/material.dart';

class SnackbarUtils {
  // Global key for the scaffold messenger
  static final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

  /// Show a general info or success snackbar
  static void showSnackbar(String message, {Duration duration = const Duration(seconds: 3)}) {
    scaffoldMessengerKey.currentState?.hideCurrentSnackBar();
    scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text(message),
        duration: duration,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Show an error snackbar with red background
  static void showErrorSnackbar(String message, {Duration duration = const Duration(seconds: 4)}) {
    scaffoldMessengerKey.currentState?.hideCurrentSnackBar();
    scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.red.shade600,
        duration: duration,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
