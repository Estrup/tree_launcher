import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:tree_launcher/core/design_system/window_chrome.dart';
import 'package:tree_launcher/features/jira/domain/jira_tag_editor.dart';
import 'package:tree_launcher/features/settings/data/app_settings_store.dart';
import 'package:tree_launcher/models/app_settings.dart';
import 'package:tree_launcher/models/jira_tag.dart';
import 'package:tree_launcher/theme/app_theme.dart';

class SettingsController extends ChangeNotifier implements JiraTagEditor {
  SettingsController({required AppSettingsStore store}) : _store = store;

  final AppSettingsStore _store;
  AppSettings _settings = AppSettings();

  AppSettings get settings => _settings;

  Future<void> loadSettings() async {
    _settings = await _store.load();
    _applyTheme(_settings.themeName);
    notifyListeners();
  }

  void _applyTheme(String name) {
    AppColors.setTheme(name);
    unawaited(WindowChrome.sync(AppColors.current));
  }

  Future<void> updateTerminalApp(TerminalApp app) async {
    _settings = _settings.copyWith(terminalApp: app);
    await _store.save(_settings);
    notifyListeners();
  }

  Future<void> updateCustomTerminalCommand(String? command) async {
    _settings = _settings.copyWith(customTerminalCommand: command);
    await _store.save(_settings);
    notifyListeners();
  }

  Future<void> updateDefaultBranchPrefix(String? prefix) async {
    _settings = _settings.copyWith(defaultBranchPrefix: prefix);
    await _store.save(_settings);
    notifyListeners();
  }

  Future<void> updateTheme(String name) async {
    _applyTheme(name);
    _settings = _settings.copyWith(themeName: name);
    await _store.save(_settings);
    notifyListeners();
  }

  Future<void> updateTerminalFontFamily(String? family) async {
    _settings = _settings.copyWith(
      terminalFontFamily: family,
      clearTerminalFontFamily: family == null,
    );
    await _store.save(_settings);
    notifyListeners();
  }

  Future<void> updateTerminalFontSize(double? size) async {
    _settings = _settings.copyWith(
      terminalFontSize: size,
      clearTerminalFontSize: size == null,
    );
    await _store.save(_settings);
    notifyListeners();
  }

  Future<void> updateShowHiddenWorktrees(bool value) async {
    _settings = _settings.copyWith(showHiddenWorktrees: value);
    await _store.save(_settings);
    notifyListeners();
  }

  Future<void> updateAgentApiPort(int port) async {
    _settings = _settings.copyWith(agentApiPort: port);
    await _store.save(_settings);
    notifyListeners();
  }

  Future<void> updateClaudeCliArgs(String args) async {
    _settings = _settings.copyWith(claudeCliArgs: args.trim());
    await _store.save(_settings);
    notifyListeners();
  }

  /// Remembers the model and effort picked for a new Claude session, so the
  /// next one starts with the same choice. Null means the CLI's default.
  Future<void> updateClaudeModelAndEffort(String? model, String? effort) async {
    if (model == _settings.claudeModel && effort == _settings.claudeEffort) {
      return;
    }
    _settings = _settings.copyWith(
      claudeModel: model,
      claudeEffort: effort,
      clearClaudeModel: model == null,
      clearClaudeEffort: effort == null,
    );
    await _store.save(_settings);
    notifyListeners();
  }

  /// Remembers the [prompt] and the new-or-existing worktree choice last used
  /// to start a Claude session, to offer them first next time. A null
  /// [useExistingWorktree] keeps the remembered choice.
  Future<void> updateClaudeStartChoices({
    required String prompt,
    bool? useExistingWorktree,
  }) async {
    final useExisting =
        useExistingWorktree ?? _settings.claudeUseExistingWorktree;
    if (prompt == _settings.claudePrompt &&
        useExisting == _settings.claudeUseExistingWorktree) {
      return;
    }
    _settings = _settings.copyWith(
      claudePrompt: prompt,
      claudeUseExistingWorktree: useExisting,
    );
    await _store.save(_settings);
    notifyListeners();
  }

