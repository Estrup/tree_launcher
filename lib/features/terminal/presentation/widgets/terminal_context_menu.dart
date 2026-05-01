import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:xterm/xterm.dart';

enum TerminalContextMenuAction { copy, paste, selectAll }

Future<void> showTerminalContextMenu({
  required BuildContext context,
  required Offset position,
  required Terminal terminal,
  required TerminalController controller,
}) async {
  final selection = controller.selection;
  final selectedText = selection == null
      ? ''
      : terminal.buffer.getText(selection);
  final canCopy = selectedText.isNotEmpty;

  final action = await showMenu<TerminalContextMenuAction>(
    context: context,
    position: RelativeRect.fromLTRB(
      position.dx,
      position.dy,
      position.dx,
      position.dy,
    ),
    items: [
      PopupMenuItem(
        value: TerminalContextMenuAction.copy,
        enabled: canCopy,
        child: const Text('Copy'),
      ),
      const PopupMenuItem(
        value: TerminalContextMenuAction.paste,
        child: Text('Paste'),
      ),
      const PopupMenuItem(
        value: TerminalContextMenuAction.selectAll,
        child: Text('Select all'),
      ),
    ],
  );

  switch (action) {
    case TerminalContextMenuAction.copy:
      await copyTerminalSelection(terminal, controller);
      break;
    case TerminalContextMenuAction.paste:
      await pasteIntoTerminal(terminal, controller);
      break;
    case TerminalContextMenuAction.selectAll:
      selectAllTerminalText(terminal, controller);
      break;
    case null:
      break;
  }
}

Future<bool> copyTerminalSelection(
  Terminal terminal,
  TerminalController controller,
) async {
  final selection = controller.selection;
  if (selection == null) {
    return false;
  }

  final text = terminal.buffer.getText(selection);
  if (text.isEmpty) {
    return false;
  }

  await Clipboard.setData(ClipboardData(text: text));
  return true;
}

Future<bool> pasteIntoTerminal(
  Terminal terminal,
  TerminalController controller,
) async {
  final data = await Clipboard.getData(Clipboard.kTextPlain);
  final text = data?.text;
  if (text == null) {
    return false;
  }

  terminal.paste(text);
  controller.clearSelection();
  return true;
}

void selectAllTerminalText(Terminal terminal, TerminalController controller) {
  controller.setSelection(
    terminal.buffer.createAnchor(
      0,
      terminal.buffer.height - terminal.viewHeight,
    ),
    terminal.buffer.createAnchor(
      terminal.viewWidth,
      terminal.buffer.height - 1,
    ),
    mode: SelectionMode.line,
  );
}
