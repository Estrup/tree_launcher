import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../models/repo_config.dart';
import '../models/app_settings.dart';

class ConfigService {
  static const _configFileName = 'config.json';
  Future<String> get _configPath async {
    final appSupport = await getApplicationSupportDirectory();
    return p.join(appSupport.path, _configFileName);
  }

  Future<String> getConfigPath() => _configPath;

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

  Future<List<RepoConfig>> loadRepos() async {
    final config = await _readConfig();
    final repos = config['repos'] as List<dynamic>? ?? [];
    return repos
        .map((r) => RepoConfig.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveRepos(List<RepoConfig> repos) async {
    final config = await _readConfig();
    config['repos'] = repos.map((r) => r.toJson()).toList();
    await _writeConfig(config);
  }

  Future<AppSettings> loadSettings() async {
    final config = await _readConfig();
    final raw = config['settings'] ?? {};
    final settings = Map<String, dynamic>.from(raw as Map);
    return AppSettings.fromJson(settings);
  }

  Future<void> saveSettings(AppSettings settings) async {
    final config = await _readConfig();
    config['settings'] = settings.toJson();
    await _writeConfig(config);
  }
}
