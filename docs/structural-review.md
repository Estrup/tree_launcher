# Structural review — 2026-10-19

A review of how Tree Launcher is put together now that it has grown well past
"launch worktrees": an agent API, agent runs, Jira, GitHub issues and PRs,
activity/time logging and an embedded terminal. ~31,700 lines in `lib/`
(134 files), 41 test files, `flutter analyze` clean.

## Summary

1. **Persistence is the weakest part.** `config.json` is a 62 KB blob holding
   four different kinds of data. Three separate copies of read-modify-write
   code write it, with no lock and no atomic write. 10 of `RepoConfig`'s 23
   fields are per-worktree maps keyed by path that are only partly cleaned up:
   365 of the 389 `baseBranches` entries point at worktrees that no longer
   exist. **Recommendation: move to SQLite through drift** (§2), with tokens
   in the Keychain.
2. **The UI and the agent API don't share one source of truth.** API handlers
   read and write the files directly; controllers hold their own in-memory
   copies. Only three write paths go through controllers, and those are wired
   in late through setters.
3. **The feature-first migration is half done, and runs backwards.** The real
   code still lives in `lib/models`, `lib/services`, `lib/theme` and
   `lib/screens`. The `features/**` and `core/**` files with the same names are
   one-line re-exports pointing back at them. `RepoProvider` (a typedef for
   `WorkspaceController`) is still used 68 times.
4. **A handful of god files.** `repo_settings_view.dart` (2,675 lines),
   `worktree_actions.dart` (1,921), `add_worktree_dialog.dart` (1,575),
   `agent_api_server.dart` (1,115), `WorkspaceController` (855). App-level
   flows ("start a Claude session", "start an agent") live inside dialogs and
   in helper objects created on each call.
5. **Jira and GitHub are implemented twice.** The issue tabs, controllers,
   dialogs and caches are near-copies. There is no shared abstraction for
   running processes, HTTP errors or user notifications.

**Worth keeping as they are:**
- The analyzer is clean, and no data layer imports presentation code.
- `AgentRunStore` does atomic temp-file-and-rename writes, serialised through a
  save chain.
- The JSONL logs are append-only with tolerant parsing.
- The stores and the API have tests.
- The `AGENT_API_PORT` override for debug instances.

---

## 1. What is stored today

Location: `~/Library/Application Support/com.treelauncher.treeLauncher/`

| File | Size | How it is written | Problems |
|---|---|---|---|
| `config.json` | 62 KB | Whole file rewritten on every change, by 3 copies of read-modify-write code (`ConfigService`, `RepoConfigStore`, `AppSettingsStore`) | Lost updates, torn reads, no atomic write, stale entries, plaintext GitHub token |
| `agent_runs.json` | 124 KB, 72 runs | Whole file rewritten on every status POST (temp file + rename) | Runs are only pruned once archived (2 of 72 are) |
| `agent_events.jsonl` | 165 KB, 987 lines | Appended | Read in full at every startup; only compacted when a run is deleted |
| `worktree_events.jsonl` | 262 KB, 828 lines | Appended | Read in full on every `GET /v1/activity` and every Activity load; no retention |
| `manual_posts.jsonl` | 15 lines | Appended, with delete tombstones | Tombstones pile up |
| `jira_issue_cache.json` | 6 KB | Read-modify-write, from 3 separate instances | A failed parse returns `{}`, so the next write wipes the cache. The startup prune evicts issues opened from the Jira tab |
| `github_issue_cache.json` | 4 KB | Same, and one write is not awaited (`github_issue_dialog.dart:145`) | Never pruned |
| `kanban.db` | 180 KB | — | Orphaned. Left over from the Kanban feature that was removed in `cfdb3fa` (March) |
| `config.backup-2026-10-08-pre-simplify.json` | 58 KB | By hand | Contains a GitHub token |

**Claude activity has no store at all.** For every worktree path ever seen,
`ClaudeSessionActivity` (`claude_session_activity.dart:70-106`) reads each
transcript in `~/.claude/projects` fully into memory to regex-match
timestamps. That folder is currently 2.2 GB across 1,253 files. The scan runs
one path at a time, uncached, on every `GET /v1/activity` and every Activity
tab load. The date filter is applied afterwards (`agent_api_server.dart:206`),
so `filter=today` costs the same as `filter=all`.

