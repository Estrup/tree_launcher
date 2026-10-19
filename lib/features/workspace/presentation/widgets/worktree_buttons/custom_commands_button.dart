import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tree_launcher/core/design_system/app_theme.dart';
import 'package:tree_launcher/features/terminal/presentation/controllers/terminal_controller.dart';
import 'package:tree_launcher/features/workspace/domain/custom_command.dart';
import 'package:tree_launcher/features/workspace/presentation/command_style.dart';
import 'package:tree_launcher/features/workspace/presentation/controllers/workspace_controller.dart';

class CustomCommandsButton extends StatefulWidget {
  final String worktreePath;
  final String worktreeName;
  final List<CustomCommand> commands;
  final bool compact;

  const CustomCommandsButton({
    super.key,
    required this.worktreePath,
    required this.worktreeName,
    required this.commands,
    this.compact = false,
  });

  @override
  State<CustomCommandsButton> createState() => _CustomCommandsButtonState();
}

class _CustomCommandsButtonState extends State<CustomCommandsButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final size = widget.compact ? 28.0 : 36.0;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () => _showDropdown(context),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: _hovered
                ? AppColors.terminal.withValues(alpha: 0.2)
                : AppColors.terminalBg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _hovered
                  ? AppColors.terminal.withValues(alpha: 0.4)
                  : AppColors.terminal.withValues(alpha: 0.15),
            ),
          ),
          child: Center(
            child: Icon(
              Icons.play_arrow_rounded,
              size: widget.compact ? 16 : 18,
              color: AppColors.terminal,
            ),
          ),
        ),
      ),
    );
  }

  void _showDropdown(BuildContext context) {
    final repo = context.read<WorkspaceController>().selectedRepo;
    final tp = context.read<TerminalController>();
    final RenderBox button = context.findRenderObject() as RenderBox;
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final position = RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(Offset(0, button.size.height)),
        button.localToGlobal(Offset(button.size.width, button.size.height)),
      ),
      Offset.zero & overlay.size,
    );

    final selected = <String>{};

    void runSelected() {
      Navigator.pop(context);
      for (final cmd in widget.commands) {
        if (!selected.contains(cmd.name)) continue;
        tp.openTerminalWithCommand(
          '${cmd.name}: ${widget.worktreeName}',
          widget.worktreePath,
          repo?.path ?? widget.worktreePath,
          cmd.command,
        );
      }
    }

    showMenu<void>(
      context: context,
      position: position,
      color: AppColors.surface1,
      constraints: const BoxConstraints(minWidth: 240),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: AppColors.border),
      ),
      items: [
        PopupMenuItem<void>(
          enabled: false,
          padding: EdgeInsets.zero,
          child: StatefulBuilder(
            builder: (context, setMenuState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (int i = 0; i < widget.commands.length; i++)
                    _CommandCheckboxRow(
                      command: widget.commands[i],
                      index: i,
                      selected: selected.contains(widget.commands[i].name),
                      onToggle: () {
                        setMenuState(() {
                          final name = widget.commands[i].name;
                          if (selected.contains(name)) {
                            selected.remove(name);
                          } else {
                            selected.add(name);
                          }
                        });
                      },
                    ),
                  Divider(height: 1, color: AppColors.border),
                  _RunSelectedButton(
                    count: selected.length,
                    onTap: selected.isEmpty ? null : runSelected,
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _CommandCheckboxRow extends StatelessWidget {
  final CustomCommand command;
  final int index;
  final bool selected;
  final VoidCallback onToggle;

  const _CommandCheckboxRow({
    required this.command,
    required this.index,
    required this.selected,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final color = getCommandColor(command.colorHex, index);
    final icon = getCommandIcon(command.iconName);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onToggle,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: Checkbox(
                  value: selected,
                  onChanged: (_) => onToggle(),
                  activeColor: color,
                  side: BorderSide(color: AppColors.textMuted),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              const SizedBox(width: 10),
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  command.name,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RunSelectedButton extends StatelessWidget {
  final int count;
  final VoidCallback? onTap;

  const _RunSelectedButton({required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.play_arrow_rounded,
                size: 15,
                color: enabled ? AppColors.terminal : AppColors.textMuted,
              ),
              const SizedBox(width: 6),
              Text(
                'Run Selected ($count)',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: enabled ? AppColors.terminal : AppColors.textMuted,
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
// Delete icon
// ---------------------------------------------------------------------------
