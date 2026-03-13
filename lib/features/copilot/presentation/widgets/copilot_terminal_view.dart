import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:xterm/xterm.dart';
import 'package:tree_launcher/core/design_system/app_theme.dart';
import 'package:tree_launcher/core/design_system/terminal_theme.dart';
import 'package:tree_launcher/features/terminal/presentation/terminal_text_style_resolver.dart';
import 'package:tree_launcher/features/terminal/presentation/widgets/terminal_key_handler.dart';
import 'package:tree_launcher/providers/copilot_provider.dart';
import 'package:tree_launcher/providers/settings_provider.dart';

class CopilotTerminalView extends StatefulWidget {
  final String sessionId;
  const CopilotTerminalView({super.key, required this.sessionId});

  @override
  State<CopilotTerminalView> createState() => _CopilotTerminalViewState();
}

class _CopilotTerminalViewState extends State<CopilotTerminalView>
    with AutomaticKeepAliveClientMixin {
  bool _isDragging = false;

  @override
  bool get wantKeepAlive => true;
  @override
  void initState() {
    super.initState();
    _ensurePtyStarted();
  }

  @override
  void didUpdateWidget(CopilotTerminalView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _ensurePtyStarted();
  }

  void _ensurePtyStarted() {
    final copilotProvider = context.read<CopilotProvider>();
    final session = copilotProvider.terminalForSession(widget.sessionId);
    if (session != null && !session.isPtyStarted) {
      WidgetsBinding.instance.endOfFrame.then((_) {
        if (mounted && !session.isPtyStarted && !session.isDisposed) {
          session.startPty();
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
    super.build(context);
    final copilotProvider = context.watch<CopilotProvider>();
    final session = copilotProvider.terminalForSession(widget.sessionId);
    final settings = context.watch<SettingsProvider>().settings;
    final terminalTextStyle = buildTerminalTextStyle(
      fontFamily: settings.terminalFontFamily,
      fontSize: settings.terminalFontSize,
      lineHeight: 1.3,
    );

    if (session == null) {
      return const Center(child: Text('No active copilot session'));
    }

    // Re-check PTY after rebuild (e.g. switching sessions)
    if (!session.isPtyStarted) {
      WidgetsBinding.instance.endOfFrame.then((_) {
        if (mounted && !session.isPtyStarted && !session.isDisposed) {
          session.startPty();
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

    return DropTarget(
      onDragDone: (details) {
        if (details.files.isNotEmpty) {
          final path = details.files.first.path;
          final copilot = context.read<CopilotProvider>();
          copilot.terminalForSession(widget.sessionId)?.writeInput(path);
        }
        setState(() => _isDragging = false);
      },
      onDragEntered: (_) => setState(() => _isDragging = true),
      onDragExited: (_) => setState(() => _isDragging = false),
      child: Container(
        color: AppColors.base,
        padding: const EdgeInsets.all(8),
        child: Stack(
          children: [
            TerminalView(
              session.terminal,
              theme: appTerminalTheme,
              textStyle: terminalTextStyle,
              textScaler: TextScaler.noScaling,
              padding: EdgeInsets.zero,
              autofocus: true,
              hardwareKeyboardOnly: true,
              onKeyEvent: (node, event) =>
                  terminalShiftEnterHandler(session.terminal, node, event) ??
                  KeyEventResult.ignored,
            ),
            if (_isDragging)
              Positioned.fill(
                child: IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Colors.blueAccent.withValues(alpha: 0.7),
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
