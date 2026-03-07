import 'package:sqlite3/sqlite3.dart';
import '../models/issue.dart';
import '../models/issue_status.dart';
import 'database_service.dart';

class IssueRepository {
  final Database _db;

  IssueRepository() : _db = DatabaseService.instance.db;

  /// For testing with a custom database.
  IssueRepository.withDb(this._db);

  /// Creates a new issue with auto-incremented issue number and returns it.
  Issue createIssue(
    String projectId,
    String projectKey,
    String title, {
    String? description,
  }) {
    // Get next issue number for this project (including archived issues)
    final maxResult = _db.select(
      'SELECT COALESCE(MAX(issue_number), 0) as max_num FROM issues WHERE project_id = ?',
      [projectId],
    );
    final nextNumber = (maxResult.first['max_num'] as int) + 1;

    final issue = Issue.create(
      projectId: projectId,
      issueNumber: nextNumber,
      projectKey: projectKey,
      title: title,
      description: description,
    );
    final map = issue.toMap();

    _db.execute(
      'INSERT INTO issues (id, project_id, issue_number, project_key, title, description, status, tags, is_archived, sort_order, created_at, updated_at) '
      'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
      [
        map['id'],
        map['project_id'],
        map['issue_number'],
        map['project_key'],
        map['title'],
        map['description'],
        map['status'],
        map['tags'],
        map['is_archived'],
        map['sort_order'],
        map['created_at'],
        map['updated_at'],
      ],
    );

    return issue;
  }

  /// Updates an existing issue (title, description, tags).
  void updateIssue(Issue issue) {
    final now = DateTime.now().toIso8601String();
    final map = issue.toMap();

    _db.execute(
      'UPDATE issues SET title = ?, description = ?, status = ?, tags = ?, updated_at = ? WHERE id = ?',
      [
        map['title'],
        map['description'],
        map['status'],
        map['tags'],
        now,
        map['id'],
      ],
    );
  }

  /// Moves an issue to a new status column.
  void moveIssue(String issueId, IssueStatus newStatus) {
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
    return getIssuesForProjectIncludingArchived(
      projectId,
      includeArchived: false,
    );
  }

  List<Issue> getIssuesForProjectIncludingArchived(
    String projectId, {
    required bool includeArchived,
  }) {
    final archivedClause = includeArchived ? '' : ' AND is_archived = 0';
    final result = _db.select(
      'SELECT * FROM issues WHERE project_id = ?$archivedClause ORDER BY sort_order ASC, created_at ASC',
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

  List<Issue> findIssuesByDisplayId({
    required String projectKey,
    required int issueNumber,
  }) {
    final result = _db.select(
      'SELECT * FROM issues WHERE project_key = ? AND issue_number = ?',
      [projectKey, issueNumber],
    );

    return result.map((row) => Issue.fromMap(row)).toList();
  }
}
