import 'package:flutter/material.dart';
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

  testWidgets('switching the theme restyles the app; other settings don\'t', (
    WidgetTester tester,
  ) async {
    final dependencies = AppDependencies(
      database: testDatabase(),
      repoConfigStore: FakeRepoConfigStore(),
      appSettingsStore: FakeAppSettingsStore(),
    );
    await tester.runAsync(dependencies.loadState);
    await tester.pumpWidget(TreeLauncherApp(dependencies: dependencies));
    await tester.pumpAndSettle();
    ThemeData? theme() =>
        tester.widget<MaterialApp>(find.byType(MaterialApp)).theme;
    final muted = theme();

    await tester.runAsync(
      () => dependencies.settings.updateClaudeModelAndEffort('opus', 'max'),
    );
    await tester.pump();
    // Not rebuilt: the very same ThemeData.
    expect(identical(theme(), muted), isTrue);

    await tester.runAsync(() => dependencies.settings.updateTheme('light'));
    await tester.pump();
    expect(theme()!.brightness, Brightness.light);
    expect(muted!.brightness, Brightness.dark);
    await tester.runAsync(() => dependencies.settings.updateTheme('muted'));
  });
}
