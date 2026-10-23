import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:tree_launcher/core/design_system/app_snackbar.dart';
import 'package:tree_launcher/core/design_system/app_theme.dart';
import 'package:tree_launcher/core/platform/open_external.dart';
import 'package:tree_launcher/features/agents/presentation/controllers/agents_controller.dart';
import 'package:tree_launcher/features/agents/presentation/widgets/agent_kind_style.dart';
import 'package:tree_launcher/features/documents/presentation/controllers/documents_controller.dart';
import 'package:tree_launcher/features/documents/presentation/widgets/document_panel.dart';
import 'package:tree_launcher/features/github_issues/presentation/widgets/github_issue_badge.dart';
import 'package:tree_launcher/features/github_prs/domain/pull_request.dart';
import 'package:tree_launcher/features/github_prs/presentation/controllers/github_prs_controller.dart';
import 'package:tree_launcher/features/jira/data/jira_issue_cache.dart';
import 'package:tree_launcher/features/jira/presentation/controllers/jira_titles_controller.dart';
import 'package:tree_launcher/features/session_panel/presentation/controllers/session_panel_controller.dart';
import 'package:tree_launcher/features/terminal/data/terminal_session.dart';
import 'package:tree_launcher/features/workspace/domain/worktree_status.dart';
import 'package:tree_launcher/features/workspace/presentation/controllers/workspace_controller.dart';
import 'package:tree_launcher/features/workspace/presentation/widgets/worktree_buttons/jira_badge.dart';
import 'package:tree_launcher/features/workspace/presentation/widgets/worktree_buttons/pr_badge.dart';

/// What is known about a Claude session's worktree: its branch and how it
/// stands against its base and upstream, its issue, PR, agent run and
/// documents. The git status is read when shown, every
/// [SessionInfoTab.refreshInterval] while shown, and when the app comes
/// back to the front.
class SessionInfoTab extends StatefulWidget {
  const SessionInfoTab({super.key, required this.session});

  final TerminalSession session;

  static const refreshInterval = Duration(seconds: 30);

  @override
  State<SessionInfoTab> createState() => _SessionInfoTabState();
}

class _SessionInfoTabState extends State<SessionInfoTab> {
  Timer? _timer;
  AppLifecycleListener? _lifecycle;

  /// Jira statuses read from the issue cache, by key.
  final Map<String, String?> _jiraStatus = {};

  String get _worktree => widget.session.workingDirectory;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(SessionInfoTab.refreshInterval, (_) => _refresh());
    _lifecycle = AppLifecycleListener(onResume: _refresh);
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  @override
  void didUpdateWidget(SessionInfoTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    // After the frame: the refresh notifies, which can't happen mid-build.
    if (oldWidget.session.workingDirectory != _worktree) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _lifecycle?.dispose();
    super.dispose();
  }

  void _refresh() {
    if (!mounted) return;
    final workspace = context.read<WorkspaceController>();
    unawaited(
      context.read<SessionPanelController>().refreshStatus(
        _worktree,
        baseBranch: _baseBranch(workspace),
      ),
    );
  }

  String? _baseBranch(WorkspaceController workspace) =>
      workspace.worktrees
          .where((w) => w.path == _worktree)
          .firstOrNull
          ?.baseBranch ??
      workspace.metadataFor(_worktree)?.baseBranch;

