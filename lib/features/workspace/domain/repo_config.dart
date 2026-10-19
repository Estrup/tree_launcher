import 'package:tree_launcher/features/activity/domain/predefined_issue.dart';
import 'package:tree_launcher/features/agents/domain/claude_prompt.dart';
import 'package:tree_launcher/features/github_prs/domain/github_config.dart';
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

  /// JIRA issue keys per worktree path (worktree path -> issue key).
  final Map<String, String> jiraIssues;

  /// GitHub issue numbers per worktree path (worktree path -> number), for
  /// worktrees made from the Issues tab.
  final Map<String, int> githubIssues;

  /// Base branch per worktree path, recorded at creation (worktree path -> base branch).
  final Map<String, String> baseBranches;

  /// PR author login per worktree path, recorded at creation (worktree path -> author login).
  final Map<String, String> prAuthors;

  /// Absolute path to the API-supplied kickoff-prompt file per worktree path
  /// (worktree path -> file path). The prompt text itself lives in the file
  /// (potentially large), so only the reference is persisted here.
  final Map<String, String> kickoffPrompts;

  /// Worktree paths the user has hidden from the list.
  final List<String> hiddenWorktrees;

  /// Worktree paths the user has snoozed.
  final List<String> snoozedWorktrees;
  final GithubConfig? githubConfig;

  /// Jira project key (e.g. `AU2`) whose issues the Jira tab lists. The tab is
  /// only shown when this is set.
  final String? jiraProjectKey;

  /// Id of the fixVersion last picked in the Jira tab, so it is remembered.
  final String? jiraFixVersionId;

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

  /// Worktree paths with a remembered Claude CLI session, shown as shortcuts
  /// under the repo in the sidebar. Kept across restarts so a session can be
  /// resumed (`claude --continue`) after its terminal is gone.
  final List<String> claudeSessions;

  /// The prompt each remembered session was started with, by worktree path:
  /// a saved prompt's name, or one of the built-in prompt ids (see
  /// [issueContextPromptId]). Decides where the sidebar groups the session.
  final Map<String, String> claudeSessionPrompts;

  /// When each remembered session was first started, by worktree path (ISO
  /// 8601). Orders the sidebar's sessions, newest first.
  final Map<String, String> claudeSessionStarts;

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
    this.jiraIssues = const {},
    this.githubIssues = const {},
    this.baseBranches = const {},
    this.prAuthors = const {},
    this.kickoffPrompts = const {},
    this.hiddenWorktrees = const [],
    this.snoozedWorktrees = const [],
    this.githubConfig,
    this.jiraProjectKey,
    this.jiraFixVersionId,
    this.githubMilestoneNumber,
    this.predefinedIssues = const [],
    this.useNestedWorktrees = false,
    this.claudeSessions = const [],
    this.claudeSessionPrompts = const {},
    this.claudeSessionStarts = const {},
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
      jiraIssues:
          (json['jiraIssues'] as Map<String, dynamic>?)
              ?.map((k, v) => MapEntry(k, v as String)) ??
          {},
      githubIssues: {
        for (final MapEntry(:key, :value)
            in (json['githubIssues'] as Map<String, dynamic>? ?? {}).entries)
          if (value is int) key: value,
      },
      baseBranches:
          (json['baseBranches'] as Map<String, dynamic>?)
              ?.map((k, v) => MapEntry(k, v as String)) ??
          {},
      prAuthors:
          (json['prAuthors'] as Map<String, dynamic>?)
              ?.map((k, v) => MapEntry(k, v as String)) ??
          {},
      kickoffPrompts:
          (json['kickoffPrompts'] as Map<String, dynamic>?)
              ?.map((k, v) => MapEntry(k, v as String)) ??
          {},
      hiddenWorktrees:
          (json['hiddenWorktrees'] as List<dynamic>?)?.cast<String>() ?? const [],
      snoozedWorktrees:
          (json['snoozedWorktrees'] as List<dynamic>?)?.cast<String>() ??
          const [],
      githubConfig: json['githubConfig'] != null
          ? GithubConfig.fromJson(
              json['githubConfig'] as Map<String, dynamic>)
          : null,
      jiraProjectKey: json['jiraProjectKey'] as String?,
      jiraFixVersionId: json['jiraFixVersionId'] as String?,
      githubMilestoneNumber: json['githubMilestoneNumber'] as int?,
      predefinedIssues:
          (json['predefinedIssues'] as List<dynamic>?)
              ?.map((e) => PredefinedIssue.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      useNestedWorktrees: json['useNestedWorktrees'] as bool? ?? false,
      claudeSessions:
          (json['claudeSessions'] as List<dynamic>?)
              ?.whereType<String>()
              .toList() ??
          const [],
      claudeSessionPrompts:
          (json['claudeSessionPrompts'] as Map<String, dynamic>?)
              ?.map((k, v) => MapEntry(k, v as String)) ??
          {},
      claudeSessionStarts:
          (json['claudeSessionStarts'] as Map<String, dynamic>?)
              ?.map((k, v) => MapEntry(k, v as String)) ??
          {},
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
    'jiraIssues': jiraIssues,
    'githubIssues': githubIssues,
    'baseBranches': baseBranches,
    'prAuthors': prAuthors,
    'kickoffPrompts': kickoffPrompts,
    'hiddenWorktrees': hiddenWorktrees,
    'snoozedWorktrees': snoozedWorktrees,
    if (githubConfig != null)
      'githubConfig': githubConfig!.toJson(),
    if (jiraProjectKey != null) 'jiraProjectKey': jiraProjectKey,
    if (jiraFixVersionId != null) 'jiraFixVersionId': jiraFixVersionId,
    if (githubMilestoneNumber != null)
      'githubMilestoneNumber': githubMilestoneNumber,
    'predefinedIssues': predefinedIssues.map((i) => i.toJson()).toList(),
    'useNestedWorktrees': useNestedWorktrees,
    'claudeSessions': claudeSessions,
    'claudeSessionPrompts': claudeSessionPrompts,
    'claudeSessionStarts': claudeSessionStarts,
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
    Map<String, String>? jiraIssues,
    Map<String, int>? githubIssues,
    Map<String, String>? baseBranches,
    Map<String, String>? prAuthors,
    Map<String, String>? kickoffPrompts,
    List<String>? hiddenWorktrees,
    List<String>? snoozedWorktrees,
    GithubConfig? githubConfig,
    bool clearGithubConfig = false,
    String? jiraProjectKey,
    bool clearJiraProjectKey = false,
    String? jiraFixVersionId,
    bool clearJiraFixVersionId = false,
    int? githubMilestoneNumber,
    bool clearGithubMilestoneNumber = false,
    List<PredefinedIssue>? predefinedIssues,
    bool? useNestedWorktrees,
    List<String>? claudeSessions,
    Map<String, String>? claudeSessionPrompts,
    Map<String, String>? claudeSessionStarts,
    String? agentWorkingDirectory,
  }) {
    return RepoConfig(
      name: name ?? this.name,
      path: path ?? this.path,
      vscodeConfigs: vscodeConfigs ?? this.vscodeConfigs,
      customCommands: customCommands ?? this.customCommands,
      lastBaseBranch: lastBaseBranch ?? this.lastBaseBranch,
      claudePrompts: claudePrompts ?? this.claudePrompts,
      jiraIssues: jiraIssues ?? this.jiraIssues,
      githubIssues: githubIssues ?? this.githubIssues,
      baseBranches: baseBranches ?? this.baseBranches,
      prAuthors: prAuthors ?? this.prAuthors,
      kickoffPrompts: kickoffPrompts ?? this.kickoffPrompts,
      hiddenWorktrees: hiddenWorktrees ?? this.hiddenWorktrees,
      snoozedWorktrees: snoozedWorktrees ?? this.snoozedWorktrees,
      githubConfig: clearGithubConfig
          ? null
          : (githubConfig ?? this.githubConfig),
      jiraProjectKey: clearJiraProjectKey
          ? null
          : (jiraProjectKey ?? this.jiraProjectKey),
      jiraFixVersionId: clearJiraFixVersionId
          ? null
          : (jiraFixVersionId ?? this.jiraFixVersionId),
      githubMilestoneNumber: clearGithubMilestoneNumber
          ? null
          : (githubMilestoneNumber ?? this.githubMilestoneNumber),
      predefinedIssues: predefinedIssues ?? this.predefinedIssues,
      useNestedWorktrees: useNestedWorktrees ?? this.useNestedWorktrees,
      claudeSessions: claudeSessions ?? this.claudeSessions,
      claudeSessionPrompts: claudeSessionPrompts ?? this.claudeSessionPrompts,
      claudeSessionStarts: claudeSessionStarts ?? this.claudeSessionStarts,
      agentWorkingDirectory:
          agentWorkingDirectory ?? this.agentWorkingDirectory,
    );
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
