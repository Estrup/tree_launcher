import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

import 'package:tree_launcher/core/database/app_database.dart';
import 'package:tree_launcher/features/workspace/domain/worktree_metadata.dart';

/// Per-worktree metadata, in the app database's `worktree_metadata` table:
/// one row per worktree path, removed once there is nothing to keep.
class WorktreeMetadataStore {
  WorktreeMetadataStore(this._db);

  final AppDatabase _db;

  /// Every row, in the order they were first written. Never throws.
  Future<List<WorktreeMetadata>> loadAll() async {
    try {
      final table = _db.worktreeMeta;
      final rows = await (_db.select(
        table,
      )..orderBy([(_) => OrderingTerm(expression: table.rowId)])).get();
      return [for (final row in rows) _fromRow(row)];
    } catch (e) {
      debugPrint('WorktreeMetadataStore.loadAll failed: $e');
      return [];
    }
  }

  /// Saves [entries] in one transaction: an empty one deletes its row, any
  /// other replaces it. Never throws.
  Future<void> saveAll(Iterable<WorktreeMetadata> entries) async {
    final list = entries.toList();
    if (list.isEmpty) return;
    try {
      await _db.batch((batch) {
        for (final entry in list) {
          if (entry.isEmpty) {
            batch.deleteWhere(
              _db.worktreeMeta,
              (t) => t.path.equals(entry.path),
            );
          } else {
            batch.insert(
              _db.worktreeMeta,
              _toRow(entry),
              onConflict: DoUpdate((_) => _toRow(entry)),
            );
          }
        }
      });
    } catch (e) {
      debugPrint('WorktreeMetadataStore.saveAll failed: $e');
    }
  }

  /// Deletes the rows of [paths]. Never throws.
  Future<void> delete(Iterable<String> paths) async {
    final list = paths.toList();
    if (list.isEmpty) return;
    try {
      await (_db.delete(
        _db.worktreeMeta,
      )..where((t) => t.path.isIn(list))).go();
    } catch (e) {
      debugPrint('WorktreeMetadataStore.delete failed: $e');
    }
  }

  /// Adds [entries] from before the database, keeping any row that is
  /// already there (so importing twice changes nothing). Throws on failure,
  /// so the caller keeps the source until it has been imported.
  Future<void> importLegacy(Iterable<WorktreeMetadata> entries) =>
      _db.batch((batch) {
        for (final entry in entries) {
          if (entry.isEmpty) continue;
          batch.insert(
            _db.worktreeMeta,
            _toRow(entry),
            mode: InsertMode.insertOrIgnore,
          );
        }
      });

  static WorktreeMetaCompanion _toRow(WorktreeMetadata m) =>
      WorktreeMetaCompanion.insert(
        path: m.path,
        repoPath: m.repoPath,
        baseBranch: Value(m.baseBranch),
        jiraIssue: Value(m.jiraIssue),
        githubIssue: Value(m.githubIssue),
        prAuthor: Value(m.prAuthor),
        kickoffPromptPath: Value(m.kickoffPromptPath),
        hidden: Value(m.hidden),
        snoozed: Value(m.snoozed),
        hasSession: Value(m.session != null),
        sessionPrompt: Value(m.session?.promptId),
        sessionStartedAt: Value(m.session?.startedAt),
      );

  static WorktreeMetadata _fromRow(WorktreeMetaRow row) => WorktreeMetadata(
    path: row.path,
    repoPath: row.repoPath,
    baseBranch: row.baseBranch,
    jiraIssue: row.jiraIssue,
    githubIssue: row.githubIssue,
    prAuthor: row.prAuthor,
    kickoffPromptPath: row.kickoffPromptPath,
    hidden: row.hidden,
    snoozed: row.snoozed,
    session: row.hasSession
        ? RememberedSession(
            promptId: row.sessionPrompt,
            startedAt: row.sessionStartedAt,
          )
        : null,
  );
}
