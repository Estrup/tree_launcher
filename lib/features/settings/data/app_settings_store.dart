import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:tree_launcher/features/settings/domain/app_settings.dart';
import 'package:tree_launcher/services/config_service.dart';

class AppSettingsStore {
  AppSettingsStore({ConfigService? configService})
    : _configService = configService;

  static const _configFileName = 'config.json';
  final ConfigService? _configService;

  Future<String> get _configPath async {
    final appSupport = await getApplicationSupportDirectory();
    return p.join(appSupport.path, _configFileName);
  }

  Future<Map<String, dynamic>> _readConfig() async {
    final path = await _configPath;
    final file = File(path);
    if (!await file.exists()) {
      return {'repos': [], 'settings': {}};
    }
    final content = await file.readAsString();
    return jsonDecode(content) as Map<String, dynamic>;
  }

  Future<void> _writeConfig(Map<String, dynamic> config) async {
    final path = await _configPath;
    final file = File(path);
    await file.parent.create(recursive: true);
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(config),
    );
  }

  Future<AppSettings> load() async {
    if (_configService != null) {
      return _configService.loadSettings();
    }
    final config = await _readConfig();
    final raw = config['settings'] ?? {};
    return AppSettings.fromJson(Map<String, dynamic>.from(raw as Map));
  }

  Future<void> save(AppSettings settings) async {
    if (_configService != null) {
      await _configService.saveSettings(settings);
      return;
    }
    final config = await _readConfig();
    config['settings'] = settings.toJson();
    await _writeConfig(config);
  }
}
