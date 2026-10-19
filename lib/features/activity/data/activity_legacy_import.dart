import 'package:flutter/foundation.dart';

import 'package:tree_launcher/core/database/app_database.dart';
import 'package:tree_launcher/core/database/legacy_importer.dart';
import 'package:tree_launcher/features/activity/data/manual_post_store.dart';
import 'package:tree_launcher/features/activity/data/worktree_event_store.dart';
import 'package:tree_launcher/features/activity/domain/manual_post.dart';
import 'package:tree_launcher/features/activity/domain/worktree_event.dart';

/// Merges the pre-database `worktree_events.jsonl` into `worktree_events`,
/// skipping events already there (same time, type and worktree).
class WorktreeEventsLegacyImport implements LegacyImport {
  WorktreeEventsLegacyImport(this._db);

  final AppDatabase _db;

  @override
  String get fileName => 'worktree_events.jsonl';

  static String _key(DateTime at, String type, String worktreePath) =>
      '${at.toIso8601String()}|$type|$worktreePath';

  @override
  Future<void> merge(String content) async {
    final seen = {
      for (final row in await _db.select(_db.worktreeEvents).get())
        _key(row.at, row.type, row.worktreePath),
    };
    final rows = <WorktreeEventsCompanion>[];
    for (final json in parseJsonLines(content, fileName)) {
      final WorktreeEvent event;
      try {
        event = WorktreeEvent.fromJson(json);
      } catch (e) {
        debugPrint('$fileName: skipping malformed event: $e');
        continue;
      }
      final key = _key(event.timestamp, event.type.name, event.worktreePath);
      if (!seen.add(key)) continue;
      rows.add(worktreeEventRow(event));
    }
    await _db.batch((batch) => batch.insertAll(_db.worktreeEvents, rows));
  }
}

/// Replays the pre-database `manual_posts.jsonl` into `manual_posts`: a post
/// line saves the post, a `{"kind": "delete", "id": …}` tombstone deletes it.
class ManualPostsLegacyImport implements LegacyImport {
  ManualPostsLegacyImport(this._db);

  final AppDatabase _db;

  @override
  String get fileName => 'manual_posts.jsonl';

  @override
  Future<void> merge(String content) async {
    for (final json in parseJsonLines(content, fileName)) {
      if (json['kind'] == 'delete') {
        final id = json['id'];
        if (id is! String) continue;
        await (_db.delete(_db.manualPosts)..where((t) => t.id.equals(id))).go();
        continue;
      }
      final ManualPost post;
      try {
        post = ManualPost.fromJson(json);
      } catch (e) {
        debugPrint('$fileName: skipping malformed post: $e');
        continue;
      }
      if (post.id.isEmpty) continue;
      await _db
          .into(_db.manualPosts)
          .insertOnConflictUpdate(manualPostRow(post));
    }
  }
}
