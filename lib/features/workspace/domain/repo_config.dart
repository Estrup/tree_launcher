import 'package:tree_launcher/features/activity/domain/predefined_issue.dart';
import 'package:tree_launcher/features/agents/domain/claude_prompt.dart';
import 'package:tree_launcher/features/github_prs/domain/github_config.dart';
import 'package:tree_launcher/features/jira/domain/jira_trigger.dart';
import 'package:tree_launcher/features/workspace/domain/custom_command.dart';
import 'package:tree_launcher/features/workspace/domain/vscode_config.dart';

/// Config key for [RepoConfig.claudePrompts]. Kept as the legacy
/// `copilotPrompts` name so prompts saved before the rename still load, and so
/// older builds sharing the same config file keep seeing them.
const _claudePromptsKey = 'copilotPrompts';

class RepoConfig {
  final String name;
  final String path;
  final List<VscodeConfig> vscodeConfigs;
  final List<CustomCommand> customCommands;
  final String? lastBaseBranch;

  /// Saved prompt templates offered when launching Claude in a worktree.
  final List<ClaudePrompt> claudePrompts;

  final GithubConfig? githubConfig;

  /// Jira project key (e.g. `AU2`) whose issues the Jira tab lists. The tab is
  /// only shown when this is set.
  final String? jiraProjectKey;

  /// Id of the fixVersion last picked in the Jira tab, so it is remembered.
  final String? jiraFixVersionId;

  /// The default base branch per fixVersion id: a new worktree for an issue
  /// in that version is created from it.
  final Map<String, String> jiraVersionBranches;

  /// Rules that start a Claude session when an issue changes in Jira.
  final List<JiraTrigger> jiraTriggers;

  /// Number of the milestone last picked in the Issues tab, so it is
  /// remembered; null for all open issues.
  final int? githubMilestoneNumber;

  /// Reusable issue key + description presets, used as the picker source when
  /// logging a manual activity post.
  final List<PredefinedIssue> predefinedIssues;

  /// When true, new worktrees for this repo are created in a `.worktrees/`
  /// subfolder inside the repo (and that folder is added to git's exclude)
  /// instead of as siblings of the repo directory. Ignored for bare repos.
  final bool useNestedWorktrees;

  /// Working directory last used for an agent that runs outside an issue's
  /// worktree (any kind but build), offered first next time. The repo path
  /// itself can't serve when the repo is bare.
  final String? agentWorkingDirectory;

  RepoConfig({
    required this.name,
    required this.path,
    this.vscodeConfigs = const [],
    this.customCommands = const [],
    this.lastBaseBranch,
    this.claudePrompts = const [],
    this.githubConfig,
    this.jiraProjectKey,
    this.jiraFixVersionId,
    this.jiraVersionBranches = const {},
    this.jiraTriggers = const [],
    this.githubMilestoneNumber,
    this.predefinedIssues = const [],
    this.useNestedWorktrees = false,
    this.agentWorkingDirectory,
  });

