import 'package:flutter/material.dart';

import 'package:tree_launcher/core/design_system/app_theme.dart';

/// Global messenger key so non-widget code (e.g. background controllers) can
/// surface SnackBars. Assigned to `MaterialApp.scaffoldMessengerKey`.
final GlobalKey<ScaffoldMessengerState> appMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

/// How long a SnackBar with an action stays up.
const appSnackBarActionDuration = Duration(seconds: 15);

/// Shows a SnackBar from anywhere via [appMessengerKey], with an optional
/// [action] button. One with an action gets a close button and still goes
/// away by itself after [appSnackBarActionDuration] (Flutter would otherwise
/// keep it up until dismissed). No-op if the messenger isn't mounted yet.
void showAppSnackBar(String message, {SnackBarAction? action}) {
  final messenger = appMessengerKey.currentState;
  if (messenger == null) return;
  messenger
    ..clearSnackBars()
    ..showSnackBar(
      SnackBar(
        content: Text(message, style: TextStyle(color: AppColors.textPrimary)),
        action: action,
        persist: false,
        showCloseIcon: action != null,
        duration: action != null
            ? appSnackBarActionDuration
            : const Duration(milliseconds: 4000),
      ),
    );
}
