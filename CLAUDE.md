# Tree Launcher

A macOS git-worktree manager (Flutter desktop). It manages worktrees, runs the
app's services in test, tracks per-worktree activity for time logging, and
exposes a small loopback HTTP **agent API** for local AI agents.

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
`lib/app/dependencies.dart`). When set it **wins over the saved config and is
never written back** — so debugging on an alternate port leaves
`config.json` untouched. With no define, the app falls back to the configured
port exactly as normal. While an override is active, the Settings → Agent API
tab shows the port read-only with a note, and Restart keeps it on the override
port.

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

## Storage

Data lives in `~/Library/Application Support/com.treelauncher.treeLauncher/`.

- `tree_launcher.db`: SQLite through drift (`lib/core/database/`), in WAL
  mode on a background isolate, so the live app and a debug instance can share
  it. It holds agent runs and their events, worktree events, manual activity
  posts, the Jira/GitHub issue cache and the `claude_transcripts` index, which
  lets Activity re-read a Claude transcript only after it changes. The stores
  in `features/*/data/` take the one `AppDatabase` that `AppDependencies` owns;
  tests use `AppDatabase.memory()` via `test/test_database.dart`.
- After changing tables in `lib/core/database/tables.dart`, regenerate with
  `dart run build_runner build` (the `.g.dart` file is committed), bump
  `schemaVersion`, add a migration and dump the new schema with
  `dart run drift_dev schema dump lib/core/database/app_database.dart drift_schemas/`.
- `backups/`: a daily `VACUUM INTO` copy of the database; the newest 7 are kept.
- `config.json` still holds settings and repo config (moving in later phases,
  see `docs/structural-review.md`).
- The JSON/JSONL files from before the database are merged into it at startup
  (`AppDependencies.prepareDatabase()`) and renamed to `*.migrated`. A file an
  older build writes again later is merged the same way, without duplicates.

## Agent API

- Server: `lib/features/agent_api/data/agent_api_server.dart` — loopback-only,
  `start({port})` / `stop()` / `restart({port})`, `isRunning` / `port` getters.
- Started at boot from `AppDependencies.startServers()` (`lib/app/dependencies.dart`).
- Routes: `GET /health`, `GET /v1/activity`, `POST /v1/activity`,
  `POST /v1/worktrees`, `GET /v1/jira/issues` (by `fixVersion` and/or
  `status`, with local tags), `GET /v1/jira/tags`,
  `PUT /v1/jira/issues/<key>/tags` (local tags only, never Jira),
  `GET`/`POST /v1/agents`, `GET /v1/agents/<id>`,
  `POST /v1/agents/<id>/status` (agent runs, see below). Adding a
  capability is a new `_router` line plus a handler.
- Agents (`lib/features/agents/`): a run of a Claude session of one kind
  (refine/build/verify/review/docs). Saved prompts carry the kind, and each kind is a
  repo tab. Agents register and report through the API (the tree-launcher
  skill's `scripts/agent.py` helper wraps it). Runs started from a tab get
  `TREE_LAUNCHER_AGENT_ID` and `TREE_LAUNCHER_URL` in their environment.
  Runs are stored in the `agent_runs` table and their timelines in
  `agent_events` (see Storage).
- Quick check while running: `curl http://127.0.0.1:8765/health`.
