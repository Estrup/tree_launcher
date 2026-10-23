# Architecture

Tree Launcher is a macOS desktop app, written in Flutter, for working across
git worktrees. For each repo it lists the worktrees with what they are for
(Jira issue, GitHub issue or PR, base branch). It starts terminals, VS Code,
custom commands and Claude sessions in them, in a built-in terminal or
outside it. It follows the Claude agent runs working on issues, shows the
repo's Jira issues, GitHub issues and PRs, and keeps an activity timeline for
time logging. A loopback HTTP API ([agent-api.md](agent-api.md)) lets local
agents do much of the same.

## Layout

```
lib/
  main.dart                 calls app/bootstrap.dart
  app/                      the composition root and what spans features
    bootstrap.dart          startup and quit
    dependencies.dart       AppDependencies: builds and wires everything
    app.dart                TreeLauncherApp: providers and MaterialApp
    shell/                  the main window (WorkspaceShell)
    use_cases/              flows across features: starting Claude sessions
                            and agents, running the agent API on its port
    migrations/             one-time moves of old config.json keys
  core/                     shared, and not about any one feature
    database/               AppDatabase (drift), tables, UiStateStore,
                            the issue cache table, legacy import, backups
    storage/                ConfigFile (config.json), the data directory
    design_system/          palettes and theme, notices, form fields,
                            selection controls, window chrome
    platform/               LauncherService, openExternal
    presentation/           IssueListController, the base of the issue tabs
    widgets/                issue list pieces, settings nav item
    errors/                 userMessage
  features/<feature>/
    domain/                 models, pure logic, small interfaces
    data/                   I/O: stores, API clients, git, files
    presentation/
      controllers/          ChangeNotifiers
      widgets/
```

Tests are in `test/`, flat, one file per area. Database migration tests use
the schema dumps in `drift_schemas/`.

## Features

| Feature | What it owns | Main classes |
|---|---|---|
| `workspace` | Repos and their settings, worktrees and their metadata, the sidebar, the worktree list and its buttons, the New Worktree / Start Claude dialog | `WorkspaceController` (with the repo registry, selection, preferences, worktree list and worktree metadata controllers), `GitService`, `RepoConfigStore`, `WorktreeMetadataStore` |
| `terminal` | The built-in terminal (xterm + a PTY), its sessions, Claude CLI commands, handing a session over to Claude Desktop | `TerminalController`, `TerminalSession`, `ClaudeDesktopHandoff`, `buildClaudeCliCommand` |
| `session_panel` | The resizable panel beside a Claude session in the built-in terminal: its worktree's Info (branch, base, upstream, changes, issue, PR, agent run, documents), Files (everything on disk, gitignored entries dimmed, folders read when opened, watched while shown; a filter over a background walk of the worktree) and open file tabs (read-only: Markdown, HTML and PDF in `DocumentView`, images, other text with line numbers; shown again when the file changes) | `SessionPanelController` (width, shown state, tabs, git status and file tree per worktree), `WorktreeFilesController`, `WorktreeFileSystem`, `SessionPanelSplit`, `SessionPanel`, `SessionInfoTab`, `WorktreeFilesTab`, `FileTabView`, `GitService.worktreeStatus` / `ignoredPaths` |
| `agents` | Agent runs of the user's agent types (refine, build, verify, review, docs, support, …), their tabs and cards, the saved prompts that start them | `AgentsController` (the `AgentRegistry`), `AgentRunStore`, `AgentRun`, `AgentType`, `ClaudePrompt` |
| `activity` | The activity timeline: worktree events, the days Claude was active (from its transcripts), manual posts | `ActivityController`, `ActivityService`, `WorktreeEventStore`, `ManualPostStore`, `ClaudeSessionActivity` |
| `jira` | The Jira tab, the issue dialog (wiki-markup rendering, attachments, the comment composer), issue titles, local tags | `JiraIssuesController`, `JiraTitlesController`, `JiraApiService`, `JiraIssueCache`, `JiraTagStore`, `JiraCommentDraftStore` |
| `github_issues` | The Issues tab and issue dialog | `GithubIssuesController`, `GithubIssuesApiService`, `GithubIssueCache` |
| `github_prs` | The PRs tab, review-request notices, the GitHub connection and token | `GithubPrsController`, `GithubApiService`, `githubRequest`, `GithubTokenStore` (Keychain) |
| `settings` | The app settings and the Settings dialog | `SettingsController` (also the `JiraTagEditor` and `AppSettingsSource`), `AppSettingsStore` |
| `documents` | The documents sessions save about their work (Markdown, HTML, PDF), the Documents page and the WKWebView viewer | `DocumentsController` (the `DocumentLibrary`), `DocumentStore`, `SessionDocument`, `DocumentView` |
| `agent_api` | The loopback HTTP API | `AgentApiServer`, `routes/` (see [agent-api.md](agent-api.md)) |

