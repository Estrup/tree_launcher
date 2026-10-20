import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import 'package:tree_launcher/core/design_system/app_theme.dart';
import 'package:tree_launcher/core/errors/user_message.dart';
import 'package:tree_launcher/core/platform/launcher_service.dart';
import 'package:tree_launcher/core/platform/open_external.dart';
import 'package:tree_launcher/features/documents/domain/session_document.dart';
import 'package:tree_launcher/features/documents/presentation/widgets/document_view.dart';
import 'package:tree_launcher/features/session_panel/data/worktree_file_system.dart';
import 'package:tree_launcher/features/session_panel/domain/file_content.dart';
import 'package:tree_launcher/features/session_panel/presentation/controllers/session_panel_controller.dart';
import 'package:tree_launcher/features/session_panel/presentation/controllers/worktree_files_controller.dart';

/// One open file, read-only: Markdown and HTML rendered (their source a
/// toggle away), PDFs and images shown, other text with line numbers. It
/// shows the file again when it changes on disk.
class FileTabView extends StatefulWidget {
  const FileTabView({super.key, required this.worktree, required this.path});

  final String worktree;
  final String path;

  @override
  State<FileTabView> createState() => _FileTabViewState();
}

class _FileTabViewState extends State<FileTabView> {
  late WorktreeFilesController _files;
  StreamSubscription<Set<String>>? _changes;

  /// Bumped when the file changes on disk, to show it again.
  int _version = 0;
  bool _showSource = false;

  /// The text read for the current [_version]; null while reading.
  FileContent? _content;
  List<String>? _lines;
  String? _readError;

  /// The path and version the last read was started for.
  String? _readFor;

  FileViewKind get _kind => FileViewKind.forPath(widget.path);

  /// Whether the file shows as text (rather than in the web view or as an
  /// image).
  bool get _showsText =>
      _kind == FileViewKind.text || (_kind.hasSource && _showSource);

  @override
  void initState() {
    super.initState();
    _watch();
  }

  @override
  void didUpdateWidget(FileTabView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.worktree != widget.worktree) {
      _unwatch();
      _watch();
    }
    if (oldWidget.path != widget.path) {
      _showSource = false;
      _forgetContent();
    }
  }

  @override
  void dispose() {
    _unwatch();
    super.dispose();
  }

  void _watch() {
    _files = context.read<SessionPanelController>().filesFor(widget.worktree)
      ..attach();
    _changes = _files.changes.listen((paths) {
      if (!paths.contains(widget.path)) return;
      if (_kind == FileViewKind.image) {
        unawaited(FileImage(File(widget.path)).evict());
      }
      setState(() {
        _version++;
        _forgetContent();
      });
    });
  }

  void _unwatch() {
    unawaited(_changes?.cancel());
    _files.detach();
  }

  void _forgetContent() {
    _content = null;
    _lines = null;
    _readError = null;
  }

  /// Reads the file as text for the current [_version], once.
  void _readIfNeeded() {
    final version = _version;
    final path = widget.path;
    final key = '$version:$path';
    if (_readFor == key) return;
    _readFor = key;
    context
        .read<SessionPanelController>()
        .readFile(path)
        .then(
          (content) {
            if (!mounted || version != _version || path != widget.path) return;
            setState(() {
              _content = content;
              _lines = content is TextFileContent ? content.lines : null;
            });
          },
          onError: (Object e) {
            if (!mounted || version != _version || path != widget.path) return;
            setState(() => _readError = userMessage(e));
          },
        );
  }

  @override
  Widget build(BuildContext context) {
    if (_showsText) _readIfNeeded();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Toolbar(
          relativePath: p.relative(widget.path, from: widget.worktree),
          kind: _kind,
          showSource: _showSource,
          onToggleSource: () => setState(() => _showSource = !_showSource),
          onOpenInVsCode: () => context
              .read<LauncherService?>()
              ?.openFileInVSCode(widget.worktree, widget.path),
          onReveal: () => revealInFinder(widget.path),
        ),
        Expanded(child: _body()),
      ],
    );
  }

  Widget _body() {
    if (_showsText) return _textBody();
    return switch (_kind) {
      FileViewKind.image => Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Image.file(
            File(widget.path),
            key: ValueKey(_version),
            errorBuilder: (_, _, _) => const _NotShown("Couldn't show it"),
          ),
        ),
      ),
      _ => DocumentView(
        filePath: widget.path,
        format: switch (_kind) {
          FileViewKind.html => DocumentFormat.html,
          FileViewKind.pdf => DocumentFormat.pdf,
          _ => DocumentFormat.markdown,
        },
        title: p.basename(widget.path),
        renderedPath: _renderedPath(widget.path),
        version: _version,
      ),
    };
  }

  Widget _textBody() {
    final error = _readError;
    if (error != null) return _NotShown(error);
    final content = _content;
    return switch (content) {
      null => const SizedBox.shrink(),
      TextFileContent() => _TextLines(lines: _lines!),
      TooLargeFileContent(:final sizeBytes) => _NotShown(
        'Too large to show here (${_megabytes(sizeBytes)} MB; up to '
        '${_megabytes(WorktreeFileSystem.maxTextBytes)} MB shows).',
      ),
      BinaryFileContent() => const _NotShown('Not a text file.'),
    };
  }
}

