import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import '../models/custom_command.dart';
import '../providers/copilot_provider.dart';
import '../providers/repo_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/terminal_provider.dart';
import '../services/chatgpt_service.dart';
import '../services/launcher_service.dart';
import '../services/microphone_recording_service.dart';
import '../services/shortcut_overlay_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/repo_sidebar.dart';
import '../widgets/worktree_grid.dart';
import '../widgets/repo_settings_view.dart';
import '../widgets/terminal_panel.dart';
import '../widgets/running_commands_bar.dart';
import '../widgets/copilot_terminal_view.dart';
import '../widgets/copilot_attention_snackbar.dart';
import '../widgets/add_repo_dialog.dart';
import '../widgets/add_worktree_dialog.dart';
import '../widgets/settings_dialog.dart';
import '../widgets/shortcut_overlay.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const double _collapseBreakpoint = 800;
  bool _sidebarOpen = false;
  late final ShortcutOverlayController _shortcutOverlayController;

  @override
  void initState() {
    super.initState();
    _shortcutOverlayController = ShortcutOverlayController(
      microphoneRecordingService: MicrophoneRecordingService(),
      chatGptService: ChatGptService(),
      repoProvider: context.read<RepoProvider>(),
      settingsProvider: context.read<SettingsProvider>(),
    );
  }

  @override
  void dispose() {
    _shortcutOverlayController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repoProvider = context.watch<RepoProvider>();
    final copilotProvider = context.watch<CopilotProvider>();
    final isCopilotActive = copilotProvider.activeSession != null;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.backquote, meta: true): () {
          final tp = context.read<TerminalProvider>();
          if (tp.sessions.isNotEmpty) {
            tp.toggleVisibility();
          }
        },
        const SingleActivator(LogicalKeyboardKey.keyM, control: true): () {
          unawaited(_shortcutOverlayController.handleShortcut());
        },
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          backgroundColor: AppColors.base,
          body: LayoutBuilder(
            builder: (context, constraints) {
              final isCollapsed = constraints.maxWidth < _collapseBreakpoint;

              // Auto-close overlay when window grows past breakpoint
              if (!isCollapsed && _sidebarOpen) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) setState(() => _sidebarOpen = false);
                });
              }

              if (repoProvider.showSettings) {
                return const RepoSettingsView();
              }

              return Stack(
                children: [
                  Row(
                    children: [
                      if (!isCollapsed)
                        RepoSidebar(
                          onAddRepo: () => AddRepoDialog.show(context),
                          onOpenSettings: () => SettingsDialog.show(context),
                        ),
                      Expanded(
                        child: Column(
                          children: [
                            _buildHeader(
                              context,
                              repoProvider,
                              copilotProvider,
                              showMenuButton: isCollapsed,
                            ),
                            if (isCopilotActive)
                              const Expanded(child: CopilotTerminalView())
                            else ...[
                              Expanded(child: const WorktreeGrid()),
                              const RunningCommandsBar(),
                              const TerminalPanel(),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  // Scrim
                  if (isCollapsed && _sidebarOpen)
                    GestureDetector(
                      onTap: () => setState(() => _sidebarOpen = false),
                      child: AnimatedOpacity(
                        opacity: _sidebarOpen ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 200),
                        child: Container(color: Colors.black54),
                      ),
                    ),
                  // Sliding sidebar overlay
                  if (isCollapsed)
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      top: 0,
                      bottom: 0,
                      left: _sidebarOpen ? 0 : -240,
                      width: 240,
                      child: Material(
                        elevation: 8,
                        color: Colors.transparent,
                        child: RepoSidebar(
                          onAddRepo: () {
                            setState(() => _sidebarOpen = false);
                            AddRepoDialog.show(context);
                          },
                          onOpenSettings: () {
                            setState(() => _sidebarOpen = false);
                            SettingsDialog.show(context);
                          },
                        ),
                      ),
                    ),
                  // Copilot attention notification
                  const CopilotAttentionSnackbar(),
                  ShortcutOverlay(controller: _shortcutOverlayController),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    RepoProvider repoProvider,
    CopilotProvider copilotProvider, {
    bool showMenuButton = false,
  }) {
    final selectedRepo = repoProvider.selectedRepo;
    final activeCopilot = copilotProvider.activeSession;

    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: AppColors.surface0,
        border: Border(
          bottom: BorderSide(color: AppColors.borderSubtle, width: 1),
        ),
      ),
      child: Row(
        children: [
          if (showMenuButton) ...[
            _MenuButton(
              onPressed: () => setState(() => _sidebarOpen = !_sidebarOpen),
            ),
            const SizedBox(width: 12),
          ],
          if (selectedRepo != null) ...[
            if (activeCopilot != null) ...[
              // Breadcrumb: reponame > session-name
              GestureDetector(
                onTap: () => copilotProvider.deselectSession(),
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Text(
                    selectedRepo.name,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textMuted,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: AppColors.textMuted,
                ),
              ),
              Icon(
                Icons.auto_awesome_rounded,
                size: 16,
                color: AppColors.copilot,
              ),
              const SizedBox(width: 6),
              Text(
                activeCopilot.name,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
            ] else ...[
              // Normal header: repo name + count
              Text(
                selectedRepo.name,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.accentMuted,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${repoProvider.worktrees.length}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.accent,
                  ),
                ),
              ),
            ],
          ] else
            Text(
              'TreeLauncher',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                letterSpacing: -0.3,
              ),
            ),
          const Spacer(),
          if (selectedRepo != null && activeCopilot != null) ...[
            _HeaderVscodeButton(
              worktreePath: activeCopilot.workingDirectory,
              vscodeConfigs: selectedRepo.vscodeConfigs,
            ),
            if (selectedRepo.customCommands.isNotEmpty) ...[
              const SizedBox(width: 8),
              _HeaderCommandsButton(
                worktreePath: activeCopilot.workingDirectory,
                worktreeName: activeCopilot.name,
                commands: selectedRepo.customCommands,
              ),
            ],
          ],
          if (selectedRepo != null && activeCopilot == null) ...[
            _AddWorktreeButton(
              onPressed: () => AddWorktreeDialog.show(context),
            ),
            const SizedBox(width: 8),
            _TerminalToggleButton(),
            const SizedBox(width: 8),
            _RefreshButton(
              loading: repoProvider.loading,
              onPressed: () => repoProvider.refreshWorktrees(),
            ),
          ],
        ],
      ),
    );
  }
}

