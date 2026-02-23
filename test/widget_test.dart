import 'package:flutter_test/flutter_test.dart';

import 'package:tree_launcher/main.dart';

void main() {
  testWidgets('App renders TreeLauncher', (WidgetTester tester) async {
    await tester.pumpWidget(const TreeLauncherApp());
    expect(find.text('TreeLauncher'), findsOneWidget);
  });
}
