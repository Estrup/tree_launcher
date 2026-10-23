import 'package:flutter/material.dart';

import 'package:tree_launcher/features/agents/domain/agent_kind.dart';
import 'package:tree_launcher/features/agents/domain/agent_run.dart';
import 'package:tree_launcher/features/agents/domain/agent_type.dart';
import 'package:tree_launcher/features/agents/domain/claude_prompt.dart';
import 'package:tree_launcher/features/agents/presentation/controllers/agents_controller.dart';
import 'package:tree_launcher/features/agents/presentation/widgets/agent_kind_style.dart';
import 'package:tree_launcher/features/agents/presentation/widgets/agents_tab.dart';
import 'package:tree_launcher/features/workspace/domain/repo_config.dart';
import 'package:tree_launcher/features/workspace/domain/worktree_metadata.dart';

const worktreesPageKey = 'worktrees';
const prsPageKey = 'prs';
const githubIssuesPageKey = 'issues';
const jiraPageKey = 'jira';
const documentsPageKey = 'documents';
const activityPageKey = 'activity';

String agentPageKey(AgentKind kind) => 'agents:${kind.id}';

/// One of a repo's pages: a tab above the repo's content, and an entry under
/// the repo in the sidebar with the Claude sessions that belong to it.
class RepoPage {
  const RepoPage({
    required this.key,
    required this.label,
    required this.icon,
    this.agentKind,
    this.badge = 0,
  });

  /// Identifies the page across rebuilds, so the selection follows it when
  /// other pages appear or disappear.
  final String key;
  final String label;
  final IconData icon;

  /// The kind of agent the page lists, for an agent page.
  final AgentKind? agentKind;

  /// Count shown on the page (agents waiting for a human); 0 hides it.
  final int badge;
}

/// The pages [repo] has: PRs, Issues and Jira when configured, an agent page
/// per type of [agentTypes] it has switched on and has prompts or runs of,
/// Documents when it [hasDocuments], and worktrees and activity always.
List<RepoPage> repoPagesFor(
  RepoConfig? repo,
  AgentsController? agents, {
  required List<AgentType> agentTypes,
  bool hasDocuments = false,
}) => [
  const RepoPage(
    key: worktreesPageKey,
    label: 'Worktrees',
    icon: Icons.account_tree_outlined,
  ),
  if (repo?.githubConfig?.isConfigured ?? false)
    const RepoPage(
      key: prsPageKey,
      label: 'PRs',
      icon: Icons.merge_type_rounded,
    ),
  if (repo?.githubConfig?.showsIssues ?? false)
    const RepoPage(
      key: githubIssuesPageKey,
      label: 'Issues',
      icon: Icons.adjust_rounded,
    ),
  if (repo?.jiraProjectKey != null)
    const RepoPage(
      key: jiraPageKey,
      label: 'Jira',
      icon: Icons.confirmation_number_outlined,
    ),
  if (repo != null && agents != null)
    for (final type in agentTypes)
      if (repo.usesAgentType(type.kind) &&
          showsAgentTab(repo.name, repo.claudePrompts, agents, type.kind))
        RepoPage(
          key: agentPageKey(type.kind),
          label: type.label,
          icon: type.iconData,
          agentKind: type.kind,
          badge: agents.needsYouCount(repo.name, type.kind),
        ),
  if (hasDocuments)
    const RepoPage(
      key: documentsPageKey,
      label: 'Documents',
      icon: Icons.article_outlined,
    ),
  const RepoPage(
    key: activityPageKey,
    label: 'Activity',
    icon: Icons.history_rounded,
  ),
];

/// The page the Claude session remembered in [worktree] belongs under, the
/// first of these that is in [pageKeys]:
///
/// 1. the prompt it was started with: an agent prompt's kind, PRs for the PR
///    context, Issues for the GitHub issue context, Jira for the issue
///    context or kickoff prompt;
/// 2. the newest agent among [runs] in the worktree: its kind;
/// 3. PRs for a worktree made from a pull request, Jira for one with a Jira
///    issue, Issues for one with a GitHub issue;
/// 4. worktrees.
String sessionPageKey(
  RepoConfig repo,
  WorktreeMetadata worktree,
  Set<String> pageKeys, {
  Iterable<AgentRun> runs = const [],
}) {
  final worktreePath = worktree.path;
  String? shown(String? key) => pageKeys.contains(key) ? key : null;
  final newestRun = runs
      .where(
        (r) =>
            r.repoName == repo.name &&
            r.worktreePath == worktreePath &&
            !r.archived,
      )
      .fold<AgentRun?>(
        null,
        (newest, r) => newest == null || r.updatedAt.isAfter(newest.updatedAt)
            ? r
            : newest,
      );
  return shown(_promptPageKey(repo, worktree.session?.promptId)) ??
      shown(newestRun == null ? null : agentPageKey(newestRun.kind)) ??
      shown(worktree.prAuthor != null ? prsPageKey : null) ??
      shown(worktree.jiraIssue != null ? jiraPageKey : null) ??
      shown(worktree.githubIssue != null ? githubIssuesPageKey : null) ??
      worktreesPageKey;
}

/// The page [promptId] (see [RememberedSession.promptId]) points to, if any.
String? _promptPageKey(RepoConfig repo, String? promptId) {
  switch (promptId) {
    case null:
      return null;
    case prContextPromptId:
      return prsPageKey;
    case githubIssueContextPromptId:
      return githubIssuesPageKey;
    case issueContextPromptId || kickoffPromptId:
      return jiraPageKey;
  }
  final kind = repo.claudePrompts
      .where((p) => p.name == promptId)
      .firstOrNull
      ?.kind;
  return kind == null ? null : agentPageKey(kind);
}