## The window

`WorkspaceShell` (`app/shell/workspace_shell.dart`) shows:

- **The sidebar** (`repo_sidebar.dart` and `sidebar/` in
  `lib/features/workspace/presentation/widgets/`):
  the repos, and under each repo its pages (all but Documents and Activity,
  which are only tabs) with the Claude sessions and agent runs that belong
  to them. It collapses to a rail.
- **The selected repo's pages**, as tabs:
  - Worktrees;
  - PRs and Issues, when GitHub is set up;
  - Jira, when the repo has a project key;
  - one tab per agent type the repo has switched on and has prompts or
    runs of;
  - Documents, when the repo has saved documents;
  - Activity.

  `repo_pages.dart` decides which pages a repo has, and under which page each
  session goes.
- **The terminal panel**. Beside a Claude session it shows the session
  panel (`session_panel`), resized from the handle between them. Dragging
  moves a guide line and the width changes on release, since every
  terminal resize makes the Claude CLI redraw.
- **Settings:** the repo's own settings (`RepoSettingsView`) replace the
  pages. The app's settings open in a dialog (`SettingsDialog`).

## Startup

`bootstrap()` runs these in order:

1. **`AppDependencies()`** builds everything, and **`openLog()`** opens the
   log in `logs/` (and captures `debugPrint` into it).
2. **`prepareDatabase()`** merges the files from before the database into it,
   moves old keys out of `config.json` (`WorktreeMetadataLegacyImport`,
   `ConfigStateImport`), and starts the daily backup.
3. **`loadState()`** loads settings and agent runs, waiting for them so the
   first frame has the theme. The repos and their worktrees load in the
   background.
4. **`startServers()`** starts the agent API and the Jira trigger polling,
   and prunes the Jira cache in the background.
5. **`runApp()`**.

When the app is asked to quit, an `AppLifecycleListener` calls
`AppDependencies.dispose()`: it stops the API, waits for agent-run writes,
disposes the controllers and closes the database.

## State and dependencies

- **`AppDependencies` is the composition root.** It builds:
  - the stores and the database;
  - the services: git, Jira, GitHub, the launcher, Claude activity;
  - the core controllers: workspace, settings, terminal, the session
    panel, agents, activity;
  - the use cases;
  - the agent API and `AgentApiControl`.

  It also wires the controllers to each other: palette changes to the
  terminal, terminal sessions to the agents.
- **`TreeLauncherApp` provides those instances** with `Provider.value` and
  `ChangeNotifierProvider.value`. The tab controllers are made lazily by the
  widget tree instead.
  - PRs, Issues and Jira are made by `ChangeNotifierProxyProvider`s that
    follow the selected repo; Jira titles by a plain provider.
  - Issues and Jira fetch nothing until their tab is opened.
  - PRs load with the repo, because the worktree list shows PR badges.
- **Widgets read what they need** with `context.watch` / `context.read`. They
  don't construct services or reach into `AppDependencies`.
- **Controllers are the one in-memory copy of the state.** The UI and the
  agent API both go through them. The API sees them through small interfaces
  in the features' `domain/`: `RepoCatalog`, `WorktreeCreator`,
  `AppSettingsSource`, `JiraTagEditor`, `AgentRegistry`,
  `ClaudeSessionStarter`, `ManualPostWriter`, `DocumentLibrary`,
  `DocumentSaver`, `IssueBaseBranches`. So an API write shows in the UI at
  once.