class _RefreshButton extends StatefulWidget {
  final bool loading;
  final VoidCallback onPressed;

  const _RefreshButton({required this.loading, required this.onPressed});

  @override
  State<_RefreshButton> createState() => _RefreshButtonState();
}

class _RefreshButtonState extends State<_RefreshButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.loading ? null : widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _hovered ? AppColors.surface2 : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: widget.loading
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.accent,
                  ),
                )
              : Icon(
                  Icons.refresh_rounded,
                  size: 20,
                  color: _hovered ? AppColors.textPrimary : AppColors.textMuted,
                ),
        ),
      ),
    );
  }
}

class _TerminalToggleButton extends StatefulWidget {
  @override
  State<_TerminalToggleButton> createState() => _TerminalToggleButtonState();
}

class _TerminalToggleButtonState extends State<_TerminalToggleButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final tp = context.watch<TerminalProvider>();
    final isActive = tp.isVisible && tp.sessions.isNotEmpty;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () {
          if (tp.sessions.isNotEmpty) {
            tp.toggleVisibility();
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isActive
                ? AppColors.terminal.withValues(alpha: 0.15)
                : (_hovered ? AppColors.surface2 : Colors.transparent),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.terminal_rounded,
            size: 20,
            color: isActive
                ? AppColors.terminal
                : (_hovered ? AppColors.textPrimary : AppColors.textMuted),
          ),
        ),
      ),
    );
  }
}

