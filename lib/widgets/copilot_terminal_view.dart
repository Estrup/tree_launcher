import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:xterm/xterm.dart';
import '../providers/copilot_provider.dart';
import '../providers/settings_provider.dart';
import '../theme/app_theme.dart';
import '../theme/terminal_theme.dart';
import 'terminal_key_handler.dart';

class CopilotTerminalView extends StatefulWidget {
  const CopilotTerminalView({super.key});

  @override
  State<CopilotTerminalView> createState() => _CopilotTerminalViewState();
}

class _CopilotTerminalViewState extends State<CopilotTerminalView> {
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
    final session = copilotProvider.activeTerminal;
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
    final copilotProvider = context.watch<CopilotProvider>();
    final session = copilotProvider.activeTerminal;
    final settings = context.watch<SettingsProvider>().settings;
    final fontFamily = settings.terminalFontFamily ?? 'SF Mono';
    final fontSize = settings.terminalFontSize ?? 13.0;

    if (session == null) {
      return const Center(
        child: Text('No active copilot session'),
      );
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

    return Container(
      //color: AppColors.base,
      color: AppColors.base,
      padding: const EdgeInsets.all(8),
      child: TerminalView(
        session.terminal,
        theme: appTerminalTheme,
        textStyle: TerminalStyle(
          fontFamily: fontFamily,
          fontSize: fontSize,
          height: 1.3,
          fontFamilyFallback: [fontFamily, 'monospace'],
        ),
        textScaler: TextScaler.noScaling,
        padding: EdgeInsets.zero,
        autofocus: true,
        hardwareKeyboardOnly: true,
        onKeyEvent: (node, event) =>
            terminalShiftEnterHandler(session.terminal, node, event) ??
            KeyEventResult.ignored,
      ),
    );
  }
}
