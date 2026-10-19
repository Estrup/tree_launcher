class VscodeConfig {
  final String name;
  final String path;

  VscodeConfig({required this.name, required this.path});

  factory VscodeConfig.fromJson(Map<String, dynamic> json) {
    return VscodeConfig(
      name: json['name'] as String,
      path: json['path'] as String,
    );
  }

  Map<String, dynamic> toJson() => {'name': name, 'path': path};
}
