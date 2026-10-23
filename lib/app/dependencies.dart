import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import 'package:tree_launcher/app/migrations/config_state_import.dart';
import 'package:tree_launcher/app/use_cases/agent_api_control.dart';
import 'package:tree_launcher/app/use_cases/agent_launcher.dart';
import 'package:tree_launcher/app/use_cases/claude_session_launcher.dart';
import 'package:tree_launcher/app/use_cases/save_document.dart';
import 'package:tree_launcher/app/use_cases/jira_issue_base_branches.dart';
import 'package:tree_launcher/app/use_cases/jira_trigger_watcher.dart';
import 'package:tree_launcher/app/use_cases/start_claude_in_worktree.dart';
import 'package:tree_launcher/app/use_cases/start_claude_session.dart';
import 'package:tree_launcher/core/database/app_database.dart';
import 'package:tree_launcher/core/database/database_backup.dart';
import 'package:tree_launcher/core/database/legacy_importer.dart';
import 'package:tree_launcher/core/database/ui_state_store.dart';
import 'package:tree_launcher/core/logging/app_log.dart';
import 'package:tree_launcher/core/platform/launcher_service.dart';
import 'package:tree_launcher/core/storage/app_data_directory.dart';
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
import 'package:tree_launcher/features/documents/data/document_store.dart';
import 'package:tree_launcher/features/documents/presentation/controllers/documents_controller.dart';
import 'package:tree_launcher/features/github_issues/data/github_issue_cache.dart';
import 'package:tree_launcher/features/github_issues/data/github_issues_api_service.dart';
import 'package:tree_launcher/features/github_prs/data/github_api_service.dart';
import 'package:tree_launcher/features/github_prs/data/github_token_store.dart';
import 'package:tree_launcher/features/jira/data/jira_api_service.dart';
import 'package:tree_launcher/features/jira/data/jira_comment_draft_store.dart';
import 'package:tree_launcher/features/jira/data/jira_issue_cache.dart';
import 'package:tree_launcher/features/jira/data/jira_tag_store.dart';
import 'package:tree_launcher/features/jira/data/jira_trigger_store.dart';
import 'package:tree_launcher/features/settings/data/app_settings_store.dart';
import 'package:tree_launcher/features/session_panel/presentation/controllers/session_panel_controller.dart';
import 'package:tree_launcher/features/settings/presentation/controllers/settings_controller.dart';
import 'package:tree_launcher/features/terminal/presentation/controllers/terminal_controller.dart';
import 'package:tree_launcher/features/workspace/data/git_service.dart';
import 'package:tree_launcher/features/workspace/data/repo_config_store.dart';
import 'package:tree_launcher/features/workspace/data/worktree_metadata_legacy_import.dart';
import 'package:tree_launcher/features/workspace/data/worktree_metadata_store.dart';
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
    DocumentStore? documentStore,
  }) : database = database ?? AppDatabase.open(),
       gitService = gitService ?? GitService(),
       configFile = configFile ?? ConfigFile() {
    this.worktreeEventStore =
        worktreeEventStore ?? WorktreeEventStore(this.database);
    this.manualPostStore = manualPostStore ?? ManualPostStore(this.database);
    this.agentRunStore = agentRunStore ?? AgentRunStore(this.database);
    this.documentStore = documentStore ?? DocumentStore(this.database);
    jiraIssueCache = JiraIssueCache(this.database);
    githubIssueCache = GithubIssueCache(this.database);
    claudeActivity = ClaudeSessionActivity(database: this.database);
    jiraService = JiraApiService();
    githubPrsService = GithubApiService();
    githubIssuesService = GithubIssuesApiService();
    launcherService = LauncherService();
    uiStateStore = UiStateStore(this.database);
    jiraTagStore = JiraTagStore(this.database);
    jiraCommentDrafts = JiraCommentDraftStore(uiStateStore);
    // Both stores share the one ConfigFile, so their saves are serialised.
    this.repoConfigStore =
        repoConfigStore ??
        RepoConfigStore(
          configFile: this.configFile,
          tokenStore: KeychainGithubTokenStore(),
          uiState: uiStateStore,
        );
    this.appSettingsStore =
        appSettingsStore ??
        AppSettingsStore(
          configFile: this.configFile,
          tagStore: jiraTagStore,
          uiState: uiStateStore,
        );

    worktreeMetadataStore = WorktreeMetadataStore(this.database);
    workspace = WorkspaceController(
      gitService: this.gitService,
      repoConfigStore: this.repoConfigStore,
      eventStore: this.worktreeEventStore,
      metadataStore: worktreeMetadataStore,
    );
    settings = SettingsController(store: this.appSettingsStore);
    terminal = TerminalController();
    sessionPanel = SessionPanelController(
      git: this.gitService,
      uiState: uiStateStore,
    );
    agents = AgentsController(store: this.agentRunStore);
    documents = DocumentsController(store: this.documentStore);
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
      apiPort: () => agentApiServer.port,
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

    claudeSessionStarter = StartClaudeInWorktree(
      repos: workspace,
      creator: workspace,
      git: this.gitService,
      metadataFor: workspace.metadataFor,
      start: startClaudeSession,
    );
    jiraTriggers = JiraTriggerWatcher(
      repos: workspace,
      settings: settings,
      jira: jiraService,
      store: JiraTriggerStore(this.database),
      starter: claudeSessionStarter,
      worktreesOf: workspace.metadata.forRepo,
      isRunning: (repoName, issueKey) => agents.runs.any(
        (run) =>
            run.repoName == repoName &&
            run.issueKeys.contains(issueKey) &&
            !run.state.isFinished &&
            agentLauncher.isOpen(run),
      ),
    );
    settings.addListener(jiraTriggers.settingsChanged);

    agentApiServer = AgentApiServer(
      repos: workspace,
      settings: settings,
      worktreeCreator: workspace,
      jiraTagEditor: settings,
      agentRegistry: agents,
      claudeSessions: claudeSessionStarter,
      activity: activityService,
      manualPosts: activity,
      documents: documents,
      documentSaver: SaveDocument(
        repos: workspace,
        agents: agents,
        metadataFor: workspace.metadataFor,
        documents: documents,
        settings: settings,
      ),
      gitService: this.gitService,
      jiraService: jiraService,
      issueBaseBranches: JiraIssueBaseBranches(
        repos: workspace,
        jira: jiraService,
      ),
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
  late final DocumentStore documentStore;
  late final JiraIssueCache jiraIssueCache;

  /// Per-worktree metadata (issue, base branch, hidden, snoozed, remembered
  /// Claude session).
  late final WorktreeMetadataStore worktreeMetadataStore;

  /// Remembered choices (last repo, Claude model, a repo's last base
  /// branch, ...).
  late final UiStateStore uiStateStore;

  /// The local issue tags.
  late final JiraTagStore jiraTagStore;

  /// Unsent Jira comments, kept in [uiStateStore].
  late final JiraCommentDraftStore jiraCommentDrafts;
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

  /// The panel beside a Claude session in the built-in terminal.
  late final SessionPanelController sessionPanel;

  /// Agent runs and their timelines.
  late final AgentsController agents;

  /// The documents sessions have saved.
  late final DocumentsController documents;

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

  /// Starts Claude in a new or an existing worktree in one go, for the agent
  /// API and the Jira triggers.
  late final StartClaudeInWorktree claudeSessionStarter;

  /// Polls Jira for the repos' triggers, on the settings' schedule, and
  /// starts their sessions.
  late final JiraTriggerWatcher jiraTriggers;

  /// Loopback-only HTTP API that exposes app data to local AI agents.
  late final AgentApiServer agentApiServer;

  /// Runs [agentApiServer] on the configured port, and changes or restarts
  /// it from Settings.
  late final AgentApiControl agentApi;

  Timer? _backupTimer;

  /// The app's log, once [openLog] has opened the one in the data directory.
  AppLog get log => AppLog.current;

  /// Opens the log in the data directory's `logs/` folder, so everything
  /// after (the `debugPrint`s too) is written there. Call first.
  Future<void> openLog() async {
    final log = AppLog(
      directory: p.join(await appDataDirectory(), 'logs'),
      echo: kDebugMode,
    );
    AppLog.current = log;
    log.captureDebugPrint();
    await log.open();
    appLog(
      'app',
      'Tree Launcher started, data in ${p.dirname(log.directory!)}',
    );
  }

  /// Merges the files from before the database into it (renaming each to
  /// `*.migrated`) and moves the per-worktree metadata, local tags and
  /// remembered choices out of `config.json`, then starts the daily backup. Call before the controllers load. Guarded
  /// so a failure never blocks app startup.
  Future<void> prepareDatabase() async {
    try {
      final dir = await appDataDirectory();
      if (dataDirectoryOverride.isNotEmpty) {
        debugPrint('Using the data in $dir (DATA_DIR)');
      }
      await LegacyImporter(database, dir, [
        AgentRunsLegacyImport(database),
        AgentEventsLegacyImport(database),
        WorktreeEventsLegacyImport(database),
        ManualPostsLegacyImport(database),
        JiraIssueCache.legacyImport(database),
        GithubIssueCache.legacyImport(database),
      ]).run();
      await WorktreeMetadataLegacyImport(
        configFile: configFile,
        store: worktreeMetadataStore,
      ).run();
      await ConfigStateImport(
        configFile: configFile,
        tagStore: jiraTagStore,
        uiState: uiStateStore,
      ).run();
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
    unawaited(documents.load());
    unawaited(sessionPanel.load());
    try {
      await Future.wait([settings.loadSettings(), agents.load()]);
    } catch (e) {
      debugPrint('Loading settings or agent runs failed: $e');
    }
  }

  /// Starts long-lived background services: the agent API, on the port from
  /// the settings [loadState] loaded, and the Jira trigger polling. Never
  /// throws.
  Future<void> startServers() async {
    await agentApi.start();
    jiraTriggers.start();
    unawaited(_pruneJiraCache());
  }

  /// Drops cached Jira issues no longer referenced by any worktree, keeping the
  /// cache bounded to relevant issues. Runs in the background once the repos
  /// have loaded; never throws.
  Future<void> _pruneJiraCache() async {
    try {
      await workspace.whenLoaded;
      await jiraIssueCache.prune(workspace.metadata.jiraIssueKeys);
    } catch (e) {
      debugPrint('Jira cache prune failed: $e');
    }
  }

  /// Stops the agent API and the backup timer, waits for pending agent-run
  /// writes, disposes the controllers and closes the database. Call once,
  /// when the app quits.
  Future<void> dispose() async {
    _backupTimer?.cancel();
    jiraTriggers.dispose();
    appLog('app', 'Tree Launcher quit');
    await agentApiServer.stop();
    agentApi.dispose();
    await agents.flush();
    settings.removeListener(terminal.syncColors);
    agents.dispose();
    documents.dispose();
    terminal.dispose();
    sessionPanel.dispose();
    activity.dispose();
    workspace.dispose();
    settings.dispose();
    await database.close();
    await log.flush();
  }
}
