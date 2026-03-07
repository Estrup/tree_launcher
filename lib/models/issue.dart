import 'dart:convert';
import 'package:uuid/uuid.dart';
import 'issue_status.dart';

const _unsetDescription = Object();

class Issue {
  final String id;
  final String projectId;

  /// Sequential number within the project (1, 2, 3, ...).
  final int issueNumber;

  /// The project key prefix, e.g. "PRO". Stored for display convenience.
  final String projectKey;
  final String title;
  final String? description;
  final IssueStatus status;
  final List<String> tags;
  final bool isArchived;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Issue({
    required this.id,
    required this.projectId,
    required this.issueNumber,
    required this.projectKey,
    required this.title,
    this.description,
    this.status = IssueStatus.todo,
    this.tags = const [],
    this.isArchived = false,
    this.sortOrder = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Display ID like "PRO-001".
  String get displayId =>
      '$projectKey-${issueNumber.toString().padLeft(3, '0')}';

  factory Issue.create({
    required String projectId,
    required int issueNumber,
    required String projectKey,
    required String title,
    String? description,
  }) {
    final now = DateTime.now();
    return Issue(
      id: const Uuid().v4(),
      projectId: projectId,
      issueNumber: issueNumber,
      projectKey: projectKey,
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
      issueNumber: map['issue_number'] as int,
      projectKey: map['project_key'] as String,
      title: map['title'] as String,
      description: map['description'] as String?,
      status: _statusFromString(map['status'] as String),
      tags: map['tags'] != null
          ? List<String>.from(jsonDecode(map['tags'] as String) as List)
          : [],
      isArchived: (map['is_archived'] as int) == 1,
      sortOrder: map['sort_order'] as int,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'project_id': projectId,
    'issue_number': issueNumber,
    'project_key': projectKey,
    'title': title,
    'description': description,
    'status': status.name,
    'tags': tags.isNotEmpty ? jsonEncode(tags) : null,
    'is_archived': isArchived ? 1 : 0,
    'sort_order': sortOrder,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };

  Issue copyWith({
    String? title,
    Object? description = _unsetDescription,
    IssueStatus? status,
    List<String>? tags,
    bool? isArchived,
    int? sortOrder,
    DateTime? updatedAt,
  }) {
    return Issue(
      id: id,
      projectId: projectId,
      issueNumber: issueNumber,
      projectKey: projectKey,
      title: title ?? this.title,
      description: identical(description, _unsetDescription)
          ? this.description
          : description as String?,
      status: status ?? this.status,
      tags: tags ?? this.tags,
      isArchived: isArchived ?? this.isArchived,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static IssueStatus _statusFromString(String s) {
    return IssueStatus.values.firstWhere(
      (e) => e.name == s,
      orElse: () => IssueStatus.todo,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Issue && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