### Four kinds of data mixed together in `config.json`

| Kind | Fields | Character |
|---|---|---|
| **Preferences** | terminalApp, customTerminalCommand, defaultBranchPrefix, themeName, terminal fonts, claudeCliArgs, agentApiPort, showHiddenWorktrees; per repo: name/path, vscodeConfigs, customCommands, prompts (`copilotPrompts`), predefinedIssues, useNestedWorktrees, githubConfig, jiraProjectKey | Set by the user, rarely change |
| **Remembered choices** | lastSelectedRepoPath, claudeModel/Effort/Prompt, claudeUseExistingWorktree, hiddenRepos; per repo: lastBaseBranch, jiraFixVersionId, githubMilestoneNumber, agentWorkingDirectory | UI state, changes constantly |
| **Growing domain data** | Per worktree path: jiraIssues, githubIssues, baseBranches, prAuthors, kickoffPrompts, hiddenWorktrees, snoozedWorktrees, claudeSessions, claudeSessionPrompts, claudeSessionStarts. Also jiraTags + jiraTagsByIssue (37 issues) | Grows with every worktree and issue |
| **Secrets** | `githubConfig.token` (2 repos) | Should not be in a plain file |

### Concrete defects

- **Lost updates between sections.** `RepoConfigStore` and `AppSettingsStore`
  each re-read the whole file, replace their own section and write it back.
  `WorkspaceController` writes `lastSelectedRepoPath` without awaiting
  (`workspace_controller.dart:155`). If two saves interleave at their `await`
  points, the later write puts back a stale copy of the other section.
  - A second running instance (a debug build using `AGENT_API_PORT`) writes the
    same `config.json`, which makes this worse.
- **Torn reads become API 500s.** `writeAsString` truncates the file and then
  writes it. API handlers read `config.json` on 8 code paths
  (`agent_api_server.dart` 173, 283, 398, 522, 734, 982, 1073, 1098). A read
  that lands mid-write makes `jsonDecode` throw.
- **Lost updates in memory.** `_addWorktreeForRepo`
  (`workspace_controller.dart:335-380`) passes one snapshot through several
  awaited `replaceRepo` calls, and `RepoConfig` equality compares the path
  only. Two parallel `POST /v1/worktrees` calls (a spin-up-issue batch) can
  therefore drop each other's `jiraIssues`, `baseBranches` or `kickoffPrompts`
  entries.
- **Write amplification.**
  - Deleting a worktree causes up to 6 sequential full rewrites
    (`workspace_controller.dart:666-729`); the prune causes up to 5.
  - Every Jira tag toggle rewrites 62 KB. It also rebuilds the whole
    `MaterialApp`, because `app.dart:131` watches `SettingsController`.
- **Orphans.**
  - au2office: 365 of 389 `baseBranches` entries are stale.
  - au2web: all 24 `baseBranches` and all 4 `kickoffPrompts` entries are stale.
  - The delete flow cleans up 7 of the 10 per-worktree maps but not
    `baseBranches` or `kickoffPrompts`. A worktree removed outside the app
    gets no cleanup at all.

---

## 2. Recommendation: SQLite through drift

**Why SQLite.**
- The data is relational: repo → worktree → issue link, session and events;
  run → events.
- It is queried by time range.
- It is written concurrently by the UI and the API.
- SQLite gives one file, real transactions, and WAL mode, which is safe across
  processes (so a debug instance next to a live one is fine).
- You can inspect it with the `sqlite3` CLI, and `VACUUM INTO` makes backups.
- This repo has already shipped SQLite once: `sqlite3` for the Kanban board
  (`89100c0`). It was removed together with that feature in `cfdb3fa`, not
  because of SQLite.

**Why drift on top of it.**
- Typed tables and versioned migrations, with generated tests that verify the
  schema.
- **`watch()` queries re-emit when a table changes.** Once the API and the UI
  write through the same database, the UI sees API writes without setters,
  callbacks or polling. That fixes problem 2 from the summary structurally.
