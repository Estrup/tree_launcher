# Tree Launcher

A macOS git-worktree manager (Flutter desktop). Per repo it lists the
worktrees with what they are for, and starts terminals, VS Code, custom
commands and Claude sessions in them (in a built-in terminal or outside). It
follows the Claude agent runs working on issues, keeps the documents sessions
save about their work (shown in a built-in WKWebView viewer), shows the
repo's Jira issues, GitHub issues and PRs, keeps an activity timeline for
time logging, and exposes a loopback HTTP **agent API** for local AI agents.

- How the code is organised, its conventions and its known gaps:
  `docs/ARCHITECTURE.md`.
- The agent API, route by route: `docs/agent-api.md`.

## Running the app

Standard debug run on macOS:

```bash
flutter run -d macos
```

The entry point is `lib/main.dart`. The only supported device is `macos`.

> Note: `pubspec.yaml` overrides `xterm` to a sibling checkout at `../xterm.dart`.
> That path must exist for `flutter pub get` / `flutter run` to resolve.

### Running a debug instance without colliding with a live one

The agent API binds a loopback port (default **8765**, configurable in
**Settings → Agent API**). If you already have a normal instance running and
launch a second debug build, both try to bind the same port and the second one
fails to start its API.

**Best practice:** start the debug instance with a port override so it doesn't
touch the running instance or the saved config:

```bash
flutter run -d macos --dart-define=AGENT_API_PORT=8766
```

`AGENT_API_PORT` is read once at startup (`agentApiPortOverride` in
`lib/app/use_cases/agent_api_control.dart`, which also owns changing the port
and restarting). When set it **wins over the saved config and is
never written back**, so debugging on an alternate port leaves
`config.json` untouched. With no define, the app falls back to the configured
port exactly as normal. While an override is active, the Settings → Agent API
tab shows the port read-only with a note, and Restart keeps it on the override
port.

To try something on a copy of your data (e.g. a migration) instead of the
real data, also pass `--dart-define=DATA_DIR=/path/to/copy`: the database,
`config.json` and the backups then live there (`appDataDirectory()` in
`lib/core/storage/app_data_directory.dart`). GitHub tokens stay in the
Keychain, shared with the real app.

IDE equivalents are already wired up:
- **VS Code**: pick `tree_launcher (macOS, debug, alt agent-API port 8766)` in
  the Run panel (`.vscode/launch.json`).
- **IntelliJ / Android Studio**: pick `main.dart (alt agent-API port 8766)`
  (`.idea/runConfigurations/`).

## Checks

```bash
flutter analyze            # keep clean before committing
flutter test               # full suite
```

Many files aren't `dart format`-clean. Format the code you write, not whole
existing files: a whole-file format buries the change in reformatting.

## Working in the code

- **New services and core controllers are built in `AppDependencies`**
  (`lib/app/dependencies.dart`, the composition root) and provided in
  `lib/app/app.dart`. Widgets read them with `context.watch` /
  `context.read`; they don't construct services or reach into
  `AppDependencies`.
- **Flows that span features go in `lib/app/use_cases/`**, e.g.
  `StartClaudeSession` and `AgentLauncher`.
- **Controllers hold the state.** Change it through them, never by writing a
  store behind a controller's back. The agent API goes through them too.
- **Shared helpers:**
  - `showAppSnackBar` for notices;
  - `appLog(source, message, level:)` for the app's log (the Log window and
    `logs/`): log what the app does on its own and what goes wrong;
  - `openExternal` (or `LauncherService` for apps) to open things;
  - `userMessage(e)` for an error's text;
  - `IssueListController` / `IssueBulkBar` for issue lists.
- **Tests:**
  - stores and controllers use `testDatabase()` (`test/test_database.dart`);
  - widget tests use the in-memory stores in `test/fake_config_stores.dart`,
    because database futures don't complete under their fake async.

## Storage

Data lives in `~/Library/Application Support/com.treelauncher.treeLauncher/`.

- **`tree_launcher.db`:** SQLite through drift (`lib/core/database/`), in
  WAL mode on a background isolate, so the live app and a debug instance can
  share it.
  - Agent runs (`agent_runs`, `agent_run_issues`) and their timelines
    (`agent_events`).
  - Worktree created/closed events (`worktree_events`) and manual activity
    posts (`manual_posts`).
  - The Jira/GitHub issue cache (`issue_cache`).
  - The `claude_transcripts` index, which lets Activity re-read a Claude
    transcript only after it changes.
  - `worktree_metadata`: per worktree path, its Jira/GitHub issue, base
    branch, PR author, kickoff prompt, hidden/snoozed state and remembered
    Claude session. `WorktreeMetadataController` holds it for all repos in
    memory. Rows of worktrees git no longer lists are dropped when the
    selected repo is refreshed.
  - The local issue tags (`jira_tags`, `jira_issue_tags`).
  - Remembered choices (`ui_state`): the last repo, the Claude
    model/effort/prompt, and a repo's last base branch, fixVersion,
    milestone and agent folder.
  - Saved documents' details (`documents`, `document_issues`).
  - The issues each Jira trigger has fired for (`jira_trigger_issues`).

  The stores in `features/*/data/` take the one `AppDatabase` that
  `AppDependencies` owns.