  /// Reads [key]'s status from the issue cache once.
  void _loadJiraStatus(String key) {
    if (_jiraStatus.containsKey(key)) return;
    _jiraStatus[key] = null;
    final cache = context.read<JiraIssueCache?>();
    if (cache == null) return;
    unawaited(
      cache.read(key).then((cached) {
        final status = cached?.issue.status;
        if (mounted && status != null) {
          setState(() => _jiraStatus[key] = status);
        }
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final panel = context.watch<SessionPanelController>();
    final workspace = context.watch<WorkspaceController>();
    final session = widget.session;
    final metadata = workspace.metadataFor(_worktree);
    final repo = workspace.repos
        .where((r) => r.path == session.repoPath)
        .firstOrNull;
    final status = panel.statusFor(_worktree);
    final error = panel.statusErrorFor(_worktree);
    final baseBranch = _baseBranch(workspace);
    final branch =
        status?.branch ??
        workspace.worktrees
            .where((w) => w.path == _worktree)
            .firstOrNull
            ?.branch;

    final jiraKey = metadata?.jiraIssue;
    if (jiraKey != null && jiraKey.isNotEmpty) {
      context.read<JiraTitlesController?>()?.ensureTitles([jiraKey]);
      _loadJiraStatus(jiraKey);
    }
    final jiraTitle = jiraKey == null
        ? null
        : context.watch<JiraTitlesController?>()?.titleFor(jiraKey);
    final githubIssue = metadata?.githubIssue;
    final githubConfig = repo?.githubConfig;

    // The PR list only covers the selected repo.
    final prsCoverRepo = workspace.selectedRepo?.path == session.repoPath;
    final pr = !prsCoverRepo || branch == null
        ? null
        : context
              .watch<GithubPrsController?>()
              ?.pullRequests
              .where((pr) => pr.headBranch == branch)
              .firstOrNull;

    final agents = context.watch<AgentsController?>();
    final agentId = session.agentId;
    final run = agentId == null ? null : agents?.runById(agentId);
    final type = run == null ? null : agentTypeOf(context, run.kind);

    final documents = context.watch<DocumentsController?>();
    final docs =
        documents?.documentsForWorktree(_worktree, issueKey: jiraKey) ??
        const [];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        _Section(
          title: 'Branch',
          trailing: _RefreshButton(
            busy: panel.isLoadingStatus(_worktree),
            onPressed: _refresh,
          ),
          children: [
            if (error != null)
              _Row(
                label: 'Git',
                child: _Muted(error, color: AppColors.error),
              ),
            _Row(
              label: 'Branch',
              child: branch == null
                  ? _Muted(status == null ? '…' : 'Detached HEAD')
                  : _CopyableText(branch, mono: true),
            ),
            if (status?.commit != null)
              _Row(
                label: 'HEAD',
                child: _CommitText(status: status!),
              ),
            _Row(
              label: 'Base',
              child: baseBranch == null
                  ? const _Muted('Not known')
                  : _BaseText(baseBranch: baseBranch, status: status),
            ),
            if (status != null) ...[
              _Row(
                label: 'Upstream',
                child: _UpstreamText(status: status),
              ),
              _Row(
                label: 'Changes',
                child: _ChangesText(status: status),
              ),
            ],
          ],
        ),
        _Section(
          title: 'Issue',
          children: [
            if ((jiraKey == null || jiraKey.isEmpty) && githubIssue == null)
              const _Muted('No issue linked'),
            if (jiraKey != null && jiraKey.isNotEmpty)
              _Row(
                label: 'Jira',
                child: _BadgeWithText(
                  badge: JiraBadge(issueKey: jiraKey, compact: true),
                  text: jiraTitle,
                  detail: _jiraStatus[jiraKey],
                ),
              ),
            if (githubIssue != null)
              _Row(
                label: 'GitHub',
                child: githubConfig != null && githubConfig.isConfigured
                    ? Align(
                        alignment: Alignment.centerLeft,
                        child: GithubIssueBadge(
                          config: githubConfig,
                          number: githubIssue,
                        ),
                      )
                    : _Muted('#$githubIssue'),
              ),
          ],
        ),
        _Section(
          title: 'Pull request',
          children: [
            if (pr != null)
              ..._prRows(pr)
            else
              _Muted(
                prsCoverRepo
                    ? 'No open pull request for this branch'
                    : 'Shown when this repo is selected',
              ),
          ],
        ),
        if (run != null)
          _Section(
            title: 'Agent',
            children: [
              _Row(
                label: 'Kind',
                child: Row(
                  children: [
                    Icon(type!.iconData, size: 13, color: type.colorValue),
                    const SizedBox(width: 6),
                    Flexible(
                      child: _Value(
                        run.title == null
                            ? type.label
                            : '${type.label} · ${run.title}',
                      ),
                    ),
                  ],
                ),
              ),
              _Row(
                label: 'State',
                child: Builder(
                  builder: (context) {
                    final style = agentStatusStyle(
                      run,
                      agents!.livenessOf(run.id),
                    );
                    return Row(
                      children: [
                        Icon(style.icon, size: 13, color: style.color),
                        const SizedBox(width: 6),
                        Flexible(
                          child: _Value(style.label, color: style.color),
                        ),
                      ],
                    );
                  },
                ),
              ),
              if (run.currentStage != null)
                _Row(label: 'Stage', child: _Value(run.currentStage!)),
              if (run.summary != null && run.summary!.isNotEmpty)
                _Row(label: 'Latest', child: _Value(run.summary!)),
            ],
          ),
        if (docs.isNotEmpty)
          _Section(
            title: 'Documents',
            children: [
              for (final doc in docs)
                _LinkRow(
                  icon: documentIcon(doc.format),
                  text: doc.title,
                  trailing: DocumentFormatTag(format: doc.format),
                  onTap: () => documents!.open(doc.id),
                ),
            ],
          ),
        _Section(
          title: 'Worktree',
          children: [
            _CopyableText(_worktree, mono: true),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              children: [
                _SmallButton(
                  icon: Icons.folder_open_outlined,
                  label: 'Reveal in Finder',
                  onPressed: () => revealInFinder(_worktree),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  List<Widget> _prRows(GithubPullRequest pr) => [
    _Row(
      label: 'PR',
      child: _BadgeWithText(
        badge: PrBadge(number: pr.number, htmlUrl: pr.htmlUrl, compact: true),
        text: pr.title,
        detail: pr.draft ? 'Draft' : null,
      ),
    ),
    _Row(label: 'Into', child: _Value(pr.baseBranch, mono: true)),
    _Row(label: 'Author', child: _Value(pr.author)),
    if (pr.requestedReviewers.isNotEmpty)
      _Row(label: 'Reviewers', child: _Value(pr.requestedReviewers.join(', '))),
    if (pr.labels.isNotEmpty)
      _Row(
        label: 'Labels',
        child: _Value(pr.labels.map((l) => l.name).join(', ')),
      ),
  ];
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children, this.trailing});

  final String title;
  final List<Widget> children;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 24,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
                ?trailing,
              ],
            ),
          ),
          const SizedBox(height: 4),
          ...children,
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                label,
                style: TextStyle(fontSize: 11, color: AppColors.textMuted),
              ),
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _Value extends StatelessWidget {
  const _Value(this.text, {this.mono = false, this.color});

  final String text;
  final bool mono;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return SelectableText(
      text,
      style: TextStyle(
        fontSize: 12,
        height: 1.4,
        fontFamily: mono ? 'SF Mono' : null,
        color: color ?? AppColors.textPrimary,
      ),
    );
  }
}

class _Muted extends StatelessWidget {
  const _Muted(this.text, {this.color});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 12,
        height: 1.4,
        color: color ?? AppColors.textMuted,
      ),
    );
  }
}

