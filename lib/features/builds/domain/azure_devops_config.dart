class BuildPipelineRef {
  final int id;
  final String name;

  BuildPipelineRef({
    required this.id,
    required this.name,
  });

  factory BuildPipelineRef.fromJson(Map<String, dynamic> json) {
    return BuildPipelineRef(
      id: json['id'] as int,
      name: json['name'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
  };

  BuildPipelineRef copyWith({
    int? id,
    String? name,
  }) {
    return BuildPipelineRef(
      id: id ?? this.id,
      name: name ?? this.name,
    );
  }
}

class AzureDevopsConfig {
  final String serverUrl;
  final String project;
  final String pat;
  final List<BuildPipelineRef> selectedPipelines;

  AzureDevopsConfig({
    required this.serverUrl,
    required this.project,
    required this.pat,
    this.selectedPipelines = const [],
  });

  factory AzureDevopsConfig.fromJson(Map<String, dynamic> json) {
    return AzureDevopsConfig(
      serverUrl: json['serverUrl'] as String,
      project: json['project'] as String,
      pat: json['pat'] as String,
      selectedPipelines:
          (json['selectedPipelines'] as List<dynamic>?)
              ?.map((e) => BuildPipelineRef.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() => {
    'serverUrl': serverUrl,
    'project': project,
    'pat': pat,
    'selectedPipelines':
        selectedPipelines.map((p) => p.toJson()).toList(),
  };

  AzureDevopsConfig copyWith({
    String? serverUrl,
    String? project,
    String? pat,
    List<BuildPipelineRef>? selectedPipelines,
  }) {
    return AzureDevopsConfig(
      serverUrl: serverUrl ?? this.serverUrl,
      project: project ?? this.project,
      pat: pat ?? this.pat,
      selectedPipelines: selectedPipelines ?? this.selectedPipelines,
    );
  }

  bool get isConfigured =>
      serverUrl.isNotEmpty && project.isNotEmpty && pat.isNotEmpty;
}
