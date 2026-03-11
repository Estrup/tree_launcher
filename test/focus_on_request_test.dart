import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tree_launcher/core/widgets/focus_on_request.dart';

void main() {
  testWidgets('requests focus when the request version changes', (
    WidgetTester tester,
  ) async {
    final focusNode = FocusNode(debugLabel: 'copilot-terminal-test');

    addTearDown(focusNode.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              const TextField(key: Key('other-field')),
              FocusOnRequest(
                focusNode: focusNode,
                isActive: false,
                requestVersion: 0,
                child: Focus(
                  focusNode: focusNode,
                  child: const SizedBox(height: 48, width: 48),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(const Key('other-field')));
    await tester.pumpAndSettle();

    expect(FocusManager.instance.primaryFocus, isNot(same(focusNode)));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              const TextField(key: Key('other-field')),
              FocusOnRequest(
                focusNode: focusNode,
                isActive: true,
                requestVersion: 1,
                child: Focus(
                  focusNode: focusNode,
                  child: const SizedBox(height: 48, width: 48),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(FocusManager.instance.primaryFocus, same(focusNode));
  });
}
