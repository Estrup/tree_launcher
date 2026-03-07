import 'package:uuid/uuid.dart';

class Project {
  final String id;
  final String repoPath;
  final String name;

  /// 1-3 uppercase letter key, e.g. "PRO". Used as prefix for issue IDs.
  final String key;
  final bool isArchived;
  final DateTime createdAt;

  const Project({
    required this.id,
    required this.repoPath,
    required this.name,
    required this.key,
    this.isArchived = false,
    required this.createdAt,
  });

  factory Project.create({
    required String repoPath,
    required String name,
    required String key,
  }) {
    return Project(
      id: const Uuid().v4(),
      repoPath: repoPath,
      name: name,
      key: key.toUpperCase(),
      createdAt: DateTime.now(),
    );
  }

  factory Project.fromMap(Map<String, dynamic> map) {
    return Project(
      id: map['id'] as String,
      repoPath: map['repo_path'] as String,
      name: map['name'] as String,
      key: map['key'] as String,
      isArchived: (map['is_archived'] as int) == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'repo_path': repoPath,
    'name': name,
    'key': key,
    'is_archived': isArchived ? 1 : 0,
    'created_at': createdAt.toIso8601String(),
  };

  Project copyWith({String? name, String? key, bool? isArchived}) {
    return Project(
      id: id,
      repoPath: repoPath,
      name: name ?? this.name,
      key: key ?? this.key,
      isArchived: isArchived ?? this.isArchived,
      createdAt: createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Project && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
