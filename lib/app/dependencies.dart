import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:tree_launcher/core/database/app_database.dart';
import 'package:tree_launcher/core/database/database_backup.dart';
import 'package:tree_launcher/core/database/legacy_importer.dart';
import 'package:tree_launcher/core/storage/config_file.dart';
import 'package:tree_launcher/features/activity/data/activity_legacy_import.dart';
import 'package:tree_launcher/features/activity/data/claude_session_activity.dart';
import 'package:tree_launcher/features/activity/data/manual_post_store.dart';
import 'package:tree_launcher/features/activity/data/worktree_event_store.dart';
import 'package:tree_launcher/features/agent_api/data/agent_api_server.dart';
import 'package:tree_launcher/features/agents/data/agent_run_legacy_import.dart';
import 'package:tree_launcher/features/agents/data/agent_run_store.dart';
import 'package:tree_launcher/features/github_issues/data/github_issue_cache.dart';
import 'package:tree_launcher/features/github_prs/data/github_token_store.dart';
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
    AppDatabase? database,
    GitService? gitService,
    ConfigFile? configFile,
    RepoConfigStore? repoConfigStore,
    AppSettingsStore? appSettingsStore,
    WorktreeEventStore? worktreeEventStore,
    ManualPostStore? manualPostStore,
    AgentRunStore? agentRunStore,
    AgentApiServer? agentApiServer,
  }) : database = database ?? AppDatabase.open(),
       gitService = gitService ?? GitService(),
       configFile = configFile ?? ConfigFile() {
    this.worktreeEventStore =
        worktreeEventStore ?? WorktreeEventStore(this.database);
    this.manualPostStore = manualPostStore ?? ManualPostStore(this.database);
    this.agentRunStore = agentRunStore ?? AgentRunStore(this.database);
    jiraIssueCache = JiraIssueCache(this.database);
    githubIssueCache = GithubIssueCache(this.database);
    claudeActivity = ClaudeSessionActivity(database: this.database);
    // Both stores share the one ConfigFile, so their saves are serialised.
    this.repoConfigStore =
        repoConfigStore ??
        RepoConfigStore(
          configFile: this.configFile,
          tokenStore: KeychainGithubTokenStore(),
        );
    this.appSettingsStore =
        appSettingsStore ?? AppSettingsStore(configFile: this.configFile);
    this.agentApiServer =
        agentApiServer ??
        AgentApiServer(
          repoConfigStore: this.repoConfigStore,
          gitService: this.gitService,
          appSettingsStore: this.appSettingsStore,
          eventStore: this.worktreeEventStore,
          claudeActivity: claudeActivity,
          manualPostStore: this.manualPostStore,
        );
  }

  /// The app's SQLite database, shared by the stores and caches below.
  final AppDatabase database;
  final GitService gitService;

  /// The one `config.json` that [repoConfigStore] and [appSettingsStore]
  /// both write.
  final ConfigFile configFile;
  late final RepoConfigStore repoConfigStore;
  late final AppSettingsStore appSettingsStore;
  late final WorktreeEventStore worktreeEventStore;
  late final ManualPostStore manualPostStore;
  late final AgentRunStore agentRunStore;
  late final JiraIssueCache jiraIssueCache;
  late final GithubIssueCache githubIssueCache;

  /// Claude transcript activity, indexed in [database].
  late final ClaudeSessionActivity claudeActivity;

  /// Loopback-only HTTP API that exposes app data to local AI agents.
  late final AgentApiServer agentApiServer;

  Timer? _backupTimer;

  /// Merges the files from before the database into it (renaming each to
  /// `*.migrated`), then starts the daily backup. Call before the controllers
  /// load. Guarded so a failure never blocks app startup.
  Future<void> prepareDatabase() async {
    try {
      final dir = (await getApplicationSupportDirectory()).path;
      await LegacyImporter(database, dir, [
        AgentRunsLegacyImport(database),
        AgentEventsLegacyImport(database),
        WorktreeEventsLegacyImport(database),
        ManualPostsLegacyImport(database),
        JiraIssueCache.legacyImport(database),
        GithubIssueCache.legacyImport(database),
      ]).run();
      _backupTimer ??= DatabaseBackup(
        database,
        p.join(dir, 'backups'),
      ).start();
    } catch (e) {
      debugPrint('Database preparation failed: $e');
    }
  }

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
      await jiraIssueCache.prune(liveKeys);
    } catch (e) {
      debugPrint('Jira cache prune failed: $e');
    }
  }
}
