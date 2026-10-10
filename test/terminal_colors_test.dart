import 'package:flutter_test/flutter_test.dart';
import 'package:tree_launcher/core/design_system/app_theme.dart';
import 'package:tree_launcher/features/terminal/presentation/controllers/terminal_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TerminalController terminal;

  setUp(() => terminal = TerminalController());
  tearDown(() {
    terminal.dispose();
    AppColors.setTheme('minimal');
  });

  test('sessions report the palette terminal colors', () {
    AppColors.setTheme('light');
    terminal.openTerminal('t', '/w/t', '/r');
    terminal.openClaudeSession('Claude: a', '/w/a', '/r', 'claude');

    for (final session in terminal.sessions) {
      expect(session.terminal.reportedBackground, 0xFFFFFF);
      expect(session.terminal.isDarkColorScheme, isFalse);
    }
  });

  test('syncColors follows a palette switch and notifies the app', () {
    AppColors.setTheme('light');
    terminal.openTerminal('t', '/w/t', '/r');
    final session = terminal.sessions.single.terminal;
    final output = <String>[];
    session.onOutput = output.add;
    // The app subscribes to light/dark changes (mode 2031).
    session.write('\x1b[?2031h');

    AppColors.setTheme('minimal');
    terminal.syncColors();

    expect(session.isDarkColorScheme, isTrue);
    expect(output, ['\x1b[?997;1n']);
  });
}
