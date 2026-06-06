import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:tree_launcher/features/activity/domain/worktree_event.dart';

/// Append-only log of [WorktreeEvent]s, stored as JSON-lines in the app support
/// directory (one event per line). Append is O(1) and a torn write only loses
/// the trailing line rather than corrupting the whole history — which is why we
/// don't fold this into the single `config.json` blob.
class WorktreeEventStore {
  WorktreeEventStore({
    String fileName = 'worktree_events.jsonl',
    String? directoryPath,
  }) : _fileName = fileName,
       _directoryPath = directoryPath;

  final String _fileName;

  /// Overrides the storage directory (used in tests). When null, the app
  /// support directory is used.
  final String? _directoryPath;

  Future<String> get _filePath async {
    final dir = _directoryPath ?? (await getApplicationSupportDirectory()).path;
    return p.join(dir, _fileName);
  }

  Future<File> _file() async {
    final file = File(await _filePath);
    await file.parent.create(recursive: true);
    return file;
  }

  /// Appends a single event. Never throws — logging must not block the worktree
  /// create/delete it accompanies.
  Future<void> append(WorktreeEvent event) async {
    try {
      final file = await _file();
      await file.writeAsString(
        '${jsonEncode(event.toJson())}\n',
        mode: FileMode.append,
        flush: true,
      );
    } catch (e) {
      debugPrint('WorktreeEventStore.append failed: $e');
    }
  }

  /// Reads all events in write order. Malformed lines are skipped defensively.
  Future<List<WorktreeEvent>> loadAll() async {
    try {
      final file = File(await _filePath);
      if (!await file.exists()) return [];
      final lines = await file.readAsLines();
      final events = <WorktreeEvent>[];
      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.isEmpty) continue;
        try {
          final json = jsonDecode(trimmed) as Map<String, dynamic>;
          events.add(WorktreeEvent.fromJson(json));
        } catch (e) {
          debugPrint('WorktreeEventStore: skipping malformed line: $e');
        }
      }
      return events;
    } catch (e) {
      debugPrint('WorktreeEventStore.loadAll failed: $e');
      return [];
    }
  }
}
