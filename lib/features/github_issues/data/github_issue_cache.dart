import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'package:tree_launcher/core/database/app_database.dart';
import 'package:tree_launcher/core/database/issue_cache_table.dart';
import 'package:tree_launcher/core/database/legacy_importer.dart';
import 'package:tree_launcher/features/github_issues/domain/github_issue.dart';

/// Cache of GitHub issues fetched for the issue dialog (`owner/repo#n` ->
/// issue and when it was fetched), in the app database's `issue_cache`
/// table. Works like `JiraIssueCache`: never throws.
class GithubIssueCache {
  GithubIssueCache(AppDatabase db) : _table = IssueCacheTable(db, source);

  /// The `issue_cache.source` of GitHub issues.
  static const source = 'github';

  final IssueCacheTable _table;

  /// Merges the pre-database `github_issue_cache.json` into the cache.
  static LegacyImport legacyImport(AppDatabase db) => IssueCacheLegacyImport(
    db,
    fileName: 'github_issue_cache.json',
    source: source,
    parse: GithubIssue.fromJson,
  );

  /// Returns the cached issue for [ref] (see [githubIssueRef]), or null on a
  /// miss or parse error.
  Future<CachedGithubIssue?> read(String ref) async {
    try {
      final row = await _table.read(ref);
      if (row == null) return null;
      return CachedGithubIssue(
        issue: GithubIssue.fromJson(
          jsonDecode(row.payload) as Map<String, dynamic>,
        ),
        fetchedAt: row.fetchedAt,
      );
    } catch (e) {
      debugPrint('GithubIssueCache read failed for $ref: $e');
      return null;
    }
  }

  /// Stores [issue] under [ref], stamped with [fetchedAt] (default now).
  Future<void> write(
    String ref,
    GithubIssue issue, {
    DateTime? fetchedAt,
  }) async {
    try {
      await _table.write(
        ref,
        jsonEncode(issue.toJson()),
        fetchedAt ?? DateTime.now(),
      );
    } catch (e) {
      debugPrint('GithubIssueCache write failed: $e');
    }
  }
}