  /// Adds a Jira tag named [name], in the first color no tag has yet.
  Future<void> addJiraTag(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    final tags = _settings.jiraTags;
    final used = tags.map((t) => t.color).toSet();
    final color = jiraTagColors.firstWhere(
      (c) => !used.contains(c),
      orElse: () => jiraTagColors[tags.length % jiraTagColors.length],
    );
    final tag = JiraTag(
      id: DateTime.now().microsecondsSinceEpoch.toRadixString(36),
      name: trimmed,
      color: color,
    );
    await _saveJiraTags([...tags, tag]);
  }

  /// Replaces the tag with [tag]'s id (a rename or new color).
  Future<void> updateJiraTag(JiraTag tag) async {
    await _saveJiraTags([
      for (final t in _settings.jiraTags) t.id == tag.id ? tag : t,
    ]);
  }

  /// Moves the tag at [oldIndex] to [newIndex], counted before the move
  /// as a reorderable list reports it.
  Future<void> reorderJiraTags(int oldIndex, int newIndex) async {
    final tags = List.of(_settings.jiraTags);
    final tag = tags.removeAt(oldIndex);
    tags.insert(newIndex > oldIndex ? newIndex - 1 : newIndex, tag);
    await _saveJiraTags(tags);
  }

  /// Deletes a tag, and takes it off the issues that have it.
  Future<void> removeJiraTag(String id) async {
    _settings = _settings.copyWith(
      jiraTagsByIssue: {
        for (final MapEntry(:key, :value) in _settings.jiraTagsByIssue.entries)
          if (value.any((tagId) => tagId != id))
            key: [
              for (final tagId in value)
                if (tagId != id) tagId,
            ],
      },
    );
    await _saveJiraTags([
      for (final t in _settings.jiraTags)
        if (t.id != id) t,
    ]);
  }

  /// Adds the tag [tagId] to [issueKey], or takes it off when not [tagged].
  Future<void> setJiraTag(String issueKey, String tagId, bool tagged) async {
    final ids = _settings.jiraTagsByIssue[issueKey] ?? const [];
    if (ids.contains(tagId) == tagged) return;
    final updated = tagged
        ? [...ids, tagId]
        : [
            for (final id in ids)
              if (id != tagId) id,
          ];
    final byIssue = Map.of(_settings.jiraTagsByIssue);
    if (updated.isEmpty) {
      byIssue.remove(issueKey);
    } else {
      byIssue[issueKey] = updated;
    }
    _settings = _settings.copyWith(jiraTagsByIssue: byIssue);
    await _store.save(_settings);
    notifyListeners();
  }

  @override
  List<JiraTag> get jiraTags => _settings.jiraTags;

  @override
  List<JiraTag> jiraTagsFor(String issueKey) => _settings.tagsFor(issueKey);

  @override
  Future<void> setJiraTagsFor(String issueKey, List<String> tagIds) async {
    final known = {for (final tag in _settings.jiraTags) tag.id};
    final ids = tagIds.where(known.contains).toSet().toList();
    final byIssue = Map.of(_settings.jiraTagsByIssue);
    if (ids.isEmpty) {
      byIssue.remove(issueKey);
    } else {
      byIssue[issueKey] = ids;
    }
    _settings = _settings.copyWith(jiraTagsByIssue: byIssue);
    await _store.save(_settings);
    notifyListeners();
  }

  Future<void> _saveJiraTags(List<JiraTag> tags) async {
    _settings = _settings.copyWith(jiraTags: tags);
    await _store.save(_settings);
    notifyListeners();
  }

  /// Hides a repo from the sidebar.
  Future<void> hideRepo(String path) async {
    if (_settings.hiddenRepos.contains(path)) return;
    final hidden = List<String>.from(_settings.hiddenRepos)..add(path);
    _settings = _settings.copyWith(hiddenRepos: hidden);
    await _store.save(_settings);
    notifyListeners();
  }

  /// Restores a previously hidden repo to the sidebar.
  Future<void> unhideRepo(String path) async {
    if (!_settings.hiddenRepos.contains(path)) return;
    final hidden = List<String>.from(_settings.hiddenRepos)..remove(path);
    _settings = _settings.copyWith(hiddenRepos: hidden);
    await _store.save(_settings);
    notifyListeners();
  }
}
