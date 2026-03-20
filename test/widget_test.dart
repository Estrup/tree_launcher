import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:tree_launcher/main.dart';

void main() {
  testWidgets('App renders TreeLauncher', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const TreeLauncherApp());
    await tester.pumpAndSettle();

    expect(find.text('TreeLauncher'), findsAtLeastNWidgets(1));
  });
}
