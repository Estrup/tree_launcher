import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:tree_launcher/core/design_system/app_snackbar.dart';
import 'package:tree_launcher/core/design_system/app_theme.dart';
import 'package:tree_launcher/features/github_prs/presentation/controllers/github_prs_controller.dart';
import 'package:tree_launcher/features/terminal/data/claude_desktop_handoff.dart';
import 'package:tree_launcher/features/terminal/domain/terminal_session.dart';
import 'package:tree_launcher/features/workspace/data/launcher_service.dart';
import 'package:tree_launcher/features/workspace/presentation/widgets/worktree_actions.dart';
import 'package:tree_launcher/providers/repo_provider.dart';

/// The session's worktree at a glance, at the right of the terminal header:
/// its Jira issue and open PR, VS Code, and for a Claude session a button
/// that continues it in Claude Desktop.
class TerminalHeaderActions extends StatelessWidget {
  final TerminalSession session;
  final ClaudeDesktopHandoff? desktopHandoff;

  const TerminalHeaderActions({
    super.key,
    required this.session,
    this.desktopHandoff,
  });

  static final _launcherService = LauncherService();

  @override
  Widget build(BuildContext context) {
    final workspace = context.watch<RepoProvider>();
    final path = session.workingDirectory;
    final repo = workspace.repos
        .where((r) => r.path == session.repoPath)
        .firstOrNull;
    // The worktree list (and its branches) and the PR list only cover the
    // selected repo, and the terminal can show another repo's session.
    final worktree = workspace.selectedRepo?.path == session.repoPath
        ? workspace.worktrees.where((w) => w.path == path).firstOrNull
        : null;
    final jiraKey = worktree?.jiraIssue ?? repo?.jiraIssues[path];
    final pr = worktree == null
        ? null
        : context
              .watch<GithubPrsController>()
              .pullRequests
              .where((pr) => pr.headBranch == worktree.branch)
              .firstOrNull;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (jiraKey != null && jiraKey.isNotEmpty) ...[
          JiraBadge(issueKey: jiraKey, compact: true),
          const SizedBox(width: 6),
        ],
        if (pr != null) ...[
          PrBadge(number: pr.number, htmlUrl: pr.htmlUrl, compact: true),
          const SizedBox(width: 6),
        ],
        VscodeButton(
          worktreePath: path,
          launcherService: _launcherService,
          compact: true,
          configs: repo?.vscodeConfigs ?? const [],
        ),
        if (session.isClaude) ...[
          const SizedBox(width: 6),
          ClaudeDesktopButton(session: session, handoff: desktopHandoff),
        ],
      ],
    );
  }
}

/// Continues the session's Claude conversation in Claude Desktop.
class ClaudeDesktopButton extends StatefulWidget {
  final TerminalSession session;
  final ClaudeDesktopHandoff? handoff;

  const ClaudeDesktopButton({super.key, required this.session, this.handoff});

  @override
  State<ClaudeDesktopButton> createState() => _ClaudeDesktopButtonState();
}

class _ClaudeDesktopButtonState extends State<ClaudeDesktopButton> {
  late final ClaudeDesktopHandoff _handoff =
      widget.handoff ?? ClaudeDesktopHandoff();
  bool _hovered = false;
  bool _busy = false;

  Future<void> _continueInDesktop() async {
    if (_busy) return;
    setState(() => _busy = true);
    final session = widget.session;
    final error = await _handoff.continueInDesktop(
      shellPid: session.pid,
      workingDirectory: session.workingDirectory,
      type: session.write,
    );
    if (mounted) setState(() => _busy = false);
    if (error != null) showAppSnackBar(error);
  }

  @override
  Widget build(BuildContext context) {
    final color = AppColors.claude;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: _busy ? SystemMouseCursors.basic : SystemMouseCursors.click,
      child: GestureDetector(
        onTap: _continueInDesktop,
        child: Tooltip(
          message: 'Continue in Claude Desktop',
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            height: 28,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: _hovered && !_busy
                  ? color.withValues(alpha: 0.2)
                  : AppColors.claudeBg,
              borderRadius: BorderRadius.circular(7),
              border: Border.all(
                color: color.withValues(alpha: _hovered ? 0.4 : 0.15),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_busy)
                  SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      color: color,
                    ),
                  )
                else
                  SvgPicture.asset(
                    'assets/icons/claude.svg',
                    width: 13,
                    height: 13,
                    colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
                  ),
                const SizedBox(width: 6),
                Text(
                  'Desktop',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: color,
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
