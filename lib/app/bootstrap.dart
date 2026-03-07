import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:marionette_flutter/marionette_flutter.dart';

import 'package:tree_launcher/app/app.dart';
import 'package:tree_launcher/features/kanban/data/database_service.dart';

Future<void> bootstrap() async {
  if (kDebugMode) {
    MarionetteBinding.ensureInitialized();
  } else {
    WidgetsFlutterBinding.ensureInitialized();
  }

  await DatabaseService.instance.initialize();
  runApp(const TreeLauncherApp());
}
