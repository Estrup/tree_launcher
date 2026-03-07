import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

/// Singleton service managing the SQLite database lifecycle.
class DatabaseService {
  static DatabaseService? _instance;
  static Database? _database;

  DatabaseService._();

  static DatabaseService get instance {
    _instance ??= DatabaseService._();
    return _instance!;
  }

  /// The active database connection. Must call [initialize] first.
  Database get db {
    if (_database == null) {
      throw StateError(
        'DatabaseService not initialized. Call initialize() first.',
      );
    }
    return _database!;
  }

  /// Opens (or creates) the kanban.db in Application Support.
  Future<void> initialize() async {
    if (_database != null) return;

    final appSupport = await getApplicationSupportDirectory();
    final dbPath = p.join(appSupport.path, 'kanban.db');

    // Ensure directory exists
    await Directory(appSupport.path).create(recursive: true);

    _database = sqlite3.open(dbPath);

    _createTables();
  }

  /// Opens an in-memory database — for testing only.
  void initializeForTesting() {
    _database = sqlite3.openInMemory();
    _createTables();
  }

  void _createTables() {
    final db = _database!;

    db.execute('''
      CREATE TABLE IF NOT EXISTS projects (
        id TEXT PRIMARY KEY,
        repo_path TEXT NOT NULL,
        name TEXT NOT NULL,
        key TEXT NOT NULL,
        is_archived INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');

    db.execute('''
      CREATE TABLE IF NOT EXISTS issues (
        id TEXT PRIMARY KEY,
        project_id TEXT NOT NULL,
        issue_number INTEGER NOT NULL,
        project_key TEXT NOT NULL,
        title TEXT NOT NULL,
        description TEXT,
        status TEXT NOT NULL DEFAULT 'todo',
        tags TEXT,
        branch TEXT,
        worktree_path TEXT,
        is_archived INTEGER NOT NULL DEFAULT 0,
        sort_order INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (project_id) REFERENCES projects(id)
      )
    ''');

    db.execute('''
      CREATE TABLE IF NOT EXISTS issue_copilot_sessions (
        id TEXT PRIMARY KEY,
        issue_id TEXT NOT NULL,
        copilot_session_id TEXT NOT NULL,
        worktree_path TEXT,
        branch TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (issue_id) REFERENCES issues(id)
      )
    ''');

    // Migration: add columns for existing DBs
    try {
      db.execute(
        'ALTER TABLE issue_copilot_sessions ADD COLUMN worktree_path TEXT',
      );
    } catch (_) {}
    try {
      db.execute('ALTER TABLE issue_copilot_sessions ADD COLUMN branch TEXT');
    } catch (_) {}

    // Indexes for common queries
    db.execute('''
      CREATE INDEX IF NOT EXISTS idx_projects_repo_path
      ON projects(repo_path)
    ''');

    db.execute('''
      CREATE INDEX IF NOT EXISTS idx_issues_project_id
      ON issues(project_id)
    ''');

    db.execute('''
      CREATE INDEX IF NOT EXISTS idx_issue_copilot_sessions_issue_id
      ON issue_copilot_sessions(issue_id)
    ''');

    db.execute('''
      CREATE TABLE IF NOT EXISTS issue_comments (
        id TEXT PRIMARY KEY,
        issue_id TEXT NOT NULL,
        content TEXT NOT NULL,
        author_type TEXT NOT NULL DEFAULT 'user',
        author_name TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (issue_id) REFERENCES issues(id)
      )
    ''');

    db.execute('''
      CREATE INDEX IF NOT EXISTS idx_issue_comments_issue_id
      ON issue_comments(issue_id)
    ''');
  }

  /// Closes the database connection.
  void close() {
    _database?.close();
    _database = null;
    _instance = null;
  }
}
