import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tree_launcher/core/design_system/app_snackbar.dart';
import 'package:tree_launcher/core/design_system/app_theme.dart';
import 'package:tree_launcher/core/widgets/issue_list.dart';

void main() {
  Future<void> pump(WidgetTester tester, IssueBulkAction onAction) =>
      tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.current,
          scaffoldMessengerKey: appMessengerKey,
          home: Scaffold(
            body: IssueBulkBar(
              count: 2,
              actionLabel: 'Change state',
              onAction: onAction,
              onClear: () {},
            ),
          ),
        ),
      );

  testWidgets('shows an action\'s error and is ready again', (tester) async {
    var runs = 0;
    await pump(tester, (context, setBusy) async {
      runs++;
      setBusy(true);
      throw Exception('GitHub is down');
    });
    expect(find.text('2 selected'), findsOneWidget);

    await tester.tap(find.text('Change state'));
    await tester.pump();
    expect(find.text('GitHub is down'), findsOneWidget);

    await tester.tap(find.text('Change state'));
    await tester.pump();
    expect(runs, 2);
  });
}
