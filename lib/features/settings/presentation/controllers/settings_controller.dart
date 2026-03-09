import 'package:flutter/foundation.dart';

import 'package:tree_launcher/core/design_system/app_theme.dart';
import 'package:tree_launcher/features/settings/data/app_settings_store.dart';
import 'package:tree_launcher/features/settings/domain/app_settings.dart';
import 'package:tree_launcher/services/config_service.dart';

class SettingsController extends ChangeNotifier {
  SettingsController({AppSettingsStore? store, ConfigService? configService})
    : _store = store ?? AppSettingsStore(configService: configService);

  final AppSettingsStore _store;
  AppSettings _settings = AppSettings();

  AppSettings get settings => _settings;
  String get openAiApiKey => _settings.openAiApiKey ?? '';

  Future<void> loadSettings() async {
    _settings = await _store.load();
    AppColors.setTheme(_settings.themeName);
    notifyListeners();
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
    AppColors.setTheme(name);
    _settings = _settings.copyWith(themeName: name);
    await _store.save(_settings);
    notifyListeners();
  }

  Future<void> updateOpenAiApiKey(String apiKey) async {
    final normalizedApiKey = apiKey.trim();
    _settings = _settings.copyWith(
      openAiApiKey: normalizedApiKey,
      clearOpenAiApiKey: normalizedApiKey.isEmpty,
    );
    await _store.save(_settings);
    notifyListeners();
  }

  Future<void> updateOpenAiTranscriptionModel(String model) async {
    _settings = _settings.copyWith(openAiTranscriptionModel: model);
    await _store.save(_settings);
    notifyListeners();
  }

  Future<void> updateOpenAiResponseModel(String model) async {
    _settings = _settings.copyWith(openAiResponseModel: model);
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

  Future<void> updateCopilotButtonMode(CopilotButtonMode mode) async {
    _settings = _settings.copyWith(copilotButtonMode: mode);
    await _store.save(_settings);
    notifyListeners();
  }

  Future<void> updateCopilotAttentionSoundEnabled(bool enabled) async {
    _settings = _settings.copyWith(copilotAttentionSoundEnabled: enabled);
    await _store.save(_settings);
    notifyListeners();
  }

  Future<void> updateCopilotAttentionSound(CopilotAttentionSound sound) async {
    _settings = _settings.copyWith(copilotAttentionSound: sound);
    await _store.save(_settings);
    notifyListeners();
  }

  Future<void> updateRemoteControlEnabled(bool enabled) async {
    _settings = _settings.copyWith(remoteControlEnabled: enabled);
    await _store.save(_settings);
    notifyListeners();
  }

  Future<void> updateRemoteControlPort(int port) async {
    _settings = _settings.copyWith(remoteControlPort: port);
    await _store.save(_settings);
    notifyListeners();
  }

  Future<void> updateRemoteControlBindAddress(String address) async {
    _settings = _settings.copyWith(remoteControlBindAddress: address);
    await _store.save(_settings);
    notifyListeners();
  }

  Future<void> updateOpenAiTtsModel(String model) async {
    _settings = _settings.copyWith(openAiTtsModel: model);
    await _store.save(_settings);
    notifyListeners();
  }

  Future<void> updateOpenAiTtsVoice(TtsVoice voice) async {
    _settings = _settings.copyWith(openAiTtsVoice: voice);
    await _store.save(_settings);
    notifyListeners();
  }
}
