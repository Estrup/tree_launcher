import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:tree_launcher/features/session_panel/presentation/controllers/session_panel_controller.dart';
import 'package:tree_launcher/features/session_panel/presentation/widgets/session_panel_split.dart';
import 'package:tree_launcher/features/workspace/data/git_service.dart';

/// Counts its states, to tell a kept terminal view from a rebuilt one.
class _Terminal extends StatefulWidget {
  const _Terminal();

  static int created = 0;

  @override
  State<_Terminal> createState() => _TerminalState();
}

class _TerminalState extends State<_Terminal> {
  @override
  void initState() {
    super.initState();
    _Terminal.created++;
  }

  @override
  Widget build(BuildContext context) => const ColoredBox(color: Colors.black);
}

void main() {
  late SessionPanelController controller;

  setUp(() {
    controller = SessionPanelController(git: GitService());
    _Terminal.created = 0;
  });

  tearDown(() => controller.dispose());

  Future<void> pump(WidgetTester tester, {required bool panel}) async {
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: controller,
        child: MaterialApp(
          home: Scaffold(
            body: SessionPanelSplit(
              terminal: const _Terminal(),
              panel: panel ? const SizedBox.expand(key: Key('panel')) : null,
            ),
          ),
        ),
      ),
    );
  }

  double panelWidth(WidgetTester tester) =>
      tester.getSize(find.byKey(const Key('panel'))).width;

  testWidgets('dragging the handle sets the width on release', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pump(tester, panel: true);
    expect(panelWidth(tester), SessionPanelController.defaultWidth);

    final handle = find.byKey(const ValueKey('session-panel-handle'));
    final gesture = await tester.startGesture(tester.getCenter(handle));
    await gesture.moveBy(const Offset(-20, 0));
    await gesture.moveBy(const Offset(-100, 0));
    await tester.pump();
    // Only the guide line moves while dragging.
    expect(panelWidth(tester), SessionPanelController.defaultWidth);

    await gesture.up();
    // Past the handle's double-tap timeout.
    await tester.pump(const Duration(milliseconds: 500));
    // The first 20px go to winning the drag gesture.
    expect(controller.width, closeTo(480, 20));
    expect(panelWidth(tester), controller.width);
  });

  testWidgets('leaves the panel out when the view is too narrow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(600, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pump(tester, panel: true);

    expect(find.byKey(const Key('panel')), findsNothing);
    expect(find.byType(_Terminal), findsOneWidget);
  });

  testWidgets('keeps the terminal view when the panel shows and hides', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await pump(tester, panel: false);
    await pump(tester, panel: true);
    await pump(tester, panel: false);

    expect(_Terminal.created, 1);
  });
}
