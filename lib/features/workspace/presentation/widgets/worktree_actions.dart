import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:tree_launcher/core/design_system/app_theme.dart';
import 'package:tree_launcher/features/workspace/data/launcher_service.dart';
import 'package:tree_launcher/features/workspace/domain/command_style.dart';
import 'package:tree_launcher/features/workspace/domain/custom_command.dart';
import 'package:tree_launcher/features/workspace/domain/custom_link.dart';
import 'package:tree_launcher/features/workspace/domain/worktree.dart';
import 'package:tree_launcher/providers/repo_provider.dart';
import 'package:tree_launcher/providers/settings_provider.dart';
import 'package:tree_launcher/providers/terminal_provider.dart';

/// Base URL for JIRA issues. The issue key is appended to build the link.
const String jiraBaseUrl = 'https://jira.elbek-vejrup.dk/browse/';

/// Builds the standard Claude launch context prompt from a worktree's recorded
/// JIRA issue and base branch. Returns null when neither is known.
String? claudeContextPrompt(Worktree wt) {
  final issue = wt.jiraIssue;
  final base = wt.baseBranch;
  if (issue != null && issue.isNotEmpty && base != null && base.isNotEmpty) {
    return 'Context: Working on issue $issue where the base branch is $base.';
  }
  if (issue != null && issue.isNotEmpty) {
    return 'Context: Working on issue $issue.';
  }
  if (base != null && base.isNotEmpty) {
    return 'Context: The base branch is $base.';
  }
  return null;
}

