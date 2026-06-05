import 'package:flutter/material.dart';

import 'package:tree_launcher/core/design_system/app_theme.dart';

/// Global messenger key so non-widget code (e.g. background controllers) can
/// surface SnackBars. Assigned to `MaterialApp.scaffoldMessengerKey`.
final GlobalKey<ScaffoldMessengerState> appMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

/// Shows a SnackBar from anywhere via [appMessengerKey]. No-op if the messenger
/// isn't mounted yet.
void showAppSnackBar(String message) {
  final messenger = appMessengerKey.currentState;
  if (messenger == null) return;
  messenger
    ..clearSnackBars()
    ..showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: TextStyle(color: AppColors.textPrimary),
        ),
      ),
    );
}
