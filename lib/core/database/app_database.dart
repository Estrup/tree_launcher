import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart' show Database;

import 'package:tree_launcher/core/database/tables.dart';
import 'package:tree_launcher/core/storage/app_data_directory.dart';

export 'package:tree_launcher/core/database/tables.dart';

part 'app_database.g.dart';

/// The app's SQLite database, `tree_launcher.db` in the app support
/// directory. It runs on a background isolate in WAL mode, so the live app
/// and a debug instance can share the file.
@DriftDatabase(
  tables: [
    AgentRuns,
    AgentRunIssues,
    AgentEvents,
    WorktreeEvents,
    ManualPosts,
    IssueCache,
    ClaudeTranscripts,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  /// Opens [fileName] in [directory] (default: the app's data directory).
  /// The file is opened on the first query, so this returns at once.
  factory AppDatabase.open({String? directory}) => AppDatabase(
    LazyDatabase(() async {
      final dir = directory ?? await appDataDirectory();
      final file = File(p.join(dir, fileName));
      await file.parent.create(recursive: true);
      return NativeDatabase.createInBackground(file, setup: _configure);
    }),
  );

  /// An empty in-memory database, for tests.
  factory AppDatabase.memory() =>
      AppDatabase(NativeDatabase.memory(setup: _configure));

  static const fileName = 'tree_launcher.db';

  /// Runs on every new connection.
  static void _configure(Database database) {
    database.execute('PRAGMA journal_mode = WAL');
    // Wait for the other instance's write instead of failing at once.
    database.execute('PRAGMA busy_timeout = 5000');
    database.execute('PRAGMA foreign_keys = ON');
  }

  @override
  int get schemaVersion => 1;
}
