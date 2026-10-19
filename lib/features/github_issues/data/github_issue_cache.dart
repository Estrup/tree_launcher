import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:tree_launcher/features/github_issues/domain/github_issue.dart';

/// On-disk cache of GitHub issues fetched for the issue dialog, stored as a
/// single keyed JSON blob in the app support directory (`owner/repo#n` ->
/// `{issue, fetchedAt}`). Works like `JiraIssueCache`: never throws.
class GithubIssueCache {
  GithubIssueCache({
    String fileName = 'github_issue_cache.json',
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
      debugPrint('GithubIssueCache read failed: $e');
      return {};
    }
  }

  Future<void> _writeMap(Map<String, dynamic> map) async {
    try {
      final file = File(await _filePath);
      await file.parent.create(recursive: true);
      await file.writeAsString(const JsonEncoder.withIndent('  ').convert(map));
    } catch (e) {
      debugPrint('GithubIssueCache write failed: $e');
    }
  }

  /// Returns the cached issue for [ref] (see [githubIssueRef]), or null on a
  /// miss or parse error.
  Future<CachedGithubIssue?> read(String ref) async {
    final map = await _readMap();
    final entry = map[ref];
    if (entry is! Map<String, dynamic>) return null;
    final issueJson = entry['issue'];
    if (issueJson is! Map<String, dynamic>) return null;
    final fetchedAt = DateTime.tryParse(entry['fetchedAt'] as String? ?? '');
    if (fetchedAt == null) return null;
    try {
      return CachedGithubIssue(
        issue: GithubIssue.fromJson(issueJson),
        fetchedAt: fetchedAt,
      );
    } catch (e) {
      debugPrint('GithubIssueCache parse failed for $ref: $e');
      return null;
    }
  }

  /// Stores [issue] under [ref], stamped with [fetchedAt] (default now).
  Future<void> write(
    String ref,
    GithubIssue issue, {
    DateTime? fetchedAt,
  }) async {
    final map = await _readMap();
    map[ref] = {
      'issue': issue.toJson(),
      'fetchedAt': (fetchedAt ?? DateTime.now()).toIso8601String(),
    };
    await _writeMap(map);
  }
}
