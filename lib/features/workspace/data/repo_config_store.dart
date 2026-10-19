import 'package:flutter/foundation.dart';

import 'package:tree_launcher/core/database/ui_state_store.dart';
import 'package:tree_launcher/core/storage/config_file.dart';
import 'package:tree_launcher/features/github_prs/data/github_token_store.dart';
import 'package:tree_launcher/features/workspace/data/worktree_metadata_legacy_import.dart';
import 'package:tree_launcher/features/workspace/domain/repo_config.dart';

/// The repos: their configuration in the `repos` section of `config.json`,
/// and each repo's remembered choices ([rememberedKeys]) and the repo last
/// selected in the [UiStateStore], so the file only changes when
/// configuration does. Keys of the file that `ConfigStateImport` hasn't
/// moved into the database yet stay in it on save, and count where the
/// database has no value.
///
/// GitHub tokens are not written to the file. They go to the
/// [GithubTokenStore] (the Keychain) and are filled back in on load; the file
/// keeps `"token": ""`, because older builds fail to load a GitHub config
/// without the key. A token found in the file, saved there by an older
/// build, is moved to the store on load. If the store can't be written, the
/// token stays in the file so it isn't lost, and the move is tried again on
/// the next load.
class RepoConfigStore {
  RepoConfigStore({
    required ConfigFile configFile,
    required GithubTokenStore tokenStore,
    required UiStateStore uiState,
  }) : _file = configFile,
       _tokens = tokenStore,
       _uiState = uiState;

  final ConfigFile _file;
  final GithubTokenStore _tokens;
  final UiStateStore _uiState;

  /// Repo keys that are remembered choices, kept in the [UiStateStore].
  static const rememberedKeys = {
    'lastBaseBranch',
    'jiraFixVersionId',
    'githubMilestoneNumber',
    'agentWorkingDirectory',
  };

  static const _lastSelectedKey = 'lastSelectedRepoPath';

  /// The token the store holds per repo path, as far as this instance knows
  /// (`''` = none). Lets loads read the store once per repo, and saves touch
  /// it only for tokens that changed.
  final Map<String, String> _knownTokens = {};

  Future<List<RepoConfig>> load() async {
    final config = await _file.read();
    final repos = <RepoConfig>[];
    for (final json in config['repos'] as List<dynamic>? ?? const []) {
      final entry = json as Map<String, dynamic>;
      final remembered = entry['path'] is String
          ? await _uiState.read(UiStateStore.repoScope(entry['path'] as String))
          : const <String, Object?>{};
      repos.add(RepoConfig.fromJson({...entry, ...remembered}));
    }
    final moved = <String, String>{};
    for (final (i, repo) in repos.indexed) {
      final github = repo.githubConfig;
      if (github == null) continue;
      if (github.token.isNotEmpty) {
        if (await _storeToken(repo.path, github.token)) {
          moved[repo.path] = github.token;
        }
        continue;
      }
      final token = await _readToken(repo.path);
      if (token.isNotEmpty) {
        repos[i] = repo.copyWith(githubConfig: github.copyWith(token: token));
      }
    }
    if (moved.isNotEmpty) await _removeTokensFromFile(moved);
    return repos;
  }

  Future<void> save(List<RepoConfig> repos) => _file.update((config) async {
    // The token store is written inside the file's lock, so saves land in
    // the order they were made.
    final kept = {for (final repo in repos) repo.path};
    final removed = [
      for (final MapEntry(:key, :value) in _knownTokens.entries)
        if (value.isNotEmpty && !kept.contains(key)) key,
    ];
    for (final path in removed) {
      await _storeToken(path, '');
    }
    // Keys from before the database stay in the file until they have been
    // moved (WorktreeMetadataLegacyImport, ConfigStateImport).
    final pendingByPath = {
      for (final entry in (config['repos'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>())
        entry['path']: {
          for (final MapEntry(:key, :value) in entry.entries)
            if (legacyWorktreeMetadataKeys.contains(key) ||
                rememberedKeys.contains(key))
              key: value,
        },
    };
    final json = <Map<String, dynamic>>[];
    for (final repo in repos) {
      final stored = await _storeToken(
        repo.path,
        repo.githubConfig?.token ?? '',
      );
      final entry = _toJson(repo, keepToken: !stored);
      await _uiState.write(UiStateStore.repoScope(repo.path), {
        for (final key in rememberedKeys) key: entry.remove(key),
      });
      json.add({...entry, ...?pendingByPath[repo.path]});
    }
    config['repos'] = json;
    await _uiState.keepRepoScopes(kept);
  });

  Future<String?> loadLastSelectedRepoPath() async =>
      (await _uiState.read(UiStateStore.appScope))[_lastSelectedKey]
          as String? ??
      (await _file.read())[_lastSelectedKey] as String?;

  Future<void> saveLastSelectedRepoPath(String? path) =>
      _uiState.write(UiStateStore.appScope, {_lastSelectedKey: path});

  Future<String> _readToken(String repoPath) async {
    final known = _knownTokens[repoPath];
    if (known != null) return known;
    try {
      final token = await _tokens.read(repoPath) ?? '';
      // A save may have recorded a newer token while this read ran.
      return _knownTokens.putIfAbsent(repoPath, () => token);
    } catch (e) {
      debugPrint('Reading the GitHub token for $repoPath failed: $e');
      return '';
    }
  }

  /// Makes the token store hold [token] for [repoPath] (`''` removes it).
  /// Returns false if the store couldn't be written.
  Future<bool> _storeToken(String repoPath, String token) async {
    final known = _knownTokens[repoPath];
    if (known == token || (known == null && token.isEmpty)) return true;
    try {
      if (token.isEmpty) {
        await _tokens.delete(repoPath);
      } else {
        await _tokens.write(repoPath, token);
      }
      _knownTokens[repoPath] = token;
      return true;
    } catch (e) {
      debugPrint('Saving the GitHub token for $repoPath failed: $e');
      return false;
    }
  }

  /// Drops the moved tokens from the file, unless a save has put a different
  /// one there since.
  Future<void> _removeTokensFromFile(Map<String, String> moved) =>
      _file.update((config) {
        for (final repo in config['repos'] as List<dynamic>? ?? const []) {
          final json = repo as Map<String, dynamic>;
          final github = json['githubConfig'];
          final token = moved[json['path']];
          if (github is Map && token != null && github['token'] == token) {
            github['token'] = '';
          }
        }
      });

  static Map<String, dynamic> _toJson(
    RepoConfig repo, {
    required bool keepToken,
  }) {
    final json = repo.toJson();
    final github = json['githubConfig'] as Map<String, dynamic>?;
    if (github != null && !keepToken) github['token'] = '';
    return json;
  }
}
