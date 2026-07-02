import 'package:flutter/foundation.dart';

import 'package:tree_launcher/features/activity/data/manual_post_store.dart';
import 'package:tree_launcher/features/activity/data/worktree_event_store.dart';
import 'package:tree_launcher/features/agent_api/data/agent_api_server.dart';
import 'package:tree_launcher/features/copilot/data/sound_service.dart';
import 'package:tree_launcher/features/jira/data/jira_issue_cache.dart';
import 'package:tree_launcher/features/settings/data/app_settings_store.dart';
import 'package:tree_launcher/features/workspace/data/git_service.dart';
import 'package:tree_launcher/features/workspace/data/repo_config_store.dart';

/// Debug-only agent API port override, supplied via
/// `--dart-define=AGENT_API_PORT=NNNN`. Lets `flutter run` bind a non-default
/// port without touching the saved config, so a debug instance doesn't collide
/// with a normally-running one. `0` means "not set" — fall back to the config.
const int agentApiPortOverride = int.fromEnvironment('AGENT_API_PORT');

class AppDependencies {
  AppDependencies({
    GitService? gitService,
    RepoConfigStore? repoConfigStore,
    AppSettingsStore? appSettingsStore,
    SoundService? soundService,
    WorktreeEventStore? worktreeEventStore,
    ManualPostStore? manualPostStore,
    AgentApiServer? agentApiServer,
  }) : gitService = gitService ?? GitService(),
       repoConfigStore = repoConfigStore ?? RepoConfigStore(),
       appSettingsStore = appSettingsStore ?? AppSettingsStore(),
       soundService = soundService ?? SoundService(),
       worktreeEventStore = worktreeEventStore ?? WorktreeEventStore(),
       manualPostStore = manualPostStore ?? ManualPostStore() {
    this.agentApiServer =
        agentApiServer ??
        AgentApiServer(
          repoConfigStore: this.repoConfigStore,
          gitService: this.gitService,
          appSettingsStore: this.appSettingsStore,
          eventStore: this.worktreeEventStore,
          manualPostStore: this.manualPostStore,
        );
  }

  final GitService gitService;
  final RepoConfigStore repoConfigStore;
  final AppSettingsStore appSettingsStore;
  final SoundService soundService;
  final WorktreeEventStore worktreeEventStore;
  final ManualPostStore manualPostStore;

  /// Loopback-only HTTP API that exposes app data to local AI agents.
  late final AgentApiServer agentApiServer;

  /// Starts long-lived background services (currently just the agent API).
  /// Guarded so a failure never blocks app startup.
  Future<void> startServers() async {
    final port = agentApiPortOverride != 0
        ? agentApiPortOverride
        : (await appSettingsStore.load()).agentApiPort;
    await agentApiServer.start(port: port);
    await _pruneJiraCache();
  }

  /// Drops cached Jira issues no longer referenced by any worktree, keeping the
  /// cache bounded to relevant issues. Guarded so a failure never blocks boot.
  Future<void> _pruneJiraCache() async {
    try {
      final repos = await repoConfigStore.load();
      final liveKeys = repos.expand((r) => r.jiraIssues.values).toSet();
      await JiraIssueCache().prune(liveKeys);
    } catch (e) {
      debugPrint('Jira cache prune failed: $e');
    }
  }
}