/// [text] with a button that copies it.
class _CopyableText extends StatelessWidget {
  const _CopyableText(this.text, {this.mono = false});

  final String text;
  final bool mono;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _Value(text, mono: mono)),
        const SizedBox(width: 4),
        SizedBox(
          width: 20,
          height: 20,
          child: IconButton(
            tooltip: 'Copy',
            padding: EdgeInsets.zero,
            iconSize: 12,
            onPressed: () {
              Clipboard.setData(ClipboardData(text: text));
              showAppSnackBar('Copied');
            },
            icon: Icon(Icons.copy_rounded, color: AppColors.textMuted),
          ),
        ),
      ],
    );
  }
}

class _CommitText extends StatelessWidget {
  const _CommitText({required this.status});

  final WorktreeStatus status;

  @override
  Widget build(BuildContext context) {
    return SelectableText.rich(
      TextSpan(
        children: [
          TextSpan(
            text: status.shortCommit,
            style: TextStyle(fontFamily: 'SF Mono', color: AppColors.branch),
          ),
          if (status.subject != null && status.subject!.isNotEmpty)
            TextSpan(text: '  ${status.subject}'),
        ],
      ),
      style: TextStyle(fontSize: 12, height: 1.4, color: AppColors.textPrimary),
    );
  }
}

