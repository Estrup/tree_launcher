import 'package:flutter/foundation.dart';

import 'package:tree_launcher/core/database/ui_state_store.dart';
import 'package:tree_launcher/core/storage/config_file.dart';
import 'package:tree_launcher/features/jira/data/jira_tag_store.dart';
import 'package:tree_launcher/features/settings/data/app_settings_store.dart';
import 'package:tree_launcher/features/settings/domain/app_settings.dart';
import 'package:tree_launcher/features/workspace/data/repo_config_store.dart';

/// Moves what `config.json` kept that is data rather than configuration into
/// the database, once: the local tags into the [JiraTagStore]; the
/// remembered choices (the Claude model, effort and prompt, the last repo,
/// each repo's last base branch, fixVersion, milestone and agent folder)
/// into the [UiStateStore]. What the database already has wins. The keys
/// are then dropped from the file; when the import fails they stay, the
/// stores keep using them, and it is tried again at the next start.
class ConfigStateImport {
  ConfigStateImport({
    required ConfigFile configFile,
    required JiraTagStore tagStore,
    required UiStateStore uiState,
  }) : _file = configFile,
       _tags = tagStore,
       _uiState = uiState;

  final ConfigFile _file;
  final JiraTagStore _tags;
  final UiStateStore _uiState;

  static const _lastSelectedKey = 'lastSelectedRepoPath';

  static bool _isMovedSetting(Object? key) =>
      AppSettingsStore.rememberedKeys.contains(key) ||
      AppSettingsStore.tagKeys.contains(key);

  Future<void> run() async {
    try {
      final config = await _file.read();
      final settings = Map<String, dynamic>.from(
        config['settings'] as Map? ?? const {},
      );
      final repos = (config['repos'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .toList();
      final pending =
          settings.keys.any(_isMovedSetting) ||
          config.containsKey(_lastSelectedKey) ||
          repos.any((r) => r.keys.any(RepoConfigStore.rememberedKeys.contains));
      if (!pending) return;

      if (settings.keys.any(AppSettingsStore.tagKeys.contains) &&
          await _tags.isEmpty) {
        final parsed = AppSettings.fromJson(settings);
        await _tags.save(parsed.jiraTags, parsed.jiraTagsByIssue);
      }
      await _uiState.writeIfAbsent(UiStateStore.appScope, {
        for (final key in AppSettingsStore.rememberedKeys) key: settings[key],
        _lastSelectedKey: config[_lastSelectedKey],
      });
      for (final repo in repos) {
        final path = repo['path'];
        if (path is! String) continue;
        await _uiState.writeIfAbsent(UiStateStore.repoScope(path), {
          for (final key in RepoConfigStore.rememberedKeys) key: repo[key],
        });
      }

      await _file.update((config) {
        final settings = config['settings'];
        if (settings is Map) settings.removeWhere((k, _) => _isMovedSetting(k));
        config.remove(_lastSelectedKey);
        for (final repo in (config['repos'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()) {
          repo.removeWhere(
            (key, _) => RepoConfigStore.rememberedKeys.contains(key),
          );
        }
      });
      debugPrint('Moved the tags and remembered choices out of config.json');
    } catch (e) {
      debugPrint('Moving tags and remembered choices failed: $e');
    }
  }
}