- It can run the database on a background isolate, so heavy queries don't
  stall the UI.
- The cost is `build_runner` code generation, which is new to this repo.
  - Without code generation the fallback is raw `sqlite3` plus hand-written
    repositories and your own change stream. That is more code and less safety.
  - I would not use Hive or Isar (forked or unmaintained, not relational). Nor
    would I keep JSON with a lock: that fixes the races but none of the rest.

**What stays outside the database.**
- **GitHub tokens → macOS Keychain**, via `flutter_secure_storage` or the
  `security` CLI. This matches how the Jira PAT already lives outside the
  config.
- **Kickoff prompt files stay as files.** Only their path moves into the
  `worktrees` table.
- **`~/.claude` stays Claude's.** The app stores only a derived index of it.
- **Which worktrees exist stays git's job** (`git worktree list`). The table
  holds only the app's metadata about them, and it is reconciled on refresh:
  rows for paths git no longer lists are deleted. That puts an end to orphans.

**Design rule:** use real columns for what you filter, sort or join on, and a
JSON column for nested, display-only detail (agent stages, links, launch
configs).

### Schema sketch

Shown as SQL for readability; in drift it is Dart table classes. Column details
for the existing models get settled during implementation.

```sql
-- Preferences and remembered choices
CREATE TABLE settings (key TEXT PRIMARY KEY, value TEXT NOT NULL);        -- JSON value
CREATE TABLE ui_state (scope TEXT NOT NULL, key TEXT NOT NULL, value TEXT NOT NULL,
                       PRIMARY KEY (scope, key));                          -- scope: 'app' or a repo id

-- Repos and their configuration
CREATE TABLE repos (
  id INTEGER PRIMARY KEY, path TEXT NOT NULL UNIQUE, name TEXT NOT NULL,
  sort_order INTEGER NOT NULL, hidden INTEGER NOT NULL DEFAULT 0,
  use_nested_worktrees INTEGER NOT NULL DEFAULT 0, jira_project_key TEXT);
CREATE TABLE repo_github (
  repo_id INTEGER PRIMARY KEY REFERENCES repos ON DELETE CASCADE,
  owner TEXT NOT NULL, name TEXT NOT NULL,
  refresh_minutes INTEGER NOT NULL DEFAULT 5, issues_enabled INTEGER NOT NULL DEFAULT 0);
                                                                           -- token: Keychain
CREATE TABLE launch_configs   (id INTEGER PRIMARY KEY, repo_id INTEGER NOT NULL REFERENCES repos ON DELETE CASCADE,
                               sort_order INTEGER NOT NULL, data TEXT NOT NULL);
CREATE TABLE custom_commands  (... same shape ...);
CREATE TABLE prompts          (id INTEGER PRIMARY KEY, repo_id INTEGER NOT NULL REFERENCES repos ON DELETE CASCADE,
                               name TEXT NOT NULL, kind TEXT, body TEXT NOT NULL, sort_order INTEGER NOT NULL);
CREATE TABLE predefined_issues(... same shape ...);

-- One row per worktree the app knows something about; replaces the 10 path-keyed fields
CREATE TABLE worktrees (
  id INTEGER PRIMARY KEY, repo_id INTEGER NOT NULL REFERENCES repos ON DELETE CASCADE,
  path TEXT NOT NULL UNIQUE, base_branch TEXT,
  jira_issue_key TEXT, github_issue_number INTEGER, pr_author TEXT,
  kickoff_prompt_path TEXT,
  hidden INTEGER NOT NULL DEFAULT 0, snoozed INTEGER NOT NULL DEFAULT 0);
CREATE TABLE claude_sessions (
  worktree_id INTEGER PRIMARY KEY REFERENCES worktrees ON DELETE CASCADE,
  prompt TEXT, started_at TEXT NOT NULL);

-- Local tags (Jira today; the GitHub tab already borrows the Jira ones)
CREATE TABLE tags       (id TEXT PRIMARY KEY, name TEXT NOT NULL, color TEXT, sort_order INTEGER NOT NULL);
CREATE TABLE issue_tags (issue_ref TEXT NOT NULL, tag_id TEXT NOT NULL REFERENCES tags ON DELETE CASCADE,
                         PRIMARY KEY (issue_ref, tag_id));                 -- 'jira:AU2-1234', 'gh:owner/repo#12'

-- Logs (keyed by path, not FK: history outlives the worktree)
CREATE TABLE worktree_events (id INTEGER PRIMARY KEY, at TEXT NOT NULL, type TEXT NOT NULL,
  repo_path TEXT, worktree_path TEXT NOT NULL, branch TEXT, jira_issue TEXT, data TEXT);
CREATE INDEX worktree_events_at ON worktree_events(at);
CREATE TABLE manual_posts (id TEXT PRIMARY KEY, at TEXT NOT NULL, issue_key TEXT, data TEXT NOT NULL);

-- Agents
CREATE TABLE agent_runs (
  id TEXT PRIMARY KEY, kind TEXT NOT NULL, repo TEXT, title TEXT, state TEXT NOT NULL,
  worktree_path TEXT, branch TEXT, pr_number INTEGER, archived INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL, updated_at TEXT NOT NULL,
  detail TEXT NOT NULL);                                                   -- stages, links, result (JSON)
CREATE TABLE agent_run_issues (run_id TEXT NOT NULL REFERENCES agent_runs ON DELETE CASCADE,
                               issue_key TEXT NOT NULL, PRIMARY KEY (run_id, issue_key));
CREATE TABLE agent_events (id INTEGER PRIMARY KEY,
  run_id TEXT NOT NULL REFERENCES agent_runs ON DELETE CASCADE,
  at TEXT NOT NULL, stage TEXT, level TEXT NOT NULL, message TEXT NOT NULL);
CREATE INDEX agent_events_run ON agent_events(run_id, id);

-- Caches
CREATE TABLE issue_cache (source TEXT NOT NULL, key TEXT NOT NULL, payload TEXT NOT NULL,
                          fetched_at TEXT NOT NULL, PRIMARY KEY (source, key));
CREATE TABLE claude_transcripts (path TEXT PRIMARY KEY, project_dir TEXT NOT NULL,
  size INTEGER NOT NULL, mtime TEXT NOT NULL, active_days TEXT NOT NULL); -- re-scan only changed files
```

