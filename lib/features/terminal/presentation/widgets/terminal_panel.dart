import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:xterm/xterm.dart';
import 'package:tree_launcher/core/design_system/app_theme.dart';
import 'package:tree_launcher/core/design_system/terminal_theme.dart';
import 'package:tree_launcher/features/session_panel/presentation/controllers/session_panel_controller.dart';
import 'package:tree_launcher/features/session_panel/presentation/widgets/session_panel.dart';
import 'package:tree_launcher/features/session_panel/presentation/widgets/session_panel_split.dart';
import 'package:tree_launcher/features/settings/presentation/controllers/settings_controller.dart';
import 'package:tree_launcher/features/terminal/presentation/controllers/terminal_controller.dart'
    as terminal;
import 'terminal_context_menu.dart';
import 'terminal_header_actions.dart';
import 'terminal_key_handler.dart';

/// The built-in terminal: a header bar over the active session, with the
/// session panel at its right for a Claude session. Sessions are switched
/// from the sidebar and the worktree rows, not from tabs here.
class TerminalFullView extends StatelessWidget {
  const TerminalFullView({super.key});

  @override
  Widget build(BuildContext context) {
    final tp = context.watch<terminal.TerminalController>();
    if (!tp.isVisible || tp.sessions.isEmpty) return const SizedBox.shrink();
    final active = tp.activeSession;
    final panel = context.watch<SessionPanelController>();
    final showPanel = active != null && active.isClaude && panel.isOpen;

    return Container(
      color: AppColors.base,
      child: Column(
        children: [
          _HeaderBar(
            title: active?.title,
            actions: active == null
                ? null
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TerminalHeaderActions(session: active),
                      if (active.isClaude) ...[
                        const SizedBox(width: 6),
                        _PanelToggle(
                          open: panel.isOpen,
                          onPressed: panel.toggle,
                        ),
                      ],
                    ],
                  ),
          ),
          Expanded(
            child: active != null
                ? SessionPanelSplit(
                    terminal: _TerminalBody(session: active),
                    panel: showPanel ? SessionPanel(session: active) : null,
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _HeaderBar extends StatelessWidget {
  /// Title of the active session.
  final String? title;

  /// The active session's worktree links and launchers.
  final Widget? actions;

  const _HeaderBar({this.title, this.actions});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.surface0,
        border: Border(
          bottom: BorderSide(color: AppColors.borderSubtle, width: 1),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title ?? '',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          if (actions != null) ...[const SizedBox(width: 12), actions!],
        ],
      ),
    );
  }
}

/// Shows or hides the panel beside Claude sessions.
class _PanelToggle extends StatelessWidget {
  const _PanelToggle({required this.open, required this.onPressed});

  final bool open;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 28,
      height: 28,
      child: IconButton(
        tooltip: open ? 'Hide the side panel' : 'Show the side panel',
        padding: EdgeInsets.zero,
        iconSize: 16,
        style: IconButton.styleFrom(
          backgroundColor: open ? AppColors.surface2 : Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(7),
            side: BorderSide(color: AppColors.border),
          ),
        ),
        onPressed: onPressed,
        icon: Icon(
          Icons.view_sidebar_outlined,
          color: open ? AppColors.textPrimary : AppColors.textMuted,
        ),
      ),
    );
  }
}

class _TerminalBody extends StatefulWidget {
  final dynamic session;
  const _TerminalBody({required this.session});

  @override
  State<_TerminalBody> createState() => _TerminalBodyState();
}

class _TerminalBodyState extends State<_TerminalBody> {
  late final TerminalController _terminalController;

  @override
  void initState() {
    super.initState();
    _terminalController = TerminalController();
    _ensurePtyStarted();
  }

  @override
  void didUpdateWidget(_TerminalBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.session != oldWidget.session) {
      _terminalController.clearSelection();
      _ensurePtyStarted();
    }
  }

  void _ensurePtyStarted() {
    final session = widget.session;
    if (!session.isPtyStarted) {
      // Defer PTY start until after the TerminalView has been laid out,
      // so terminal.viewWidth/viewHeight reflect the actual view size.
      WidgetsBinding.instance.endOfFrame.then((_) {
        if (mounted && !session.isPtyStarted && !session.isDisposed) {
          session.startPty();
          // Send queued command after PTY and shell have initialized
          if (session.command != null) {
            Future.delayed(const Duration(milliseconds: 200), () {
              if (!session.isDisposed) {
                session.sendCommand(session.command!);
              }
            });
          }
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>().settings;
    final fontFamily = settings.terminalFontFamily ?? 'SF Mono';
    final fontSize = settings.terminalFontSize ?? 13.0;

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (event) {
        if (event.buttons == kSecondaryMouseButton) {
          showTerminalContextMenu(
            context: context,
            position: event.position,
            terminal: widget.session.terminal as Terminal,
            controller: _terminalController,
          );
        }
      },
      child: TerminalView(
        widget.session.terminal as Terminal,
        controller: _terminalController,
        theme: appTerminalTheme,
        textStyle: TerminalStyle(
          fontFamily: fontFamily,
          fontSize: fontSize,
          height: 1.9,
          // Text fonts for symbols the main font lacks, tried before the
          // system fallback, which would pick Apple Color Emoji for some
          // (e.g. the Claude CLI's ⏺ bullet) and draw a wide emoji.
          fontFamilyFallback: [
            fontFamily,
            'Menlo',
            'Apple Symbols',
            'STIX Two Math',
          ],
        ),
        textScaler: TextScaler.noScaling,
        // Painted in the terminal background, so the gutter reads as part of
        // the terminal rather than a frame around it.
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        autofocus: true,
        hardwareKeyboardOnly: true,
        onKeyEvent: (node, event) =>
            terminalShiftEnterHandler(
              widget.session.terminal as Terminal,
              node,
              event,
            ) ??
            KeyEventResult.ignored,
      ),
    );
  }

  @override
  void dispose() {
    _terminalController.dispose();
    super.dispose();
  }
}
