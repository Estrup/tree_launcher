import 'package:tree_launcher/core/storage/config_file.dart';
import 'package:tree_launcher/features/settings/domain/app_settings.dart';

/// The `settings` section of `config.json`.
class AppSettingsStore {
  AppSettingsStore({required ConfigFile configFile}) : _file = configFile;

  final ConfigFile _file;

  Future<AppSettings> load() async {
    final config = await _file.read();
    final raw = config['settings'] ?? {};
    return AppSettings.fromJson(Map<String, dynamic>.from(raw as Map));
  }

  Future<void> save(AppSettings settings) => _file.update((config) {
    config['settings'] = settings.toJson();
  });
}
