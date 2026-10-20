import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:tree_launcher/core/design_system/app_theme.dart';
import 'package:tree_launcher/features/session_panel/presentation/controllers/session_panel_controller.dart';
import 'package:tree_launcher/features/session_panel/presentation/widgets/file_icons.dart';
import 'package:tree_launcher/features/session_panel/presentation/widgets/file_tab_view.dart';
import 'package:tree_launcher/features/session_panel/presentation/widgets/session_info_tab.dart';
import 'package:tree_launcher/features/session_panel/presentation/widgets/worktree_files_tab.dart';
import 'package:tree_launcher/features/terminal/data/terminal_session.dart';

/// The panel beside a Claude session: its worktree's Info, Files and open
/// file tabs.
class SessionPanel extends StatelessWidget {
  const SessionPanel({super.key, required this.session});

  final TerminalSession session;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<SessionPanelController>();
    final worktree = session.workingDirectory;
    final selected = controller.selectedFor(worktree);

    return ColoredBox(
      color: AppColors.surface0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _TabStrip(
            tabs: controller.tabsFor(worktree),
            selected: selected,
            onSelect: (tab) => controller.select(worktree, tab),
            onClose: (tab) => controller.closeTab(worktree, tab),
          ),
          Expanded(
            child: switch (selected.kind) {
              SessionPanelTabKind.info => SessionInfoTab(session: session),
              SessionPanelTabKind.files => WorktreeFilesTab(worktree: worktree),
              SessionPanelTabKind.file => FileTabView(
                key: ValueKey(selected.path),
                worktree: worktree,
                path: selected.path!,
              ),
            },
          ),
        ],
      ),
    );
  }
}

class _TabStrip extends StatelessWidget {
  const _TabStrip({
    required this.tabs,
    required this.selected,
    required this.onSelect,
    required this.onClose,
  });

  final List<SessionPanelTab> tabs;
  final SessionPanelTab selected;
  final ValueChanged<SessionPanelTab> onSelect;
  final ValueChanged<SessionPanelTab> onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.borderSubtle)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final tab in tabs)
              _Tab(
                tab: tab,
                selected: tab == selected,
                onTap: () => onSelect(tab),
                onClose: tab.kind == SessionPanelTabKind.file
                    ? () => onClose(tab)
                    : null,
              ),
          ],
        ),
      ),
    );
  }
}

class _Tab extends StatefulWidget {
  const _Tab({
    required this.tab,
    required this.selected,
    required this.onTap,
    this.onClose,
  });

  final SessionPanelTab tab;
  final bool selected;
  final VoidCallback onTap;

  /// Closes the tab; null for tabs that can't close.
  final VoidCallback? onClose;

  @override
  State<_Tab> createState() => _TabState();
}

class _TabState extends State<_Tab> {
  bool _hovered = false;

  /// The tab's icon, and for a file its own color.
  ({IconData icon, Color? color}) get _icon => switch (widget.tab.kind) {
    SessionPanelTabKind.info => (icon: Icons.info_outline_rounded, color: null),
    SessionPanelTabKind.files => (icon: Icons.folder_outlined, color: null),
    SessionPanelTabKind.file => fileIcon(widget.tab.title),
  };

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;
    final color = selected || _hovered
        ? AppColors.textPrimary
        : AppColors.textMuted;
    final onClose = widget.onClose;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Listener(
        // A middle click closes a file tab.
        onPointerDown: (event) {
          if (onClose != null && event.buttons == kMiddleMouseButton) {
            onClose();
          }
        },
        child: GestureDetector(
          onTap: widget.onTap,
          child: Tooltip(
            message: widget.tab.path ?? '',
            waitDuration: const Duration(milliseconds: 600),
            child: Container(
              height: 36,
              padding: EdgeInsets.only(
                left: 12,
                right: onClose == null ? 12 : 6,
              ),
              decoration: BoxDecoration(
                color: selected ? AppColors.base : Colors.transparent,
                border: Border(
                  bottom: BorderSide(
                    color: selected ? AppColors.accent : Colors.transparent,
                    width: 2,
                  ),
                  right: BorderSide(color: AppColors.borderSubtle),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(_icon.icon, size: 14, color: _icon.color ?? color),
                  const SizedBox(width: 6),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 160),
                    child: Text(
                      widget.tab.title,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.w500,
                        color: color,
                      ),
                    ),
                  ),
                  if (onClose != null) ...[
                    const SizedBox(width: 4),
                    _CloseButton(
                      visible: selected || _hovered,
                      onPressed: onClose,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.visible, required this.onPressed});

  final bool visible;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 18,
      height: 18,
      child: visible
          ? IconButton(
              tooltip: 'Close',
              padding: EdgeInsets.zero,
              iconSize: 12,
              splashRadius: 10,
              onPressed: onPressed,
              icon: Icon(Icons.close_rounded, color: AppColors.textMuted),
            )
          : null,
    );
  }
}
