import 'package:tree_launcher/features/activity/data/worktree_event_store.dart';
import 'package:tree_launcher/features/agent_api/data/agent_api_server.dart';
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
    WorktreeEventStore? worktreeEventStore,
    AgentApiServer? agentApiServer,
  }) : gitService = gitService ?? GitService(),
       repoConfigStore = repoConfigStore ?? RepoConfigStore(),
       appSettingsStore = appSettingsStore ?? AppSettingsStore(),
       soundService = soundService ?? SoundService(),
       worktreeEventStore = worktreeEventStore ?? WorktreeEventStore() {
    this.agentApiServer =
        agentApiServer ??
        AgentApiServer(
          repoConfigStore: this.repoConfigStore,
          gitService: this.gitService,
          eventStore: this.worktreeEventStore,
        );
  }

  final GitService gitService;
  final RepoConfigStore repoConfigStore;
  final AppSettingsStore appSettingsStore;
  final SoundService soundService;
  final WorktreeEventStore worktreeEventStore;

  /// Loopback-only HTTP API that exposes app data to local AI agents.
  late final AgentApiServer agentApiServer;

  /// Starts long-lived background services (currently just the agent API).
  /// Guarded so a failure never blocks app startup.
  Future<void> startServers() async {
    await agentApiServer.start();
  }
}
