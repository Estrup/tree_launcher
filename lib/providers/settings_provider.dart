import 'package:flutter/foundation.dart';
import '../models/app_settings.dart';
import '../services/config_service.dart';
import '../theme/app_theme.dart';

class SettingsProvider extends ChangeNotifier {
  final ConfigService _configService;
  AppSettings _settings = AppSettings();

  SettingsProvider({required ConfigService configService})
      : _configService = configService;

  AppSettings get settings => _settings;

  Future<void> loadSettings() async {
    _settings = await _configService.loadSettings();
    AppColors.setTheme(_settings.themeName);
    notifyListeners();
  }

  Future<void> updateTerminalApp(TerminalApp app) async {
    _settings = _settings.copyWith(terminalApp: app);
    await _configService.saveSettings(_settings);
    notifyListeners();
  }

  Future<void> updateCustomTerminalCommand(String? command) async {
    _settings = _settings.copyWith(customTerminalCommand: command);
    await _configService.saveSettings(_settings);
    notifyListeners();
  }

  Future<void> updateDefaultBranchPrefix(String? prefix) async {
    _settings = _settings.copyWith(defaultBranchPrefix: prefix);
    await _configService.saveSettings(_settings);
    notifyListeners();
  }

  Future<void> updateTheme(String name) async {
    AppColors.setTheme(name);
    _settings = _settings.copyWith(themeName: name);
    await _configService.saveSettings(_settings);
    notifyListeners();
  }

  Future<void> updateTerminalFontFamily(String? family) async {
    _settings = _settings.copyWith(
      terminalFontFamily: family,
      clearTerminalFontFamily: family == null,
    );
    await _configService.saveSettings(_settings);
    notifyListeners();
  }

  Future<void> updateTerminalFontSize(double? size) async {
    _settings = _settings.copyWith(
      terminalFontSize: size,
      clearTerminalFontSize: size == null,
    );
    await _configService.saveSettings(_settings);
    notifyListeners();
  }
}
