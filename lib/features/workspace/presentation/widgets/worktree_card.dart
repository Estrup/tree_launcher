import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:tree_launcher/core/design_system/app_theme.dart';
import 'package:tree_launcher/features/settings/domain/app_settings.dart';
import 'package:tree_launcher/features/workspace/data/launcher_service.dart';
import 'package:tree_launcher/features/workspace/domain/custom_command.dart';
import 'package:tree_launcher/features/workspace/domain/custom_link.dart';
import 'package:tree_launcher/features/workspace/domain/worktree.dart';
import 'package:tree_launcher/models/worktree_slot.dart';
import 'package:tree_launcher/providers/copilot_provider.dart';
import 'package:tree_launcher/providers/repo_provider.dart';
import 'package:tree_launcher/providers/settings_provider.dart';
import 'package:tree_launcher/providers/terminal_provider.dart';

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
    final customLinks = repo?.customLinks ?? [];
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
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row: name + slot badge + primary badge
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        wt.name,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                          letterSpacing: -0.3,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    _SlotBadge(worktree: wt),
                    const SizedBox(width: 6),
                    if (wt.isMain)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.accentMuted,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
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
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: () => _copyToClipboard(context, wt.branch, 'Branch'),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
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
                          Icon(
                            Icons.call_split_rounded,
                            size: 12,
                            color: AppColors.copilot,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              wt.branch,
                              style: TextStyle(
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
                  ),
                ),
                SizedBox(height: 10),

                // Commit + path
                Row(
                  children: [
                    MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        onTap: () => _copyToClipboard(
                          context,
                          wt.commitHash,
                          'Commit hash',
                        ),
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surface2,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            wt.commitHash,
                            style: TextStyle(
                              fontSize: 11,
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.w500,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: GestureDetector(
                          onTap: () =>
                              _copyToClipboard(context, wt.path, 'Path'),
                          child: Tooltip(
                            message: wt.path,
                            child: Text(
                              wt.path.replaceFirst(
                                RegExp(r'^(/Users/[^/]+|[A-Za-z]:\\Users\\[^\\]+)'),
                                '~',
                              ),
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textMuted,
                                fontFamily: 'monospace',
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                Spacer(),

                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: _TerminalSplitButton(
                        worktreePath: wt.path,
                        worktreeName: wt.name,
                        launcherService: _launcherService,
                      ),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: _VscodeSplitButton(
                        worktreePath: wt.path,
                        launcherService: _launcherService,
                      ),
                    ),
                    SizedBox(width: 8),
                    _ActionButton(
                      icon: Icons.auto_awesome_rounded,
                      color: AppColors.copilot,
                      bgColor: AppColors.copilotBg,
                      onPressed: () {
                        if (settings.copilotButtonMode ==
                            CopilotButtonMode.inApp) {
                          final repo = context
                              .read<RepoProvider>()
                              .selectedRepo;
                          context.read<CopilotProvider>().createSession(
                            repo?.path ?? wt.path,
                            wt.path,
                            wt.name,
                          );
                        } else {
                          _launcherService.openCopilotCli(wt.path, settings);
                        }
                      },
                    ),
                    if (customCommands.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      _CustomCommandsButton(
                        worktreePath: wt.path,
                        worktreeName: wt.name,
                        commands: customCommands,
                        slot: wt.slot,
                      ),
                    ],
                    if (customLinks.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      _CustomLinksButton(
                        links: customLinks,
                        slot: wt.slot,
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

  void _copyToClipboard(BuildContext context, String value, String label) {
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copied to clipboard'),
        duration: const Duration(milliseconds: 1500),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final wt = widget.worktree;
    final repoProvider = context.read<RepoProvider>();
    final terminalProvider = context.read<TerminalProvider>();
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

    if (confirmed == true) {
      try {
        terminalProvider.closeSessionsForPath(wt.path);
        await repoProvider.deleteWorktree(wt);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Failed to delete: $e')));
        }
      }
    }
  }
}

class _TerminalSplitButton extends StatefulWidget {
  final String worktreePath;
  final String worktreeName;
  final LauncherService launcherService;

  const _TerminalSplitButton({
    required this.worktreePath,
    required this.worktreeName,
    required this.launcherService,
  });

  @override
  State<_TerminalSplitButton> createState() => _TerminalSplitButtonState();
}

class _TerminalSplitButtonState extends State<_TerminalSplitButton> {
  bool _mainHovered = false;
  bool _dropHovered = false;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: AnimatedContainer(
        duration: Duration(milliseconds: 120),
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
              // Main button — opens embedded terminal
              Expanded(
                child: MouseRegion(
                  onEnter: (_) => setState(() => _mainHovered = true),
                  onExit: (_) => setState(() => _mainHovered = false),
                  child: GestureDetector(
                    onTap: () {
                      final repo = context.read<RepoProvider>().selectedRepo;
                      final tp = context.read<TerminalProvider>();
                      tp.openTerminal(
                        widget.worktreeName,
                        widget.worktreePath,
                        repo?.path ?? widget.worktreePath,
                      );
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 120),
                      color: _mainHovered
                          ? AppColors.terminal.withValues(alpha: 0.2)
                          : Colors.transparent,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.terminal_rounded,
                            size: 14,
                            color: AppColors.terminal,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              'Terminal',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: AppColors.terminal,
                              ),
                              overflow: TextOverflow.ellipsis,
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
                color: AppColors.terminal.withValues(alpha: 0.15),
              ),
              // Dropdown — external terminal
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

  void _showDropdown(BuildContext context) {
    final settings = context.read<SettingsProvider>().settings;
    final RenderBox button = context.findRenderObject() as RenderBox;
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final position = RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(Offset(0, button.size.height)),
        button.localToGlobal(Offset(button.size.width, button.size.height)),
      ),
      Offset.zero & overlay.size,
    );

    showMenu<String>(
      context: context,
      position: position,
      color: AppColors.surface1,
      constraints: const BoxConstraints(minWidth: 200),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: AppColors.border),
      ),
      items: [
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
              SizedBox(width: 8),
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
      if (value == 'external') {
        widget.launcherService.openTerminal(widget.worktreePath, settings);
      }
    });
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
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.code_rounded,
                            size: 14,
                            color: AppColors.vscode,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              'VS Code',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: AppColors.vscode,
                              ),
                              overflow: TextOverflow.ellipsis,
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
                    child: Center(
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

  void _showDropdown(BuildContext context, List<dynamic> configs) {
    final RenderBox button = context.findRenderObject() as RenderBox;
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final position = RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(Offset(0, button.size.height)),
        button.localToGlobal(Offset(button.size.width, button.size.height)),
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
        side: BorderSide(color: AppColors.border),
      ),
      items: configs.map((config) {
        return PopupMenuItem<String>(
          value: config.path as String,
          height: 36,
          child: Row(
            children: [
              Icon(Icons.code_rounded, size: 13, color: AppColors.vscode),
              const SizedBox(width: 8),
              Text(
                config.name as String,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  config.path as String,
                  style: TextStyle(
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
  final String worktreeName;
  final List<CustomCommand> commands;
  final String slot;

  const _CustomCommandsButton({
    required this.worktreePath,
    required this.worktreeName,
    required this.commands,
    required this.slot,
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
          child: Center(
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
    final repo = context.read<RepoProvider>().selectedRepo;
    final tp = context.read<TerminalProvider>();
    final RenderBox button = context.findRenderObject() as RenderBox;
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final position = RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(Offset(0, button.size.height)),
        button.localToGlobal(Offset(button.size.width, button.size.height)),
      ),
      Offset.zero & overlay.size,
    );

    showMenu<CustomCommand>(
      context: context,
      position: position,
      color: AppColors.surface1,
      constraints: const BoxConstraints(minWidth: 220),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: AppColors.border),
      ),
      items: widget.commands.map((cmd) {
        return PopupMenuItem<CustomCommand>(
          value: cmd,
          height: 36,
          child: Row(
            children: [
              Icon(
                Icons.play_arrow_rounded,
                size: 13,
                color: AppColors.terminal,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  cmd.name,
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
        );
      }).toList(),
    ).then((selected) {
      if (selected != null) {
        final command = selected.command.replaceAll('{{SLOT}}', widget.slot);
        tp.openTerminalWithCommand(
          '${widget.worktreeName}: ${selected.name}',
          widget.worktreePath,
          repo?.path ?? widget.worktreePath,
          command,
        );
      }
    });
  }
}

class _CustomLinksButton extends StatefulWidget {
  final List<CustomLink> links;
  final String slot;

  const _CustomLinksButton({
    required this.links,
    required this.slot,
  });

  @override
  State<_CustomLinksButton> createState() => _CustomLinksButtonState();
}

class _CustomLinksButtonState extends State<_CustomLinksButton> {
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
                ? AppColors.accent.withValues(alpha: 0.2)
                : AppColors.accentMuted,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _hovered
                  ? AppColors.accent.withValues(alpha: 0.4)
                  : AppColors.accent.withValues(alpha: 0.15),
            ),
          ),
          child: Center(
            child: Icon(
              Icons.link_rounded,
              size: 18,
              color: AppColors.accent,
            ),
          ),
        ),
      ),
    );
  }

  void _showDropdown(BuildContext context) {
    final RenderBox button = context.findRenderObject() as RenderBox;
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final position = RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(Offset(0, button.size.height)),
        button.localToGlobal(Offset(button.size.width, button.size.height)),
      ),
      Offset.zero & overlay.size,
    );

    showMenu<CustomLink>(
      context: context,
      position: position,
      color: AppColors.surface1,
      constraints: const BoxConstraints(minWidth: 220),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: AppColors.border),
      ),
      items: widget.links.map((link) {
        return PopupMenuItem<CustomLink>(
          value: link,
          height: 36,
          child: Row(
            children: [
              Icon(
                Icons.open_in_new_rounded,
                size: 13,
                color: AppColors.accent,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  link.name,
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
        );
      }).toList(),
    ).then((selected) {
      if (selected != null) {
        final url = selected.url.replaceAll('{{SLOT}}', widget.slot);
        Process.run('open', [url]);
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
  final String? label;
  final Color color;
  final Color bgColor;
  final VoidCallback onPressed;

  const _ActionButton({
    required this.icon,
    this.label,
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
          width: widget.label == null ? 36 : null,
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
              if (widget.label != null) ...[
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    widget.label!,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: widget.color,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SlotBadge extends StatelessWidget {
  final Worktree worktree;

  const _SlotBadge({required this.worktree});

  @override
  Widget build(BuildContext context) {
    final rp = context.read<RepoProvider>();
    final repo = rp.selectedRepo;
    if (repo == null) return const SizedBox.shrink();

    // Collect slots already used by other worktrees in this repo
    final allWorktrees = rp.worktrees;
    final usedSlots = <String>{};
    for (final wt in allWorktrees) {
      if (wt.path != worktree.path) {
        usedSlots.add(wt.slot);
      }
    }
    final availableSlots =
        greekSlots.where((s) => !usedSlots.contains(s)).toList();

    return PopupMenuButton<String>(
      tooltip: 'Change slot',
      offset: const Offset(0, 28),
      color: AppColors.surface2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: AppColors.border),
      ),
      onSelected: (slot) {
        rp.updateSlotAssignment(worktree.path, slot);
      },
      itemBuilder: (_) => availableSlots.map((slot) {
        final isCurrent = slot == worktree.slot;
        return PopupMenuItem<String>(
          value: slot,
          height: 32,
          child: Text(
            slot.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
              color: isCurrent ? AppColors.accent : AppColors.textSecondary,
              letterSpacing: 0.5,
            ),
          ),
        );
      }).toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.terminalBg,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: AppColors.terminal.withValues(alpha: 0.3),
          ),
        ),
        child: Text(
          worktree.slot.toUpperCase(),
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            color: AppColors.terminal,
            letterSpacing: 0.8,
          ),
        ),
      ),
    );
  }
}
