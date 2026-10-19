import 'package:flutter/material.dart';

import 'package:tree_launcher/app/app.dart';
import 'package:tree_launcher/app/dependencies.dart';

Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();

  final dependencies = AppDependencies();
  // Import the pre-database files before anything reads the stores.
  await dependencies.prepareDatabase();
  // Start the loopback agent API. startServers() never throws, but guard
  // anyway so nothing here can block runApp.
  try {
    await dependencies.startServers();
  } catch (_) {
    // Already logged inside the server; the app runs fine without it.
  }

  runApp(TreeLauncherApp(dependencies: dependencies));
}
