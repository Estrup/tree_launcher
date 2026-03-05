# Remote Flutter Web Client for Terminal Streaming + Worktree/Session Management

## Problem
The main TreeLauncher app has an embedded HTTP+WebSocket server (`RemoteControlService`) that currently serves a hand-written xterm.js web page for remote Copilot terminal access. We want to replace this with a proper Flutter Web/PWA app that:
1. Streams terminal output using the `xterm` Dart package
2. Can **create worktrees** remotely (select repo, pick base branch, name the worktree)
3. Can **create Copilot sessions** remotely (select a worktree, optionally provide an initial prompt)

The app is served directly by the main app's embedded webserver (same-origin, no discovery needed).

## Approach
1. **Expand the server API** — add REST endpoints for repos, worktrees, branches, and session creation
2. **Create a new Flutter Web project** as a sibling in the monorepo (`../remote/`)
3. The Flutter Web app connects to same-origin HTTP/WebSocket endpoints
4. Replace the current `assets/remote/` xterm.js files with the built Flutter Web output
5. Update `RemoteControlService` to serve Flutter Web build + new API routes

## Architecture

```
tree_launcher/
├── main/          ← existing macOS desktop app (host)
│   ├── lib/
│   │   └── services/remote_control_service.dart  ← serves Flutter Web + REST API
│   └── assets/remote/   ← Flutter Web build output
└── remote/        ← NEW Flutter Web app (client)
    ├── lib/
    │   ├── main.dart
    │   ├── services/
    │   │   ├── api_service.dart               ← HTTP client for all REST endpoints
    │   │   └── terminal_connection.dart        ← WebSocket terminal streaming
    │   ├── models/                             ← shared DTOs (repo, worktree, session)
    │   ├── screens/
    │   │   ├── home_screen.dart                ← repo selector + worktree grid
    │   │   ├── terminal_screen.dart            ← full-screen terminal view
    │   │   └── create_worktree_screen.dart     ← worktree creation form
    │   └── theme/                              ← Tokyo Night theme constants
    └── web/
        └── index.html
```

**REST API (expanded):**
```
GET  /api/repos                              → list all repos [{name, path}]
GET  /api/repos/{repoPath}/worktrees         → list worktrees [{path, branch, name, isMain, commitHash}]
GET  /api/repos/{repoPath}/branches          → list branches [string]
POST /api/repos/{repoPath}/worktrees         → create worktree {name, baseBranch?, newBranch?} → {path}
GET  /api/sessions                           → list copilot sessions (existing)
POST /api/sessions                           → create copilot session {repoPath, workingDirectory, worktreeName, prompt?} → {id, name, ...}
```

**WebSocket (unchanged):**
```
WS   /ws/{sessionId}                         → bidirectional terminal streaming
```

## Todos

### 1. Expand RemoteControlService REST API
Add new endpoints to `remote_control_service.dart`:
- `GET /api/repos` — delegates to `RepoProvider.repos`, returns JSON list of `{name, path}`
- `GET /api/repos/:encodedPath/worktrees` — calls `GitService.getWorktrees(path)`, returns JSON worktree list
- `GET /api/repos/:encodedPath/branches` — calls `GitService.listBranches(path)`, returns JSON string list
- `POST /api/repos/:encodedPath/worktrees` — parses JSON body `{name, baseBranch?, newBranch?}`, calls `RepoProvider.addWorktree()`, returns created worktree path
- `POST /api/sessions` — parses JSON body `{repoPath, workingDirectory, worktreeName, prompt?}`, calls `CopilotProvider.createSession()`, returns created session JSON
- The service needs access to `RepoProvider` and `GitService` (currently only has `CopilotProvider`)

### 2. Create the Flutter Web project (`remote/`)
- `flutter create --platforms=web remote` in `tree_launcher/`
- Add `xterm` dependency (same local fork `path: ../xterm.dart`)
- Add `http` package for REST calls
- No `flutter_pty` needed — PTY lives on the host

### 3. Build API service and models
- `ApiService` class: stateless HTTP client for all REST endpoints (repos, worktrees, branches, sessions)
- Model classes: `RemoteRepo`, `RemoteWorktree`, `RemoteSession` (lightweight DTOs matching the API responses)
- `TerminalConnection` class: manages WebSocket lifecycle for a single session (connect, stream data into `Terminal`, send input, auto-reconnect)

### 4. Build the remote UI
- **Home screen**: Repo selector dropdown → worktree grid showing branch/name/commit
- **Worktree creation**: Form with name field, base branch picker, new branch toggle — calls `POST /api/repos/:path/worktrees`
- **Session creation**: Button on worktree card → optional prompt input → calls `POST /api/sessions` → navigates to terminal
- **Terminal screen**: Full-screen `TerminalView` with session selector dropdown and connection status indicator
- **Session list**: Shows existing Copilot sessions, tap to connect terminal
- Tokyo Night theme (reuse color constants from main app)
- PWA manifest for installability

### 5. Build Flutter Web app and integrate into main app assets
- Build with `flutter build web --release` in `remote/`
- Copy build output into `main/assets/remote/` (replacing old xterm.js files)
- Create a `build_remote.sh` script to automate: build → copy → done

### 6. Update RemoteControlService to serve Flutter Web build
- Replace hardcoded 4-file asset serving with generic static file serving from `assets/remote/` build output
- Serve `index.html` for the root path and any unknown non-API/WS paths (SPA fallback)
- Serve Flutter's `main.dart.js`, `flutter.js`, `assets/` etc. with correct MIME types
- Keep `/api/*` and `/ws/*` routes unchanged

### 7. Remove old xterm.js assets and clean up
- Delete old `index.html`, `xterm.min.js`, `xterm.min.css`, `addon-fit.min.js` from `assets/remote/`
- Update `pubspec.yaml` asset declarations for the new Flutter Web build output structure
- Remove the old `_loadAssets()` cache logic, replace with serving from filesystem or asset bundle

## Key Decisions
- **Same-origin serving**: Flutter Web app is hosted by the same embedded server, so all API calls are relative paths — no CORS, no discovery
- **repoPath encoding**: Repo paths contain `/` so they'll be URL-encoded in API routes (e.g., `/api/repos/base64(path)/worktrees`)
- **xterm Dart package on Flutter Web**: Canvas-based rendering — functional and consistent with the main app
- **PWA**: Web manifest enables "install to home screen" on mobile devices
- **Stateless remote client**: No local state persistence needed — everything is fetched from the server

## Notes
- The `xterm` local fork at `../xterm.dart` is used by both apps — identical terminal rendering
- `RemoteControlService` currently only receives `CopilotProvider` — it will also need `RepoProvider` and `GitService` for the new endpoints
- Flutter Web build output is ~2-5MB; serving from embedded assets is fine
- The build script should be idempotent and fast for iterative development
