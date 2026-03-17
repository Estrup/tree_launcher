import 'package:flutter_test/flutter_test.dart';
import 'package:tree_launcher/models/terminal_session.dart';

void main() {
  group('TerminalSession command dispatch', () {
    test('uses carriage return for queued Windows commands', () {
      expect(
        TerminalSession.buildQueuedCommandInput('copilot', isWindows: true),
        'copilot\r',
      );
    });

    test('uses line feed for queued non-Windows commands', () {
      expect(
        TerminalSession.buildQueuedCommandInput('copilot', isWindows: false),
        'copilot\n',
      );
    });
  });
}
