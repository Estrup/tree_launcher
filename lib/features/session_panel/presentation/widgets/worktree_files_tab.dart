import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import 'package:tree_launcher/core/design_system/app_snackbar.dart';
import 'package:tree_launcher/core/design_system/app_theme.dart';
import 'package:tree_launcher/core/platform/launcher_service.dart';
import 'package:tree_launcher/core/platform/open_external.dart';
import 'package:tree_launcher/features/session_panel/presentation/controllers/session_panel_controller.dart';
import 'package:tree_launcher/features/session_panel/presentation/controllers/worktree_files_controller.dart';
import 'package:tree_launcher/features/session_panel/presentation/widgets/file_icons.dart';

/// The worktree's files as a tree: everything on disk, gitignored entries
/// dimmed. A folder opens on click and a file opens in a tab of the panel.
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

  @override
  void initState() {
    super.initState();
    _files = context.read<SessionPanelController>().filesFor(widget.worktree)
      ..attach();
  }

  @override
  void didUpdateWidget(WorktreeFilesTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.worktree != widget.worktree) {
      _files.detach();
      _files = context.read<SessionPanelController>().filesFor(widget.worktree)
        ..attach();
    }
  }

  @override
  void dispose() {
    _files.detach();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final panel = context.watch<SessionPanelController>();
    final selectedPath = panel.selectedFor(widget.worktree).path;

    return ListenableBuilder(
      listenable: _files,
      builder: (context, _) {
        final rows = _files.rows;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Toolbar(
              name: p.basename(widget.worktree),
              onCollapseAll: _files.collapseAll,
              onRefresh: _files.refresh,
            ),
            Expanded(
              child: _files.error != null
                  ? _Message(_files.error!, color: AppColors.error)
                  : _files.isLoading
                  ? const _Message('Reading…')
                  : rows.isEmpty
                  ? const _Message('No files')
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      itemExtent: WorktreeFilesTab.rowHeight,
                      itemCount: rows.length,
                      itemBuilder: (context, index) {
                        final row = rows[index];
                        return _FileRow(
                          row: row,
                          selected: row.entry.path == selectedPath,
                          onTap: () => row.entry.isDirectory
                              ? _files.toggle(row.entry.path)
                              : panel.openFile(widget.worktree, row.entry.path),
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

enum _MenuAction { open, vscode, reveal, copyPath, copyRelativePath }

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
  });

  final FileTreeRow row;
  final bool selected;
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
                        child: Text(
                          entry.name,
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