class _AddWorktreeButton extends StatefulWidget {
  final VoidCallback onPressed;

  const _AddWorktreeButton({required this.onPressed});

  @override
  State<_AddWorktreeButton> createState() => _AddWorktreeButtonState();
}

class _AddWorktreeButtonState extends State<_AddWorktreeButton> {
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
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: _hovered
                ? AppColors.terminal.withValues(alpha: 0.15)
                : AppColors.terminalBg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _hovered
                  ? AppColors.terminal.withValues(alpha: 0.4)
                  : AppColors.terminal.withValues(alpha: 0.15),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add_rounded, size: 15, color: AppColors.terminal),
              SizedBox(width: 5),
              Text(
                'New Worktree',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.terminal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuButton extends StatefulWidget {
  final VoidCallback onPressed;

  const _MenuButton({required this.onPressed});

  @override
  State<_MenuButton> createState() => _MenuButtonState();
}

class _MenuButtonState extends State<_MenuButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _hovered ? AppColors.surface2 : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.menu_rounded,
            size: 20,
            color: _hovered ? AppColors.textPrimary : AppColors.textMuted,
          ),
        ),
      ),
    );
  }
}

class _HeaderVscodeButton extends StatefulWidget {
  final String worktreePath;
  final List<dynamic> vscodeConfigs;

  const _HeaderVscodeButton({
    required this.worktreePath,
    required this.vscodeConfigs,
  });

  @override
  State<_HeaderVscodeButton> createState() => _HeaderVscodeButtonState();
}

class _HeaderVscodeButtonState extends State<_HeaderVscodeButton> {
  bool _hovered = false;
  final LauncherService _launcherService = LauncherService();

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () {
          if (widget.vscodeConfigs.isEmpty) {
            _launcherService.openVSCode(widget.worktreePath);
          } else {
            _showDropdown(context);
          }
        },
        child: Tooltip(
          message: 'Open in VS Code',
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _hovered
                  ? AppColors.vscode.withValues(alpha: 0.15)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.code_rounded,
              size: 20,
              color: _hovered ? AppColors.vscode : AppColors.textMuted,
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

    showMenu<String>(
      context: context,
      position: position,
      color: AppColors.surface1,
      constraints: const BoxConstraints(minWidth: 280),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: AppColors.border),
      ),
      items: [
        PopupMenuItem<String>(
          value: '',
          height: 36,
          child: Row(
            children: [
              Icon(Icons.code_rounded, size: 13, color: AppColors.vscode),
              const SizedBox(width: 8),
              Text(
                'VS Code (default)',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
        ...widget.vscodeConfigs.map((config) {
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
        }),
      ],
    ).then((selectedPath) {
      if (selectedPath != null) {
        if (selectedPath.isEmpty) {
          _launcherService.openVSCode(widget.worktreePath);
        } else {
          final resolved = p.join(widget.worktreePath, selectedPath);
          _launcherService.openVSCode(resolved);
        }
      }
    });
  }
}

class _HeaderCommandsButton extends StatefulWidget {
  final String worktreePath;
  final String worktreeName;
  final List<CustomCommand> commands;

  const _HeaderCommandsButton({
    required this.worktreePath,
    required this.worktreeName,
    required this.commands,
  });

  @override
  State<_HeaderCommandsButton> createState() => _HeaderCommandsButtonState();
}

class _HeaderCommandsButtonState extends State<_HeaderCommandsButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () => _showDropdown(context),
        child: Tooltip(
          message: 'Run Command',
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _hovered
                  ? AppColors.terminal.withValues(alpha: 0.15)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.play_arrow_rounded,
              size: 20,
              color: _hovered ? AppColors.terminal : AppColors.textMuted,
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
        tp.openTerminalWithCommand(
          '${widget.worktreeName}: ${selected.name}',
          widget.worktreePath,
          repo?.path ?? widget.worktreePath,
          selected.command,
        );
      }
    });
  }
}
