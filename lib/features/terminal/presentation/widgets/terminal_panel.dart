import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:xterm/xterm.dart';
import 'package:tree_launcher/core/design_system/app_theme.dart';
import 'package:tree_launcher/core/design_system/terminal_theme.dart';
import 'package:tree_launcher/providers/settings_provider.dart';
import 'package:tree_launcher/providers/terminal_provider.dart'
    hide TerminalController;
import 'terminal_context_menu.dart';
import 'terminal_header_actions.dart';
import 'terminal_key_handler.dart';

/// The built-in terminal: a header bar over the active session. Sessions are
/// switched from the sidebar and the worktree rows, not from tabs here.
class TerminalFullView extends StatelessWidget {
  const TerminalFullView({super.key});

  @override
  Widget build(BuildContext context) {
    final tp = context.watch<TerminalProvider>();
    if (!tp.isVisible || tp.sessions.isEmpty) return const SizedBox.shrink();
    final active = tp.activeSession;

    return Container(
      color: AppColors.base,
      child: Column(
        children: [
          _HeaderBar(
            title: active?.title,
            actions: active == null
                ? null
                : TerminalHeaderActions(session: active),
            onClose: active == null
                ? null
                : () => tp.closeTerminal(tp.activeIndex),
            onHide: () => tp.toggleVisibility(),
          ),
          Expanded(
            child: active != null
                ? _TerminalBody(session: active)
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _HeaderBar extends StatelessWidget {
  /// Title of the active session, shown after the TERMINAL label.
  final String? title;

  /// The active session's worktree links and launchers, shown before the
  /// close and hide buttons.
  final Widget? actions;

  /// Closes the active session; null hides the button.
  final VoidCallback? onClose;
  final VoidCallback onHide;

  const _HeaderBar({
    this.title,
    this.actions,
    this.onClose,
    required this.onHide,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: AppColors.surface0,
        border: Border(
          bottom: BorderSide(color: AppColors.borderSubtle, width: 1),
        ),
      ),
      child: Row(
        children: [
          const SizedBox(width: 8),
          Icon(Icons.terminal_rounded, size: 14, color: AppColors.terminal),
          const SizedBox(width: 6),
          Text(
            'TERMINAL',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppColors.textMuted,
              letterSpacing: 0.8,
            ),
          ),
          if (title != null) ...[
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                title!,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
            ),
          ],
          const SizedBox(width: 12),
          const Spacer(),
          if (actions != null) ...[
            actions!,
            Container(
              width: 1,
              height: 16,
              margin: const EdgeInsets.symmetric(horizontal: 8),
              color: AppColors.borderSubtle,
            ),
          ],
          if (onClose != null) ...[
            _IconBtn(
              icon: Icons.close_rounded,
              tooltip: 'Close session',
              onPressed: onClose!,
            ),
            const SizedBox(width: 2),
          ],
          _IconBtn(
            icon: Icons.remove_rounded,
            tooltip: 'Hide terminal',
            onPressed: onHide,
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }
}

class _IconBtn extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  const _IconBtn({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  State<_IconBtn> createState() => _IconBtnState();
}

class _IconBtnState extends State<_IconBtn> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onPressed,
          child: Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: _hovered ? AppColors.surface2 : Colors.transparent,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Icon(
              widget.icon,
              size: 14,
              color: _hovered ? AppColors.textPrimary : AppColors.textMuted,
            ),
          ),
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
    final settings = context.watch<SettingsProvider>().settings;
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
