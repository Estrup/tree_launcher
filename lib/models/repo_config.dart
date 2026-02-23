import 'vscode_config.dart';

class RepoConfig {
  final String name;
  final String path;
  final List<VscodeConfig> vscodeConfigs;

  RepoConfig({
    required this.name,
    required this.path,
    this.vscodeConfigs = const [],
  });

  factory RepoConfig.fromJson(Map<String, dynamic> json) {
    return RepoConfig(
      name: json['name'] as String,
      path: json['path'] as String,
      vscodeConfigs: (json['vscodeConfigs'] as List<dynamic>?)
              ?.map((e) => VscodeConfig.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'path': path,
        'vscodeConfigs': vscodeConfigs.map((c) => c.toJson()).toList(),
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
