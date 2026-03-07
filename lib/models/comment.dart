import 'package:uuid/uuid.dart';

/// Represents who authored the comment.
enum CommentAuthorType { user, agent }

extension CommentAuthorTypeParsing on CommentAuthorType {
  static CommentAuthorType fromName(String value) {
    return CommentAuthorType.values.firstWhere(
      (type) => type.name == value,
      orElse: () => CommentAuthorType.user,
    );
  }
}

class Comment {
  final String id;
  final String issueId;

  /// Markdown content.
  final String content;
  final CommentAuthorType authorType;

  /// Display name of the author (e.g. username or agent name).
  final String authorName;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Comment({
    required this.id,
    required this.issueId,
    required this.content,
    required this.authorType,
    required this.authorName,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Comment.create({
    required String issueId,
    required String content,
    required CommentAuthorType authorType,
    required String authorName,
  }) {
    final now = DateTime.now();
    return Comment(
      id: const Uuid().v4(),
      issueId: issueId,
      content: content,
      authorType: authorType,
      authorName: authorName,
      createdAt: now,
      updatedAt: now,
    );
  }

  factory Comment.fromMap(Map<String, dynamic> map) {
    return Comment(
      id: map['id'] as String,
      issueId: map['issue_id'] as String,
      content: map['content'] as String,
      authorType: CommentAuthorTypeParsing.fromName(
        map['author_type'] as String? ?? CommentAuthorType.user.name,
      ),
      authorName: map['author_name'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'issue_id': issueId,
    'content': content,
    'author_type': authorType.name,
    'author_name': authorName,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };

  Comment copyWith({String? content, DateTime? updatedAt}) {
    return Comment(
      id: id,
      issueId: issueId,
      content: content ?? this.content,
      authorType: authorType,
      authorName: authorName,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
