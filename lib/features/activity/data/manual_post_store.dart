import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

import 'package:tree_launcher/core/database/app_database.dart';
import 'package:tree_launcher/models/manual_post.dart';

/// Manually logged activity posts, in the app database's `manual_posts`
/// table. Deleting a post deletes its row.
class ManualPostStore {
  ManualPostStore(this._db);

  final AppDatabase _db;

  /// Saves a single post, replacing one with the same id. Never throws.
  Future<void> add(ManualPost post) async {
    try {
      await _db
          .into(_db.manualPosts)
          .insertOnConflictUpdate(manualPostRow(post));
    } catch (e) {
      debugPrint('ManualPostStore.add failed: $e');
    }
  }

  /// Deletes the post with [id]. Never throws.
  Future<void> delete(String id) async {
    try {
      await (_db.delete(_db.manualPosts)..where((t) => t.id.equals(id))).go();
    } catch (e) {
      debugPrint('ManualPostStore.delete failed: $e');
    }
  }

  /// The posts in write order. Never throws.
  Future<List<ManualPost>> loadAll() async {
    try {
      final table = _db.manualPosts;
      final rows = await (_db.select(
        table,
      )..orderBy([(_) => OrderingTerm(expression: table.rowId)])).get();
      return [
        for (final row in rows)
          ManualPost(
            id: row.id,
            timestamp: row.at,
            repoName: row.repoName,
            issueKey: row.issueKey,
            description: row.description,
            hours: row.hours,
          ),
      ];
    } catch (e) {
      debugPrint('ManualPostStore.loadAll failed: $e');
      return [];
    }
  }
}

/// The `manual_posts` row for [post].
ManualPostsCompanion manualPostRow(ManualPost post) =>
    ManualPostsCompanion.insert(
      id: post.id,
      at: post.timestamp,
      repoName: post.repoName,
      issueKey: post.issueKey,
      description: post.description,
      hours: Value(post.hours),
    );
