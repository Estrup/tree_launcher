import 'package:sqlite3/sqlite3.dart';
import '../models/issue_copilot_link.dart';
import 'database_service.dart';

class IssueCopilotRepository {
  final Database _db;

  IssueCopilotRepository() : _db = DatabaseService.instance.db;

  /// For testing with a custom database.
  IssueCopilotRepository.withDb(this._db);

  /// Links a copilot session to an issue.
  IssueCopilotLink linkSession(String issueId, String copilotSessionId) {
    final link = IssueCopilotLink.create(
      issueId: issueId,
      copilotSessionId: copilotSessionId,
    );
    final map = link.toMap();

    _db.execute(
      'INSERT INTO issue_copilot_sessions (id, issue_id, copilot_session_id, created_at) '
      'VALUES (?, ?, ?, ?)',
      [
        map['id'],
        map['issue_id'],
        map['copilot_session_id'],
        map['created_at'],
      ],
    );

    return link;
  }

  /// Unlinks a copilot session from an issue.
  void unlinkSession(String issueId, String copilotSessionId) {
    _db.execute(
      'DELETE FROM issue_copilot_sessions WHERE issue_id = ? AND copilot_session_id = ?',
      [issueId, copilotSessionId],
    );
  }

  /// Returns all copilot session links for an issue.
  List<IssueCopilotLink> getLinksForIssue(String issueId) {
    final result = _db.select(
      'SELECT * FROM issue_copilot_sessions WHERE issue_id = ? ORDER BY created_at DESC',
      [issueId],
    );

    return result.map((row) => IssueCopilotLink.fromMap(row)).toList();
  }
}
