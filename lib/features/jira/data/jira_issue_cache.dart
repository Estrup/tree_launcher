import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'package:tree_launcher/core/database/app_database.dart';
import 'package:tree_launcher/core/database/issue_cache_table.dart';
import 'package:tree_launcher/core/database/legacy_importer.dart';
import 'package:tree_launcher/features/jira/domain/jira_issue.dart';

/// Cache of fetched Jira issues (issue key -> issue and when it was fetched),
/// in the app database's `issue_cache` table. Never throws: a failure is
/// logged and reads as a miss.
class JiraIssueCache {
  JiraIssueCache(AppDatabase db) : _table = IssueCacheTable(db, source);

  /// The `issue_cache.source` of Jira issues.
  static const source = 'jira';

  final IssueCacheTable _table;

  /// Merges the pre-database `jira_issue_cache.json` into the cache.
  static LegacyImport legacyImport(AppDatabase db) => IssueCacheLegacyImport(
    db,
    fileName: 'jira_issue_cache.json',
    source: source,
    parse: JiraIssue.fromJson,
  );

  /// Returns the cached issue for [key], or null on miss/parse error.
  Future<CachedJiraIssue?> read(String key) async {
    try {
      final row = await _table.read(key);
      if (row == null) return null;
      return CachedJiraIssue(
        issue: JiraIssue.fromJson(
          jsonDecode(row.payload) as Map<String, dynamic>,
        ),
        fetchedAt: row.fetchedAt,
      );
    } catch (e) {
      debugPrint('JiraIssueCache read failed for $key: $e');
      return null;
    }
  }

  /// Returns every cached issue that parses, keyed by issue key. Never throws.
  Future<Map<String, JiraIssue>> readAll() async {
    final result = <String, JiraIssue>{};
    try {
      for (final row in await _table.readAll()) {
        try {
          result[row.key] = JiraIssue.fromJson(
            jsonDecode(row.payload) as Map<String, dynamic>,
          );
        } catch (e) {
          debugPrint('JiraIssueCache parse failed for ${row.key}: $e');
        }
      }
    } catch (e) {
      debugPrint('JiraIssueCache readAll failed: $e');
    }
    return result;
  }

  /// Stores [issue] under its key, stamped with [fetchedAt] (default now).
  Future<void> write(String key, JiraIssue issue, {DateTime? fetchedAt}) async {
    try {
      await _table.write(
        key,
        jsonEncode(issue.toJson()),
        fetchedAt ?? DateTime.now(),
      );
    } catch (e) {
      debugPrint('JiraIssueCache write failed: $e');
    }
  }

  /// Drops every cached key not in [liveKeys]. Never throws.
  Future<void> prune(Set<String> liveKeys) async {
    try {
      await _table.prune(liveKeys);
    } catch (e) {
      debugPrint('JiraIssueCache prune failed: $e');
    }
  }
}
