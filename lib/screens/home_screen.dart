import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:tree_launcher/core/design_system/app_theme.dart';
import 'package:tree_launcher/features/copilot/presentation/widgets/copilot_attention_snackbar.dart';
import 'package:tree_launcher/features/copilot/presentation/widgets/copilot_terminal_view.dart';
import 'package:tree_launcher/features/kanban/presentation/widgets/create_project_dialog.dart';
import 'package:tree_launcher/features/kanban/presentation/widgets/kanban_board.dart';
import 'package:tree_launcher/features/settings/presentation/widgets/settings_dialog.dart';
import 'package:tree_launcher/features/terminal/presentation/widgets/running_commands_bar.dart';
import 'package:tree_launcher/features/terminal/presentation/widgets/terminal_panel.dart';
import 'package:tree_launcher/features/agent/presentation/controllers/agent_panel_controller.dart';
import 'package:tree_launcher/features/agent/presentation/widgets/agent_panel.dart';
import 'package:tree_launcher/features/workspace/domain/custom_command.dart';
import 'package:tree_launcher/features/workspace/data/launcher_service.dart';
import 'package:tree_launcher/features/workspace/presentation/widgets/add_repo_dialog.dart';
import 'package:tree_launcher/features/workspace/presentation/widgets/add_worktree_dialog.dart';
import 'package:tree_launcher/features/workspace/presentation/widgets/repo_settings_view.dart';
import 'package:tree_launcher/features/workspace/presentation/widgets/repo_sidebar.dart';
import 'package:tree_launcher/features/workspace/presentation/widgets/worktree_grid.dart';
import 'package:tree_launcher/providers/copilot_provider.dart';
import 'package:tree_launcher/providers/kanban_provider.dart';
import 'package:tree_launcher/providers/repo_provider.dart';
import 'package:tree_launcher/providers/terminal_provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  static const double _collapseBreakpoint = 800;
  bool _sidebarOpen = false;
  TabController? _tabController;
  int _lastTabCount = 0;
  AgentPanelController? _agentController;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleGlobalKeyEvent);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _agentController = context.read<AgentPanelController>();
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleGlobalKeyEvent);
    _tabController?.dispose();
    super.dispose();
  }

  bool _handleGlobalKeyEvent(KeyEvent event) {
    if (!mounted || event is! KeyDownEvent) return false;
    final agentController = _agentController;
    if (agentController == null) return false;

    final keyboard = HardwareKeyboard.instance;
    if (event.logicalKey == LogicalKeyboardKey.keyM) {
      if (!keyboard.isControlPressed ||
          keyboard.isAltPressed ||
          keyboard.isMetaPressed ||
          keyboard.isShiftPressed) {
        return false;
      }

      unawaited(agentController.handleVoiceShortcut());
      return true;
    }

    if (event.logicalKey == LogicalKeyboardKey.keyL) {
      if (!keyboard.isMetaPressed ||
          keyboard.isAltPressed ||
          keyboard.isControlPressed ||
          keyboard.isShiftPressed ||
          !agentController.panelOpen) {
        return false;
      }

      agentController.clearHistory();
      return true;
    }

    if (event.logicalKey == LogicalKeyboardKey.keyI) {
      if (!keyboard.isMetaPressed ||
          !keyboard.isAltPressed ||
          keyboard.isControlPressed ||
          keyboard.isShiftPressed) {
        return false;
      }

      unawaited(agentController.handleCopilotSummaryShortcut());
      return true;
    }

    return false;
  }

  void _onTabChanged() {
    if (!mounted || _tabController == null) return;
    if (_tabController!.indexIsChanging) return;

    final repoProvider = context.read<RepoProvider>();
    final copilotProvider = context.read<CopilotProvider>();
    final kanbanProvider = context.read<KanbanProvider>();
    final projects = kanbanProvider.projects;
    final sessionsStartIdx = projects.length + 1;

    if (_tabController!.index >= sessionsStartIdx) {
      final sessionIdx = _tabController!.index - sessionsStartIdx;
      final allSessions = copilotProvider.allSessions
          .where((s) => s.repoPath == repoProvider.selectedRepo?.path)
          .toList();
      if (sessionIdx >= 0 && sessionIdx < allSessions.length) {
        final session = allSessions[sessionIdx];
        if (copilotProvider.activeSession?.id != session.id) {
          copilotProvider.selectSession(session);
        }
      }
    } else {
      if (copilotProvider.activeSession != null) {
        copilotProvider.deselectSession();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final repoProvider = context.watch<RepoProvider>();
    final copilotProvider = context.watch<CopilotProvider>();
    final kanbanProvider = context.watch<KanbanProvider>();
    final agentController = context.read<AgentPanelController>();
    final isCopilotActive = copilotProvider.activeSession != null;

    final projects = kanbanProvider.projects;
    final repoPath = repoProvider.selectedRepo?.path;
    final allSessions = copilotProvider.allSessions
        .where((s) => s.repoPath == repoPath)
        .toList();
    final tabCount = projects.length + 1 + allSessions.length;

    if (_tabController == null || _lastTabCount != tabCount) {
      final oldIndex = _tabController?.index ?? 0;
      _tabController?.dispose();
      _tabController = TabController(
        length: tabCount,
        initialIndex: oldIndex >= tabCount
            ? (tabCount > 0 ? tabCount - 1 : 0)
            : oldIndex,
        vsync: this,
      );
      _tabController!.addListener(_onTabChanged);
      _lastTabCount = tabCount;
    }

    if (isCopilotActive) {
      final sessionIndex = allSessions.indexWhere(
        (s) => s.id == copilotProvider.activeSession!.id,
      );
      if (sessionIndex != -1) {
        final targetIndex = projects.length + 1 + sessionIndex;
        if (_tabController!.index != targetIndex) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _tabController!.index != targetIndex) {
              _tabController!.animateTo(targetIndex);
            }
          });
        }
      }
    } else {
      if (_tabController!.index >= projects.length + 1) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _tabController!.animateTo(0);
        });
      }
    }

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.backquote, meta: true): () {
          final tp = context.read<TerminalProvider>();
          if (tp.sessions.isNotEmpty) {
            tp.toggleVisibility();
          }
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
                          onOpenAgent: () => agentController.openPanel(),
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
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      left: 24,
                                      right: 24,
                                      top: 16,
                                      bottom: 0,
                                    ),
                                    child: AnimatedBuilder(
                                      animation: _tabController!,
                                      builder: (context, _) {
                                        final currentIndex =
                                            _tabController!.index;
                                        return SingleChildScrollView(
                                          scrollDirection: Axis.horizontal,
                                          child: Row(
                                            children: [
                                              // Worktrees & Projects Segmented Control
                                              Container(
                                                padding: const EdgeInsets.all(
                                                  4,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: AppColors.surface0,
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                ),
                                                child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    _buildSegmentTab(
                                                      text: "Worktrees",
                                                      index: 0,
                                                      currentIndex:
                                                          currentIndex,
                                                      onTap: () =>
                                                          _tabController!
                                                              .animateTo(0),
                                                    ),
                                                    for (
                                                      int i = 0;
                                                      i < projects.length;
                                                      i++
                                                    )
                                                      _buildSegmentTab(
                                                        text: projects[i].name,
                                                        index: i + 1,
                                                        currentIndex:
                                                            currentIndex,
                                                        onTap: () =>
                                                            _tabController!
                                                                .animateTo(
                                                                  i + 1,
                                                                ),
                                                        onSecondaryTapUp:
                                                            (
                                                              details,
                                                            ) => _showProjectContextMenu(
                                                              context,
                                                              details
                                                                  .globalPosition,
                                                              projects[i].id,
                                                              kanbanProvider,
                                                            ),
                                                      ),
                                                  ],
                                                ),
                                              ),
                                              // Copilot Sessions Group
                                              if (allSessions.isNotEmpty) ...[
                                                const SizedBox(width: 8),
                                                Container(
                                                  padding: const EdgeInsets.all(
                                                    4,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: AppColors.surface0,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          10,
                                                        ),
                                                    border: Border.all(
                                                      color: AppColors.copilot
                                                          .withValues(
                                                            alpha: 0.2,
                                                          ),
                                                    ),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      for (
                                                        int i = 0;
                                                        i < allSessions.length;
                                                        i++
                                                      )
                                                        _buildSegmentTab(
                                                          text: allSessions[i]
                                                              .name,
                                                          index:
                                                              projects.length +
                                                              1 +
                                                              i,
                                                          currentIndex:
                                                              currentIndex,
                                                          icon: Icons
                                                              .auto_awesome_rounded,
                                                          activeColor:
                                                              AppColors.copilot,
                                                          onTap: () =>
                                                              _tabController!
                                                                  .animateTo(
                                                                    projects.length +
                                                                        1 +
                                                                        i,
                                                                  ),
                                                        ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Expanded(
                                    child: TabBarView(
                                      controller: _tabController,
                                      physics:
                                          const NeverScrollableScrollPhysics(),
                                      children: [
                                        const WorktreeGrid(),
                                        ...projects.map(
                                          (p) => KanbanBoard(projectId: p.id),
                                        ),
                                        ...allSessions.map(
                                          (s) => CopilotTerminalView(
                                            key: ValueKey(s.id),
                                            sessionId: s.id,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const RunningCommandsBar(),
                            const TerminalPanel(),
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
                          onOpenAgent: () {
                            setState(() => _sidebarOpen = false);
                            agentController.openPanel();
                          },
                        ),
                      ),
                    ),
                  // Copilot attention notification
                  const CopilotAttentionSnackbar(),
                  AgentPanel(controller: agentController),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  void _showProjectContextMenu(
    BuildContext context,
    Offset position,
    String projectId,
    KanbanProvider kanbanProvider,
  ) {
    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx + 1,
        position.dy + 1,
      ),
      color: AppColors.surface1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: AppColors.border),
      ),
      items: [
        PopupMenuItem<String>(
          value: 'archive',
          height: 36,
          child: Row(
            children: [
              Icon(
                Icons.archive_outlined,
                size: 14,
                color: AppColors.textMuted,
              ),
              const SizedBox(width: 8),
              Text(
                'Archive project',
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
      if (value == 'archive') {
        kanbanProvider.archiveProject(projectId);
      }
    });
  }

  Widget _buildSegmentTab({
    required String text,
    required int index,
    required int currentIndex,
    required VoidCallback onTap,
    GestureTapUpCallback? onSecondaryTapUp,
    IconData? icon,
    Color? activeColor,
  }) {
    final isSelected = index == currentIndex;
    final color = activeColor ?? AppColors.textPrimary;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        onSecondaryTapUp: onSecondaryTapUp,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.surface2 : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 14,
                  color: isSelected ? color : AppColors.textMuted,
                ),
                const SizedBox(width: 6),
              ],
              Text(
                text,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected ? color : AppColors.textMuted,
                ),
              ),
            ],
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
            _AddProjectButton(
              onPressed: () =>
                  CreateProjectDialog.show(context, selectedRepo.path),
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

class _AddProjectButton extends StatefulWidget {
  final VoidCallback onPressed;

  const _AddProjectButton({required this.onPressed});

  @override
  State<_AddProjectButton> createState() => _AddProjectButtonState();
}

class _AddProjectButtonState extends State<_AddProjectButton> {
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
            color: _hovered ? AppColors.surface2 : AppColors.surface1,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _hovered ? AppColors.border : AppColors.borderSubtle,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add_rounded, size: 15, color: AppColors.textPrimary),
              SizedBox(width: 5),
              Text(
                'New Project',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
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
