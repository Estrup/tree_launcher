import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tree_launcher/core/design_system/app_theme.dart';
import 'package:tree_launcher/features/settings/domain/app_settings.dart';
import 'package:tree_launcher/features/workspace/data/launcher_service.dart';
import 'package:tree_launcher/features/workspace/domain/worktree.dart';
import 'package:tree_launcher/features/workspace/presentation/widgets/worktree_actions.dart';
import 'package:tree_launcher/providers/copilot_provider.dart';
import 'package:tree_launcher/providers/repo_provider.dart';
import 'package:tree_launcher/providers/settings_provider.dart';

/// Shared column layout so the header and every row line up.
const double _kJiraWidth = 120;
const double _kHashWidth = 80;
const double _kActionsWidth = 290;
const double _kColumnGap = 16;
const int _kNameFlex = 3;
const int _kBranchFlex = 3;
const int _kPathFlex = 4;

/// Compact list/table view of worktrees. An alternative to [WorktreeGrid]'s
/// tile layout, easier to scan when there are many worktrees.
class WorktreeTable extends StatelessWidget {
  final List<Worktree> worktrees;

  const WorktreeTable({super.key, required this.worktrees});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _HeaderRow(),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.only(bottom: 20),
            itemCount: worktrees.length,
            itemBuilder: (context, index) =>
                _WorktreeRow(worktree: worktrees[index]),
          ),
        ),
      ],
    );
  }
}

class _HeaderRow extends StatelessWidget {
  const _HeaderRow();

  Widget _label(String text) => Text(
    text.toUpperCase(),
    style: TextStyle(
      fontSize: 10,
      fontWeight: FontWeight.w700,
      color: AppColors.textMuted,
      letterSpacing: 0.6,
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 10, 24, 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.borderSubtle)),
      ),
      child: Row(
        children: [
          Expanded(flex: _kNameFlex, child: _label('Worktree')),
          const SizedBox(width: _kColumnGap),
          Expanded(flex: _kBranchFlex, child: _label('Branch')),
          const SizedBox(width: _kColumnGap),
          SizedBox(width: _kJiraWidth, child: _label('Jira')),
          const SizedBox(width: _kColumnGap),
          SizedBox(width: _kHashWidth, child: _label('Hash')),
          const SizedBox(width: _kColumnGap),
          Expanded(flex: _kPathFlex, child: _label('Path')),
          const SizedBox(width: _kColumnGap),
          SizedBox(
            width: _kActionsWidth,
            child: Align(
              alignment: Alignment.centerRight,
              child: _label('Actions'),
            ),
          ),
        ],
      ),
    );
  }
}

class _WorktreeRow extends StatefulWidget {
  final Worktree worktree;

  const _WorktreeRow({required this.worktree});

  @override
  State<_WorktreeRow> createState() => _WorktreeRowState();
}

class _WorktreeRowState extends State<_WorktreeRow> {
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
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        decoration: BoxDecoration(
          color: _hovered ? AppColors.surface2 : Colors.transparent,
          border: Border(bottom: BorderSide(color: AppColors.borderSubtle)),
        ),
        child: Row(
          children: [
            // Name (+ PRIMARY badge)
            Expanded(
              flex: _kNameFlex,
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      wt.name,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.2,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (wt.isMain) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.accentMuted,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'PRIMARY',
                        style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.w700,
                          color: AppColors.accent,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: _kColumnGap),

            // Branch (click to copy)
            Expanded(
              flex: _kBranchFlex,
              child: Align(
                alignment: Alignment.centerLeft,
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: () => copyToClipboard(context, wt.branch, 'Branch'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
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
                            size: 11,
                            color: AppColors.copilot,
                          ),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              wt.branch,
                              style: TextStyle(
                                fontSize: 11,
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
              ),
            ),
            const SizedBox(width: _kColumnGap),

            // Jira
            SizedBox(
              width: _kJiraWidth,
              child: Align(
                alignment: Alignment.centerLeft,
                child: wt.jiraIssue != null
                    ? JiraBadge(issueKey: wt.jiraIssue!, compact: true)
                    : Text(
                        '—',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: _kColumnGap),

            // Hash (click to copy)
            SizedBox(
              width: _kHashWidth,
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () =>
                      copyToClipboard(context, wt.commitHash, 'Commit hash'),
                  child: Text(
                    wt.commitHash,
                    style: TextStyle(
                      fontSize: 11,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w500,
                      color: AppColors.textMuted,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
            const SizedBox(width: _kColumnGap),

            // Path (click to copy)
            Expanded(
              flex: _kPathFlex,
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () => copyToClipboard(context, wt.path, 'Path'),
                  child: Tooltip(
                    message: wt.path,
                    child: Text(
                      wt.path.replaceFirst(RegExp(r'^/Users/[^/]+'), '~'),
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
            const SizedBox(width: _kColumnGap),

            // Actions
            SizedBox(
              width: _kActionsWidth,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
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
                        final repo = context.read<RepoProvider>().selectedRepo;
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
                  Tooltip(
                    message: 'Claude',
                    child: ActionButton(
                      compact: true,
                      svgAsset: 'assets/icons/claude.svg',
                      color: AppColors.claude,
                      bgColor: AppColors.claudeBg,
                      onPressed: () => _launcherService.openClaude(
                        wt.path,
                        prompt: claudeContextPrompt(wt),
                      ),
                    ),
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
                  const SizedBox(width: 6),
                  SizedBox(
                    width: 24,
                    child: wt.isMain
                        ? null
                        : DeleteIconButton(
                            onPressed: () => confirmDeleteWorktree(context, wt),
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
