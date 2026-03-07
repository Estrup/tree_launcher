import 'package:sqlite3/sqlite3.dart';
import '../models/comment.dart';
import 'database_service.dart';

class CommentRepository {
  final Database _db;

  CommentRepository() : _db = DatabaseService.instance.db;

  /// For testing with a custom database.
  CommentRepository.withDb(this._db);

  /// Creates a new comment and returns it.
  Comment createComment({
    required String issueId,
    required String content,
    required CommentAuthorType authorType,
    required String authorName,
  }) {
    final comment = Comment.create(
      issueId: issueId,
      content: content,
      authorType: authorType,
      authorName: authorName,
    );
    final map = comment.toMap();

    _db.execute(
      'INSERT INTO issue_comments (id, issue_id, content, author_type, author_name, created_at, updated_at) '
      'VALUES (?, ?, ?, ?, ?, ?, ?)',
      [
        map['id'],
        map['issue_id'],
        map['content'],
        map['author_type'],
        map['author_name'],
        map['created_at'],
        map['updated_at'],
      ],
    );

    return comment;
  }

  /// Updates the content of an existing comment.
  void updateComment(String commentId, String newContent) {
    final now = DateTime.now().toIso8601String();
    _db.execute(
      'UPDATE issue_comments SET content = ?, updated_at = ? WHERE id = ?',
      [newContent, now, commentId],
    );
  }

  /// Deletes a comment.
  void deleteComment(String commentId) {
    _db.execute('DELETE FROM issue_comments WHERE id = ?', [commentId]);
  }

  /// Returns all comments for an issue, ordered chronologically.
  List<Comment> getCommentsForIssue(String issueId) {
    final result = _db.select(
      'SELECT * FROM issue_comments WHERE issue_id = ? ORDER BY created_at ASC',
      [issueId],
    );

    return result.map((row) => Comment.fromMap(row)).toList();
  }
}
