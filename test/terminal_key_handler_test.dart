import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tree_launcher/features/terminal/presentation/widgets/terminal_key_handler.dart';

KeyDownEvent _keyDown(
  LogicalKeyboardKey logicalKey,
  PhysicalKeyboardKey physicalKey,
) {
  return KeyDownEvent(
    logicalKey: logicalKey,
    physicalKey: physicalKey,
    timeStamp: Duration.zero,
  );
}

void main() {
  group('handleTerminalKeyEvent', () {
    test('sends the kitty Shift+Enter sequence', () {
      final inputs = <String>[];
      var interrupted = false;

      final result = handleTerminalKeyEvent(
        _keyDown(LogicalKeyboardKey.enter, PhysicalKeyboardKey.enter),
        isShiftPressed: true,
        isControlPressed: false,
        isAltPressed: false,
        isMetaPressed: false,
        textInput: inputs.add,
        sendInterrupt: () => interrupted = true,
      );

      expect(result, KeyEventResult.handled);
      expect(inputs, ['\x1b[13;2u']);
      expect(interrupted, isFalse);
    });

    test('maps Ctrl+C to an interrupt', () {
      final inputs = <String>[];
      var interrupted = false;

      final result = handleTerminalKeyEvent(
        _keyDown(LogicalKeyboardKey.keyC, PhysicalKeyboardKey.keyC),
        isShiftPressed: false,
        isControlPressed: true,
        isAltPressed: false,
        isMetaPressed: false,
        textInput: inputs.add,
        sendInterrupt: () => interrupted = true,
      );

      expect(result, KeyEventResult.handled);
      expect(inputs, isEmpty);
      expect(interrupted, isTrue);
    });

    test('ignores unrelated keys', () {
      final result = handleTerminalKeyEvent(
        _keyDown(LogicalKeyboardKey.keyA, PhysicalKeyboardKey.keyA),
        isShiftPressed: false,
        isControlPressed: false,
        isAltPressed: false,
        isMetaPressed: false,
        textInput: (_) {},
        sendInterrupt: () {},
      );

      expect(result, isNull);
    });
  });
}