### Migration in phases

Each phase ships on its own, and the original files are kept, renamed to
`*.migrated`, for one release.

| Phase | Scope | Why this order |
|---|---|---|
| **0 — Before the database** | One `ConfigFile` class with a mutex and temp-file + rename writes, replacing the 3 copies; GitHub token → Keychain; delete `kanban.db` and the backup file once the token has moved | Fixes the races and the plaintext token now. About 50 lines, and easy to delete later |
| **1 — Foundation + logs** | `AppDatabase` in `lib/core/database/`: WAL, background isolate, a daily `VACUUM INTO` backup (keep 7). Move `AgentRunStore`, `WorktreeEventStore`, `ManualPostStore`, `JiraIssueCache` and `GithubIssueCache` onto it **behind their current class APIs**, each with a one-time importer. Add the `claude_transcripts` index | Lowest risk: the store interfaces and their tests already exist. Biggest performance win (Activity, agent status writes, startup) |
| **2 — Worktrees** | A `WorktreeMetadataRepository`. `WorkspaceController` loses its 7 metadata maps and their relay plumbing. Deleting a worktree becomes one `DELETE`; refresh reconciles against git; the import drops orphans | Removes most of `config.json`'s growth and the multi-rewrite flows |
| **3 — Config** | Repos and their child config, tags, settings and `ui_state` move to the database. `config.json` is retired; add an Export/Import JSON button in Settings for hand edits. `RepoConfig` and `AppSettings` split per feature | Touches the most UI, so it goes last |
| **4 — Reactive** | Controllers subscribe to `watch()` streams. API handlers call the same repositories and use cases (§4). The `registerX` setters and the 503 "not ready" window go away | The payoff: one source of truth |

**Notes on the migration.**
- **Tests:** `NativeDatabase.memory()` replaces the 9 `_FakeConfigService`
  subclasses and the temp-directory tests. Drift's schema dumps cover the
  migration tests.
