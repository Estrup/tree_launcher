import 'dart:convert';
import 'package:uuid/uuid.dart';
import '../widgets/kanban_board.dart';

class Issue {
  final String id;
  final String projectId;
  final String title;
  final String? description;
  final KanbanColumnStatus status;
  final List<String> tags;
  final String? branch;
  final String? worktreePath;
  final bool isArchived;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Issue({
    required this.id,
    required this.projectId,
    required this.title,
    this.description,
    this.status = KanbanColumnStatus.todo,
    this.tags = const [],
    this.branch,
    this.worktreePath,
    this.isArchived = false,
    this.sortOrder = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Issue.create({
    required String projectId,
    required String title,
    String? description,
  }) {
    final now = DateTime.now();
    return Issue(
      id: const Uuid().v4(),
      projectId: projectId,
      title: title,
      description: description,
      createdAt: now,
      updatedAt: now,
    );
  }

  factory Issue.fromMap(Map<String, dynamic> map) {
    return Issue(
      id: map['id'] as String,
      projectId: map['project_id'] as String,
      title: map['title'] as String,
      description: map['description'] as String?,
      status: _statusFromString(map['status'] as String),
      tags: map['tags'] != null
          ? List<String>.from(jsonDecode(map['tags'] as String) as List)
          : [],
      branch: map['branch'] as String?,
      worktreePath: map['worktree_path'] as String?,
      isArchived: (map['is_archived'] as int) == 1,
      sortOrder: map['sort_order'] as int,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'project_id': projectId,
    'title': title,
    'description': description,
    'status': status.name,
    'tags': tags.isNotEmpty ? jsonEncode(tags) : null,
    'branch': branch,
    'worktree_path': worktreePath,
    'is_archived': isArchived ? 1 : 0,
    'sort_order': sortOrder,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };

  Issue copyWith({
    String? title,
    String? description,
    KanbanColumnStatus? status,
    List<String>? tags,
    String? branch,
    String? worktreePath,
    bool? isArchived,
    int? sortOrder,
    DateTime? updatedAt,
  }) {
    return Issue(
      id: id,
      projectId: projectId,
      title: title ?? this.title,
      description: description ?? this.description,
      status: status ?? this.status,
      tags: tags ?? this.tags,
      branch: branch ?? this.branch,
      worktreePath: worktreePath ?? this.worktreePath,
      isArchived: isArchived ?? this.isArchived,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static KanbanColumnStatus _statusFromString(String s) {
    return KanbanColumnStatus.values.firstWhere(
      (e) => e.name == s,
      orElse: () => KanbanColumnStatus.todo,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Issue && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