- **After changing tables** in `lib/core/database/tables.dart`:
  1. regenerate with `dart run build_runner build` (the `.g.dart` file is
     committed);
  2. bump `schemaVersion` and add a step to `AppDatabase.migration`;
  3. dump the new schema with
     `dart run drift_dev schema dump lib/core/database/app_database.dart drift_schemas/`;
  4. regenerate the test helpers with
     `dart run drift_dev schema generate drift_schemas/ test/generated_migrations/`;
  5. add the step to `test/database_migration_test.dart`.
- **`documents/`:** each saved document's one file (`<id>.md`, `.html` or
  `.pdf`), and rendered Markdown in `documents/.view/` (a cache). The
  backups don't include it.
- **`backups/`:** a daily `VACUUM INTO` copy of the database; the newest 7
  are kept.
- **`logs/`:** the app's log, one plain-text file a day (`YYYY-MM-DD.log`,
  kept 14 days): one line per entry, `time LEVEL source message`, a
  message's later lines indented. Sources include `jira-triggers`,
  `agent-api`, `agents`, `claude`, `worktrees`, `jira`, `github` and `app`
  (every `debugPrint`). Read it to see what the app did, e.g.
  `grep jira-triggers logs/$(date +%F).log`. The Log button in the sidebar
  shows it live.
- **`config.json` holds configuration only:** the preferences, and the repos
  with their commands, prompts, GitHub and Jira settings (including the
  fixVersion → branch mapping and the Jira triggers). It only changes when
  configuration does (`ConfigFile` skips writes that change nothing).
  `AppSettingsStore` and `RepoConfigStore` keep the models whole and decide
  per field where it is saved.
- **Older data is moved in once at startup** (`AppDependencies.prepareDatabase()`):
  - The JSON/JSONL files from before the database are merged in and renamed
    to `*.migrated`. A file an older build writes again later is merged the
    same way, without duplicates.
  - Old `config.json` keys are moved out by `WorktreeMetadataLegacyImport`
    (keeping only worktrees that still exist) and `ConfigStateImport`. Until
    that has worked, the stores keep the keys in the file.
- **Secrets aren't in the data directory.** GitHub tokens are in the login
  Keychain (`GithubTokenStore`); the Jira token is in
  `~/.config/jira-pat.txt`.

## Agent API

The reference for every route (fields, responses, status codes, examples) is
`docs/agent-api.md`. When you add or change a route, update it there too:
`test/agent_api_doc_test.dart` fails while a mounted route has no section in
it, or a section has no route.

- **Server:** `lib/features/agent_api/data/agent_api_server.dart`.
  - It is loopback-only, and refuses a foreign `Host` (403) and a non-JSON
    POST/PUT (415).
  - Each area's handlers are in `agent_api/data/routes/` (activity,
    worktrees, Claude sessions, jira, agents, documents).
  - The shared request helpers are in `api_http.dart`: `readJsonObject`,
    `stringField`, `intField`, `missingFields`, `unsupportedFields`,
    `boolQuery`, `serverError`.
  - Routes reject fields they don't take.
- **It is built and started by `AppDependencies`.** It reaches the app's live
  controllers through small domain interfaces (`RepoCatalog`,
  `WorktreeCreator`, `AppSettingsSource`, `JiraTagEditor`, `AgentRegistry`,
  `ClaudeSessionStarter`, `ManualPostWriter`, `DocumentLibrary`,
  `DocumentSaver`), never the saved files, so API writes show in the UI at
  once.
- **Agents** (`lib/features/agents/`): an agent run is a Claude session of
  one kind (refine/build/verify/review/docs).
  - Saved prompts carry the kind, and each kind is a repo tab.
  - Agents register and report through the API; the tree-launcher skill's
    `scripts/agent.py` helper wraps it.
  - Runs started from a tab get `TREE_LAUNCHER_AGENT_ID` and
    `TREE_LAUNCHER_URL` in their environment; every Claude session in the
    built-in terminal gets `TREE_LAUNCHER_URL`.
- **Documents** (`lib/features/documents/`): a session saves its result
  (one self-contained Markdown, HTML or PDF file) with
  `POST /v1/documents`; the skill's `agent.py doc` wraps it.
- **Quick check while running:** `curl http://127.0.0.1:8765/health`.
