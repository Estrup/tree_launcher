import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tree_launcher/features/terminal/presentation/widgets/terminal_context_menu.dart';
import 'package:xterm/xterm.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  String? clipboardText;

  setUp(() {
    clipboardText = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          switch (call.method) {
            case 'Clipboard.setData':
              final data = call.arguments as Map<Object?, Object?>;
              clipboardText = data['text'] as String?;
              return null;
            case 'Clipboard.getData':
              return clipboardText == null ? null : {'text': clipboardText};
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  test('copies selected terminal text', () async {
    final terminal = Terminal();
    final controller = TerminalController();
    addTearDown(controller.dispose);

    terminal.write('hello world');
    controller.setSelection(
      terminal.buffer.createAnchor(0, 0),
      terminal.buffer.createAnchor(5, 0),
    );

    final copied = await copyTerminalSelection(terminal, controller);
    final clipboard = await Clipboard.getData(Clipboard.kTextPlain);

    expect(copied, isTrue);
    expect(clipboard?.text, 'hello');
  });

  test('pastes clipboard text into terminal input', () async {
    var output = '';
    final terminal = Terminal(onOutput: (data) => output += data);
    final controller = TerminalController();
    addTearDown(controller.dispose);

    await Clipboard.setData(const ClipboardData(text: 'paste me'));

    final pasted = await pasteIntoTerminal(terminal, controller);

    expect(pasted, isTrue);
    expect(output, 'paste me');
  });

  test('selects all terminal text', () {
    final terminal = Terminal();
    final controller = TerminalController();
    addTearDown(controller.dispose);

    terminal.write('alpha\nbeta');

    selectAllTerminalText(terminal, controller);

    final selection = controller.selection;
    expect(selection, isNotNull);
    expect(terminal.buffer.getText(selection!), contains('alpha'));
    expect(terminal.buffer.getText(selection), contains('beta'));
  });
}
