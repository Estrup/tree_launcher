import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:tree_launcher/features/workspace/domain/repo_config.dart';
import 'package:tree_launcher/services/config_service.dart';

class RepoConfigStore {
  RepoConfigStore({ConfigService? configService})
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

  Future<List<RepoConfig>> load() async {
    if (_configService != null) {
      return _configService.loadRepos();
    }
    final config = await _readConfig();
    final repos = config['repos'] as List<dynamic>? ?? [];
    return repos
        .map((repo) => RepoConfig.fromJson(repo as Map<String, dynamic>))
        .toList();
  }

  Future<void> save(List<RepoConfig> repos) async {
    if (_configService != null) {
      await _configService.saveRepos(repos);
      return;
    }
    final config = await _readConfig();
    config['repos'] = repos.map((repo) => repo.toJson()).toList();
    await _writeConfig(config);
  }
}
