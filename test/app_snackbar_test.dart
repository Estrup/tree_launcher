import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tree_launcher/core/design_system/app_snackbar.dart';

void main() {
  testWidgets('a notice with an action can be closed and goes away by itself', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        scaffoldMessengerKey: appMessengerKey,
        home: const Scaffold(),
      ),
    );

    showAppSnackBar(
      'Started Claude: main',
      action: SnackBarAction(label: 'Show', onPressed: () {}),
    );
    await tester.pumpAndSettle();
    expect(find.text('Started Claude: main'), findsOneWidget);
    expect(find.byIcon(Icons.close), findsOneWidget);

    await tester.pump(const Duration(seconds: 14));
    expect(find.text('Started Claude: main'), findsOneWidget);

    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.text('Started Claude: main'), findsNothing);
  });
}
