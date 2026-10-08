import 'package:tree_launcher/features/github_prs/domain/github_config.dart';

import 'claude_prompt.dart';
import 'custom_command.dart';
import 'predefined_issue.dart';
import 'vscode_config.dart';

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
  final Map<String, String> slotAssignments;

  /// JIRA issue keys per worktree path (worktree path -> issue key).
  final Map<String, String> jiraIssues;

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

  /// Reusable issue key + description presets, used as the picker source when
  /// logging a manual activity post.
  final List<PredefinedIssue> predefinedIssues;

  /// When true, new worktrees for this repo are created in a `.worktrees/`
  /// subfolder inside the repo (and that folder is added to git's exclude)
  /// instead of as siblings of the repo directory. Ignored for bare repos.
  final bool useNestedWorktrees;

  RepoConfig({
    required this.name,
    required this.path,
    this.vscodeConfigs = const [],
    this.customCommands = const [],
    this.lastBaseBranch,
    this.claudePrompts = const [],
    this.slotAssignments = const {},
    this.jiraIssues = const {},
    this.baseBranches = const {},
    this.prAuthors = const {},
    this.kickoffPrompts = const {},
    this.hiddenWorktrees = const [],
    this.snoozedWorktrees = const [],
    this.githubConfig,
    this.predefinedIssues = const [],
    this.useNestedWorktrees = false,
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
      slotAssignments:
          (json['slotAssignments'] as Map<String, dynamic>?)
              ?.map((k, v) => MapEntry(k, v as String)) ??
          {},
      jiraIssues:
          (json['jiraIssues'] as Map<String, dynamic>?)
              ?.map((k, v) => MapEntry(k, v as String)) ??
          {},
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
      predefinedIssues:
          (json['predefinedIssues'] as List<dynamic>?)
              ?.map((e) => PredefinedIssue.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      useNestedWorktrees: json['useNestedWorktrees'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'path': path,
    'vscodeConfigs': vscodeConfigs.map((c) => c.toJson()).toList(),
    'customCommands': customCommands.map((c) => c.toJson()).toList(),
    'lastBaseBranch': lastBaseBranch,
    _claudePromptsKey: claudePrompts.map((p) => p.toJson()).toList(),
    'slotAssignments': slotAssignments,
    'jiraIssues': jiraIssues,
    'baseBranches': baseBranches,
    'prAuthors': prAuthors,
    'kickoffPrompts': kickoffPrompts,
    'hiddenWorktrees': hiddenWorktrees,
    'snoozedWorktrees': snoozedWorktrees,
    if (githubConfig != null)
      'githubConfig': githubConfig!.toJson(),
    'predefinedIssues': predefinedIssues.map((i) => i.toJson()).toList(),
    'useNestedWorktrees': useNestedWorktrees,
  };

  RepoConfig copyWith({
    String? name,
    String? path,
    List<VscodeConfig>? vscodeConfigs,
    List<CustomCommand>? customCommands,
    String? lastBaseBranch,
    List<ClaudePrompt>? claudePrompts,
    Map<String, String>? slotAssignments,
    Map<String, String>? jiraIssues,
    Map<String, String>? baseBranches,
    Map<String, String>? prAuthors,
    Map<String, String>? kickoffPrompts,
    List<String>? hiddenWorktrees,
    List<String>? snoozedWorktrees,
    GithubConfig? githubConfig,
    List<PredefinedIssue>? predefinedIssues,
    bool? useNestedWorktrees,
  }) {
    return RepoConfig(
      name: name ?? this.name,
      path: path ?? this.path,
      vscodeConfigs: vscodeConfigs ?? this.vscodeConfigs,
      customCommands: customCommands ?? this.customCommands,
      lastBaseBranch: lastBaseBranch ?? this.lastBaseBranch,
      claudePrompts: claudePrompts ?? this.claudePrompts,
      slotAssignments: slotAssignments ?? this.slotAssignments,
      jiraIssues: jiraIssues ?? this.jiraIssues,
      baseBranches: baseBranches ?? this.baseBranches,
      prAuthors: prAuthors ?? this.prAuthors,
      kickoffPrompts: kickoffPrompts ?? this.kickoffPrompts,
      hiddenWorktrees: hiddenWorktrees ?? this.hiddenWorktrees,
      snoozedWorktrees: snoozedWorktrees ?? this.snoozedWorktrees,
      githubConfig: githubConfig ?? this.githubConfig,
      predefinedIssues: predefinedIssues ?? this.predefinedIssues,
      useNestedWorktrees: useNestedWorktrees ?? this.useNestedWorktrees,
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
