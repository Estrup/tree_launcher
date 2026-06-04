import 'package:flutter/material.dart';

import 'package:tree_launcher/app/app.dart';

Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(const TreeLauncherApp());
}
