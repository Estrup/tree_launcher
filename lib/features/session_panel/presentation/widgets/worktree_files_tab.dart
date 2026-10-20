import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import 'package:tree_launcher/core/design_system/app_snackbar.dart';
import 'package:tree_launcher/core/design_system/app_theme.dart';
import 'package:tree_launcher/core/platform/launcher_service.dart';
import 'package:tree_launcher/core/platform/open_external.dart';
import 'package:tree_launcher/features/session_panel/data/worktree_file_system.dart';
import 'package:tree_launcher/features/session_panel/presentation/controllers/session_panel_controller.dart';
import 'package:tree_launcher/features/session_panel/presentation/controllers/worktree_files_controller.dart';
import 'package:tree_launcher/features/session_panel/presentation/widgets/file_icons.dart';

/// The worktree's files as a tree: everything on disk, gitignored entries
/// dimmed. A folder opens on click and a file opens in a tab of the panel.
/// The filter box shows the matches under their folders; clicking a folder
/// there shows it in the whole tree.
class WorktreeFilesTab extends StatefulWidget {
  const WorktreeFilesTab({super.key, required this.worktree});

  final String worktree;

  static const rowHeight = 24.0;
  static const indent = 12.0;

  @override
  State<WorktreeFilesTab> createState() => _WorktreeFilesTabState();
}

class _WorktreeFilesTabState extends State<WorktreeFilesTab> {
  late WorktreeFilesController _files;
  final _filterText = TextEditingController();

  @override
  void initState() {
    super.initState();
    _files = context.read<SessionPanelController>().filesFor(widget.worktree)
      ..attach();
    _filterText.text = _files.filter;
  }

