import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:xterm/xterm.dart';
import 'package:tree_launcher/core/design_system/app_theme.dart';
import 'package:tree_launcher/features/terminal/domain/terminal_link.dart';

/// A link in the terminal: the cells it covers and what it opens. A path
/// target's path is absolute and exists.
class TerminalLink {
  const TerminalLink({
    required this.begin,
    required this.end,
    required this.target,
    this.isDirectory = false,
  });

  final CellOffset begin;

  /// The cell after the link's last one.
  final CellOffset end;
  final TerminalLinkTarget target;
  final bool isDirectory;

  @override
  bool operator ==(Object other) =>
      other is TerminalLink &&
      other.begin == begin &&
      other.end == end &&
      other.target == target;

  @override
  int get hashCode => Object.hash(begin, end, target);
}

/// The link at [cell] of [buffer], or null. The text searched is the
/// cell's whole line, with the rows it wraps onto; a relative path is
/// looked up from [workingDirectory].
TerminalLink? terminalLinkAt(
  Buffer buffer,
  CellOffset cell,
  String workingDirectory,
) {
  final lines = buffer.lines;
  if (cell.y < 0 || cell.y >= lines.length) return null;
  var first = cell.y;
  while (first > 0 && lines[first].isWrapped) {
    first--;
  }
  var last = cell.y;
  while (last + 1 < lines.length && lines[last + 1].isWrapped) {
    last++;
  }

  // The text, and the cell each of its UTF-16 code units comes from.
  final text = StringBuffer();
  final cells = <CellOffset>[];
  int? index;
  for (var y = first; y <= last; y++) {
    final line = lines[y];
    final end = y == last ? line.getTrimmedLength() : line.length;
    for (var x = 0; x < end; x++) {
      final codePoint = line.getCodePoint(x);
      final String char;
      if (codePoint != 0) {
        char = String.fromCharCode(codePoint);
      } else if (x == 0 || line.getWidth(x - 1) != 2) {
        char = ' ';
      } else {
        // The second half of a wide character.
        if (y == cell.y && x == cell.x) index = cells.length - 1;
        continue;
      }
      if (y == cell.y && x == cell.x) index = cells.length;
      text.write(char);
      for (var i = 0; i < char.length; i++) {
        cells.add(CellOffset(x, y));
      }
    }
  }
  if (index == null || index < 0) return null;

  final match = findTerminalLink(text.toString(), index);
  if (match == null) return null;
  final lastCell = cells[match.end - 1];
  final width = lines[lastCell.y].getWidth(lastCell.x);
  final begin = cells[match.start];
  final end = CellOffset(lastCell.x + (width < 1 ? 1 : width), lastCell.y);

  switch (match.target) {
    case UrlLinkTarget():
      return TerminalLink(begin: begin, end: end, target: match.target);
    case PathLinkTarget(:final path, :final line, :final column):
      final resolved = _resolve(path, workingDirectory);
      final type = FileSystemEntity.typeSync(resolved);
      if (type == FileSystemEntityType.notFound) return null;
      return TerminalLink(
        begin: begin,
        end: end,
        target: PathLinkTarget(resolved, line: line, column: column),
        isDirectory: type == FileSystemEntityType.directory,
      );
  }
}

String _resolve(String path, String workingDirectory) {
  if (path == '~' || path.startsWith('~/')) {
    final home = Platform.environment['HOME'];
    if (home != null) path = home + path.substring(1);
  }
  return p.normalize(
    p.isAbsolute(path) ? path : p.join(workingDirectory, path),
  );
}

/// Makes the URLs and existing paths in a terminal open on Cmd+click. While
/// Cmd is held, the link under the pointer is highlighted and the pointer
/// becomes a hand.
///
/// [builder] builds the [TerminalView], which must take [viewKey] and the
/// mouse cursor it is given. Clicks are caught here rather than through the
/// view's tap callback, so they work while the program in the terminal
/// reports the mouse (as the Claude CLI does).
class TerminalLinks extends StatefulWidget {
  const TerminalLinks({
    super.key,
    required this.terminal,
    required this.controller,
    required this.viewKey,
    required this.workingDirectory,
    required this.onOpen,
    required this.builder,
  });

