import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xterm/xterm.dart';
import 'package:tree_launcher/features/terminal/domain/terminal_link.dart';
import 'package:tree_launcher/features/terminal/presentation/widgets/terminal_links.dart';

void main() {
  const url = 'https://github.com/a/b/pull/7140';

  Future<
    ({TerminalController controller, List<TerminalLink> opened, Offset at})
  >
  pump(WidgetTester tester, String output) async {
    final terminal = Terminal();
    final controller = TerminalController();
    final viewKey = GlobalKey<TerminalViewState>();
    final opened = <TerminalLink>[];
    await tester.pumpWidget(
      MaterialApp(
        home: TerminalLinks(
          terminal: terminal,
          controller: controller,
          viewKey: viewKey,
          workingDirectory: '/tmp',
          onOpen: opened.add,
          builder: (context, mouseCursor) => TerminalView(
            terminal,
            key: viewKey,
            controller: controller,
            mouseCursor: mouseCursor,
            hardwareKeyboardOnly: true,
          ),
        ),
      ),
    );
    terminal.write(output);
    await tester.pump();
    final render = viewKey.currentState!.renderTerminal;
    final column = output
        .replaceAll(RegExp(r'\x1b\[[?0-9;]*[a-zA-Z]'), '')
        .indexOf('pull');
    final at = render.localToGlobal(
      render.getOffset(CellOffset(column, 0)) + const Offset(2, 4),
    );
    return (controller: controller, opened: opened, at: at);
  }

  Future<void> cmdClick(WidgetTester tester, Offset at) async {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: at);
    await mouse.moveTo(at);
    await tester.pump();
  }

  for (final mouseReporting in [false, true]) {
    testWidgets('Cmd+hover highlights and Cmd+click opens '
        '(mouse reporting $mouseReporting)', (tester) async {
      final setup = await pump(
        tester,
        '${mouseReporting ? '\x1b[?1000h\x1b[?1006h' : ''}PR: $url (base)',
      );
      await cmdClick(tester, setup.at);
      expect(setup.controller.highlights, hasLength(1));

      await tester.tapAt(setup.at, kind: PointerDeviceKind.mouse);
      await tester.pump(const Duration(milliseconds: 500));
      expect(setup.opened.map((l) => l.target), [const UrlLinkTarget(url)]);

      await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
      await tester.pump();
      expect(setup.controller.highlights, isEmpty);
    });
  }

  testWidgets('a click without Cmd opens nothing', (tester) async {
    final setup = await pump(tester, 'PR: $url');
    await tester.tapAt(setup.at, kind: PointerDeviceKind.mouse);
    await tester.pump(const Duration(milliseconds: 500));
    expect(setup.opened, isEmpty);
    expect(setup.controller.highlights, isEmpty);
  });
}