  @override
  void didUpdateWidget(WorktreeFilesTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.worktree != widget.worktree) {
      _files.detach();
      _files = context.read<SessionPanelController>().filesFor(widget.worktree)
        ..attach();
      _filterText.text = _files.filter;
    }
  }

  @override
  void dispose() {
    _files.detach();
    _filterText.dispose();
    super.dispose();
  }

  void _clearFilter() {
    _filterText.clear();
    _files.setFilter('');
  }

  /// Ends filtering and shows [row]'s entry in the whole tree.
  void _reveal(FileTreeRow row) {
    _filterText.clear();
    _files.reveal(row.entry.path, isDirectory: row.entry.isDirectory);
  }

  @override
  Widget build(BuildContext context) {
    final panel = context.watch<SessionPanelController>();
    final selectedPath = panel.selectedFor(widget.worktree).path;

    return ListenableBuilder(
      listenable: _files,
      builder: (context, _) {
        final rows = _files.rows;
        final filtering = _files.isFiltering;
        final query = _files.filter.trim();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Toolbar(
              name: p.basename(widget.worktree),
              onCollapseAll: _files.collapseAll,
              onRefresh: _files.refresh,
            ),
            _FilterField(
              controller: _filterText,
              onChanged: _files.setFilter,
              onClear: _clearFilter,
            ),
            if (filtering && !_files.isWalking)
              _FilterNote(
                matches: _files.matchCount,
                truncated: _files.isFilterTruncated,
              ),
            Expanded(
              child: _files.error != null
                  ? _Message(_files.error!, color: AppColors.error)
                  : _files.isLoading
                  ? const _Message('Reading…')
                  : _files.isWalking
                  ? const _Message('Searching…')
                  : rows.isEmpty
                  ? _Message(filtering ? 'No matches' : 'No files')
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      itemExtent: WorktreeFilesTab.rowHeight,
                      itemCount: rows.length,
                      itemBuilder: (context, index) {
                        final row = rows[index];
                        return _FileRow(
                          row: row,
                          selected: row.entry.path == selectedPath,
                          highlight: filtering && row.isMatch ? query : null,
                          onTap: () => !row.entry.isDirectory
                              ? panel.openFile(widget.worktree, row.entry.path)
                              : filtering
                              ? _reveal(row)
                              : _files.toggle(row.entry.path),
                          onContextMenu: (position) =>
                              _showMenu(context, position, row),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showMenu(
    BuildContext context,
    Offset position,
    FileTreeRow row,
  ) async {
    final path = row.entry.path;
    final launcher = context.read<LauncherService?>();
    final panel = context.read<SessionPanelController>();
    final action = await showMenu<_MenuAction>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx,
        position.dy,
      ),
      items: [
        if (!row.entry.isDirectory)
          const PopupMenuItem(value: _MenuAction.open, child: Text('Open')),
        if (_files.isFiltering)
          const PopupMenuItem(
            value: _MenuAction.showInTree,
            child: Text('Show in tree'),
          ),
        if (launcher != null)
          const PopupMenuItem(
            value: _MenuAction.vscode,
            child: Text('Open in VS Code'),
          ),
        const PopupMenuItem(
          value: _MenuAction.reveal,
          child: Text('Reveal in Finder'),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: _MenuAction.copyPath,
          child: Text('Copy path'),
        ),
        const PopupMenuItem(
          value: _MenuAction.copyRelativePath,
          child: Text('Copy relative path'),
        ),
      ],
    );
    if (!mounted) return;
    switch (action) {
      case _MenuAction.open:
        panel.openFile(widget.worktree, path);
      case _MenuAction.showInTree:
        _reveal(row);
      case _MenuAction.vscode:
        launcher?.openFileInVSCode(widget.worktree, path);
      case _MenuAction.reveal:
        revealInFinder(path);
      case _MenuAction.copyPath:
        _copy(path);
      case _MenuAction.copyRelativePath:
        _copy(p.relative(path, from: widget.worktree));
      case null:
        break;
    }
  }

  void _copy(String text) {
    Clipboard.setData(ClipboardData(text: text));
    showAppSnackBar('Copied $text');
  }
}

enum _MenuAction {
  open,
  showInTree,
  vscode,
  reveal,
  copyPath,
  copyRelativePath,
}

/// The filter box. Escape clears it.
class _FilterField extends StatelessWidget {
  const _FilterField({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
      child: CallbackShortcuts(
        bindings: {const SingleActivator(LogicalKeyboardKey.escape): onClear},
        child: SizedBox(
          height: 28,
          child: ValueListenableBuilder(
            valueListenable: controller,
            builder: (context, value, _) => TextField(
              controller: controller,
              onChanged: onChanged,
              style: TextStyle(fontSize: 12, color: AppColors.textPrimary),
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Filter files (a / searches paths)',
                hintStyle: TextStyle(fontSize: 12, color: AppColors.textMuted),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  size: 15,
                  color: AppColors.textMuted,
                ),
                prefixIconConstraints: const BoxConstraints(minWidth: 30),
                suffixIcon: value.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear',
                        iconSize: 13,
                        padding: EdgeInsets.zero,
                        onPressed: onClear,
                        icon: Icon(
                          Icons.close_rounded,
                          color: AppColors.textMuted,
                        ),
                      ),
                suffixIconConstraints: const BoxConstraints(
                  minWidth: 28,
                  minHeight: 28,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 7),
                filled: true,
                fillColor: AppColors.base,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: AppColors.accent),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// How many entries match, and whether the search stopped early.
class _FilterNote extends StatelessWidget {
  const _FilterNote({required this.matches, required this.truncated});

  final int matches;
  final bool truncated;

  @override
  Widget build(BuildContext context) {
    final count = matches == 1 ? '1 match' : '$matches matches';
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
      child: Text(
        truncated
            ? '$count · stopped after '
                  '${WorktreeFileSystem.walkLimit ~/ 1000}k files'
            : count,
        style: TextStyle(
          fontSize: 11,
          color: truncated ? AppColors.error : AppColors.textMuted,
        ),
      ),
    );
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.name,
    required this.onCollapseAll,
    required this.onRefresh,
  });

  final String name;
  final VoidCallback onCollapseAll;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 30,
      padding: const EdgeInsets.only(left: 12, right: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              name.toUpperCase(),
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: AppColors.textMuted,
              ),
            ),
          ),
          _ToolbarButton(
            icon: Icons.unfold_less_rounded,
            tooltip: 'Collapse all',
            onPressed: onCollapseAll,
          ),
          _ToolbarButton(
            icon: Icons.refresh_rounded,
            tooltip: 'Refresh',
            onPressed: onRefresh,
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
        iconSize: 15,
        onPressed: onPressed,
        icon: Icon(icon, color: AppColors.textMuted),
      ),
    );
  }
}

class _FileRow extends StatefulWidget {
  const _FileRow({
    required this.row,
    required this.selected,
    required this.onTap,
    required this.onContextMenu,
    this.highlight,
  });

  final FileTreeRow row;
  final bool selected;

  /// The filter text to mark in the name, if any.
  final String? highlight;
  final VoidCallback onTap;
  final ValueChanged<Offset> onContextMenu;

  @override
  State<_FileRow> createState() => _FileRowState();
}

class _FileRowState extends State<_FileRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final row = widget.row;
    final entry = row.entry;
    final style = entry.isDirectory
        ? (icon: Icons.folder_rounded, color: AppColors.textSecondary)
        : fileIcon(entry.name);
    final opacity = row.ignored ? 0.5 : 1.0;
    final left = 8 + row.depth * WorktreeFilesTab.indent;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Listener(
        onPointerDown: (event) {
          if (event.buttons == kSecondaryMouseButton) {
            widget.onContextMenu(event.position);
          }
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: Container(
            color: widget.selected
                ? AppColors.accent.withValues(alpha: 0.14)
                : _hovered
                ? AppColors.surfaceHover
                : Colors.transparent,
            child: CustomPaint(
              painter: _IndentGuides(depth: row.depth),
              child: Padding(
                padding: EdgeInsets.only(left: left, right: 8),
                child: Row(
                  children: [
                    SizedBox(
                      width: 16,
                      child: entry.isDirectory
                          ? row.loading
                                ? Padding(
                                    padding: const EdgeInsets.all(3),
                                    child: CircularProgressIndicator(
                                      strokeWidth: 1.2,
                                      color: AppColors.textMuted,
                                    ),
                                  )
                                : Icon(
                                    row.expanded
                                        ? Icons.keyboard_arrow_down_rounded
                                        : Icons.chevron_right_rounded,
                                    size: 16,
                                    color: AppColors.textMuted,
                                  )
                          : null,
                    ),
                    const SizedBox(width: 2),
                    Opacity(
                      opacity: opacity,
                      child: Icon(
                        entry.isDirectory && row.expanded
                            ? Icons.folder_open_rounded
                            : style.icon,
                        size: 15,
                        color: style.color,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Opacity(
                        opacity: opacity,
                        child: Text.rich(
                          _nameSpan(entry.name, widget.highlight),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// [name] with the first case-insensitive occurrence of [highlight] (or of
/// its last path segment) marked.
TextSpan _nameSpan(String name, String? highlight) {
  final query = highlight?.split('/').last.toLowerCase() ?? '';
  final start = query.isEmpty ? -1 : name.toLowerCase().indexOf(query);
  if (start == -1) return TextSpan(text: name);
  final end = start + query.length;
  return TextSpan(
    children: [
      TextSpan(text: name.substring(0, start)),
      TextSpan(
        text: name.substring(start, end),
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: AppColors.accent,
          backgroundColor: AppColors.accent.withValues(alpha: 0.12),
        ),
      ),
      TextSpan(text: name.substring(end)),
    ],
  );
}

/// The vertical lines that show which folder a line is in.
class _IndentGuides extends CustomPainter {
  _IndentGuides({required this.depth});

  final int depth;

  @override
  void paint(Canvas canvas, Size size) {
    if (depth == 0) return;
    final paint = Paint()
      ..color = AppColors.borderSubtle
      ..strokeWidth = 1;
    for (var level = 0; level < depth; level++) {
      // Under the chevron of the folder at that level.
      final x = 8 + level * WorktreeFilesTab.indent + 8.5;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(_IndentGuides oldDelegate) => oldDelegate.depth != depth;
}

class _Message extends StatelessWidget {
  const _Message(this.text, {this.color});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: color ?? AppColors.textMuted),
        ),
      ),
    );
  }
}
