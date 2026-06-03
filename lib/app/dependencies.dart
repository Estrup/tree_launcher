import 'package:tree_launcher/features/copilot/data/sound_service.dart';
import 'package:tree_launcher/features/settings/data/app_settings_store.dart';
import 'package:tree_launcher/features/workspace/data/git_service.dart';
import 'package:tree_launcher/features/workspace/data/repo_config_store.dart';

class AppDependencies {
  AppDependencies({
    GitService? gitService,
    RepoConfigStore? repoConfigStore,
    AppSettingsStore? appSettingsStore,
    SoundService? soundService,
  }) : gitService = gitService ?? GitService(),
       repoConfigStore = repoConfigStore ?? RepoConfigStore(),
       appSettingsStore = appSettingsStore ?? AppSettingsStore(),
       soundService = soundService ?? SoundService();

  final GitService gitService;
  final RepoConfigStore repoConfigStore;
  final AppSettingsStore appSettingsStore;
  final SoundService soundService;
}
