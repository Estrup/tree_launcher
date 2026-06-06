---
name: tree-launcher-activity
description: >-
  Query the Tree Launcher app's worktree activity timeline (which issues/worktrees
  were worked on, when they were created/closed, and which days Claude was active in
  each) over its local HTTP API. Use when the user asks what they worked on, when a
  worktree was created or closed, how recently a branch saw activity, or to summarize
  work across repos and date ranges.
---

# Tree Launcher Activity API

Tree Launcher (a macOS git-worktree manager) runs a small **read-only HTTP server bound to
loopback** that exposes its Activity timeline. The Activity timeline merges:

- the durable worktree **created/closed** event log, and
- **Claude Code session history** (which calendar days work happened in each worktree).

## Prerequisites

- The **Tree Launcher app must be running** (the server starts with the app).
- The API listens on `http://127.0.0.1:8765` (loopback only — not reachable from other machines).
- No authentication. All endpoints are `GET` only.

Check it's up:

```bash
curl -s http://127.0.0.1:8765/health
# {"status":"ok","service":"tree_launcher","version":1}
```

If this fails with a connection error, tell the user to launch the Tree Launcher app.

## Endpoint: `GET /v1/activity`

Returns the activity timeline, newest-first.

Query parameters (both optional):

| Param    | Values                                                      | Meaning                                              |
|----------|-------------------------------------------------------------|------------------------------------------------------|
| `repo`   | a repository **name** (as shown in the app)                 | Narrow to one repo. Omit for all configured repos.   |
| `filter` | `all` (default), `today`, `yesterday`, `thisWeek`, `thisMonth` | Date window. `thisWeek` is Monday–Sunday, local time. |

A worktree is included by a date `filter` if it was **created**, **closed**, or had a **Claude
active day** within the window.

### Examples

```bash
# Everything, all repos
curl -s 'http://127.0.0.1:8765/v1/activity' | jq

# What did I work on today?
curl -s 'http://127.0.0.1:8765/v1/activity?filter=today' | jq

# This week, only the tree_launcher repo
curl -s 'http://127.0.0.1:8765/v1/activity?repo=tree_launcher&filter=thisWeek' | jq
```

### Response shape

```json
{
  "repo": "tree_launcher",
  "filter": "thisWeek",
  "count": 2,
  "entries": [
    {
      "worktreePath": "/Users/me/Projects/tree_launcher/feature-x",
      "worktreeName": "feature-x",
      "repoName": "tree_launcher",
      "branch": "feature/x",
      "jiraIssue": "AU2-1234",
      "createdAt": "2026-06-03T09:12:00.000",
      "closedAt": null,
      "isOpen": true,
      "activeDays": ["2026-06-03T00:00:00.000", "2026-06-05T00:00:00.000"],
      "lastActiveDay": "2026-06-05T00:00:00.000"
    }
  ]
}
```

Field notes:

- `createdAt` / `closedAt` — ISO-8601 local timestamps, or `null` (a `null` `closedAt` means the
  worktree is still open; `isOpen` mirrors this).
- `jiraIssue` — the attached issue key, or `null`.
- `activeDays` — date-only (midnight local) ISO strings; one per distinct day Claude was active in
  that worktree. `lastActiveDay` is the most recent.
- `entries` is sorted newest-first by the most recent of created/closed/last-active.

## Tips

- To answer "what did I work on this week", call `?filter=thisWeek` and group the entries by
  `repoName` and/or `jiraIssue`.
- `activeDays` is the best signal for *time spent* — count the days, not just created/closed.
- An unknown `filter` value returns HTTP 400 with `{"error": "..."}`.
