# Architecture

TreeLauncher is a Flutter desktop app organized around a feature-first structure.

## Layout

- `lib/app/`: bootstrap, dependency wiring, app shell, and cross-feature coordinators
- `lib/core/`: shared design-system exports and small cross-cutting utilities
- `lib/features/`: feature-owned domain, data, controllers, and widgets
- `lib/screens/`: top-level screens; currently includes `HomeScreen`
- `lib/providers/`: compatibility aliases that point at the newer feature controllers

## Main Features

- `workspace`: repositories, worktrees, repo preferences, launch actions
- `kanban`: projects, issues, comments, and issue API behavior
- `copilot`: session lifecycle, activity state, and Copilot terminal UX
- `terminal`: embedded terminal sessions and terminal panel state
- `settings`: app settings, persistence, and theme selection
- `voice_commands`: microphone capture, transcription, transcript routing, and overlay UI
- `remote_control`: embedded HTTP/WebSocket server for external control

## Runtime Flow

1. `lib/main.dart` calls `app/bootstrap.dart`.
2. `app/app.dart` builds shared dependencies and registers top-level `Provider` controllers.
3. Coordinators in `lib/app/coordinators/` handle cross-feature workflows such as:
   - repo selection -> kanban refresh
   - settings changes -> remote-control lifecycle
4. Feature widgets read only the controllers they need.

## State and Data

- State management uses `Provider` with `ChangeNotifier`.
- Git and shell integration are local process calls.
- Settings and repo config are stored in JSON config files.
- Kanban data is stored in SQLite.

## Current Boundary Rule

Feature UI should live under `lib/features/<feature>/presentation/widgets/`.
Shared UI should only move into `lib/core/` when it is truly reused across multiple features.
