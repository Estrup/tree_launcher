import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:tree_launcher/features/jira/domain/jira_issue.dart';

/// On-disk cache of fetched Jira issues, stored as a single keyed JSON blob in
/// the app support directory (issue key -> `{issue, fetchedAt}`). The
/// read-modify-write blob style matches `AppSettingsStore`; the "never throws /
/// debugPrint" defensiveness matches `ManualPostStore`.
class JiraIssueCache {
  JiraIssueCache({
    String fileName = 'jira_issue_cache.json',
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

  Future<Map<String, dynamic>> _readMap() async {
    try {
      final file = File(await _filePath);
      if (!await file.exists()) return {};
      final content = await file.readAsString();
      if (content.trim().isEmpty) return {};
      return jsonDecode(content) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('JiraIssueCache read failed: $e');
      return {};
    }
  }

  Future<void> _writeMap(Map<String, dynamic> map) async {
    try {
      final file = File(await _filePath);
      await file.parent.create(recursive: true);
      await file.writeAsString(
        const JsonEncoder.withIndent('  ').convert(map),
      );
    } catch (e) {
      debugPrint('JiraIssueCache write failed: $e');
    }
  }

  /// Returns the cached issue for [key], or null on miss/parse error.
  Future<CachedJiraIssue?> read(String key) async {
    final map = await _readMap();
    final entry = map[key];
    if (entry is! Map<String, dynamic>) return null;
    final issueJson = entry['issue'];
    if (issueJson is! Map<String, dynamic>) return null;
    final fetchedAt = DateTime.tryParse(entry['fetchedAt'] as String? ?? '');
    if (fetchedAt == null) return null;
    try {
      return CachedJiraIssue(
        issue: JiraIssue.fromJson(issueJson),
        fetchedAt: fetchedAt,
      );
    } catch (e) {
      debugPrint('JiraIssueCache parse failed for $key: $e');
      return null;
    }
  }

  /// Stores [issue] under its key, stamped with [fetchedAt] (default now).
  Future<void> write(String key, JiraIssue issue, {DateTime? fetchedAt}) async {
    final map = await _readMap();
    map[key] = {
      'issue': issue.toJson(),
      'fetchedAt': (fetchedAt ?? DateTime.now()).toIso8601String(),
    };
    await _writeMap(map);
  }

  /// Drops every cached key not in [liveKeys]. Writes back only if something
  /// changed. Never throws.
  Future<void> prune(Set<String> liveKeys) async {
    final map = await _readMap();
    final toRemove = map.keys.where((k) => !liveKeys.contains(k)).toList();
    if (toRemove.isEmpty) return;
    for (final k in toRemove) {
      map.remove(k);
    }
    await _writeMap(map);
  }
}
