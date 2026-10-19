import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'package:tree_launcher/core/database/app_database.dart';
import 'package:tree_launcher/core/database/legacy_importer.dart';
import 'package:tree_launcher/features/agents/data/agent_run_store.dart';
import 'package:tree_launcher/features/agents/domain/agent_event.dart';
import 'package:tree_launcher/features/agents/domain/agent_run.dart';

/// Merges the pre-database `agent_runs.json` into `agent_runs`. A run that is
/// already there is replaced only by a copy updated at the same time or later.
class AgentRunsLegacyImport implements LegacyImport {
  AgentRunsLegacyImport(this._db);

  final AppDatabase _db;

  @override
  String get fileName => 'agent_runs.json';

  @override
  Future<void> merge(String content) async {
    final json = jsonDecode(content);
    final runs = json is Map<String, dynamic> ? json['runs'] : null;
    if (runs is! List) return;
    final existing = {
      for (final row in await _db.select(_db.agentRuns).get())
        row.id: row.updatedAt,
    };
    for (final runJson in runs.whereType<Map<String, dynamic>>()) {
      final AgentRun run;
      try {
        run = AgentRun.fromJson(runJson);
      } catch (e) {
        debugPrint('$fileName: skipping malformed run: $e');
        continue;
      }
      final have = existing[run.id];
      if (have != null && have.isAfter(run.updatedAt)) continue;
      await writeAgentRun(_db, run);
    }
  }
}

/// Merges the pre-database `agent_events.jsonl` into `agent_events`. Events
/// already there (same run, time and message) and events of runs that no
/// longer exist are skipped. Run after [AgentRunsLegacyImport].
class AgentEventsLegacyImport implements LegacyImport {
  AgentEventsLegacyImport(this._db);

  final AppDatabase _db;

  @override
  String get fileName => 'agent_events.jsonl';

  static String _key(String runId, DateTime at, String message) =>
      '$runId|${at.toIso8601String()}|$message';

  @override
  Future<void> merge(String content) async {
    final runIds = {
      for (final row in await _db.select(_db.agentRuns).get()) row.id,
    };
    final seen = {
      for (final row in await _db.select(_db.agentEvents).get())
        _key(row.runId, row.at, row.message),
    };
    final rows = <AgentEventsCompanion>[];
    for (final json in parseJsonLines(content, fileName)) {
      final AgentEvent event;
      try {
        event = AgentEvent.fromJson(json);
      } catch (e) {
        debugPrint('$fileName: skipping malformed event: $e');
        continue;
      }
      if (!runIds.contains(event.agentId)) continue;
      if (!seen.add(_key(event.agentId, event.at, event.message))) continue;
      rows.add(agentEventRow(event));
    }
    await _db.batch((batch) => batch.insertAll(_db.agentEvents, rows));
  }
}
