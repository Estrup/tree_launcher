import 'package:sqlite3/sqlite3.dart';
import '../models/issue.dart';
import '../widgets/kanban_board.dart';
import 'database_service.dart';

class IssueRepository {
  final Database _db;

  IssueRepository() : _db = DatabaseService.instance.db;

  /// For testing with a custom database.
  IssueRepository.withDb(this._db);

  /// Creates a new issue and returns it.
  Issue createIssue(String projectId, String title, {String? description}) {
    final issue = Issue.create(
      projectId: projectId,
      title: title,
      description: description,
    );
    final map = issue.toMap();

    _db.execute(
      'INSERT INTO issues (id, project_id, title, description, status, tags, branch, worktree_path, is_archived, sort_order, created_at, updated_at) '
      'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
      [
        map['id'],
        map['project_id'],
        map['title'],
        map['description'],
        map['status'],
        map['tags'],
        map['branch'],
        map['worktree_path'],
        map['is_archived'],
        map['sort_order'],
        map['created_at'],
        map['updated_at'],
      ],
    );

    return issue;
  }

  /// Updates an existing issue (title, description, tags, branch, worktreePath).
  void updateIssue(Issue issue) {
    final now = DateTime.now().toIso8601String();
    final map = issue.toMap();

    _db.execute(
      'UPDATE issues SET title = ?, description = ?, tags = ?, branch = ?, worktree_path = ?, updated_at = ? WHERE id = ?',
      [
        map['title'],
        map['description'],
        map['tags'],
        map['branch'],
        map['worktree_path'],
        now,
        map['id'],
      ],
    );
  }

  /// Moves an issue to a new status column.
  void moveIssue(String issueId, KanbanColumnStatus newStatus) {
    final now = DateTime.now().toIso8601String();

    _db.execute('UPDATE issues SET status = ?, updated_at = ? WHERE id = ?', [
      newStatus.name,
      now,
      issueId,
    ]);
  }

  /// Archives an issue.
  void archiveIssue(String issueId) {
    final now = DateTime.now().toIso8601String();

    _db.execute(
      'UPDATE issues SET is_archived = 1, updated_at = ? WHERE id = ?',
      [now, issueId],
    );
  }

  /// Returns all non-archived issues for a project, grouped by the caller.
  List<Issue> getIssuesForProject(String projectId) {
    final result = _db.select(
      'SELECT * FROM issues WHERE project_id = ? AND is_archived = 0 ORDER BY sort_order ASC, created_at ASC',
      [projectId],
    );

    return result.map((row) => Issue.fromMap(row)).toList();
  }

  /// Returns a single issue by ID.
  Issue? getIssueById(String issueId) {
    final result = _db.select('SELECT * FROM issues WHERE id = ?', [issueId]);

    if (result.isEmpty) return null;
    return Issue.fromMap(result.first);
  }
}
