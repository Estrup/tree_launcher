import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

import 'package:tree_launcher/core/database/app_database.dart';
import 'package:tree_launcher/core/database/legacy_importer.dart';

/// The `issue_cache` rows of one [source] ('jira' or 'github'): an issue's
/// JSON and when it was fetched, by key. Shared by the Jira and GitHub issue
/// caches, which parse the JSON into their own models.
class IssueCacheTable {
  IssueCacheTable(this._db, this.source);

  final AppDatabase _db;
  final String source;

  Future<IssueCacheRow?> read(String key) =>
      (_db.select(_db.issueCache)
            ..where((t) => t.source.equals(source) & t.key.equals(key)))
          .getSingleOrNull();

  Future<List<IssueCacheRow>> readAll() =>
      (_db.select(_db.issueCache)..where((t) => t.source.equals(source))).get();

  Future<void> write(String key, String payload, DateTime fetchedAt) => _db
      .into(_db.issueCache)
      .insertOnConflictUpdate(
        IssueCacheCompanion.insert(
          source: source,
          key: key,
          payload: payload,
          fetchedAt: fetchedAt,
        ),
      );

  /// Deletes every row whose key is not in [liveKeys].
  Future<void> prune(Set<String> liveKeys) => (_db.delete(
    _db.issueCache,
  )..where((t) => t.source.equals(source) & t.key.isNotIn(liveKeys))).go();
}

/// Merges a pre-database issue cache file (`{key: {issue, fetchedAt}}`) into
/// [source]'s rows, keeping whichever copy of an issue was fetched last.
/// Entries that [parse] rejects are skipped, as the file caches skipped them
/// on read.
class IssueCacheLegacyImport implements LegacyImport {
  IssueCacheLegacyImport(
    this._db, {
    required this.fileName,
    required this.source,
    required this.parse,
  });

  final AppDatabase _db;

  @override
  final String fileName;
  final String source;
  final Object Function(Map<String, dynamic> json) parse;

  @override
  Future<void> merge(String content) async {
    if (content.trim().isEmpty) return;
    final entries = jsonDecode(content) as Map<String, dynamic>;
    final table = IssueCacheTable(_db, source);
    final existing = {
      for (final row in await table.readAll()) row.key: row.fetchedAt,
    };
    for (final MapEntry(:key, :value) in entries.entries) {
      if (value is! Map<String, dynamic>) continue;
      final issue = value['issue'];
      final fetchedAt = DateTime.tryParse(value['fetchedAt'] as String? ?? '');
      if (issue is! Map<String, dynamic> || fetchedAt == null) continue;
      try {
        parse(issue);
      } catch (e) {
        debugPrint('$fileName: skipping $key: $e');
        continue;
      }
      final have = existing[key];
      if (have != null && have.isAfter(fetchedAt)) continue;
      await table.write(key, jsonEncode(issue), fetchedAt);
    }
  }
}
