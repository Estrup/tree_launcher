class BuildDefinition {
  final int id;
  final String name;
  final String? path;
  final String? url;

  BuildDefinition({
    required this.id,
    required this.name,
    this.path,
    this.url,
  });

  factory BuildDefinition.fromApiJson(Map<String, dynamic> json) {
    return BuildDefinition(
      id: json['id'] as int,
      name: json['name'] as String,
      path: json['path'] as String?,
      url: json['url'] as String?,
    );
  }
}
