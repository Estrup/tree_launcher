import 'package:tree_launcher/features/builds/domain/azure_devops_config.dart';
import 'package:tree_launcher/features/github_prs/domain/github_config.dart';

import 'copilot_prompt.dart';
import 'copilot_session.dart';
import 'custom_command.dart';
import 'custom_link.dart';
import 'predefined_issue.dart';
import 'vscode_config.dart';

class RepoConfig {
  final String name;
  final String path;
  final List<VscodeConfig> vscodeConfigs;
  final List<CustomCommand> customCommands;
  final List<CustomLink> customLinks;
  final String? lastBaseBranch;
  final List<String> defaultRunCommands;
  final List<CopilotSession> copilotSessions;
  final List<CopilotPrompt> copilotPrompts;
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
  final AzureDevopsConfig? azureDevopsConfig;
  final String? lastAzureDevopsBranch;
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
    this.customLinks = const [],
    this.lastBaseBranch,
    this.defaultRunCommands = const [],
    this.copilotSessions = const [],
    this.copilotPrompts = const [],
    this.slotAssignments = const {},
    this.jiraIssues = const {},
    this.baseBranches = const {},
    this.prAuthors = const {},
    this.kickoffPrompts = const {},
    this.hiddenWorktrees = const [],
    this.snoozedWorktrees = const [],
    this.azureDevopsConfig,
    this.lastAzureDevopsBranch,
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
      customLinks:
          (json['customLinks'] as List<dynamic>?)
              ?.map((e) => CustomLink.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      lastBaseBranch: json['lastBaseBranch'] as String?,
      defaultRunCommands:
          (json['defaultRunCommands'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      copilotSessions:
          (json['copilotSessions'] as List<dynamic>?)
              ?.map((e) => CopilotSession.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      copilotPrompts:
          (json['copilotPrompts'] as List<dynamic>?)
              ?.map((e) => CopilotPrompt.fromJson(e as Map<String, dynamic>))
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
      azureDevopsConfig: json['azureDevopsConfig'] != null
          ? AzureDevopsConfig.fromJson(
              json['azureDevopsConfig'] as Map<String, dynamic>)
          : null,
      lastAzureDevopsBranch: json['lastAzureDevopsBranch'] as String?,
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
    'customLinks': customLinks.map((l) => l.toJson()).toList(),
    'lastBaseBranch': lastBaseBranch,
    'defaultRunCommands': defaultRunCommands,
    'copilotSessions': copilotSessions.map((s) => s.toJson()).toList(),
    'copilotPrompts': copilotPrompts.map((p) => p.toJson()).toList(),
    'slotAssignments': slotAssignments,
    'jiraIssues': jiraIssues,
    'baseBranches': baseBranches,
    'prAuthors': prAuthors,
    'kickoffPrompts': kickoffPrompts,
    'hiddenWorktrees': hiddenWorktrees,
    'snoozedWorktrees': snoozedWorktrees,
    if (azureDevopsConfig != null)
      'azureDevopsConfig': azureDevopsConfig!.toJson(),
    if (lastAzureDevopsBranch != null)
      'lastAzureDevopsBranch': lastAzureDevopsBranch,
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
    List<CustomLink>? customLinks,
    String? lastBaseBranch,
    List<String>? defaultRunCommands,
    List<CopilotSession>? copilotSessions,
    List<CopilotPrompt>? copilotPrompts,
    Map<String, String>? slotAssignments,
    Map<String, String>? jiraIssues,
    Map<String, String>? baseBranches,
    Map<String, String>? prAuthors,
    Map<String, String>? kickoffPrompts,
    List<String>? hiddenWorktrees,
    List<String>? snoozedWorktrees,
    AzureDevopsConfig? azureDevopsConfig,
    String? lastAzureDevopsBranch,
    GithubConfig? githubConfig,
    List<PredefinedIssue>? predefinedIssues,
    bool? useNestedWorktrees,
  }) {
    return RepoConfig(
      name: name ?? this.name,
      path: path ?? this.path,
      vscodeConfigs: vscodeConfigs ?? this.vscodeConfigs,
      customCommands: customCommands ?? this.customCommands,
      customLinks: customLinks ?? this.customLinks,
      lastBaseBranch: lastBaseBranch ?? this.lastBaseBranch,
      defaultRunCommands: defaultRunCommands ?? this.defaultRunCommands,
      copilotSessions: copilotSessions ?? this.copilotSessions,
      copilotPrompts: copilotPrompts ?? this.copilotPrompts,
      slotAssignments: slotAssignments ?? this.slotAssignments,
      jiraIssues: jiraIssues ?? this.jiraIssues,
      baseBranches: baseBranches ?? this.baseBranches,
      prAuthors: prAuthors ?? this.prAuthors,
      kickoffPrompts: kickoffPrompts ?? this.kickoffPrompts,
      hiddenWorktrees: hiddenWorktrees ?? this.hiddenWorktrees,
      snoozedWorktrees: snoozedWorktrees ?? this.snoozedWorktrees,
      azureDevopsConfig: azureDevopsConfig ?? this.azureDevopsConfig,
      lastAzureDevopsBranch:
          lastAzureDevopsBranch ?? this.lastAzureDevopsBranch,
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
