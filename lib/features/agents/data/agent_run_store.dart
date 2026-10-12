import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:tree_launcher/features/agents/domain/agent_event.dart';
import 'package:tree_launcher/features/agents/domain/agent_run.dart';

/// Persists agent runs in the app support directory: the runs' current state
/// in `agent_runs.json` (rewritten on each change) and their timelines in the
/// append-only `agent_events.jsonl`, like the worktree events.
class AgentRunStore {
  AgentRunStore({
    String runsFileName = 'agent_runs.json',
    String eventsFileName = 'agent_events.jsonl',
    String? directoryPath,
  }) : _runsFileName = runsFileName,
       _eventsFileName = eventsFileName,
       _directoryPath = directoryPath;

  final String _runsFileName;
  final String _eventsFileName;

  /// Overrides the storage directory (used in tests). When null, the app
  /// support directory is used.
  final String? _directoryPath;

  Future<String> _path(String fileName) async {
    final dir = _directoryPath ?? (await getApplicationSupportDirectory()).path;
    return p.join(dir, fileName);
  }

  /// Every saved run. Never throws; a missing or unreadable file is empty.
  Future<List<AgentRun>> loadRuns() async {
    try {
      final file = File(await _path(_runsFileName));
      if (!await file.exists()) return [];
      final json = jsonDecode(await file.readAsString());
      final runs = json is Map<String, dynamic> ? json['runs'] : null;
      if (runs is! List) return [];
      final result = <AgentRun>[];
      for (final run in runs.whereType<Map<String, dynamic>>()) {
        try {
          result.add(AgentRun.fromJson(run));
        } catch (e) {
          debugPrint('AgentRunStore: skipping malformed run: $e');
        }
      }
      return result;
    } catch (e) {
      debugPrint('AgentRunStore.loadRuns failed: $e');
      return [];
    }
  }

  /// Replaces the saved runs. Written to a temporary file first and renamed,
  /// so a crash mid-write keeps the previous file.
  Future<void> saveRuns(List<AgentRun> runs) async {
    try {
      final path = await _path(_runsFileName);
      final file = File(path);
      await file.parent.create(recursive: true);
      final tmp = File('$path.tmp');
      await tmp.writeAsString(
        const JsonEncoder.withIndent(
          '  ',
        ).convert({'runs': runs.map((r) => r.toJson()).toList()}),
        flush: true,
      );
      await tmp.rename(path);
    } catch (e) {
      debugPrint('AgentRunStore.saveRuns failed: $e');
    }
  }

  /// Appends one timeline event. Never throws.
  Future<void> appendEvent(AgentEvent event) async {
    try {
      final file = File(await _path(_eventsFileName));
      await file.parent.create(recursive: true);
      await file.writeAsString(
        '${jsonEncode(event.toJson())}\n',
        mode: FileMode.append,
        flush: true,
      );
    } catch (e) {
      debugPrint('AgentRunStore.appendEvent failed: $e');
    }
  }

  /// Every event in write order. Malformed lines are skipped.
  Future<List<AgentEvent>> loadEvents() async {
    try {
      final file = File(await _path(_eventsFileName));
      if (!await file.exists()) return [];
      final events = <AgentEvent>[];
      for (final line in await file.readAsLines()) {
        final trimmed = line.trim();
        if (trimmed.isEmpty) continue;
        try {
          events.add(
            AgentEvent.fromJson(jsonDecode(trimmed) as Map<String, dynamic>),
          );
        } catch (e) {
          debugPrint('AgentRunStore: skipping malformed event: $e');
        }
      }
      return events;
    } catch (e) {
      debugPrint('AgentRunStore.loadEvents failed: $e');
      return [];
    }
  }

  /// Rewrites the event log with only [events] (after old runs are pruned).
  Future<void> replaceEvents(List<AgentEvent> events) async {
    try {
      final path = await _path(_eventsFileName);
      final tmp = File('$path.tmp');
      await tmp.parent.create(recursive: true);
      await tmp.writeAsString(
        events.map((e) => '${jsonEncode(e.toJson())}\n').join(),
        flush: true,
      );
      await tmp.rename(path);
    } catch (e) {
      debugPrint('AgentRunStore.replaceEvents failed: $e');
    }
  }
}
