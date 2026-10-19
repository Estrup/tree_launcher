import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:tree_launcher/app/use_cases/agent_api_control.dart';
import 'package:tree_launcher/app/use_cases/agent_launcher.dart';
import 'package:tree_launcher/app/use_cases/claude_session_launcher.dart';
import 'package:tree_launcher/app/use_cases/start_claude_session.dart';
import 'package:tree_launcher/core/database/app_database.dart';
import 'package:tree_launcher/core/database/database_backup.dart';
import 'package:tree_launcher/core/database/legacy_importer.dart';
import 'package:tree_launcher/core/platform/launcher_service.dart';
import 'package:tree_launcher/core/storage/config_file.dart';
import 'package:tree_launcher/features/activity/data/activity_legacy_import.dart';
import 'package:tree_launcher/features/activity/data/claude_session_activity.dart';
import 'package:tree_launcher/features/activity/data/manual_post_store.dart';
import 'package:tree_launcher/features/activity/data/worktree_event_store.dart';
import 'package:tree_launcher/features/activity/domain/activity_service.dart';
import 'package:tree_launcher/features/activity/presentation/controllers/activity_controller.dart';
import 'package:tree_launcher/features/agent_api/data/agent_api_server.dart';
import 'package:tree_launcher/features/agents/data/agent_run_legacy_import.dart';
import 'package:tree_launcher/features/agents/data/agent_run_store.dart';
import 'package:tree_launcher/features/agents/presentation/controllers/agents_controller.dart';
import 'package:tree_launcher/features/github_issues/data/github_issue_cache.dart';
import 'package:tree_launcher/features/github_issues/data/github_issues_api_service.dart';
import 'package:tree_launcher/features/github_prs/data/github_api_service.dart';
import 'package:tree_launcher/features/github_prs/data/github_token_store.dart';
import 'package:tree_launcher/features/jira/data/jira_api_service.dart';
import 'package:tree_launcher/features/jira/data/jira_issue_cache.dart';
import 'package:tree_launcher/features/settings/data/app_settings_store.dart';
import 'package:tree_launcher/features/settings/presentation/controllers/settings_controller.dart';
import 'package:tree_launcher/features/terminal/presentation/controllers/terminal_controller.dart';
import 'package:tree_launcher/features/workspace/data/git_service.dart';
import 'package:tree_launcher/features/workspace/data/repo_config_store.dart';
import 'package:tree_launcher/features/workspace/domain/repo_catalog.dart';
import 'package:tree_launcher/features/workspace/presentation/controllers/workspace_controller.dart';

