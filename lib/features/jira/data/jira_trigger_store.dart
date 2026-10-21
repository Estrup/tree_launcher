import 'package:drift/drift.dart';

import 'package:tree_launcher/core/database/app_database.dart';

/// The issues each Jira trigger has fired for, in the `jira_trigger_issues`
/// table.
class JiraTriggerStore {
  JiraTriggerStore(this._db);

  final AppDatabase _db;

  /// The issues trigger [triggerId] has fired for.
  Future<Set<String>> firedFor(String triggerId) async {
    final rows = await (_db.select(
      _db.jiraTriggerIssues,
    )..where((t) => t.triggerId.equals(triggerId))).get();
    return {for (final row in rows) row.issueKey};
  }

  /// Records that trigger [triggerId] fires for [issueKey]. False when it
  /// already has, maybe from another instance sharing the database, which
  /// then starts the session instead.
  Future<bool> claim(String triggerId, String issueKey) async {
    final inserted = await _db.customUpdate(
      'INSERT OR IGNORE INTO jira_trigger_issues '
      '(trigger_id, issue_key, fired_at) VALUES (?, ?, ?)',
      variables: [
        Variable.withString(triggerId),
        Variable.withString(issueKey),
        Variable.withString(DateTime.now().toIso8601String()),
      ],
      updates: {_db.jiraTriggerIssues},
      updateKind: UpdateKind.insert,
    );
    return inserted == 1;
  }

  /// Forgets the issues of trigger [triggerId] that are not in [matching],
  /// so they fire again when they match again.
  Future<void> keepOnly(String triggerId, Set<String> matching) =>
      (_db.delete(_db.jiraTriggerIssues)..where(
            (t) => t.triggerId.equals(triggerId) & t.issueKey.isNotIn(matching),
          ))
          .go();

  /// Forgets every trigger but [triggerIds] (the ones still configured).
  Future<void> keepTriggers(Set<String> triggerIds) => (_db.delete(
    _db.jiraTriggerIssues,
  )..where((t) => t.triggerId.isNotIn(triggerIds))).go();
}
