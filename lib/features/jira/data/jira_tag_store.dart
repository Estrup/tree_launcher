import 'dart:convert';

import 'package:drift/drift.dart';

import 'package:tree_launcher/core/database/app_database.dart';
import 'package:tree_launcher/features/jira/domain/jira_tag.dart';

/// The user's local issue tags and which issues have them, in the
/// `jira_tags` and `jira_issue_tags` tables.
class JiraTagStore {
  JiraTagStore(this._db);

  final AppDatabase _db;

  /// What was last read or saved, encoded, so saving the same again (every
  /// settings save does) touches nothing.
  String? _known;

  /// The tags in display order, and each issue's tag ids.
  Future<({List<JiraTag> tags, Map<String, List<String>> byIssue})>
  load() async {
    final tagRows = await (_db.select(
      _db.jiraTags,
    )..orderBy([(t) => OrderingTerm(expression: t.position)])).get();
    final issueRows = await (_db.select(_db.jiraIssueTags)..orderBy([
          (t) => OrderingTerm(expression: t.issueKey),
          (t) => OrderingTerm(expression: t.position),
        ]))
        .get();
    final tags = [
      for (final row in tagRows)
        JiraTag(id: row.id, name: row.name, color: row.color),
    ];
    final byIssue = <String, List<String>>{};
    for (final row in issueRows) {
      (byIssue[row.issueKey] ??= []).add(row.tagId);
    }
    _known = _encode(tags, byIssue);
    return (tags: tags, byIssue: byIssue);
  }

  /// Whether no tag has been saved yet.
  Future<bool> get isEmpty async =>
      (await (_db.selectOnly(
            _db.jiraTags,
          )..addColumns([_db.jiraTags.id])).get())
          .isEmpty;

  /// Replaces every tag and issue tag with [tags] and [byIssue]. Ids in
  /// [byIssue] that aren't one of [tags] are left out.
  Future<void> save(
    List<JiraTag> tags,
    Map<String, List<String>> byIssue,
  ) async {
    final encoded = _encode(tags, byIssue);
    if (encoded == _known) return;
    final ids = {for (final tag in tags) tag.id};
    await _db.transaction(() async {
      await _db.delete(_db.jiraIssueTags).go();
      await _db.delete(_db.jiraTags).go();
      await _db.batch((batch) {
        batch.insertAll(_db.jiraTags, [
          for (final (i, tag) in tags.indexed)
            JiraTagsCompanion.insert(
              id: tag.id,
              name: tag.name,
              color: tag.color,
              position: i,
            ),
        ]);
        batch.insertAll(_db.jiraIssueTags, [
          for (final MapEntry(key: issueKey, value: tagIds) in byIssue.entries)
            for (final (i, tagId) in {...tagIds}.indexed)
              if (ids.contains(tagId))
                JiraIssueTagsCompanion.insert(
                  issueKey: issueKey,
                  tagId: tagId,
                  position: i,
                ),
        ]);
      });
    });
    _known = encoded;
  }

  static String _encode(List<JiraTag> tags, Map<String, List<String>> byIssue) =>
      jsonEncode({
        'tags': [for (final tag in tags) tag.toJson()],
        'byIssue': {
          for (final key in byIssue.keys.toList()..sort()) key: byIssue[key],
        },
      });
}
