import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

import 'package:tree_launcher/core/database/app_database.dart';
import 'package:tree_launcher/features/agents/domain/agent_event.dart';
import 'package:tree_launcher/features/agents/domain/agent_run.dart';

/// Persists agent runs in the app database: each run's state in `agent_runs`
/// (its issue keys in `agent_run_issues`) and their timelines in
/// `agent_events`. Deleting a run deletes its issue keys and events.
class AgentRunStore {
  AgentRunStore(this._db);

  final AppDatabase _db;

  /// Each run as this store last loaded or saved it (its JSON), so
  /// [saveRuns] writes only the runs that changed and deletes only runs it
  /// knew about (not ones another instance has added since).
  final Map<String, String> _saved = {};

  /// Every saved run. Never throws; an unreadable row is skipped.
  Future<List<AgentRun>> loadRuns() async {
    try {
      final rows = await (_db.select(
        _db.agentRuns,
      )..orderBy([(t) => OrderingTerm(expression: t.startedAt)])).get();
      final issueRows = await (_db.select(
        _db.agentRunIssues,
      )..orderBy([(t) => OrderingTerm(expression: t.position)])).get();
      final issueKeys = <String, List<String>>{};
      for (final row in issueRows) {
        issueKeys.putIfAbsent(row.runId, () => []).add(row.issueKey);
      }
      final result = <AgentRun>[];
      for (final row in rows) {
        try {
          final run = agentRunFromRow(row, issueKeys[row.id] ?? const []);
          result.add(run);
          _saved[run.id] = jsonEncode(run.toJson());
        } catch (e) {
          debugPrint('AgentRunStore: skipping malformed run ${row.id}: $e');
        }
      }
      return result;
    } catch (e) {
      debugPrint('AgentRunStore.loadRuns failed: $e');
      return [];
    }
  }

  /// Makes [runs] the saved runs: writes the ones that changed and deletes
  /// the ones this store saved before that are no longer in the list.
  Future<void> saveRuns(List<AgentRun> runs) async {
    try {
      final encoded = {
        for (final run in runs) run.id: jsonEncode(run.toJson()),
      };
      final changed = [
        for (final run in runs)
          if (_saved[run.id] != encoded[run.id]) run,
      ];
      final removed = [
        for (final id in _saved.keys)
          if (!encoded.containsKey(id)) id,
      ];
      if (changed.isEmpty && removed.isEmpty) return;
      await _db.transaction(() async {
        for (final run in changed) {
          await writeAgentRun(_db, run);
        }
        if (removed.isNotEmpty) {
          await (_db.delete(
            _db.agentRuns,
          )..where((t) => t.id.isIn(removed))).go();
        }
      });
      for (final run in changed) {
        _saved[run.id] = encoded[run.id]!;
      }
      removed.forEach(_saved.remove);
    } catch (e) {
      debugPrint('AgentRunStore.saveRuns failed: $e');
    }
  }

  /// Appends one timeline event. Never throws.
  Future<void> appendEvent(AgentEvent event) async {
    try {
      await _db.into(_db.agentEvents).insert(agentEventRow(event));
    } catch (e) {
      debugPrint('AgentRunStore.appendEvent failed: $e');
    }
  }

  /// Every event in write order. Never throws.
  Future<List<AgentEvent>> loadEvents() async {
    try {
      final rows = await (_db.select(
        _db.agentEvents,
      )..orderBy([(t) => OrderingTerm(expression: t.id)])).get();
      return [
        for (final row in rows)
          AgentEvent(
            agentId: row.runId,
            at: row.at,
            message: row.message,
            stage: row.stage,
            level: AgentEventLevel.tryParse(row.level) ?? AgentEventLevel.info,
          ),
      ];
    } catch (e) {
      debugPrint('AgentRunStore.loadEvents failed: $e');
      return [];
    }
  }

  /// Replaces the saved events with [events] (after old runs are pruned).
  /// Events of runs that aren't saved are left out.
  Future<void> replaceEvents(List<AgentEvent> events) async {
    try {
      await _db.transaction(() async {
        final runIds = (await _db.select(_db.agentRuns).get())
            .map((r) => r.id)
            .toSet();
        await _db.delete(_db.agentEvents).go();
        await _db.batch(
          (batch) => batch.insertAll(_db.agentEvents, [
            for (final event in events)
              if (runIds.contains(event.agentId)) agentEventRow(event),
          ]),
        );
      });
    } catch (e) {
      debugPrint('AgentRunStore.replaceEvents failed: $e');
    }
  }
}

/// The JSON keys of [AgentRun.toJson] that have their own column (or, for
/// `issueKeys`, their own table); the rest go in `agent_runs.detail`.
const _agentRunColumnKeys = {
  'id',
  'kind',
  'repo',
  'title',
  'state',
  'worktreePath',
  'branch',
  'prNumber',
  'archived',
  'startedAt',
  'updatedAt',
  'finishedAt',
  'issueKeys',
};

/// Inserts or updates [run] and its issue keys. Run inside a transaction.
/// An upsert, not `INSERT OR REPLACE`, which would delete the run's events.
Future<void> writeAgentRun(AppDatabase db, AgentRun run) async {
  final json = run.toJson();
  await db
      .into(db.agentRuns)
      .insertOnConflictUpdate(
        AgentRunsCompanion.insert(
          id: run.id,
          kind: run.kind.id,
          repo: run.repoName,
          title: Value(run.title),
          state: run.state.name,
          worktreePath: Value(run.worktreePath),
          branch: Value(run.branch),
          prNumber: Value(run.prNumber),
          archived: Value(run.archived),
          startedAt: run.startedAt,
          updatedAt: run.updatedAt,
          finishedAt: Value(run.finishedAt),
          detail: jsonEncode({
            for (final entry in json.entries)
              if (!_agentRunColumnKeys.contains(entry.key))
                entry.key: entry.value,
          }),
        ),
      );
  await (db.delete(
    db.agentRunIssues,
  )..where((t) => t.runId.equals(run.id))).go();
  final keys = run.issueKeys.toSet().toList();
  await db.batch(
    (batch) => batch.insertAll(db.agentRunIssues, [
      for (var i = 0; i < keys.length; i++)
        AgentRunIssuesCompanion.insert(
          runId: run.id,
          issueKey: keys[i],
          position: i,
        ),
    ]),
  );
}

/// The run stored in [row], with its [issueKeys].
AgentRun agentRunFromRow(AgentRunRow row, List<String> issueKeys) =>
    AgentRun.fromJson({
      ...jsonDecode(row.detail) as Map<String, dynamic>,
      'id': row.id,
      'kind': row.kind,
      'repo': row.repo,
      'title': row.title,
      'state': row.state,
      'worktreePath': row.worktreePath,
      'branch': row.branch,
      'prNumber': row.prNumber,
      'archived': row.archived,
      'startedAt': row.startedAt.toIso8601String(),
      'updatedAt': row.updatedAt.toIso8601String(),
      'finishedAt': row.finishedAt?.toIso8601String(),
      'issueKeys': issueKeys,
    });

/// The `agent_events` row for [event].
AgentEventsCompanion agentEventRow(AgentEvent event) =>
    AgentEventsCompanion.insert(
      runId: event.agentId,
      at: event.at,
      stage: Value(event.stage),
      level: event.level.name,
      message: event.message,
    );