- **Docs:** `CLAUDE.md` names `agent_runs.json` and `agent_events.jsonl`; update
  it in phase 1.
- **Debug instances:** with SQLite, the live app and a `flutter run` instance
  can safely share the file. Drift's streams don't cross processes, though, so
  the live UI won't see the debug instance's writes until it reloads. For
  destructive debugging, add a `--dart-define=DATA_DIR=…` next to
  `AGENT_API_PORT`.

---

## 3. Finish the feature-first move (it runs backwards today)

**What's there now.**
- The real code is in the legacy folders, and the feature folders re-export it:
  - `features/workspace/data/git_service.dart` → `services/git_service.dart`
  - `core/design_system/app_theme.dart` → `theme/app_theme.dart`
  - `features/workspace/domain/*` → `models/*`
  - …12 shims in all.
- Typedef aliases are still in use: `RepoProvider` (68 uses), `SettingsProvider`
  (21), `TerminalProvider` (14). `GithubPrsProvider` has no users.
- Placeholders that do nothing:
  - `WorkspaceShell` is just `typedef WorkspaceShell = HomeScreen`.
  - `WorkspaceFlowCoordinator.build` returns its child unchanged.
  - `features/markdown_editor/` is empty.
- Legacy code imports features: `models/repo_config.dart:1` imports
  github_prs/domain, `models/claude_prompt.dart:1` imports agents/domain, and
  `services/git_service.dart:3` imports workspace/domain.

**Recommendation: one mechanical PR, done with `git mv` and no behaviour
change, before the database work, so new code lands in its final place.**

