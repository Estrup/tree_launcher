# Kanban Board — Full SQLite-Backed Implementation

Replace the current dummy-data prototype with a fully functional Kanban board backed by SQLite. Each repo can have multiple projects, each project has issues that can be dragged between status columns, and each issue can have a branch, worktree, and linked copilot sessions.

## User Review Required

> [!IMPORTANT]
> **New dependency**: This adds the [`sqlite3`](https://pub.dev/packages/sqlite3) package which uses dart:ffi bindings and bundles SQLite natively via hooks. No extra native libs package needed — it supports macOS out of the box.

> [!IMPORTANT]
> **Database location**: The SQLite database will be stored alongside the existing `config.json` in the Application Support directory (`~/Library/Application Support/tree_launcher/kanban.db`). This keeps all user data in one place.

> [!WARNING]
> **Migration impact**: This replaces the existing hardcoded "Project 1" tab and all dummy data. After implementation, the UI will start empty — users create projects via the "+" tab.

---

## Proposed Changes

### Phase 1 — Database Layer

#### [MODIFY] [pubspec.yaml](file:///Users/estrup/Projects/tree_launcher/kanban/pubspec.yaml)
Add dependency:
- `sqlite3: ^3.1.6` — Lightweight dart:ffi SQLite bindings with bundled native libs via hooks

#### [NEW] [database_service.dart](file:///Users/estrup/Projects/tree_launcher/kanban/lib/services/database_service.dart)
Singleton service that:
- Opens `kanban.db` in Application Support dir via `sqlite3.open(path)`
- Uses synchronous API (`Database.execute`, `Database.select`)
- Creates 3 tables on first open:

```sql
CREATE TABLE projects (
  id TEXT PRIMARY KEY,
  repo_path TEXT NOT NULL,
  name TEXT NOT NULL,
  is_archived INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL
);

CREATE TABLE issues (
  id TEXT PRIMARY KEY,
  project_id TEXT NOT NULL,
  title TEXT NOT NULL,
  description TEXT,
  status TEXT NOT NULL DEFAULT 'todo',
  tags TEXT,              -- JSON-encoded list of strings
  branch TEXT,
  worktree_path TEXT,
  is_archived INTEGER NOT NULL DEFAULT 0,
  sort_order INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  FOREIGN KEY (project_id) REFERENCES projects(id)
);

CREATE TABLE issue_copilot_sessions (
  id TEXT PRIMARY KEY,
  issue_id TEXT NOT NULL,
  copilot_session_id TEXT NOT NULL,
  created_at TEXT NOT NULL,
  FOREIGN KEY (issue_id) REFERENCES issues(id)
);
```

#### [NEW] [project.dart](file:///Users/estrup/Projects/tree_launcher/kanban/lib/models/project.dart)
```dart
class Project {
  final String id;
  final String repoPath;
  final String name;
  final bool isArchived;
  final DateTime createdAt;
  // + fromMap / toMap for SQLite
}
```

#### [NEW] [issue.dart](file:///Users/estrup/Projects/tree_launcher/kanban/lib/models/issue.dart)
```dart
class Issue {
  final String id;
  final String projectId;
  final String title;
  final String? description;
  final KanbanColumnStatus status;
  final List<String> tags;
  final String? branch;
  final String? worktreePath;
  final bool isArchived;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;
  // + fromMap / toMap for SQLite
  // + copyWith for immutable updates
}
```

#### [NEW] [issue_copilot_link.dart](file:///Users/estrup/Projects/tree_launcher/kanban/lib/models/issue_copilot_link.dart)
Simple linking model between issue and copilot session IDs.

---

### Phase 2 — Data Access Repositories

#### [NEW] [project_repository.dart](file:///Users/estrup/Projects/tree_launcher/kanban/lib/services/project_repository.dart)
Methods:
- `createProject(repoPath, name) → Project`
- `getProjectsForRepo(repoPath) → List<Project>` (excludes archived)
- `archiveProject(projectId)` — sets `is_archived = 1`

#### [NEW] [issue_repository.dart](file:///Users/estrup/Projects/tree_launcher/kanban/lib/services/issue_repository.dart)
Methods:
- `createIssue(projectId, title, description?) → Issue`
- `updateIssue(issue) → Issue` — updates title, description, tags, branch, worktreePath
- `moveIssue(issueId, newStatus)` — changes status column
- `archiveIssue(issueId)` — sets `is_archived = 1`
- `getIssuesForProject(projectId) → List<Issue>` (excludes archived)

#### [NEW] [issue_copilot_repository.dart](file:///Users/estrup/Projects/tree_launcher/kanban/lib/services/issue_copilot_repository.dart)
Methods:
- `linkSession(issueId, copilotSessionId)`
- `unlinkSession(issueId, copilotSessionId)`
- `getSessionsForIssue(issueId) → List<IssueCopilotLink>`

---

### Phase 3 — State Management

#### [NEW] [kanban_provider.dart](file:///Users/estrup/Projects/tree_launcher/kanban/lib/providers/kanban_provider.dart)
`ChangeNotifier` that:
- Holds `List<Project> projects` and `Map<String, List<Issue>> issuesByProject`
- Exposes methods that delegate to repositories then call `notifyListeners()`
- `loadProjectsForRepo(repoPath)` — called when repo is selected
- `createProject(repoPath, name)`
- `archiveProject(projectId)`
- `loadIssues(projectId)`
- `createIssue(projectId, title, description?)`
- `updateIssue(issue)`
- `moveIssue(issueId, newStatus)`
- `archiveIssue(issueId)`
- Copilot session linking: `linkCopilotSession(...)`, `unlinkCopilotSession(...)`, `getLinkedSessions(...)`

#### [MODIFY] [main.dart](file:///Users/estrup/Projects/tree_launcher/kanban/lib/main.dart)
- Initialize `DatabaseService` before `runApp` (synchronous — `sqlite3.open()` is sync)
- Add `KanbanProvider` to the `MultiProvider` tree

---

### Phase 4 — Project Management UI

#### [MODIFY] [home_screen.dart](file:///Users/estrup/Projects/tree_launcher/kanban/lib/screens/home_screen.dart)
- Replace hardcoded `DefaultTabController(length: 3)` with dynamic tab count from `KanbanProvider.projects`
- First tab stays "Worktrees", then one tab per project by name, last tab is "+"
- "+" tab triggers `CreateProjectDialog`
- Right-click on project tab → context menu with "Archive project"
- When a project tab is selected, pass `projectId` to `KanbanBoard`

#### [NEW] [create_project_dialog.dart](file:///Users/estrup/Projects/tree_launcher/kanban/lib/widgets/create_project_dialog.dart)
Simple dialog with a name `TextField` and Create/Cancel buttons. Calls `kanbanProvider.createProject(repoPath, name)`.

---

### Phase 5 — Issue Management UI

#### [MODIFY] [kanban_board.dart](file:///Users/estrup/Projects/tree_launcher/kanban/lib/widgets/kanban_board.dart)
- Accept `projectId` parameter
- Remove `_DummyData` and `KanbanCardData` class
- Load issues from `KanbanProvider` on init and when project changes
- Wire "Add card" to show `CreateIssueDialog`
- Wire drag-drop `_moveCard` to call `kanbanProvider.moveIssue()`
- Cards now use `Issue` model instead of `KanbanCardData`

#### [NEW] [create_issue_dialog.dart](file:///Users/estrup/Projects/tree_launcher/kanban/lib/widgets/create_issue_dialog.dart)
Dialog with Title (required) + Description (optional) fields. Calls `kanbanProvider.createIssue(projectId, title, description)`.

#### [MODIFY] [issue_view_dialog.dart](file:///Users/estrup/Projects/tree_launcher/kanban/lib/widgets/issue_view_dialog.dart)
- Accept `Issue` model instead of `KanbanCardData`
- Save button persists description edits via `kanbanProvider.updateIssue()`
- Add "Archive issue" action to the header
- Properties section reads/writes from `Issue` model (status, labels)

---

### Phase 6 — Branch, Worktree & Copilot Sessions on Issues

#### [MODIFY] [issue_view_dialog.dart](file:///Users/estrup/Projects/tree_launcher/kanban/lib/widgets/issue_view_dialog.dart)
**Development section:**
- "Branch" row displays `issue.branch` or "None"; "+ Create" sets branch name on issue
- "Worktree" row displays `issue.worktreePath` or "None"; "+ Create" sets worktree path on issue

**Copilot Sessions section:**
- Load linked sessions via `kanbanProvider.getLinkedSessions(issueId)`
- "New" button creates a copilot session (via existing `CopilotProvider`) and links it to the issue
- Each session item is clickable to open the copilot terminal

---

## Verification Plan

### Automated Tests

**Unit tests for repositories** — `test/kanban_repository_test.dart`

```bash
flutter test test/kanban_repository_test.dart
```

Tests will use an in-memory SQLite database (`sqlite3.openInMemory()`) to verify:
- Create, list, and archive projects
- Create, update, move status, and archive issues
- Link and unlink copilot sessions

### Manual Verification

> [!TIP]
> Could you suggest any additional manual test steps, or is there a specific flow you'd like to verify beyond these basics?

1. **Run the app**: `flutter run -d macos`
2. **Select a repo** from the sidebar
3. **Create a project**: Click the "+" tab → enter "My Project" → confirm → a new tab should appear
4. **Create issues**: In the new project tab, click "Add card" on the "To do" column → fill in title → confirm → card appears
5. **Drag & drop**: Drag a card from "To do" to "In progress" → card moves and persists after app restart
6. **Edit issue**: Click a card → edit description → save → reopen → description persists
7. **Archive issue**: Click a card → archive → card disappears from board
8. **Archive project**: Right-click project tab → archive → tab disappears
9. **Branch/worktree on issue**: Open issue → click "+ Create" on branch → set branch name → persists
10. **Copilot session on issue**: Open issue → click "New" in copilot sessions → session is created and linked
