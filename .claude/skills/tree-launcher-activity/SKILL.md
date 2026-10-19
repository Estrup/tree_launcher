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

Tree Launcher (a macOS git-worktree manager) runs a small **HTTP server bound to loopback**
for local agents. This skill covers its Activity timeline; the whole API (worktrees, Jira
issues and tags, agent runs) is described in `docs/agent-api.md` in this repo. The Activity
timeline merges:

- the durable worktree **created/closed** event log,
- **Claude Code session history** (which calendar days work happened in each worktree), and
- **manual posts**: work logged by hand, with hours.

## Prerequisites

- The **Tree Launcher app must be running** (the server starts with the app).
- The API listens on `http://127.0.0.1:8765` (loopback only — not reachable from other machines;
  the port is set in Settings → Agent API).
- No authentication, but it only answers local clients: a `Host` other than
  `127.0.0.1:<port>`/`localhost:<port>` gets 403, and a POST without
  `Content-Type: application/json` gets 415.

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
      "lastActiveDay": "2026-06-05T00:00:00.000",
      "kind": "worktree"
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
- `kind` — `worktree`, or `manual` for a logged post. A manual entry's `worktreePath` is
  `manual:<id>`, its `worktreeName` the post's description (or issue key), its `createdAt` when it
  was logged, and it has `hours` when they were given.

## Logging work: `POST /v1/activity`

Logs work done outside any worktree, stamped now; it shows in the app's Activity tab at once.

```bash
curl -s -X POST 'http://127.0.0.1:8765/v1/activity' -H 'Content-Type: application/json' \
  -d '{"repo": "tree_launcher", "issueKey": "AU2-1234", "description": "Review", "hours": 1.5}'
```

`repo` and `issueKey` are required; `description` defaults to the repo's predefined issue with
that key; `hours` is optional. Returns 201 with the post. Any other field is a 400.

## Tips

- To answer "what did I work on this week", call `?filter=thisWeek` and group the entries by
  `repoName` and/or `jiraIssue`.
- `activeDays` is the best signal for *time spent* — count the days, not just created/closed.
- To total hours, add up the `hours` of the `manual` entries.
- An unknown `filter` value returns HTTP 400 with `{"error": "..."}`.