/// A session under a page in the sidebar: an agent [run], or a remembered
/// shortcut to the session in [path]. [order] breaks ties in [startedAt].
typedef PageSession = ({
  DateTime startedAt,
  int order,
  String? path,
  AgentRun? run,
});

/// The sessions the sidebar lists under each of [repo]'s pages (by page key,
/// among [pageKeys]), newest first in a fixed order that status updates
/// don't move: [repo]'s agent [runs] that show (see [showsAgentSession];
/// [isOpen] says whether a run's terminal is open), and the [remembered]
/// session shortcuts, in the order remembered. The worktree of an agent
/// whose type [AgentType.ownsWorktree] (of [agentTypes]) is also a shortcut;
/// while that agent is listed it stands for it.
Map<String, List<PageSession>> sessionsByPage(
  RepoConfig repo, {
  required List<AgentType> agentTypes,
  required Set<String> pageKeys,
  required Iterable<AgentRun> runs,
  required bool Function(AgentRun run) isOpen,
  required Iterable<WorktreeMetadata> remembered,
}) {
  final sessions = <String, List<PageSession>>{};
  final worktreeOwnerKinds = {
    for (final type in agentTypes)
      if (type.ownsWorktree) type.kind,
  };
  final buildAgentPaths = <String>{};
  for (final run in runs) {
    if (run.repoName != repo.name) continue;
    if (!showsAgentSession(run, isOpen: isOpen(run))) continue;
    sessions
        .putIfAbsent(agentPageKey(run.kind), () => [])
        .add((startedAt: run.startedAt, order: 0, path: null, run: run));
    final path = run.worktreePath;
    if (worktreeOwnerKinds.contains(run.kind) && path != null) {
      buildAgentPaths.add(path);
    }
  }
  for (final (index, worktree) in remembered.indexed) {
    if (buildAgentPaths.contains(worktree.path)) continue;
    final pageKey = sessionPageKey(repo, worktree, pageKeys, runs: runs);
    sessions.putIfAbsent(pageKey, () => []).add((
      // Shortcuts from before start times were kept count as oldest, in the
      // order they were remembered.
      startedAt:
          worktree.session?.startedAt ?? DateTime.fromMillisecondsSinceEpoch(0),
      order: index,
      path: worktree.path,
      run: null,
    ));
  }
  for (final list in sessions.values) {
    list.sort((a, b) {
      final byStart = b.startedAt.compareTo(a.startedAt);
      return byStart != 0 ? byStart : b.order.compareTo(a.order);
    });
  }
  return sessions;
}

/// The sessions in [repo] that a row of a list stands for, newest first,
/// finished or not: [repo]'s unarchived agent [runs] that [runMatches] picks
/// or that work in a worktree [inWorktree] picks, and the session shortcuts
/// remembered in those worktrees (among [worktrees], [repo]'s metadata). As
/// in [sessionsByPage], an agent whose type [AgentType.ownsWorktree] (of
/// [agentTypes]) stands for its worktree's shortcut.
List<PageSession> sessionsWhere(
  RepoConfig repo, {
  required bool Function(WorktreeMetadata worktree) inWorktree,
  bool Function(AgentRun run)? runMatches,
  required List<AgentType> agentTypes,
  required Iterable<AgentRun> runs,
  required Iterable<WorktreeMetadata> worktrees,
}) {
  final paths = {
    for (final m in worktrees)
      if (inWorktree(m)) m.path,
  };
  final worktreeOwnerKinds = {
    for (final type in agentTypes)
      if (type.ownsWorktree) type.kind,
  };
  final sessions = <PageSession>[];
  final agentPaths = <String>{};
  for (final run in runs) {
    if (run.repoName != repo.name || run.archived) continue;
    final path = run.worktreePath;
    if (!paths.contains(path) && !(runMatches?.call(run) ?? false)) continue;
    sessions.add((startedAt: run.startedAt, order: 0, path: null, run: run));
    if (worktreeOwnerKinds.contains(run.kind) && path != null) {
      agentPaths.add(path);
    }
  }
  for (final (index, worktree) in worktrees.indexed) {
    final session = worktree.session;
    if (session == null || !paths.contains(worktree.path)) continue;
    if (agentPaths.contains(worktree.path)) continue;
    sessions.add((
      startedAt: session.startedAt ?? DateTime.fromMillisecondsSinceEpoch(0),
      order: index,
      path: worktree.path,
      run: null,
    ));
  }
  sessions.sort((a, b) {
    final byStart = b.startedAt.compareTo(a.startedAt);
    return byStart != 0 ? byStart : b.order.compareTo(a.order);
  });
  return sessions;
}

/// The sessions of Jira issue [issueKey] in [repo] (see [sessionsWhere]):
/// the agent runs that work on it, and the sessions in its worktrees.
List<PageSession> sessionsForIssue(
  RepoConfig repo,
  String issueKey, {
  required List<AgentType> agentTypes,
  required Iterable<AgentRun> runs,
  required Iterable<WorktreeMetadata> worktrees,
}) => sessionsWhere(
  repo,
  inWorktree: (m) => m.jiraIssue == issueKey,
  runMatches: (run) => run.issueKeys.contains(issueKey),
  agentTypes: agentTypes,
  runs: runs,
  worktrees: worktrees,
);

/// Whether [run] shows as a session under its agent page in the sidebar:
/// unarchived, and unfinished or with its terminal still open.
bool showsAgentSession(AgentRun run, {required bool isOpen}) =>
    !run.archived && (!run.state.isFinished || isOpen);