/// Where Markdown at [path] is rendered for the web view: outside the
/// worktree, so viewing a file never writes into it.
String _renderedPath(String path) {
  final key = path.hashCode.toUnsigned(32).toRadixString(16);
  return p.join(
    Directory.systemTemp.path,
    'tree_launcher_view',
    '$key-${p.basenameWithoutExtension(path)}.html',
  );
}

String _megabytes(int bytes) => (bytes / (1024 * 1024)).toStringAsFixed(1);

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.relativePath,
    required this.kind,
    required this.showSource,
    required this.onToggleSource,
    required this.onOpenInVsCode,
    required this.onReveal,
  });

  final String relativePath;
  final FileViewKind kind;
  final bool showSource;
  final VoidCallback onToggleSource;
  final VoidCallback onOpenInVsCode;
  final VoidCallback onReveal;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 30,
      padding: const EdgeInsets.only(left: 12, right: 4),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.borderSubtle)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Tooltip(
              message: relativePath,
              waitDuration: const Duration(milliseconds: 600),
              child: Text(
                relativePath,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: AppColors.textMuted),
              ),
            ),
          ),
          if (kind.hasSource)
            _ToolbarButton(
              icon: showSource ? Icons.visibility_outlined : Icons.code_rounded,
              tooltip: showSource ? 'Show rendered' : 'Show source',
              onPressed: onToggleSource,
            ),
          _ToolbarButton(
            icon: Icons.open_in_new_rounded,
            tooltip: 'Open in VS Code',
            onPressed: onOpenInVsCode,
          ),
          _ToolbarButton(
            icon: Icons.folder_open_outlined,
            tooltip: 'Reveal in Finder',
            onPressed: onReveal,
          ),
        ],
      ),
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  const _ToolbarButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 24,
      height: 24,
      child: IconButton(
        tooltip: tooltip,
        padding: EdgeInsets.zero,
        iconSize: 14,
        onPressed: onPressed,
        icon: Icon(icon, color: AppColors.textMuted),
      ),
    );
  }
}

/// Text with line numbers, wrapped to the panel. The text can be selected;
/// the numbers can't.
class _TextLines extends StatelessWidget {
  const _TextLines({required this.lines});

  final List<String> lines;

  static const _fontSize = 12.0;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontFamily: 'SF Mono',
      fontFamilyFallback: const ['Menlo'],
      fontSize: _fontSize,
      height: 1.5,
      color: AppColors.textPrimary,
    );
    final numberStyle = style.copyWith(color: AppColors.textMuted);
    // Room for the longest line number.
    final gutter = '${lines.length}'.length * _fontSize * 0.62 + 16;

    return ColoredBox(
      color: AppColors.base,
      child: SelectionArea(
        child: ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: lines.length,
          itemBuilder: (context, index) => Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SelectionContainer.disabled(
                child: SizedBox(
                  width: gutter,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Text(
                      '${index + 1}',
                      textAlign: TextAlign.right,
                      style: numberStyle,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 12),
                  // Tabs as spaces: Text draws a tab as one narrow space.
                  child: Text(
                    lines[index].replaceAll('\t', '    '),
                    style: style,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Why the file isn't shown, with the ways to open it elsewhere above.
class _NotShown extends StatelessWidget {
  const _NotShown(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.visibility_off_outlined,
              size: 26,
              color: AppColors.textMuted,
            ),
            const SizedBox(height: 8),
            Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
            const SizedBox(height: 4),
            Text(
              'Open it in VS Code or Finder from the toolbar.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}