- **Flows that span features live in `app/use_cases/`.**
  - `StartClaudeSession` is the flow behind the Jira, PR and issue buttons.
  - `StartClaudeInWorktree` is the same through the agent API
    (`POST /v1/claude/sessions`): it creates or finds the worktree, then
    calls `StartClaudeSession.launch`, which doesn't remember the choices.
  - `AgentLauncher` and `ClaudeSessionLauncher` start, resume and stop
    sessions in the terminal.
  - `SaveDocument` saves a document sent through the agent API
    (`POST /v1/documents`), tied to its agent run or worktree.
  - `AgentApiControl` runs the API on the right port.
  - `JiraIssueBaseBranches` gives the API an issue's default base branch,
    from the repo's fixVersion → branch mapping.
  - `JiraTriggerWatcher` (a `ChangeNotifier`: last and next check,
    `checkNow()`) polls Jira for the repos' `JiraTrigger`s (an issue
    in a fixVersion moves to a status, or is created) on the settings'
    `JiraTriggerSchedule` (on/off, interval, hours), and starts each new
    match through `StartClaudeInWorktree`: in the rule's worktree, else the
    issue's own, else a new one from the version's branch. The issues a rule
    has fired for are kept in the `jira_trigger_issues` table until they
    stop matching.
- **The Jira and GitHub issue controllers extend `IssueListController`**,
  which holds the load cycle (a superseded response is dropped), search and
  selection. Each tab passes its own action to the shared `IssueBulkBar`.

## Data

| What | Where |
|---|---|
| Preferences, and repos with their commands, prompts, GitHub and Jira settings | `config.json`, through `ConfigFile` (one lock, atomic writes, no write when nothing changed), split by `AppSettingsStore` and `RepoConfigStore` |
| Agent runs and events, worktree events, manual posts, issue caches, the Claude transcript index, worktree metadata, local tags, remembered choices, documents' details | `tree_launcher.db` (SQLite through drift, WAL, on a background isolate) |
| Saved documents' files | `documents/<id>.md`, `.html` or `.pdf` in the data directory; rendered Markdown is cached in `documents/.view/` |
| GitHub tokens | The login Keychain (`GithubTokenStore`) |
| The Jira token | `~/.config/jira-pat.txt` |
| Claude Code transcripts | `~/.claude/projects`, read only |
| Kickoff prompts | `<worktree>/.tree-launcher/kickoff-prompt.md` |

The data directory is `~/Library/Application Support/com.treelauncher.treeLauncher/`.
`--dart-define=DATA_DIR=…` points the app at another one. CLAUDE.md (Storage)
has the details: schema changes, migrations and backups.

## Conventions

- **Layers.**
  - `domain/` holds models, pure logic and the interfaces other parts
    depend on.
  - `data/` does the I/O.
  - `presentation/` has the `ChangeNotifier` controllers and the widgets.
- **Dependencies between features.** A feature may use another feature's
  `domain/`. A flow that needs several features' controllers goes in
  `app/use_cases/`. `core/` knows no feature.
- **Notices** go through `showAppSnackBar` (`core/design_system/app_snackbar.dart`).
- **Opening** a URL, file or folder goes through `openExternal`
  (`core/platform/open_external.dart`). Opening another app goes through
  `LauncherService`. Both show a notice when that fails.
- **Errors** shown to the user go through `userMessage()`. Errors a caller
  acts on are typed:
  - `JiraApiException` and `GithubApiException` (with the HTTP status);
  - `WorktreeConflictException`;
  - `RepoNotFoundException`;
  - `AgentNotFoundException`.
- **Tests.**
  - Stores and controllers use an in-memory database (`testDatabase()`).
  - Widget tests use the in-memory stores in `test/fake_config_stores.dart`,
    because database futures don't complete under their fake clock.
  - The app's wiring can be built for a test with
    `AppDependencies(database: testDatabase(), …)`.

## Known gaps

What doesn't follow the conventions yet:

- **`core/` depends on a feature.** `core/platform/launcher_service.dart`
  takes `AppSettings` from `settings`.
- **I/O in `domain/`.** `activity/domain/activity_service.dart` uses
  `activity`'s stores, and `jira/domain/jira_pat.dart` reads a file.
- **Workspace widgets compose other features' widgets directly.** The
  worktree list shows Jira and PR badges and GitHub issue links, and the
  sidebar shows agent sessions.
- **"Jira tags" aren't only for Jira.** The local tags are called Jira tags
  in code, in the database and in the API (`JiraTag`, `/v1/jira/tags`), but
  the Issues tab tags GitHub issues with them too.
- **One very large dialog.** `add_worktree_dialog.dart` is still one large
  form (about 1,200 lines). Its parts share its state, so splitting it
  further needs a form controller first.
- **The session panel's PR row only covers the selected repo.** The PR
  list is the selected repo's, so a Claude session of another repo shows no
  PR there.
- **Formatting.** Many files aren't `dart format`-clean; see CLAUDE.md.

[structural-review.md](structural-review.md) is the review from 2026-10-19
that led to this structure. It describes the code as it was then.