| From | To |
|---|---|
| `models/repo_config.dart`, `worktree.dart`, `custom_command.dart`, `vscode_config.dart`, `claude_prompt.dart` | `features/workspace/domain/` (`ClaudePrompt` → `features/agents/domain/`) |
| `models/jira_tag.dart` | `features/jira/domain/` |
| `models/manual_post.dart`, `predefined_issue.dart` | `features/activity/domain/` |
| `models/terminal_session.dart` (spawns a PTY, so it isn't domain) | `features/terminal/data/` |
| `models/command_style.dart` (imports material) | `features/workspace/presentation/` |
| `models/app_settings.dart` | `features/settings/domain/` |
| `services/git_service.dart` | `features/workspace/data/` |
| `services/launcher_service.dart` | `core/platform/` |
| `services/config_service.dart` | delete (folded into the phase-0 `ConfigFile`) |
| `theme/*` | `core/design_system/` |
| `screens/home_screen.dart` | `app/shell/` |
| `providers/*`, all shims, `WorkspaceFlowCoordinator`, `markdown_editor/` | delete; rename `RepoProvider` → `WorkspaceController` and the others |

**Then fix the code that breaks the layering rules:**
- `activity/domain/activity_service.dart` creates data stores itself (lines
  19-21); inject them instead.
- `jira/domain/jira_pat.dart` does file I/O; move it to `jira/data`.
- `agent_launcher.dart` and `settings_dialog.dart` import
  `app/dependencies.dart`, an upward dependency.
- Presentation code creates `LauncherService()`, the API services and the
  caches directly: `worktree_table.dart:417`, `agent_card.dart:296`,
  `jira_issue_dialog.dart:51`, `github_issue_dialog.dart:64`.

**Ownership.** `RepoConfig` mixes 23 fields from 7 features, and `AppSettings`
mixes 16 fields from 6. Each feature should own its own slice; the database
tables in §2 do that naturally.

**Cross-feature dependencies.** Workspace imports from, and is imported by,
agents, terminal, activity, github_prs, github_issues and jira. The same goes
for agents and terminal, and for settings and jira.
- Rule: a feature may use another feature's **domain** layer.
- One feature's presentation reaching into another's goes through `app/`
  (cross-feature flows and composition) only.

---

## 4. Composition root and an application layer (UI/API parity)

**What's there now.**
- Controllers are created lazily inside one `MultiProvider` (`app.dart:30-128`).
- The API server is started before `runApp`, then handed the controllers
  through 3 late setters (`app.dart:43,54,71`). Until then, those routes answer
  503.
- Handlers read the stores directly, and `POST /v1/activity` writes the
  manual-post file without telling `ActivityController`.
- App flows live in odd places:
  - `AddWorktreeDialog.startClaudeSession` (`add_worktree_dialog.dart:161-239`)
  - helper objects created on each call: `ClaudeSessionLauncher`, `AgentLauncher`
  - the Settings dialog restarts the API server itself (`settings_dialog.dart:1029-1037`).

**Recommendation.**
- **Make `AppDependencies` the composition root.** Build the
  stores/repositories, the services (Jira, GitHub, launcher, process runner) and
  the controllers there, outside the widget tree. Provide them with `.value`,
  and dispose them on exit, which includes stopping the server.
- **Add use cases** in `lib/app/use_cases/`: `CreateWorktree`,
  `StartClaudeSession`, `StartAgentRun`, `LogManualPost`, `SetIssueTags`,
  `LoadActivity`, `RestartAgentApi`.
  - The UI and the API both call them, and API handlers shrink to
    parse → use case → JSON.
  - Combined with drift streams, controllers then only observe.
  - After the database, this is the largest structural improvement.

---

## 5. Agent API

- **Split `agent_api_server.dart`:**
  - `api/server.dart`: start, stop, middleware
  - `api/http.dart`: `readJsonObject`, field validation, `ApiError` → status
    code. Today JSON parsing is copied into 3 handlers and the `field()` closure
    into 4.
  - `api/routes/{activity,worktrees,jira,agents}.dart`
- **Typed errors instead of string matching.**
  - Status codes are picked by matching message text today: 409 if it contains
    "already exists" (line 426), 400 if it starts with "Jira rejected"
    (line 512).
  - 500 responses echo the raw exception.
  - Handling of unknown fields and query flags differs between routes.
- **Security.** There is no Host check, no Content-Type check and no Origin
  check. Any web page open in your browser can send a "simple" `text/plain`
  POST to `127.0.0.1:8765/v1/worktrees`, `/v1/activity` or `/v1/agents`; the
  request goes through even though the page can't read the reply. Add
  middleware that:
  - requires `Host` to be `127.0.0.1:<port>` or `localhost:<port>`, which
    blocks DNS rebinding;
  - requires `Content-Type: application/json` on POST and PUT, which forces a
    CORS preflight that the server never answers.
- **Put the API doc in the repo** (`docs/agent-api.md`, or OpenAPI).
  - The authoritative doc today is `~/.claude/skills/tree-launcher/SKILL.md`,
    outside the repo.
  - The in-repo `.claude/skills/tree-launcher-activity/SKILL.md` covers only
    `/health` and `/v1/activity`.
  - The class doc still calls the server "read-only" (line 35).
- **Activity performance.**
  - Apply the date filter before scanning.
  - Add the transcript index (phase 1).
  - Run `git worktree list` for the repos in parallel.
  - Replace the O(n²) `order.contains` in `activity_service.dart:46`.

---

## 6. Break up the big files

| File | Lines | Split along |
|---|---|---|
| `repo_settings_view.dart` | 2,675 | One file per section (General, VS Code, Commands, Prompts, Issue keys, GitHub, Jira), plus one shared "debounced repo field" helper to replace the 7 copied debounce/resync blocks. Move GitHub URL parsing and the Jira key regex to domain |
| `worktree_actions.dart` | 1,921 | Prompt helpers → domain (also used by the add-worktree dialog and the sidebar); the delete, bulk-delete and Jira-edit flows → an actions/use-case file; each of the ~10 buttons → its own file |
| `add_worktree_dialog.dart` | 1,575 | `startClaudeSession` → a use case; the prompt panel → a widget; form state → a small controller. One ~1,060-line `State` currently serves two modes |
| `repo_sidebar.dart` | 1,414 | Session grouping and sorting (`_RepoTile.build`, 623-690) → a pure function. Each tile watches `TerminalController` and `AgentsController`, so a poll that changes anything rebuilds every tile; use `select` |
| `settings_dialog.dart` | 1,253 | One file per section, following the precedent of `jira_settings_section.dart` |
| `agent_api_server.dart` | 1,115 | See §5 |
| `workspace_controller.dart` | 855 | Shrinks by itself once worktree metadata moves to the database. Drop the second constructor; one preferences update currently fires ~5 notifications |

---

## 7. Shared infrastructure and duplication

- **Processes.** Add `ProcessRunner` and `UrlOpener` abstractions.
  `Process.run('open', …)` appears ad hoc in 7 presentation files, and
  `LauncherService` ignores exit codes. Both changes make this code testable.
- **HTTP.**
  - Give `JiraApiService` a typed `JiraApiException`, like
    `GithubApiException`. That removes 14 copies of
    `e.toString().replaceFirst('Exception: ', '')`.
  - Reuse one `HttpClient` per service. Jira currently creates a new client
    and re-reads the PAT on every request.
  - Inject one instance of each service. `JiraApiService` is constructed in
    4 places.
- **Issue lists.** Add an `IssueListController<T>` base class: the generation
  counter, load/fail/finish, search, selection, and the `syncToRepo`
  microtask, all of which are copied today.
  - Share the row and bulk-bar widgets. The GitHub copies lack the `catch`
    that the Jira ones have.
  - Make one cache, `issue_cache(source, key)` in the database.
  - Make local tags generic, since the GitHub tab already calls
    `jiraTags`/`setJiraTag`.
  - `github_prs_tab.dart` has its own copies of the error banner and
    `_formatLastRefreshed`.
- **Notifications.** Use `showAppSnackBar` everywhere. `worktree_actions`,
  `activity_tab` and `add_repo_dialog` call `ScaffoldMessenger` directly, with
  different durations.
- **Theme.** `AppColors.setTheme` is a global mutable static, and the whole app
  rebuilds on any settings change. Select only the theme name.

---

## 8. Bugs found along the way

- **`GithubPrsController.syncToRepo` compares only the repo path**
  (`github_prs_controller.dart:81`). Editing the selected repo's token, owner,
  repo or refresh interval has no effect until you switch repos.
  (`GithubIssuesController` compares the whole connection and is fine.)
- **The races and torn reads in §1:** lost config sections, 500s from the API,
  and parallel worktree creation dropping metadata.
- **The GitHub bulk bar and `_IssueRow._changeState` have no error handling.**
- **The Jira cache prune is awaited before `runApp`**, which slows startup, and
  it evicts issues opened from the Jira tab.
- **Hide and snooze futures are not awaited** (`WorktreeOptionsButton`, around
  line 1515), and bulk delete throws away the reasons for failures
  (`worktree_actions.dart:272`).

## 9. Housekeeping

- **`docs/ARCHITECTURE.md` is stale.** It describes Kanban and SQLite and says
  nothing about the API, agents, Jira, GitHub or activity. Rewrite it after
  phase 1.
- **Stray files and folders:**
  - a `main/` folder at the repo root that contains only `.gitignore`;
  - `tools/*.py`, which install Codex skills from `tools/skills`, a folder
    emptied in `cfdb3fa`;
  - the empty `features/markdown_editor/`.
- **`pubspec.yaml`:**
  - The description still reads "A new Flutter project."
  - The `xterm` path override needs a sibling checkout. Make it a git
    dependency on `github.com/Estrup/xterm.dart`, pinned to a commit, so a
    fresh clone builds.
- **Tests** are all flat in `test/`; mirror the `lib/` layout. These have no
  tests:
  - github_prs
  - `RepoSettingsView`
  - `WorktreeActions`
  - `LauncherService`
  - `SettingsDialog`
  - `AgentLauncher`
  - `RepoPreferencesController`

---

## Suggested order

1. **Phase 0 safety fixes:** the config write lock with atomic writes, the API
   Host and Content-Type checks, the token → Keychain, and the PR controller
   bug. Small and independent.
2. **The folder move (§3):** mechanical, one PR.
3. **Database phase 1:** the foundation, the logs, agent runs, the caches and
   the transcript index.
4. **Composition root and use cases (§4):** unblocks API/UI parity.
5. **Database phases 2–4:** worktrees, then config, then reactive. `config.json`
   is retired.
6. **Big-file splits, the issue-list base and the shared infrastructure:** do
   these when you are working in those areas anyway.
