import 'package:sqlite3/sqlite3.dart';
import '../models/project.dart';
import 'database_service.dart';

class ProjectRepository {
  final Database _db;

  ProjectRepository() : _db = DatabaseService.instance.db;

  /// For testing with a custom database.
  ProjectRepository.withDb(this._db);

  /// Creates a new project and returns it.
  Project createProject(String repoPath, String name, String key) {
    final project = Project.create(repoPath: repoPath, name: name, key: key);
    final map = project.toMap();

    _db.execute(
      'INSERT INTO projects (id, repo_path, name, key, is_archived, created_at) '
      'VALUES (?, ?, ?, ?, ?, ?)',
      [
        map['id'],
        map['repo_path'],
        map['name'],
        map['key'],
        map['is_archived'],
        map['created_at'],
      ],
    );

    return project;
  }

  /// Returns all non-archived projects for a given repo path.
  List<Project> getProjectsForRepo(String repoPath) {
    final result = _db.select(
      'SELECT * FROM projects WHERE repo_path = ? AND is_archived = 0 ORDER BY created_at ASC',
      [repoPath],
    );

    return result.map((row) => Project.fromMap(row)).toList();
  }

  /// Returns all projects (including archived) for a given repo path.
  List<Project> getAllProjectsForRepo(String repoPath) {
    final result = _db.select(
      'SELECT * FROM projects WHERE repo_path = ? ORDER BY created_at ASC',
      [repoPath],
    );

    return result.map((row) => Project.fromMap(row)).toList();
  }

  /// Returns a single project by ID.
  Project? getProjectById(String projectId) {
    final result = _db.select('SELECT * FROM projects WHERE id = ?', [
      projectId,
    ]);

    if (result.isEmpty) return null;
    return Project.fromMap(result.first);
  }

  /// Archives a project by setting is_archived = 1.
  void archiveProject(String projectId) {
    _db.execute('UPDATE projects SET is_archived = 1 WHERE id = ?', [
      projectId,
    ]);
  }

  /// Renames a project.
  void renameProject(String projectId, String newName) {
    _db.execute('UPDATE projects SET name = ? WHERE id = ?', [
      newName,
      projectId,
    ]);
  }
}
