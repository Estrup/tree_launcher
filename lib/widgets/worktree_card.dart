import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import '../models/custom_command.dart';
import '../models/worktree.dart';
import '../providers/repo_provider.dart';
import '../providers/settings_provider.dart';
import '../services/launcher_service.dart';
import '../theme/app_theme.dart';

class WorktreeCard extends StatefulWidget {
  final Worktree worktree;

  const WorktreeCard({super.key, required this.worktree});

  @override
  State<WorktreeCard> createState() => _WorktreeCardState();
}

class _WorktreeCardState extends State<WorktreeCard> {
  final LauncherService _launcherService = LauncherService();
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>().settings;
    final repo = context.watch<RepoProvider>().selectedRepo;
    final customCommands = repo?.customCommands ?? [];
    final wt = widget.worktree;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: _hovered ? AppColors.surface2 : AppColors.surface1,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _hovered ? AppColors.border : AppColors.borderSubtle,
          ),
        ),
        padding: const EdgeInsets.all(20),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row: name + badge
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        wt.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                          letterSpacing: -0.3,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (wt.isMain)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.accentMuted,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'PRIMARY',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: AppColors.accent,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                    if (!wt.isMain) const SizedBox(width: 24),
                  ],
                ),
            const SizedBox(height: 12),

            // Branch tag
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.copilotBg,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: AppColors.copilot.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.call_split_rounded,
                      size: 12, color: AppColors.copilot),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      wt.branch,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.copilot,
                        fontFamily: 'monospace',
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Commit + path
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.surface2,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    wt.commitHash,
                    style: const TextStyle(
                      fontSize: 11,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w500,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Tooltip(
                    message: wt.path,
                    child: Text(
                      wt.path.replaceFirst(RegExp(r'^/Users/[^/]+'), '~'),
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                        fontFamily: 'monospace',
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),

            const Spacer(),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: _ActionButton(
                    icon: Icons.terminal_rounded,
                    label: 'Terminal',
                    color: AppColors.terminal,
                    bgColor: AppColors.terminalBg,
                    onPressed: () =>
                        _launcherService.openTerminal(wt.path, settings),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ActionButton(
                    icon: Icons.auto_awesome_rounded,
                    label: 'Copilot',
                    color: AppColors.copilot,
                    bgColor: AppColors.copilotBg,
                    onPressed: () =>
                        _launcherService.openCopilotCli(wt.path, settings),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _VscodeSplitButton(
                    worktreePath: wt.path,
                    launcherService: _launcherService,
                  ),
                ),
                if (customCommands.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  _CustomCommandsButton(
                    worktreePath: wt.path,
                    commands: customCommands,
                    launcherService: _launcherService,
                  ),
                ],
              ],
            ),
          ],
        ),
            // Delete icon (upper-right, hover-only, non-primary only)
            if (!wt.isMain && _hovered)
              Positioned(
                top: 0,
                right: 0,
                child: _DeleteIcon(onPressed: () => _confirmDelete(context)),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final wt = widget.worktree;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete worktree?'),
        content: Text(
          'This will permanently remove "${wt.name}" (${wt.branch}) from disk and git.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        await context.read<RepoProvider>().deleteWorktree(wt);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete: $e')),
          );
        }
      }
    }
  }
}

class _VscodeSplitButton extends StatefulWidget {
  final String worktreePath;
  final LauncherService launcherService;

  const _VscodeSplitButton({
    required this.worktreePath,
    required this.launcherService,
  });

  @override
  State<_VscodeSplitButton> createState() => _VscodeSplitButtonState();
}

class _VscodeSplitButtonState extends State<_VscodeSplitButton> {
  bool _mainHovered = false;
  bool _dropHovered = false;

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<RepoProvider>().selectedRepo;
    final configs = repo?.vscodeConfigs ?? [];
    final hasConfigs = configs.isNotEmpty;

    if (!hasConfigs) {
      return _ActionButton(
        icon: Icons.code_rounded,
        label: 'VS Code',
        color: AppColors.vscode,
        bgColor: AppColors.vscodeBg,
        onPressed: () => widget.launcherService.openVSCode(widget.worktreePath),
      );
    }