class _BaseText extends StatelessWidget {
  const _BaseText({required this.baseBranch, required this.status});

  final String baseBranch;
  final WorktreeStatus? status;

  @override
  Widget build(BuildContext context) {
    final status = this.status;
    final ahead = status?.aheadOfBase;
    final behind = status?.behindBase;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Value(baseBranch, mono: true),
        if (ahead != null && behind != null)
          _Muted(
            '${_commits(ahead)} ahead · ${_commits(behind)} behind '
            '${status!.base}',
          )
        else if (status != null)
          const _Muted('Not found in this checkout'),
      ],
    );
  }
}

class _UpstreamText extends StatelessWidget {
  const _UpstreamText({required this.status});

  final WorktreeStatus status;

  @override
  Widget build(BuildContext context) {
    final upstream = status.upstream;
    if (upstream == null) return const _Muted('Not pushed');
    final ahead = status.aheadOfUpstream;
    final behind = status.behindUpstream;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Value(upstream, mono: true),
        _Muted(
          ahead == 0 && behind == 0
              ? 'Up to date'
              : [
                  if (ahead > 0) '${_commits(ahead)} to push',
                  if (behind > 0) '${_commits(behind)} to pull',
                ].join(' · '),
        ),
      ],
    );
  }
}

class _ChangesText extends StatelessWidget {
  const _ChangesText({required this.status});

  final WorktreeStatus status;

  @override
  Widget build(BuildContext context) {
    if (status.changedFiles == 0) {
      return _Value('Clean', color: AppColors.success);
    }
    return _Value(
      [
        if (status.conflicted > 0) '${status.conflicted} conflicted',
        if (status.staged > 0) '${status.staged} staged',
        if (status.modified > 0) '${status.modified} modified',
        if (status.untracked > 0) '${status.untracked} untracked',
      ].join(' · '),
      color: status.conflicted > 0 ? AppColors.error : null,
    );
  }
}

/// A badge, then a title and a muted detail (such as a status) under it.
class _BadgeWithText extends StatelessWidget {
  const _BadgeWithText({required this.badge, this.text, this.detail});

  final Widget badge;
  final String? text;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(alignment: Alignment.centerLeft, child: badge),
        if (text != null && text!.isNotEmpty) ...[
          const SizedBox(height: 4),
          _Value(text!),
        ],
        if (detail != null) _Muted(detail!),
      ],
    );
  }
}

class _LinkRow extends StatefulWidget {
  const _LinkRow({
    required this.icon,
    required this.text,
    required this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String text;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  State<_LinkRow> createState() => _LinkRowState();
}

class _LinkRowState extends State<_LinkRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
          decoration: BoxDecoration(
            color: _hovered ? AppColors.surfaceHover : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              Icon(widget.icon, size: 14, color: AppColors.textSecondary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.text,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: AppColors.textPrimary),
                ),
              ),
              if (widget.trailing != null) ...[
                const SizedBox(width: 6),
                widget.trailing!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SmallButton extends StatelessWidget {
  const _SmallButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: AppColors.textSecondary,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        minimumSize: const Size(0, 28),
        textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
      ),
      icon: Icon(icon, size: 13),
      label: Text(label),
    );
  }
}

class _RefreshButton extends StatelessWidget {
  const _RefreshButton({required this.busy, required this.onPressed});

  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 22,
      height: 22,
      child: busy
          ? Padding(
              padding: const EdgeInsets.all(5),
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                color: AppColors.textMuted,
              ),
            )
          : IconButton(
              tooltip: 'Refresh',
              padding: EdgeInsets.zero,
              iconSize: 14,
              onPressed: onPressed,
              icon: Icon(Icons.refresh_rounded, color: AppColors.textMuted),
            ),
    );
  }
}

String _commits(int n) => n == 1 ? '1 commit' : '$n commits';