  factory RepoConfig.fromJson(Map<String, dynamic> json) {
    return RepoConfig(
      name: json['name'] as String,
      path: json['path'] as String,
      vscodeConfigs:
          (json['vscodeConfigs'] as List<dynamic>?)
              ?.map((e) => VscodeConfig.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      customCommands:
          (json['customCommands'] as List<dynamic>?)
              ?.map((e) => CustomCommand.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      lastBaseBranch: json['lastBaseBranch'] as String?,
      claudePrompts:
          (json[_claudePromptsKey] as List<dynamic>?)
              ?.map((e) => ClaudePrompt.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      githubConfig: json['githubConfig'] != null
          ? GithubConfig.fromJson(
              json['githubConfig'] as Map<String, dynamic>)
          : null,
      jiraProjectKey: json['jiraProjectKey'] as String?,
      jiraFixVersionId: json['jiraFixVersionId'] as String?,
      jiraVersionBranches:
          (json['jiraVersionBranches'] as Map<String, dynamic>?)
              ?.cast<String, String>() ??
          const {},
      jiraTriggers:
          (json['jiraTriggers'] as List<dynamic>?)
              ?.map((e) => JiraTrigger.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      githubMilestoneNumber: json['githubMilestoneNumber'] as int?,
      predefinedIssues:
          (json['predefinedIssues'] as List<dynamic>?)
              ?.map((e) => PredefinedIssue.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      useNestedWorktrees: json['useNestedWorktrees'] as bool? ?? false,
      agentWorkingDirectory: json['agentWorkingDirectory'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'path': path,
    'vscodeConfigs': vscodeConfigs.map((c) => c.toJson()).toList(),
    'customCommands': customCommands.map((c) => c.toJson()).toList(),
    'lastBaseBranch': lastBaseBranch,
    _claudePromptsKey: claudePrompts.map((p) => p.toJson()).toList(),
    if (githubConfig != null)
      'githubConfig': githubConfig!.toJson(),
    if (jiraProjectKey != null) 'jiraProjectKey': jiraProjectKey,
    if (jiraFixVersionId != null) 'jiraFixVersionId': jiraFixVersionId,
    if (jiraVersionBranches.isNotEmpty)
      'jiraVersionBranches': jiraVersionBranches,
    if (jiraTriggers.isNotEmpty)
      'jiraTriggers': jiraTriggers.map((t) => t.toJson()).toList(),
    if (githubMilestoneNumber != null)
      'githubMilestoneNumber': githubMilestoneNumber,
    'predefinedIssues': predefinedIssues.map((i) => i.toJson()).toList(),
    'useNestedWorktrees': useNestedWorktrees,
    if (agentWorkingDirectory != null)
      'agentWorkingDirectory': agentWorkingDirectory,
  };

  RepoConfig copyWith({
    String? name,
    String? path,
    List<VscodeConfig>? vscodeConfigs,
    List<CustomCommand>? customCommands,
    String? lastBaseBranch,
    List<ClaudePrompt>? claudePrompts,
    GithubConfig? githubConfig,
    bool clearGithubConfig = false,
    String? jiraProjectKey,
    bool clearJiraProjectKey = false,
    String? jiraFixVersionId,
    bool clearJiraFixVersionId = false,
    Map<String, String>? jiraVersionBranches,
    List<JiraTrigger>? jiraTriggers,
    int? githubMilestoneNumber,
    bool clearGithubMilestoneNumber = false,
    List<PredefinedIssue>? predefinedIssues,
    bool? useNestedWorktrees,
    String? agentWorkingDirectory,
  }) {
    return RepoConfig(
      name: name ?? this.name,
      path: path ?? this.path,
      vscodeConfigs: vscodeConfigs ?? this.vscodeConfigs,
      customCommands: customCommands ?? this.customCommands,
      lastBaseBranch: lastBaseBranch ?? this.lastBaseBranch,
      claudePrompts: claudePrompts ?? this.claudePrompts,
      githubConfig: clearGithubConfig
          ? null
          : (githubConfig ?? this.githubConfig),
      jiraProjectKey: clearJiraProjectKey
          ? null
          : (jiraProjectKey ?? this.jiraProjectKey),
      jiraFixVersionId: clearJiraFixVersionId
          ? null
          : (jiraFixVersionId ?? this.jiraFixVersionId),
      jiraVersionBranches: jiraVersionBranches ?? this.jiraVersionBranches,
      jiraTriggers: jiraTriggers ?? this.jiraTriggers,
      githubMilestoneNumber: clearGithubMilestoneNumber
          ? null
          : (githubMilestoneNumber ?? this.githubMilestoneNumber),
      predefinedIssues: predefinedIssues ?? this.predefinedIssues,
      useNestedWorktrees: useNestedWorktrees ?? this.useNestedWorktrees,
      agentWorkingDirectory:
          agentWorkingDirectory ?? this.agentWorkingDirectory,
    );
  }

  /// The base branch mapped to the first of [fixVersionIds] that has one.
  String? baseBranchForFixVersions(Iterable<String> fixVersionIds) {
    for (final id in fixVersionIds) {
      final branch = jiraVersionBranches[id];
      if (branch != null) return branch;
    }
    return null;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RepoConfig &&
          runtimeType == other.runtimeType &&
          path == other.path;

  @override
  int get hashCode => path.hashCode;
}
