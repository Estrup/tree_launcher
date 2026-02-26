import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/command_style.dart';
import '../providers/repo_provider.dart';
import '../providers/terminal_provider.dart';
import '../theme/app_theme.dart';

/// A horizontal row of icon buttons for running command terminals,
/// displayed just above the terminal panel.
class RunningCommandsBar extends StatelessWidget {
  const RunningCommandsBar({super.key});

  @override
  Widget build(BuildContext context) {
    final tp = context.watch<TerminalProvider>();
    final repo = context.watch<RepoProvider>().selectedRepo;
    if (repo == null) return const SizedBox.shrink();

    final commands = repo.customCommands;

    // Collect sessions that are command-based and belong to this repo.
    final entries = <_RunningEntry>[];
    for (var i = 0; i < tp.sessions.length; i++) {
      final session = tp.sessions[i];
      if (session.command == null || session.isDisposed) continue;
      if (session.repoPath != repo.path) continue;

      // Match to a CustomCommand config for icon/color.
      final matchIndex =
          commands.indexWhere((c) => c.command == session.command);
      final matched = matchIndex != -1 ? commands[matchIndex] : null;

      entries.add(_RunningEntry(
        sessionIndex: i,
        commandName: matched?.name ?? session.title,
        icon: getCommandIcon(matched?.iconName),
        color: getCommandColor(
          matched?.colorHex,
          matchIndex != -1 ? matchIndex : i,
        ),
        isActive: i == tp.activeIndex && tp.isVisible,
      ));
    }

    if (entries.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: const BoxDecoration(
        color: AppColors.surface0,
        border: Border(
          top: BorderSide(color: AppColors.borderSubtle, width: 1),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.play_circle_outline_rounded,
            size: 12,
            color: AppColors.textMuted.withValues(alpha: 0.6),
          ),
          const SizedBox(width: 6),
          Text(
            'RUNNING',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: AppColors.textMuted.withValues(alpha: 0.6),
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(width: 10),
          ...entries.map((e) => _CommandIconButton(
                entry: e,
                onTap: () {
                  tp.setActive(e.sessionIndex);
                  if (!tp.isVisible) tp.toggleVisibility();
                },
              )),
        ],
      ),
    );
  }
}

class _RunningEntry {
  final int sessionIndex;
  final String commandName;
  final IconData icon;
  final Color color;
  final bool isActive;

  _RunningEntry({
    required this.sessionIndex,
    required this.commandName,
    required this.icon,
    required this.color,
    required this.isActive,
  });
}

class _CommandIconButton extends StatefulWidget {
  final _RunningEntry entry;
  final VoidCallback onTap;

  const _CommandIconButton({required this.entry, required this.onTap});

  @override
  State<_CommandIconButton> createState() => _CommandIconButtonState();
}

class _CommandIconButtonState extends State<_CommandIconButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final e = widget.entry;

    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: Tooltip(
        message: e.commandName,
        waitDuration: const Duration(milliseconds: 300),
        child: MouseRegion(
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: GestureDetector(
            onTap: widget.onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: e.isActive
                    ? e.color.withValues(alpha: 0.2)
                    : (_hovered
                        ? e.color.withValues(alpha: 0.12)
                        : Colors.transparent),
                borderRadius: BorderRadius.circular(6),
                border: e.isActive
                    ? Border.all(color: e.color.withValues(alpha: 0.5), width: 1)
                    : null,
              ),
              child: Center(
                child: Icon(
                  e.icon,
                  size: 22,
                  color: e.isActive
                      ? e.color
                      : (_hovered
                          ? e.color.withValues(alpha: 0.9)
                          : e.color.withValues(alpha: 0.6)),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
