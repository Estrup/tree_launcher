import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:xterm/xterm.dart';
import 'package:tree_launcher/core/design_system/app_theme.dart';
import 'package:tree_launcher/core/design_system/terminal_theme.dart';
import 'package:tree_launcher/providers/settings_provider.dart';
import 'package:tree_launcher/providers/terminal_provider.dart';
import 'terminal_key_handler.dart';

class TerminalPanel extends StatefulWidget {
  const TerminalPanel({super.key});

  @override
  State<TerminalPanel> createState() => _TerminalPanelState();
}

class _TerminalPanelState extends State<TerminalPanel> {
  static const double _defaultSidebarWidth = 120.0;
  static const double _minSidebarWidth = 80.0;
  static const double _maxSidebarWidth = 260.0;

  double _sidebarWidth = _defaultSidebarWidth;

  @override
  Widget build(BuildContext context) {
    final tp = context.watch<TerminalProvider>();
    if (!tp.isVisible || tp.sessions.isEmpty) return const SizedBox.shrink();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _DragHandle(
          onDrag: (dy) {
            tp.setPanelHeight(tp.panelHeight - dy);
          },
        ),
        Container(
          height: tp.panelHeight,
          decoration: BoxDecoration(
            color: AppColors.base,
            border: Border(
              top: BorderSide(color: AppColors.borderSubtle, width: 1),
            ),
          ),
          child: Column(
            children: [
              _HeaderBar(onHide: () => tp.toggleVisibility()),
              Expanded(
                child: Row(
                  children: [
                    _VerticalTabList(
                      width: _sidebarWidth,
                      sessions: tp.sessions,
                      activeIndex: tp.activeIndex,
                      onSelect: (i) => tp.setActive(i),
                      onClose: (i) => tp.closeTerminal(i),
                    ),
                    _SidebarResizeHandle(
                      onDrag: (dx) {
                        setState(() {
                          _sidebarWidth = (_sidebarWidth + dx)
                              .clamp(_minSidebarWidth, _maxSidebarWidth);
                        });
                      },
                    ),
                    Expanded(
                      child: tp.activeSession != null
                          ? _TerminalBody(session: tp.activeSession!)
                          : const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DragHandle extends StatelessWidget {
  final ValueChanged<double> onDrag;
  const _DragHandle({required this.onDrag});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onVerticalDragUpdate: (d) => onDrag(d.delta.dy),
      child: MouseRegion(
        cursor: SystemMouseCursors.resizeRow,
        child: Container(
          height: 6,
          color: Colors.transparent,
          child: Center(
            child: Container(
              width: 40,
              height: 3,
              decoration: BoxDecoration(
                color: AppColors.textMuted.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HeaderBar extends StatelessWidget {
  final VoidCallback onHide;

  const _HeaderBar({required this.onHide});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
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
          const Spacer(),
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

class _VerticalTabList extends StatelessWidget {
  final double width;
  final List<dynamic> sessions;
  final int activeIndex;
  final ValueChanged<int> onSelect;
  final ValueChanged<int> onClose;

  const _VerticalTabList({
    required this.width,
    required this.sessions,
    required this.activeIndex,
    required this.onSelect,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      decoration: BoxDecoration(
        color: AppColors.surface0,
      ),
      child: ListView.builder(
        itemCount: sessions.length,
        padding: const EdgeInsets.symmetric(vertical: 4),
        itemBuilder: (context, i) {
          final session = sessions[i];
          final tooltipLines = [session.title];
          tooltipLines.add(session.workingDirectory);
          if (session.command != null) {
            tooltipLines.add('cmd: ${session.command}');
          }
          return _Tab(
            title: session.title,
            tooltip: tooltipLines.join('\n'),
            isActive: i == activeIndex,
            onTap: () => onSelect(i),
            onClose: () => onClose(i),
          );
        },
      ),
    );
  }
}

class _SidebarResizeHandle extends StatelessWidget {
  final ValueChanged<double> onDrag;
  const _SidebarResizeHandle({required this.onDrag});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragUpdate: (d) => onDrag(d.delta.dx),
      child: MouseRegion(
        cursor: SystemMouseCursors.resizeColumn,
        child: Container(
          width: 4,
          color: AppColors.borderSubtle,
        ),
      ),
    );
  }
}

class _Tab extends StatefulWidget {
  final String title;
  final String tooltip;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback onClose;

  const _Tab({
    required this.title,
    required this.tooltip,
    required this.isActive,
    required this.onTap,
    required this.onClose,
  });

  @override
  State<_Tab> createState() => _TabState();
}

class _TabState extends State<_Tab> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      waitDuration: const Duration(milliseconds: 400),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: Container(
            height: 30,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: widget.isActive
                  ? AppColors.base
                  : (_hovered ? AppColors.surface2 : Colors.transparent),
              borderRadius: BorderRadius.circular(4),
              border: widget.isActive
                  ? Border(
                      left: BorderSide(color: AppColors.terminal, width: 2),
                    )
                  : null,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: widget.isActive
                          ? FontWeight.w600
                          : FontWeight.w400,
                      color: widget.isActive
                          ? AppColors.textPrimary
                          : AppColors.textMuted,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
                if (_hovered || widget.isActive) ...[
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: widget.onClose,
                    child: Icon(
                      Icons.close_rounded,
                      size: 12,
                      color: _hovered
                          ? AppColors.textSecondary
                          : AppColors.textMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
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
  @override
  void initState() {
    super.initState();
    _ensurePtyStarted();
  }

  @override
  void didUpdateWidget(_TerminalBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.session != oldWidget.session) {
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

    return Container(
      padding: const EdgeInsets.all(8),
      color: AppColors.terminalBg,
      child: TerminalView(
        widget.session.terminal as Terminal,
        theme: appTerminalTheme,
        textStyle: TerminalStyle(
          fontFamily: fontFamily,
          fontSize: fontSize,
          height: 1.9,
          fontFamilyFallback: [fontFamily, 'monospace'],
        ),
        textScaler: TextScaler.noScaling,
        padding: EdgeInsets.zero,
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
}
