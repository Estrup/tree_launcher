import 'package:tree_launcher/features/builds/domain/azure_devops_config.dart';
import 'package:tree_launcher/features/github_prs/domain/github_config.dart';

import 'copilot_prompt.dart';
import 'copilot_session.dart';
import 'custom_command.dart';
import 'custom_link.dart';
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
  final AzureDevopsConfig? azureDevopsConfig;
  final String? lastAzureDevopsBranch;
  final GithubConfig? githubConfig;

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
    this.azureDevopsConfig,
    this.lastAzureDevopsBranch,
    this.githubConfig,
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
      azureDevopsConfig: json['azureDevopsConfig'] != null
          ? AzureDevopsConfig.fromJson(
              json['azureDevopsConfig'] as Map<String, dynamic>)
          : null,
      lastAzureDevopsBranch: json['lastAzureDevopsBranch'] as String?,
      githubConfig: json['githubConfig'] != null
          ? GithubConfig.fromJson(
              json['githubConfig'] as Map<String, dynamic>)
          : null,
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
    if (azureDevopsConfig != null)
      'azureDevopsConfig': azureDevopsConfig!.toJson(),
    if (lastAzureDevopsBranch != null)
      'lastAzureDevopsBranch': lastAzureDevopsBranch,
    if (githubConfig != null)
      'githubConfig': githubConfig!.toJson(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RepoConfig &&
          runtimeType == other.runtimeType &&
          path == other.path;

  @override
  int get hashCode => path.hashCode;
}
