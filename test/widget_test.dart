import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:tree_launcher/app/dependencies.dart';
import 'package:tree_launcher/main.dart';

import 'fake_config_stores.dart';
import 'test_database.dart';

void main() {
  testWidgets('App renders TreeLauncher', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final dependencies = AppDependencies(
      database: testDatabase(),
      repoConfigStore: FakeRepoConfigStore(),
      appSettingsStore: FakeAppSettingsStore(),
    );
    await tester.runAsync(dependencies.loadState);

    await tester.pumpWidget(TreeLauncherApp(dependencies: dependencies));
    await tester.pumpAndSettle();

    expect(find.text('TreeLauncher'), findsAtLeastNWidgets(1));
  });
}