/// The app's composition root: builds the stores, the services and the core
/// controllers once, wires the controllers to each other, and hands them to
/// both the widget tree (see `TreeLauncherApp`) and the agent API, so the UI
/// and the API share one live state.
///
/// Controllers that only a tab uses (Jira, GitHub) are still made by the
/// widget tree, so nothing is fetched for a tab that is never opened.
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
    jiraService = JiraApiService();
    githubPrsService = GithubApiService();
    githubIssuesService = GithubIssuesApiService();
    launcherService = LauncherService();
    // Both stores share the one ConfigFile, so their saves are serialised.
    this.repoConfigStore =
        repoConfigStore ??
        RepoConfigStore(
          configFile: this.configFile,
          tokenStore: KeychainGithubTokenStore(),
        );
    this.appSettingsStore =
        appSettingsStore ?? AppSettingsStore(configFile: this.configFile);

    workspace = WorkspaceController(
      gitService: this.gitService,
      repoConfigStore: this.repoConfigStore,
      eventStore: this.worktreeEventStore,
    );
    settings = SettingsController(store: this.appSettingsStore);
    terminal = TerminalController();
    agents = AgentsController(store: this.agentRunStore);
    activityService = ActivityService(
      eventStore: this.worktreeEventStore,
      claudeActivity: claudeActivity,
      manualPostStore: this.manualPostStore,
    );
    activity = ActivityController(
      eventStore: this.worktreeEventStore,
      manualPostStore: this.manualPostStore,
      service: activityService,
    );
    agentLauncher = AgentLauncher(
      terminal: terminal,
      agents: agents,
      workspace: workspace,
      settings: settings,
      claudeActivity: claudeActivity,
      apiPort: () => agentApiServer.port,
    );
    claudeSessions = ClaudeSessionLauncher(
      terminal: terminal,
      workspace: workspace,
      settings: settings,
      claudeActivity: claudeActivity,
      agents: agentLauncher,
    );
    startClaudeSession = StartClaudeSession(
      settings: settings,
      sessions: claudeSessions,
      agents: agentLauncher,
    );
    // Re-report the terminal colors after a palette switch.
    settings.addListener(terminal.syncColors);
    // Watch the terminal's agent sessions (busy / waiting / exited).
    agents.attachTerminal(terminal);

    agentApiServer = AgentApiServer(
      repos: workspace,
      settings: settings,
      worktreeCreator: workspace,
      jiraTagEditor: settings,
      agentRegistry: agents,
      activity: activityService,
      manualPosts: activity,
      gitService: this.gitService,
      jiraService: jiraService,
    );
    agentApi = AgentApiControl(server: agentApiServer, settings: settings);
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

  /// The Jira REST client, shared by the Jira tab, the issue dialog, issue
  /// titles and the agent API.
  late final JiraApiService jiraService;

  /// GitHub's pull requests, for the PRs tab.
  late final GithubApiService githubPrsService;

  /// GitHub's issues and milestones, for the Issues tab and its dialog.
  late final GithubIssuesApiService githubIssuesService;

  /// Opens terminals, VS Code and custom commands.
  late final LauncherService launcherService;

  /// Repos, the selected repo and its worktrees.
  late final WorkspaceController workspace;

  /// App settings, including the local Jira tags.
  late final SettingsController settings;

  /// The built-in terminal's sessions.
  late final TerminalController terminal;

  /// Agent runs and their timelines.
  late final AgentsController agents;

  /// Builds the Activity timeline, for the Activity tab and the agent API.
  late final ActivityService activityService;

  /// The Activity tab's timeline.
  late final ActivityController activity;

  /// Starts, resumes and stops agents in the built-in terminal.
  late final AgentLauncher agentLauncher;

  /// Starts and resumes plain Claude sessions in the built-in terminal.
  late final ClaudeSessionLauncher claudeSessions;

  /// The Start Claude flow behind the Jira, PR and issue buttons.
  late final StartClaudeSession startClaudeSession;

  /// Loopback-only HTTP API that exposes app data to local AI agents.
  late final AgentApiServer agentApiServer;

  /// Runs [agentApiServer] on the configured port, and changes or restarts
  /// it from Settings.
  late final AgentApiControl agentApi;

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

  /// Loads the saved state into the controllers. Call after
  /// [prepareDatabase] and before [startServers].
  ///
  /// Settings and agent runs are awaited: the first frame needs the theme,
  /// and agents may report as soon as the API is up. Repos load in the
  /// background (that includes listing the selected repo's worktrees); the
  /// API waits for them itself. Never throws.
  Future<void> loadState() async {
    unawaited(
      workspace.loadRepos().catchError(
        (Object e) => debugPrint('Loading repos failed: $e'),
      ),
    );
    try {
      await Future.wait([settings.loadSettings(), agents.load()]);
    } catch (e) {
      debugPrint('Loading settings or agent runs failed: $e');
    }
  }

  /// Starts long-lived background services (currently just the agent API),
  /// on the port from the settings [loadState] loaded. Never throws.
  Future<void> startServers() async {
    await agentApi.start();
    unawaited(_pruneJiraCache());
  }

  /// Drops cached Jira issues no longer referenced by any worktree, keeping the
  /// cache bounded to relevant issues. Runs in the background once the repos
  /// have loaded; never throws.
  Future<void> _pruneJiraCache() async {
    try {
      final repos = await workspace.loadedRepos();
      final liveKeys = repos.expand((r) => r.jiraIssues.values).toSet();
      await jiraIssueCache.prune(liveKeys);
    } catch (e) {
      debugPrint('Jira cache prune failed: $e');
    }
  }

  /// Stops the agent API and the backup timer, waits for pending agent-run
  /// writes, disposes the controllers and closes the database. Call once,
  /// when the app quits.
  Future<void> dispose() async {
    _backupTimer?.cancel();
    await agentApiServer.stop();
    agentApi.dispose();
    await agents.flush();
    settings.removeListener(terminal.syncColors);
    agents.dispose();
    terminal.dispose();
    activity.dispose();
    workspace.dispose();
    settings.dispose();
    await database.close();
  }
}
