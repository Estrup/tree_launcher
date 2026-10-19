import 'package:tree_launcher/core/database/ui_state_store.dart';
import 'package:tree_launcher/core/storage/config_file.dart';
import 'package:tree_launcher/features/jira/data/jira_tag_store.dart';
import 'package:tree_launcher/features/settings/domain/app_settings.dart';

/// The app settings: the preferences in the `settings` section of
/// `config.json`, the local tags in the [JiraTagStore], and the remembered
/// Claude choices ([rememberedKeys]) in the [UiStateStore], so the file only
/// changes when a preference does.
///
/// Keys of the file that `ConfigStateImport` hasn't moved into the database
/// yet stay in it on save, and count where the database has no value.
class AppSettingsStore {
  AppSettingsStore({
    required ConfigFile configFile,
    required JiraTagStore tagStore,
    required UiStateStore uiState,
  }) : _file = configFile,
       _tags = tagStore,
       _uiState = uiState;

  final ConfigFile _file;
  final JiraTagStore _tags;
  final UiStateStore _uiState;

  /// Settings keys that are remembered choices, kept in the [UiStateStore].
  static const rememberedKeys = {
    'claudeModel',
    'claudeEffort',
    'claudePrompt',
    'claudeUseExistingWorktree',
  };

  /// Settings keys of the local tags, kept in the [JiraTagStore].
  static const tagKeys = {'jiraTags', 'jiraTagsByIssue'};

  Future<AppSettings> load() async {
    final config = await _file.read();
    final json = Map<String, dynamic>.from(config['settings'] as Map? ?? {});
    final remembered = await _uiState.read(UiStateStore.appScope);
    final tags = await _tags.load();
    final tagsSaved = tags.tags.isNotEmpty || tags.byIssue.isNotEmpty;
    return AppSettings.fromJson({
      ...json,
      ...remembered,
      if (tagsSaved || !json.containsKey('jiraTags')) ...{
        'jiraTags': [for (final tag in tags.tags) tag.toJson()],
        'jiraTagsByIssue': tags.byIssue,
      },
    });
  }

  Future<void> save(AppSettings settings) => _file.update((config) async {
    final json = settings.toJson();
    final remembered = {
      for (final key in rememberedKeys) key: json.remove(key),
    };
    for (final key in tagKeys) {
      json.remove(key);
    }
    final current = config['settings'];
    if (current is Map) {
      for (final key in [...rememberedKeys, ...tagKeys]) {
        if (current.containsKey(key)) json[key] = current[key];
      }
    }
    config['settings'] = json;
    // Inside the file's lock, so saves land in the order they were made.
    await _tags.save(settings.jiraTags, settings.jiraTagsByIssue);
    await _uiState.write(UiStateStore.appScope, remembered);
  });
}
