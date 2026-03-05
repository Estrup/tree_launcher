import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:xterm/xterm.dart';

/// Intercepts Shift+Enter and sends the CSI u escape sequence (\x1b[13;2u)
/// so TUI CLIs can distinguish it from plain Enter for multi-line input.
KeyEventResult? terminalShiftEnterHandler(
  Terminal terminal,
  FocusNode node,
  KeyEvent event,
) {
  if (event is! KeyDownEvent && event is! KeyRepeatEvent) return null;
  if (event.logicalKey != LogicalKeyboardKey.enter) return null;
  if (!HardwareKeyboard.instance.isShiftPressed) return null;

  terminal.textInput('\x1b[13;2u');
  return KeyEventResult.handled;
}
