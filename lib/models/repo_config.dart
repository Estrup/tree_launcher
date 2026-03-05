import 'copilot_prompt.dart';
import 'copilot_session.dart';
import 'custom_command.dart';
import 'vscode_config.dart';

class RepoConfig {
  final String name;
  final String path;
  final List<VscodeConfig> vscodeConfigs;
  final List<CustomCommand> customCommands;
  final String? lastBaseBranch;
  final List<String> defaultRunCommands;
  final List<CopilotSession> copilotSessions;
  final List<CopilotPrompt> copilotPrompts;

  RepoConfig({
    required this.name,
    required this.path,
    this.vscodeConfigs = const [],
    this.customCommands = const [],
    this.lastBaseBranch,
    this.defaultRunCommands = const [],
    this.copilotSessions = const [],
    this.copilotPrompts = const [],
  });

  factory RepoConfig.fromJson(Map<String, dynamic> json) {
    return RepoConfig(
      name: json['name'] as String,
      path: json['path'] as String,
      vscodeConfigs: (json['vscodeConfigs'] as List<dynamic>?)
              ?.map((e) => VscodeConfig.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      customCommands: (json['customCommands'] as List<dynamic>?)
              ?.map((e) => CustomCommand.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      lastBaseBranch: json['lastBaseBranch'] as String?,
      defaultRunCommands: (json['defaultRunCommands'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      copilotSessions: (json['copilotSessions'] as List<dynamic>?)
              ?.map((e) => CopilotSession.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      copilotPrompts: (json['copilotPrompts'] as List<dynamic>?)
              ?.map((e) => CopilotPrompt.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'path': path,
        'vscodeConfigs': vscodeConfigs.map((c) => c.toJson()).toList(),
        'customCommands': customCommands.map((c) => c.toJson()).toList(),
        'lastBaseBranch': lastBaseBranch,
        'defaultRunCommands': defaultRunCommands,
        'copilotSessions': copilotSessions.map((s) => s.toJson()).toList(),
        'copilotPrompts': copilotPrompts.map((p) => p.toJson()).toList(),
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