    return SizedBox(
      height: 36,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        decoration: BoxDecoration(
          color: AppColors.vscodeBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: (_mainHovered || _dropHovered)
                ? AppColors.vscode.withValues(alpha: 0.4)
                : AppColors.vscode.withValues(alpha: 0.15),
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(7),
          child: Row(
            children: [
              // Main button
              Expanded(
                child: MouseRegion(
                  onEnter: (_) => setState(() => _mainHovered = true),
                  onExit: (_) => setState(() => _mainHovered = false),
                  child: GestureDetector(
                    onTap: () =>
                        widget.launcherService.openVSCode(widget.worktreePath),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 120),
                      color: _mainHovered
                          ? AppColors.vscode.withValues(alpha: 0.2)
                          : Colors.transparent,
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.code_rounded,
                              size: 14, color: AppColors.vscode),
                          SizedBox(width: 6),
                          Text(
                            'VS Code',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.vscode,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              // Divider
              Container(
                width: 1,
                color: AppColors.vscode.withValues(alpha: 0.15),
              ),
              // Dropdown arrow
              MouseRegion(
                onEnter: (_) => setState(() => _dropHovered = true),
                onExit: (_) => setState(() => _dropHovered = false),
                child: GestureDetector(
                  onTap: () => _showDropdown(context, configs),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    width: 28,
                    color: _dropHovered
                        ? AppColors.vscode.withValues(alpha: 0.2)
                        : Colors.transparent,
                    child: const Center(
                      child: Icon(
                        Icons.arrow_drop_down_rounded,
                        size: 18,
                        color: AppColors.vscode,
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

  void _showDropdown(
      BuildContext context, List<dynamic> configs) {
    final RenderBox button = context.findRenderObject() as RenderBox;
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;
    final position = RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(Offset(0, button.size.height)),
        button.localToGlobal(
            Offset(button.size.width, button.size.height)),
      ),
      Offset.zero & overlay.size,
    );

    showMenu<String>(
      context: context,
      position: position,
      color: AppColors.surface1,
      constraints: const BoxConstraints(minWidth: 280),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: AppColors.border),
      ),
      items: configs.map((config) {
        return PopupMenuItem<String>(
          value: config.path as String,
          height: 36,
          child: Row(
            children: [
              const Icon(Icons.code_rounded,
                  size: 13, color: AppColors.vscode),
              const SizedBox(width: 8),
              Text(
                config.name as String,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  config.path as String,
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textMuted,
                    fontFamily: 'monospace',
                  ),
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    ).then((selectedPath) {
      if (selectedPath != null) {
        final resolved = p.join(widget.worktreePath, selectedPath);
        widget.launcherService.openVSCode(resolved);
      }
    });
  }
}

class _CustomCommandsButton extends StatefulWidget {
  final String worktreePath;
  final List<CustomCommand> commands;
  final LauncherService launcherService;

  const _CustomCommandsButton({
    required this.worktreePath,
    required this.commands,
    required this.launcherService,
  });

  @override
  State<_CustomCommandsButton> createState() => _CustomCommandsButtonState();
}

class _CustomCommandsButtonState extends State<_CustomCommandsButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () => _showDropdown(context),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: 36,
          height: 36,
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
          child: const Center(
            child: Icon(
              Icons.play_arrow_rounded,
              size: 18,
              color: AppColors.terminal,
            ),
          ),
        ),
      ),
    );
  }

  void _showDropdown(BuildContext context) {
    final settings = context.read<SettingsProvider>().settings;
    final RenderBox button = context.findRenderObject() as RenderBox;
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;
    final position = RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(Offset(0, button.size.height)),
        button.localToGlobal(
            Offset(button.size.width, button.size.height)),
      ),
      Offset.zero & overlay.size,
    );

    showMenu<String>(
      context: context,
      position: position,
      color: AppColors.surface1,
      constraints: const BoxConstraints(minWidth: 220),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: AppColors.border),
      ),
      items: widget.commands.map((cmd) {
        return PopupMenuItem<String>(
          value: cmd.command,
          height: 36,
          child: Row(
            children: [
              const Icon(Icons.play_arrow_rounded,
                  size: 13, color: AppColors.terminal),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  cmd.name,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    ).then((selectedCommand) {
      if (selectedCommand != null) {
        widget.launcherService
            .runCustomCommand(widget.worktreePath, selectedCommand, settings);
      }
    });
  }
}

class _DeleteIcon extends StatefulWidget {
  final VoidCallback onPressed;
  const _DeleteIcon({required this.onPressed});

  @override
  State<_DeleteIcon> createState() => _DeleteIconState();
}

class _DeleteIconState extends State<_DeleteIcon> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: _hovered
                ? AppColors.error.withValues(alpha: 0.2)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(
            Icons.close_rounded,
            size: 14,
            color: _hovered ? AppColors.error : AppColors.textMuted,
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color bgColor;
  final VoidCallback onPressed;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.bgColor,
    required this.onPressed,
  });

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          height: 36,
          decoration: BoxDecoration(
            color: _hovered
                ? widget.color.withValues(alpha: 0.2)
                : widget.bgColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _hovered
                  ? widget.color.withValues(alpha: 0.4)
                  : widget.color.withValues(alpha: 0.15),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(widget.icon, size: 14, color: widget.color),
              const SizedBox(width: 6),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: widget.color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
