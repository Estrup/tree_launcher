import 'package:flutter/material.dart';

import 'package:tree_launcher/features/agents/domain/agent_kind.dart';
import 'package:tree_launcher/features/agents/domain/agent_run.dart';
import 'package:tree_launcher/features/agents/presentation/controllers/agents_controller.dart';
import 'package:tree_launcher/features/agents/presentation/widgets/agent_kind_style.dart';
import 'package:tree_launcher/features/agents/presentation/widgets/agents_tab.dart';
import 'package:tree_launcher/features/workspace/domain/claude_prompt.dart';
import 'package:tree_launcher/features/workspace/domain/repo_config.dart';

const worktreesPageKey = 'worktrees';
const prsPageKey = 'prs';
const jiraPageKey = 'jira';
const activityPageKey = 'activity';

String agentPageKey(AgentKind kind) => 'agents:${kind.name}';

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

/// The pages [repo] has: PRs and Jira when configured, an agent page per
/// kind it has prompts or runs of, and worktrees and activity always.
List<RepoPage> repoPagesFor(RepoConfig? repo, AgentsController? agents) => [
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
  if (repo?.jiraProjectKey != null)
    const RepoPage(
      key: jiraPageKey,
      label: 'Jira',
      icon: Icons.confirmation_number_outlined,
    ),
  if (repo != null && agents != null)
    for (final kind in AgentKind.values)
      if (showsAgentTab(repo.name, repo.claudePrompts, agents, kind))
        RepoPage(
          key: agentPageKey(kind),
          label: kind.label,
          icon: kind.icon,
          agentKind: kind,
          badge: agents.needsYouCount(repo.name, kind),
        ),
  const RepoPage(
    key: activityPageKey,
    label: 'Activity',
    icon: Icons.history_rounded,
  ),
];

/// The page a remembered Claude session in [worktreePath] belongs under,
/// the first of these that is in [pageKeys]:
///
/// 1. the prompt it was started with: an agent prompt's kind, PRs for the PR
///    context, Jira for the issue context or kickoff prompt;
/// 2. the newest agent among [runs] in the worktree: its kind;
/// 3. PRs for a worktree made from a pull request, Jira for one with an
///    issue;
/// 4. worktrees.
String sessionPageKey(
  RepoConfig repo,
  String worktreePath,
  Set<String> pageKeys, {
  Iterable<AgentRun> runs = const [],
}) {
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
  return shown(_promptPageKey(repo, repo.claudeSessionPrompts[worktreePath])) ??
      shown(newestRun == null ? null : agentPageKey(newestRun.kind)) ??
      shown(repo.prAuthors.containsKey(worktreePath) ? prsPageKey : null) ??
      shown(repo.jiraIssues.containsKey(worktreePath) ? jiraPageKey : null) ??
      worktreesPageKey;
}

/// The page [promptId] (see [RepoConfig.claudeSessionPrompts]) points to,
/// if any.
String? _promptPageKey(RepoConfig repo, String? promptId) {
  switch (promptId) {
    case null:
      return null;
    case prContextPromptId:
      return prsPageKey;
    case issueContextPromptId || kickoffPromptId:
      return jiraPageKey;
  }
  final kind = repo.claudePrompts
      .where((p) => p.name == promptId)
      .firstOrNull
      ?.kind;
  return kind == null ? null : agentPageKey(kind);
}

/// Whether [run] shows as a session under its agent page in the sidebar:
/// unarchived, and unfinished or with its terminal still open.
bool showsAgentSession(AgentRun run, {required bool isOpen}) =>
    !run.archived && (!run.state.isFinished || isOpen);
