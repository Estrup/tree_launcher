import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tree_launcher/core/design_system/app_theme.dart';
import 'package:tree_launcher/features/settings/domain/app_settings.dart';
import 'package:tree_launcher/features/workspace/data/launcher_service.dart';
import 'package:tree_launcher/features/workspace/domain/worktree.dart';
import 'package:tree_launcher/features/workspace/presentation/widgets/worktree_actions.dart';
import 'package:tree_launcher/models/worktree_slot.dart';
import 'package:tree_launcher/providers/copilot_provider.dart';
import 'package:tree_launcher/providers/repo_provider.dart';
import 'package:tree_launcher/providers/settings_provider.dart';

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
                      child: Tooltip(
                        message: wt.name,
                        waitDuration: const Duration(milliseconds: 300),
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
                  ],
                ),
                const SizedBox(height: 12),

                // Branch tag and Jira Tag
                Row(
                  spacing: 5,
                  children: [
                    MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        onTap: () =>
                            copyToClipboard(context, wt.branch, 'Branch'),
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
                    if (wt.jiraIssue != null) ...[
                      const SizedBox(height: 8),
                      JiraBadge(issueKey: wt.jiraIssue!),
                    ],
                  ],
                ),

                SizedBox(height: 10),

                // Commit + path
                Row(
                  children: [
                    MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        onTap: () => copyToClipboard(
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
                              copyToClipboard(context, wt.path, 'Path'),
                          child: Tooltip(
                            message: wt.path,
                            child: Text(
                              wt.path.replaceFirst(
                                RegExp(r'^/Users/[^/]+'),
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

                // Action buttons (compact, mirroring the table view)
                Row(
                  children: [
                    TerminalButton(
                      worktreePath: wt.path,
                      worktreeName: wt.name,
                      launcherService: _launcherService,
                      compact: true,
                    ),
                    const SizedBox(width: 6),
                    VscodeButton(
                      worktreePath: wt.path,
                      launcherService: _launcherService,
                      compact: true,
                    ),
                    const SizedBox(width: 6),
                    ActionButton(
                      compact: true,
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
                    const SizedBox(width: 6),
                    ClaudeButton(
                      wt: wt,
                      launcherService: _launcherService,
                      compact: true,
                    ),
                    if (customLinks.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      CustomLinksButton(
                        links: customLinks,
                        slot: wt.slot,
                        compact: true,
                      ),
                    ],
                    if (customCommands.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      CustomCommandsButton(
                        worktreePath: wt.path,
                        worktreeName: wt.name,
                        commands: customCommands,
                        slot: wt.slot,
                        compact: true,
                      ),
                    ],
                    const Spacer(),
                    PullButton(worktree: wt, compact: true),
                    const SizedBox(width: 6),
                    WorktreeOptionsButton(worktree: wt),
                  ],
                ),
              ],
            ),
          ],
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
    final availableSlots = greekSlots
        .where((s) => !usedSlots.contains(s))
        .toList();

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
          border: Border.all(color: AppColors.terminal.withValues(alpha: 0.3)),
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
