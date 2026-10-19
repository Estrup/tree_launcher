import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tree_launcher/core/design_system/app_theme.dart';
import 'package:tree_launcher/core/platform/launcher_service.dart';
import 'package:tree_launcher/features/settings/presentation/controllers/settings_controller.dart';
import 'package:tree_launcher/features/terminal/presentation/controllers/terminal_controller.dart';
import 'package:tree_launcher/features/workspace/presentation/controllers/workspace_controller.dart';
import 'package:tree_launcher/features/workspace/presentation/widgets/worktree_buttons/action_buttons.dart';

class TerminalButton extends StatefulWidget {
  final String worktreePath;
  final String worktreeName;
  final LauncherService launcherService;

  /// When true, renders as a single compact icon button (primary action on tap)
  /// with a small caret affordance that opens the extra-options dropdown.
  /// When false, renders the wider split button used by the tile card.
  final bool compact;

  const TerminalButton({
    super.key,
    required this.worktreePath,
    required this.worktreeName,
    required this.launcherService,
    this.compact = false,
  });

  @override
  State<TerminalButton> createState() => _TerminalButtonState();
}

class _TerminalButtonState extends State<TerminalButton> {
  bool _mainHovered = false;
  bool _dropHovered = false;

  void _openEmbedded(BuildContext context) {
    final repo = context.read<WorkspaceController>().selectedRepo;
    final tp = context.read<TerminalController>();
    tp.openTerminal(
      widget.worktreeName,
      widget.worktreePath,
      repo?.path ?? widget.worktreePath,
    );
  }

  void _showDropdown(BuildContext context) {
    final settings = context.read<SettingsController>().settings;
    final repo = context.read<WorkspaceController>().selectedRepo;
    final tp = context.read<TerminalController>();
    showMenuBelow<String>(
      context,
      items: [
        PopupMenuItem<String>(
          value: 'embedded',
          height: 36,
          child: Row(
            children: [
              Icon(Icons.terminal_rounded, size: 13, color: AppColors.terminal),
              const SizedBox(width: 8),
              Text(
                'Terminal',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'external',
          height: 36,
          child: Row(
            children: [
              Icon(
                Icons.open_in_new_rounded,
                size: 13,
                color: AppColors.terminal,
              ),
              const SizedBox(width: 8),
              Text(
                'External Terminal',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    ).then((value) {
      if (value == 'embedded') {
        tp.openTerminal(
          widget.worktreeName,
          widget.worktreePath,
          repo?.path ?? widget.worktreePath,
        );
      } else if (value == 'external') {
        widget.launcherService.openTerminal(widget.worktreePath, settings);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.compact) {
      return CompactActionButton(
        color: AppColors.terminal,
        bgColor: AppColors.terminalBg,
        tooltip: 'Terminal',
        icon: Icon(Icons.terminal_rounded, size: 14, color: AppColors.terminal),
        onPrimary: () => _openEmbedded(context),
        onDropdown: () => _showDropdown(context),
      );
    }

    return SizedBox(
      width: 60,
      height: 36,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        decoration: BoxDecoration(
          color: AppColors.terminalBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: (_mainHovered || _dropHovered)
                ? AppColors.terminal.withValues(alpha: 0.4)
                : AppColors.terminal.withValues(alpha: 0.15),
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(7),
          child: Row(
            children: [
              Expanded(
                child: MouseRegion(
                  onEnter: (_) => setState(() => _mainHovered = true),
                  onExit: (_) => setState(() => _mainHovered = false),
                  child: GestureDetector(
                    onTap: () => _openEmbedded(context),
                    child: Tooltip(
                      message: 'Terminal',
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 120),
                        color: _mainHovered
                            ? AppColors.terminal.withValues(alpha: 0.2)
                            : Colors.transparent,
                        child: Center(
                          child: Icon(
                            Icons.terminal_rounded,
                            size: 16,
                            color: AppColors.terminal,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Container(
                width: 1,
                color: AppColors.terminal.withValues(alpha: 0.15),
              ),
              MouseRegion(
                onEnter: (_) => setState(() => _dropHovered = true),
                onExit: (_) => setState(() => _dropHovered = false),
                child: GestureDetector(
                  onTap: () => _showDropdown(context),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    width: 28,
                    color: _dropHovered
                        ? AppColors.terminal.withValues(alpha: 0.2)
                        : Colors.transparent,
                    child: Center(
                      child: Icon(
                        Icons.arrow_drop_down_rounded,
                        size: 18,
                        color: AppColors.terminal,
                      ),
                    ),
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

// ---------------------------------------------------------------------------
// VS Code button
// ---------------------------------------------------------------------------
