import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:tree_launcher/core/design_system/app_theme.dart';
import 'package:tree_launcher/core/design_system/window_chrome.dart';
import 'package:tree_launcher/features/settings/data/app_settings_store.dart';
import 'package:tree_launcher/features/settings/domain/app_settings.dart';
import 'package:tree_launcher/services/config_service.dart';

class SettingsController extends ChangeNotifier {
  SettingsController({AppSettingsStore? store, ConfigService? configService})
    : _store = store ?? AppSettingsStore(configService: configService);

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