/// Copies [value] to the clipboard and shows a brief confirmation snackbar.
void copyToClipboard(BuildContext context, String value, String label) {
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

/// Shows the standard delete-worktree confirmation dialog and, when confirmed,
/// closes any open terminal sessions for the path and deletes the worktree.
Future<void> confirmDeleteWorktree(BuildContext context, Worktree wt) async {
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

/// Opens a dropdown menu positioned below [anchorContext]'s render box.
Future<T?> _showMenuBelow<T>(
  BuildContext anchorContext, {
  required List<PopupMenuEntry<T>> items,
  double minWidth = 200,
}) {
  final RenderBox button = anchorContext.findRenderObject() as RenderBox;
  final overlay =
      Overlay.of(anchorContext).context.findRenderObject() as RenderBox;
  final position = RelativeRect.fromRect(
    Rect.fromPoints(
      button.localToGlobal(Offset(0, button.size.height)),
      button.localToGlobal(Offset(button.size.width, button.size.height)),
    ),
    Offset.zero & overlay.size,
  );

  return showMenu<T>(
    context: anchorContext,
    position: position,
    color: AppColors.surface1,
    constraints: BoxConstraints(minWidth: minWidth),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
      side: BorderSide(color: AppColors.border),
    ),
    items: items,
  );
}

// ---------------------------------------------------------------------------
// Terminal button
// ---------------------------------------------------------------------------

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
    final repo = context.read<RepoProvider>().selectedRepo;
    final tp = context.read<TerminalProvider>();
    tp.openTerminal(
      widget.worktreeName,
      widget.worktreePath,
      repo?.path ?? widget.worktreePath,
    );
  }

  void _showDropdown(BuildContext context) {
    final settings = context.read<SettingsProvider>().settings;
    _showMenuBelow<String>(
      context,
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
      if (value == 'external') {
        widget.launcherService.openTerminal(widget.worktreePath, settings);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.compact) {
      return _CompactSplitButton(
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

class VscodeButton extends StatefulWidget {
  final String worktreePath;
  final LauncherService launcherService;
  final bool compact;

  const VscodeButton({
    super.key,
    required this.worktreePath,
    required this.launcherService,
    this.compact = false,
  });

  @override
  State<VscodeButton> createState() => _VscodeButtonState();
}

class _VscodeButtonState extends State<VscodeButton> {
  bool _mainHovered = false;
  bool _dropHovered = false;

  void _showDropdown(BuildContext context, List<dynamic> configs) {
    _showMenuBelow<String>(
      context,
      minWidth: 280,
      items: configs.map((config) {
        return PopupMenuItem<String>(
          value: config.path as String,
          height: 36,
          child: Row(
            children: [
              SvgPicture.asset(
                'assets/icons/vscode.svg',
                width: 13,
                height: 13,
                colorFilter: ColorFilter.mode(
                  AppColors.vscode,
                  BlendMode.srcIn,
                ),
              ),
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

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<RepoProvider>().selectedRepo;
    final configs = repo?.vscodeConfigs ?? [];
    final hasConfigs = configs.isNotEmpty;

    if (widget.compact) {
      final vscodeIcon = SvgPicture.asset(
        'assets/icons/vscode.svg',
        width: 14,
        height: 14,
        colorFilter: ColorFilter.mode(AppColors.vscode, BlendMode.srcIn),
      );
      return _CompactSplitButton(
        color: AppColors.vscode,
        bgColor: AppColors.vscodeBg,
        tooltip: 'VS Code',
        icon: vscodeIcon,
        onPrimary: () => widget.launcherService.openVSCode(widget.worktreePath),
        onDropdown: hasConfigs ? () => _showDropdown(context, configs) : null,
      );
    }

    if (!hasConfigs) {
      return Tooltip(
        message: 'VS Code',
        child: ActionButton(
          svgAsset: 'assets/icons/vscode.svg',
          color: AppColors.vscode,
          bgColor: AppColors.vscodeBg,
          onPressed: () =>
              widget.launcherService.openVSCode(widget.worktreePath),
        ),
      );
    }

    return SizedBox(
      width: 60,
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
              Expanded(
                child: MouseRegion(
                  onEnter: (_) => setState(() => _mainHovered = true),
                  onExit: (_) => setState(() => _mainHovered = false),
                  child: GestureDetector(
                    onTap: () =>
                        widget.launcherService.openVSCode(widget.worktreePath),
                    child: Tooltip(
                      message: 'VS Code',
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 120),
                        color: _mainHovered
                            ? AppColors.vscode.withValues(alpha: 0.2)
                            : Colors.transparent,
                        child: Center(
                          child: SvgPicture.asset(
                            'assets/icons/vscode.svg',
                            width: 15,
                            height: 15,
                            colorFilter: ColorFilter.mode(
                              AppColors.vscode,
                              BlendMode.srcIn,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Container(
                width: 1,
                color: AppColors.vscode.withValues(alpha: 0.15),
              ),
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
}

/// A compact (table-mode) icon button whose body click runs [onPrimary]. When
/// [onDropdown] is non-null a small caret affordance is shown that opens the
/// extra-options dropdown — deliberately *not* a 50/50 split button.
class _CompactSplitButton extends StatefulWidget {
  final Color color;
  final Color bgColor;
  final String tooltip;
  final Widget icon;
  final VoidCallback onPrimary;
  final VoidCallback? onDropdown;

  const _CompactSplitButton({
    required this.color,
    required this.bgColor,
    required this.tooltip,
    required this.icon,
    required this.onPrimary,
    required this.onDropdown,
  });

  @override
  State<_CompactSplitButton> createState() => _CompactSplitButtonState();
}

class _CompactSplitButtonState extends State<_CompactSplitButton> {
  bool _mainHovered = false;
  bool _dropHovered = false;

  @override
  Widget build(BuildContext context) {
    final hovered = _mainHovered || _dropHovered;
    return SizedBox(
      height: 28,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        decoration: BoxDecoration(
          color: hovered ? widget.color.withValues(alpha: 0.2) : widget.bgColor,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(
            color: hovered
                ? widget.color.withValues(alpha: 0.4)
                : widget.color.withValues(alpha: 0.15),
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              MouseRegion(
                onEnter: (_) => setState(() => _mainHovered = true),
                onExit: (_) => setState(() => _mainHovered = false),
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: widget.onPrimary,
                  child: Tooltip(
                    message: widget.tooltip,
                    child: SizedBox(
                      width: 28,
                      height: 28,
                      child: Center(child: widget.icon),
                    ),
                  ),
                ),
              ),
              if (widget.onDropdown != null)
                MouseRegion(
                  onEnter: (_) => setState(() => _dropHovered = true),
                  onExit: (_) => setState(() => _dropHovered = false),
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: widget.onDropdown,
                    child: SizedBox(
                      width: 14,
                      height: 28,
                      child: Center(
                        child: Icon(
                          Icons.arrow_drop_down_rounded,
                          size: 16,
                          color: widget.color,
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
// Custom commands button
// ---------------------------------------------------------------------------

class CustomCommandsButton extends StatefulWidget {
  final String worktreePath;
  final String worktreeName;
  final List<CustomCommand> commands;
  final String slot;
  final bool compact;

  const CustomCommandsButton({
    super.key,
    required this.worktreePath,
    required this.worktreeName,
    required this.commands,
    required this.slot,
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

    final selected = <String>{};

    void runSelected() {
      Navigator.pop(context);
      for (final cmd in widget.commands) {
        if (!selected.contains(cmd.name)) continue;
        final command = cmd.command.replaceAll('{{SLOT}}', widget.slot);
        tp.openTerminalWithCommand(
          '${cmd.name}: ${widget.worktreeName}',
          widget.worktreePath,
          repo?.path ?? widget.worktreePath,
          command,
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
// Custom links button
// ---------------------------------------------------------------------------

class CustomLinksButton extends StatefulWidget {
  final List<CustomLink> links;
  final String slot;
  final bool compact;

  const CustomLinksButton({
    super.key,
    required this.links,
    required this.slot,
    this.compact = false,
  });

  @override
  State<CustomLinksButton> createState() => _CustomLinksButtonState();
}

class _CustomLinksButtonState extends State<CustomLinksButton> {
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
              size: widget.compact ? 16 : 18,
              color: AppColors.accent,
            ),
          ),
        ),
      ),
    );
  }

  void _showDropdown(BuildContext context) {
    _showMenuBelow<CustomLink>(
      context,
      minWidth: 220,
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

// ---------------------------------------------------------------------------
// Delete icon
// ---------------------------------------------------------------------------

class DeleteIconButton extends StatefulWidget {
  final VoidCallback onPressed;
  const DeleteIconButton({super.key, required this.onPressed});

  @override
  State<DeleteIconButton> createState() => _DeleteIconButtonState();
}

class _DeleteIconButtonState extends State<DeleteIconButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onPressed,
        child: Tooltip(
          message: 'Delete worktree',
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
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Generic action button (copilot, claude, vscode-no-configs)
// ---------------------------------------------------------------------------

class ActionButton extends StatefulWidget {
  final IconData? icon;
  final String? svgAsset;
  final Color color;
  final Color bgColor;
  final VoidCallback onPressed;
  final bool compact;

  const ActionButton({
    super.key,
    this.icon,
    this.svgAsset,
    required this.color,
    required this.bgColor,
    required this.onPressed,
    this.compact = false,
  }) : assert(icon != null || svgAsset != null);

  @override
  State<ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<ActionButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final size = widget.compact ? 28.0 : 36.0;
    final glyphSize = widget.compact ? 13.0 : 14.0;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: size,
          height: size,
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
              widget.svgAsset != null
                  ? SvgPicture.asset(
                      widget.svgAsset!,
                      width: glyphSize,
                      height: glyphSize,
                      colorFilter: ColorFilter.mode(
                        widget.color,
                        BlendMode.srcIn,
                      ),
                    )
                  : Icon(widget.icon, size: glyphSize, color: widget.color),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// JIRA badge (link)
// ---------------------------------------------------------------------------

class JiraBadge extends StatefulWidget {
  final String issueKey;
  final bool compact;

  const JiraBadge({super.key, required this.issueKey, this.compact = false});

  @override
  State<JiraBadge> createState() => _JiraBadgeState();
}

class _JiraBadgeState extends State<JiraBadge> {
  static const Color _jiraColor = Color(0xFF2684FF);
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final iconSize = widget.compact ? 11.0 : 12.0;
    final fontSize = widget.compact ? 11.0 : 12.0;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () => Process.run('open', ['$jiraBaseUrl${widget.issueKey}']),
        child: Tooltip(
          message: 'Open $jiraBaseUrl${widget.issueKey}',
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: widget.compact ? 8 : 10,
              vertical: widget.compact ? 3 : 5,
            ),
            decoration: BoxDecoration(
              color: _jiraColor.withValues(alpha: _hovered ? 0.18 : 0.1),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: _jiraColor.withValues(alpha: _hovered ? 0.4 : 0.2),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.open_in_new_rounded,
                  size: iconSize,
                  color: _jiraColor,
                ),
                const SizedBox(width: 6),
                Text(
                  widget.issueKey,
                  style: TextStyle(
                    fontSize: fontSize,
                    fontWeight: FontWeight.w600,
                    color: _jiraColor,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
