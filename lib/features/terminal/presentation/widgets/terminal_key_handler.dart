import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:tree_launcher/features/terminal/domain/terminal_session.dart';

/// Intercepts terminal-specific shortcuts before they reach xterm.
KeyEventResult terminalKeyHandler(
  TerminalSession session,
  FocusNode node,
  KeyEvent event,
) {
  return handleTerminalKeyEvent(
        event,
        isShiftPressed: HardwareKeyboard.instance.isShiftPressed,
        isControlPressed: HardwareKeyboard.instance.isControlPressed,
        isAltPressed: HardwareKeyboard.instance.isAltPressed,
        isMetaPressed: HardwareKeyboard.instance.isMetaPressed,
        textInput: session.terminal.textInput,
        sendInterrupt: session.sendInterrupt,
      ) ??
      KeyEventResult.ignored;
}

/// Intercepts Shift+Enter and Ctrl+C so TUI CLIs can distinguish multiline
/// submit from plain Enter and Windows sessions receive an interrupt signal.
KeyEventResult? handleTerminalKeyEvent(
  KeyEvent event, {
  required bool isShiftPressed,
  required bool isControlPressed,
  required bool isAltPressed,
  required bool isMetaPressed,
  required void Function(String text) textInput,
  required VoidCallback sendInterrupt,
}) {
  if (event is! KeyDownEvent && event is! KeyRepeatEvent) return null;

  if (event.logicalKey == LogicalKeyboardKey.enter && isShiftPressed) {
    textInput('\x1b[13;2u');
    return KeyEventResult.handled;
  }

  if (event.logicalKey == LogicalKeyboardKey.keyC &&
      isControlPressed &&
      !isAltPressed &&
      !isMetaPressed) {
    sendInterrupt();
    return KeyEventResult.handled;
  }

  return null;
}
