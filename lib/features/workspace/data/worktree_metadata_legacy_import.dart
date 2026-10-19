import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:tree_launcher/core/storage/config_file.dart';
import 'package:tree_launcher/features/workspace/data/worktree_metadata_store.dart';
import 'package:tree_launcher/features/workspace/domain/worktree_metadata.dart';

/// The keys of a repo entry in `config.json` that held per-worktree metadata
/// (each keyed by worktree path) before it moved into the database.
const legacyWorktreeMetadataKeys = {
  'jiraIssues',
  'githubIssues',
  'baseBranches',
  'prAuthors',
  'kickoffPrompts',
  'hiddenWorktrees',
  'snoozedWorktrees',
  'claudeSessions',
  'claudeSessionPrompts',
  'claudeSessionStarts',
};

/// Moves the per-worktree metadata out of `config.json` into the
/// `worktree_metadata` table, once: rows for the worktrees that still exist
/// (the rest is stale), then the keys are dropped from the file. When the
/// import fails the file is left alone, and it is tried again at the next
/// start; `RepoConfigStore` keeps the keys in the file until then.
class WorktreeMetadataLegacyImport {
  WorktreeMetadataLegacyImport({
    required ConfigFile configFile,
    required WorktreeMetadataStore store,
    bool Function(String path)? exists,
  }) : _configFile = configFile,
       _store = store,
       _exists = exists ?? ((path) => Directory(path).existsSync());

  final ConfigFile _configFile;
  final WorktreeMetadataStore _store;
  final bool Function(String path) _exists;

  Future<void> run() async {
    try {
      final repos = (await _configFile.read())['repos'];
      if (repos is! List) return;
      final entries = [
        for (final repo in repos.whereType<Map<String, dynamic>>())
          ...legacyWorktreeMetadata(repo),
      ];
      final hasKeys = repos.whereType<Map<String, dynamic>>().any(
        (repo) => repo.keys.any(legacyWorktreeMetadataKeys.contains),
      );
      if (!hasKeys) return;
      final kept = entries.where((m) => _exists(m.path)).toList();
      await _store.importLegacy(kept);
      await _configFile.update((config) {
        for (final repo in (config['repos'] as List? ?? const [])
            .whereType<Map<String, dynamic>>()) {
          repo.removeWhere((key, _) => legacyWorktreeMetadataKeys.contains(key));
        }
      });
      debugPrint(
        'Moved ${kept.length} worktrees\' metadata into the database '
        '(dropped ${entries.length - kept.length} whose worktree is gone)',
      );
    } catch (e) {
      debugPrint('Moving worktree metadata into the database failed: $e');
    }
  }
}

/// The per-worktree metadata in [repo], a repo entry of `config.json` from
/// before the database, one entry per worktree path.
@visibleForTesting
List<WorktreeMetadata> legacyWorktreeMetadata(Map<String, dynamic> repo) {
  final repoPath = repo['path'];
  if (repoPath is! String) return const [];

  Map<String, T> byPath<T>(String key) => {
    for (final MapEntry(:key, :value)
        in (repo[key] as Map<String, dynamic>? ?? const {}).entries)
      if (value is T) key: value,
  };
  Set<String> paths(String key) =>
      (repo[key] as List<dynamic>? ?? const []).whereType<String>().toSet();

  final jira = byPath<String>('jiraIssues');
  final github = byPath<int>('githubIssues');
  final bases = byPath<String>('baseBranches');
  final authors = byPath<String>('prAuthors');
  final kickoffs = byPath<String>('kickoffPrompts');
  final hidden = paths('hiddenWorktrees');
  final snoozed = paths('snoozedWorktrees');
  final sessions = [
    ...{...(repo['claudeSessions'] as List<dynamic>? ?? const []).whereType<String>()},
  ];
  final sessionPrompts = byPath<String>('claudeSessionPrompts');
  final sessionStarts = byPath<String>('claudeSessionStarts');

  // Sessions first, in the order they were remembered, so the sidebar keeps
  // ordering the ones without a start time the same way.
  final all = {
    ...sessions,
    ...jira.keys,
    ...github.keys,
    ...bases.keys,
    ...authors.keys,
    ...kickoffs.keys,
    ...hidden,
    ...snoozed,
  };
  return [
    for (final path in all)
      WorktreeMetadata(
        path: path,
        repoPath: repoPath,
        baseBranch: bases[path],
        jiraIssue: jira[path],
        githubIssue: github[path],
        prAuthor: authors[path],
        kickoffPromptPath: kickoffs[path],
        hidden: hidden.contains(path),
        snoozed: snoozed.contains(path),
        session: sessions.contains(path)
            ? RememberedSession(
                promptId: sessionPrompts[path],
                startedAt: DateTime.tryParse(sessionStarts[path] ?? ''),
              )
            : null,
      ),
  ];
}
