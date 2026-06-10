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

## Agent API

- Server: `lib/features/agent_api/data/agent_api_server.dart` — loopback-only,
  `start({port})` / `stop()` / `restart({port})`, `isRunning` / `port` getters.
- Started at boot from `AppDependencies.startServers()` (`lib/app/dependencies.dart`).
- Routes: `GET /health`, `GET /v1/activity`, `POST /v1/activity`,
  `POST /v1/worktrees`. Adding a capability is a new `_router` line plus a handler.
- Quick check while running: `curl http://127.0.0.1:8765/health`.
