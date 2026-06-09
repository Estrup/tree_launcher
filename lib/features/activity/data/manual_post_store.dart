import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:tree_launcher/models/manual_post.dart';

/// Append-only log of manually logged activity posts, stored as JSON-lines in
/// the app support directory (one record per line). Append is O(1) and a torn
/// write only loses the trailing line — same rationale as `WorktreeEventStore`,
/// which is why this isn't folded into the single `config.json` blob.
///
/// Two record shapes share the file:
/// - a full post (has an `id`, `timestamp`, …);
/// - a delete tombstone `{"kind": "delete", "id": "…"}`.
///
/// [loadAll] replays the log, applying tombstones, and returns the live posts.
class ManualPostStore {
  ManualPostStore({String fileName = 'manual_posts.jsonl', String? directoryPath})
    : _fileName = fileName,
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

  Future<void> _appendLine(Map<String, dynamic> json) async {
    try {
      final file = await _file();
      await file.writeAsString(
        '${jsonEncode(json)}\n',
        mode: FileMode.append,
        flush: true,
      );
    } catch (e) {
      debugPrint('ManualPostStore append failed: $e');
    }
  }

  /// Appends a single post. Never throws.
  Future<void> add(ManualPost post) => _appendLine(post.toJson());

  /// Appends a delete tombstone for [id]. Never throws.
  Future<void> delete(String id) => _appendLine({'kind': 'delete', 'id': id});

  /// Replays the log and returns the live posts in write order. Malformed lines
  /// are skipped defensively.
  Future<List<ManualPost>> loadAll() async {
    try {
      final file = File(await _filePath);
      if (!await file.exists()) return [];
      final lines = await file.readAsLines();
      final byId = <String, ManualPost>{};
      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.isEmpty) continue;
        try {
          final json = jsonDecode(trimmed) as Map<String, dynamic>;
          if (json['kind'] == 'delete') {
            byId.remove(json['id'] as String?);
            continue;
          }
          final post = ManualPost.fromJson(json);
          if (post.id.isEmpty) continue;
          byId[post.id] = post;
        } catch (e) {
          debugPrint('ManualPostStore: skipping malformed line: $e');
        }
      }
      return byId.values.toList();
    } catch (e) {
      debugPrint('ManualPostStore.loadAll failed: $e');
      return [];
    }
  }
}
