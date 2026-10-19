import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';

import 'package:tree_launcher/app/app.dart';
import 'package:tree_launcher/app/dependencies.dart';

/// Longest the app waits for its cleanup when quitting.
const _exitCleanupTimeout = Duration(seconds: 2);

Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();

  final dependencies = AppDependencies();
  // Import the pre-database files before anything reads the stores.
  await dependencies.prepareDatabase();
  await dependencies.loadState();
  // Start the loopback agent API. startServers() never throws, but guard
  // anyway so nothing here can block runApp.
  try {
    await dependencies.startServers();
  } catch (_) {
    // Already logged inside the server; the app runs fine without it.
  }

  // Close the database and stop the API when the app quits. Kept for the
  // app's lifetime, so never disposed.
  AppLifecycleListener(
    onExitRequested: () async {
      try {
        await dependencies.dispose().timeout(_exitCleanupTimeout);
      } catch (e) {
        debugPrint('Cleanup on quit failed: $e');
      }
      return AppExitResponse.exit;
    },
  );

  runApp(TreeLauncherApp(dependencies: dependencies));
}