  final Terminal terminal;
  final TerminalController controller;
  final GlobalKey<TerminalViewState> viewKey;
  final String workingDirectory;
  final ValueChanged<TerminalLink> onOpen;
  final Widget Function(BuildContext context, MouseCursor mouseCursor) builder;

  @override
  State<TerminalLinks> createState() => _TerminalLinksState();
}

class _TerminalLinksState extends State<TerminalLinks> {
  /// Where the pointer is, in global coordinates; null when it is outside.
  Offset? _pointer;
  TerminalLink? _hovered;

  /// The link a Cmd+press went down on, opened when it comes up on it too.
  TerminalLink? _pressed;
  TerminalHighlight? _highlight;
  CellAnchor? _highlightBegin;
  CellAnchor? _highlightEnd;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onKey);
    widget.terminal.addListener(_onTerminalChanged);
  }

  @override
  void didUpdateWidget(TerminalLinks oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.terminal != widget.terminal) {
      oldWidget.terminal.removeListener(_onTerminalChanged);
      widget.terminal.addListener(_onTerminalChanged);
      _setHovered(null);
    }
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    widget.terminal.removeListener(_onTerminalChanged);
    _clearHighlight();
    super.dispose();
  }

  bool _onKey(KeyEvent event) {
    if (event.logicalKey == LogicalKeyboardKey.metaLeft ||
        event.logicalKey == LogicalKeyboardKey.metaRight) {
      _update();
    }
    return false;
  }

  void _onTerminalChanged() {
    if (_hovered != null) _update();
  }

  /// The link under [position] (global), or null.
  TerminalLink? _linkAt(Offset position) {
    final render = widget.viewKey.currentState?.renderTerminal;
    if (render == null || !render.attached) return null;
    final local = render.globalToLocal(position);
    if (!(Offset.zero & render.size).contains(local)) return null;
    return terminalLinkAt(
      widget.terminal.buffer,
      render.getCellOffset(local),
      widget.workingDirectory,
    );
  }

  void _update() {
    final pointer = _pointer;
    _setHovered(
      pointer != null && HardwareKeyboard.instance.isMetaPressed
          ? _linkAt(pointer)
          : null,
    );
  }

  void _setHovered(TerminalLink? link) {
    if (link == _hovered) return;
    _clearHighlight();
    if (link != null) {
      final buffer = widget.terminal.buffer;
      _highlightBegin = buffer.createAnchorFromOffset(link.begin);
      _highlightEnd = buffer.createAnchorFromOffset(link.end);
      _highlight = widget.controller.highlight(
        p1: _highlightBegin!,
        p2: _highlightEnd!,
        color: AppColors.accent.withValues(alpha: 0.28),
      );
    }
    if (mounted) setState(() => _hovered = link);
  }

  void _clearHighlight() {
    _highlight?.dispose();
    _highlightBegin?.dispose();
    _highlightEnd?.dispose();
    _highlight = null;
    _highlightBegin = null;
    _highlightEnd = null;
  }

  void _onPointerDown(PointerDownEvent event) {
    _pressed =
        event.buttons == kPrimaryMouseButton &&
            HardwareKeyboard.instance.isMetaPressed
        ? _linkAt(event.position)
        : null;
  }

  void _onPointerUp(PointerUpEvent event) {
    final pressed = _pressed;
    _pressed = null;
    if (pressed == null || !HardwareKeyboard.instance.isMetaPressed) return;
    if (_linkAt(event.position) == pressed) widget.onOpen(pressed);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: _onPointerDown,
      onPointerUp: _onPointerUp,
      onPointerCancel: (_) => _pressed = null,
      child: MouseRegion(
        onHover: (event) {
          _pointer = event.position;
          _update();
        },
        onExit: (_) {
          _pointer = null;
          _setHovered(null);
        },
        child: widget.builder(
          context,
          _hovered != null ? SystemMouseCursors.click : SystemMouseCursors.text,
        ),
      ),
    );
  }
}
