# Agent API

A small HTTP API on loopback that local agents (Claude Code sessions and the
skills they run) use to read and change what Tree Launcher knows: the activity
timeline, worktrees, Jira issues with the user's local tags, and agent runs.
Everything goes through the running app, so a change made here shows in the
app at once, and the other way round.

- **Base URL:** `http://127.0.0.1:8765`. The port is set in Settings → Agent
  API. A debug build started with `--dart-define=AGENT_API_PORT=8766` uses
  that port instead and doesn't save it.
- **Agents started from Tree Launcher** get `TREE_LAUNCHER_URL` (the base URL)
  and `TREE_LAUNCHER_AGENT_ID` (their run's id) in their environment.
- **Check it's up:** `curl http://127.0.0.1:8765/health`.
- **Code:** `lib/features/agent_api/data/`. `agent_api_server.dart` is the
  server; each area's handlers are in `routes/`.

| Method | Path | What it does |
|---|---|---|
| GET | `/health` | Whether the API is up, and its version |
| GET | `/v1/activity` | The activity timeline: worktrees and manual posts |
| POST | `/v1/activity` | Log a manual activity post |
| POST | `/v1/worktrees` | Create a worktree, optionally with a kickoff prompt |
| GET | `/v1/jira/issues` | A Jira project's issues by fixVersion and/or status, with local tags |
| GET | `/v1/jira/tags` | The user's local tags |
| PUT | `/v1/jira/issues/<key>/tags` | Set an issue's local tags |
| GET | `/v1/agents` | Agent runs, filtered |
| POST | `/v1/agents` | Register an agent run |
| GET | `/v1/agents/<id>` | One agent run with its latest timeline events |
| POST | `/v1/agents/<id>/status` | Report an agent run's progress |

## Conventions

**Only local clients.** The server binds 127.0.0.1 only, and refuses what a
web page open in a browser could send:

- a `Host` header other than `127.0.0.1:<port>` or `localhost:<port>` → **403**
  (this blocks DNS rebinding);
- a POST or PUT whose `Content-Type` isn't `application/json` (a charset is
  fine) → **415**. A browser sends a cross-site `text/plain` POST without
  asking, but for JSON it must ask first (a CORS preflight), which this server
  never answers.

`curl` with `-H 'Content-Type: application/json'` and Python's `urllib` with
that header pass both checks.

**Requests**

- Bodies are JSON objects.
- String fields are trimmed, and a blank string counts as missing.
- A field a route doesn't take → **400**, with `fields` listing the ones it
  does.
- Boolean query parameters must be `true` or `false`; anything else → **400**.
- Jira issue keys must look like `AU2-1234`: uppercase project, a dash, a
  number.

**Responses** are JSON. A failed request returns
`{"error": "<what went wrong>"}`, sometimes with more keys that help fix it
(`fields`, `fixVersions`, `tags`):

| Status | When |
|---|---|
| 200 | Done |
| 201 | Created: a post, a worktree, an agent run |
| 400 | The request is wrong: a missing or invalid field, an unknown filter, a field the route doesn't take |
| 403 | Not a local client (see above) |
| 404 | No such repo, issue, fixVersion or agent run |
| 409 | The worktree, its folder or its branch already exists |
| 415 | A POST or PUT that isn't JSON |
| 500 | The app failed unexpectedly; `error` says what failed and why |
| 502 | Jira failed (Jira's own 400s, e.g. an unknown status, come back as 400) |

**Times** are ISO-8601. The app's own times are local time without an offset
(`2026-10-19T14:05:00.000`). Times from Jira are UTC (`…Z`).

**Versioning.** `/health` reports `version: 1`. Adding routes or response
fields doesn't change it; changing or removing them would.

## Health

### `GET /health`

```json
{"status": "ok", "service": "tree_launcher", "version": 1}
```

## Activity

The activity timeline that Tree Launcher keeps for time logging. It has two
kinds of entries:

- **Worktree entries:** one per worktree. They record when it was created and
  closed (from the app's own log) and which days Claude was active in it
  (read from Claude Code's session transcripts). Worktrees that exist but were
  never created through the app are included too.
- **Manual entries:** work logged by hand or through `POST /v1/activity`.

### `GET /v1/activity?repo=<name>&filter=<filter>`

| Query | |
|---|---|
| `repo` | Optional. A repo name as the sidebar shows it; only that repo's entries. |
| `filter` | Optional, default `all`. One of `all`, `today`, `yesterday`, `thisWeek` (Monday to Sunday), `thisMonth`, all in local time. An entry matches when it was created or closed in the window, or Claude was active in it on a day in the window. |

```json
{
  "repo": "au2office",
  "filter": "thisWeek",
  "count": 1,
  "entries": [
    {
      "worktreePath": "/Users/me/Projects/au2-project/au2-5987",
      "worktreeName": "au2-5987",
      "repoName": "au2office",
      "branch": "sen/au2-5987",
      "jiraIssue": "AU2-5987",
      "createdAt": "2026-10-14T09:12:03.000",
      "closedAt": null,
      "isOpen": true,
      "activeDays": ["2026-10-14T00:00:00.000", "2026-10-15T00:00:00.000"],
      "lastActiveDay": "2026-10-15T00:00:00.000",
      "kind": "worktree"
    }
  ]
}
```

Entries come newest activity first. Their fields:

| Field | |
|---|---|
| `worktreePath` | The worktree's path; `manual:<id>` for a manual entry. |
| `worktreeName` | The worktree's folder name; for a manual entry, its description (or issue key). |
| `repoName`, `branch`, `jiraIssue` | What the worktree is for; may be null. |
| `createdAt`, `closedAt` | When it was created and closed, if known; a manual entry's `createdAt` is when it was logged. |
| `isOpen` | Whether no close has been logged for it. |
| `activeDays` | The local days Claude was active in it, at midnight. |
| `lastActiveDay` | The last of them, or null. |
| `kind` | `worktree` or `manual`. |
| `hours` | A manual entry's hours, when given. |

**Errors:** 400 for an unknown `filter`.

### `POST /v1/activity`

Logs work done outside any worktree, stamped now. It shows in the Activity tab
at once.

| Field | |
|---|---|
| `repo` | Required. A repo name. |
| `issueKey` | Required. The Jira key the work is logged against. |
| `description` | Optional. Defaults to the description of the repo's predefined issue with this key (Repo settings → Issue keys), else empty. |
| `hours` | Optional. A number, or a string holding one. |

**201** returns the post:

```json
{"id": "…", "timestamp": "2026-10-19T14:05:00.000", "repoName": "au2office",
 "issueKey": "AU2-9", "description": "Code review", "hours": 1.5}
```

**Errors:**
- 400: a missing field, an invalid key, `hours` not a number, or a field
  the route doesn't take;
- 404: no repo with that name.

## Worktrees

### `POST /v1/worktrees`

Creates a worktree in a repo, the same way the app's New Worktree dialog does,
and records the Jira issue and base branch with it.

| Field | |
|---|---|
| `repo` | Required. A repo name. |
| `baseBranch` | Required. The branch to start from; its latest `origin/` state is fetched first. |
| `branch` | Required. The new branch's name *without* the prefix: it becomes `<prefix>/<branch>` when Settings has a branch prefix. |
| `worktreeName` | Required. The worktree's folder name. |
| `issueKey` | Optional. The Jira issue it is for. |
| `kickoffPrompt` | Optional. Text, e.g. a whole implementation plan, written to `<worktree>/.tree-launcher/kickoff-prompt.md` (excluded from git). The worktree's Claude menu then offers to start Claude on it. |

`worktreeName` and `branch` are lowercased, with spaces turned into dashes.
They may then hold only `a-z 0-9 . - _`.

**201:**

```json
{
  "repo": "au2office",
  "worktreeName": "au2-6001-fix-konto",
  "worktreePath": "/Users/me/Projects/au2-project/au2-6001-fix-konto",
  "branch": "sen/au2-6001-fix-konto",
  "issueKey": "AU2-6001",
  "kickoffPromptPath": "/Users/me/Projects/au2-project/au2-6001-fix-konto/.tree-launcher/kickoff-prompt.md"
}
```

`branch` is the full name, prefix included. `kickoffPromptPath` is null when no
prompt was given, or when writing it failed; a failed write doesn't fail the
request.

**Errors:**
- 400: a missing or invalid field, or a field the route doesn't take;
- 404: no repo with that name;
- 409: the folder, the branch or the worktree already exists, in git's words.
  Nothing was created and no prompt was written.

## Jira

Reads come from the app's Jira server (`jiraBaseUrl` in
`lib/features/jira/domain/jira_constants.dart`), with the token in
`~/.config/jira-pat.txt`. Nothing here changes anything in Jira. Tags are the
user's own, kept by Tree Launcher; the GitHub Issues tab uses them for GitHub
issues too.

### `GET /v1/jira/issues?repo=<name>&fixVersion=<version>&status=<status>`

The project's issues, sub-tasks left out, in rank order.

| Query | |
|---|---|
| `repo` or `project` | One is required. `repo` is a repo name, whose Jira project key (Repo settings → Jira) is used. `project` is a project key such as `AU2`. |
| `fixVersion` | A version name (any case) or id. |
| `status` | Status names; repeat the parameter or separate them with commas. An issue in any of them matches. |

At least one of `fixVersion` and `status` is required.

```json
{
  "project": "AU2",
  "fixVersion": {"id": "29501", "name": "au2office 2.41.3", "released": false},
  "statuses": ["Review"],
  "count": 1,
  "issues": [
    {
      "key": "AU2-5928",
      "summary": "Værksted kontakt",
      "status": "Review",
      "statusCategory": "indeterminate",
      "issueType": "Story",
      "assignee": "Jane Doe",
      "priority": "Medium",
      "updated": "2026-10-01T12:00:00.000Z",
      "url": "https://jira.example.com/browse/AU2-5928",
      "tags": ["Blocked"]
    }
  ]
}
```

`fixVersion` is null when none was asked for. `statusCategory` is Jira's:
`new`, `indeterminate` or `done`.

**Errors:**
- 400: neither filter given, no `repo` or `project`, a repo without a Jira
  project key, or Jira rejecting the search (e.g. an unknown status);
- 404: an unknown repo, or a fixVersion the project doesn't have (with
  `fixVersions` listing those it has);
- 502: Jira failed.

### `GET /v1/jira/tags`

The user's local tags, in display order:

```json
{"tags": [{"name": "Blocked", "color": "red"}, {"name": "Demo", "color": "blue"}]}
```

### `PUT /v1/jira/issues/<key>/tags`

Replaces issue `<key>`'s local tags. Body: `{"tags": ["Blocked", "Demo"]}`,
with names as `GET /v1/jira/tags` lists them, in any case. An empty list removes
them all. **200** returns `{"key": "AU2-5928", "tags": ["Blocked", "Demo"]}`.

**Errors:**
- 400: an invalid key, `tags` not a list of names, an unknown tag (with
  `tags` listing the known ones), or any other field. Only local tags can
  be set here; nothing is sent to Jira.

## Agents

An **agent run** is one Claude session of a kind (`refine`, `build`, `verify`,
`review` or `docs`) working on a repo, usually on one or more Jira issues in a
worktree. The app shows the runs in each kind's tab of the repo. Agents
register when they start and report as they go; the tree-launcher skill's
`scripts/agent.py` wraps these calls. A run started from the app is created
before the agent starts, and gets its id in `TREE_LAUNCHER_AGENT_ID`.

**A run's state:**
- `starting`: registered, nothing reported yet;
- `running`;
- `waiting`: needs a human, e.g. at a gate;
- `done`, `failed` or `stopped`: finished.

**Stages** are the run's steps, e.g. `spec`, `plan`, `implement`. Each is
`pending`, `running`, `waiting`, `done`, `failed` or `skipped`, and may have
progress, such as 4 of 7.

**The timeline** is the run's events: one line of text each, with a level of
`info`, `success`, `warning`, `error` or `action`.

### `GET /v1/agents?repo=<name>&kind=<kind>&active=<bool>&issue=<key>&archived=<bool>`

The runs, most recently updated first. Every filter is optional:

| Query | |
|---|---|
| `repo` | Runs in this repo. |
| `kind` | Runs of this kind. |
| `active` | `true`: unfinished runs only; `false`: finished runs only. |
| `issue` | Runs working on this issue key (any case). |
| `archived` | `true` includes archived runs, which are left out otherwise. |

Returns `{"count": 2, "agents": [<run>, …]}`. **400** for an unknown `kind`, or
an `active` or `archived` that isn't `true` or `false`.

### `GET /v1/agents/<id>`

The run, with `events`: its latest 50 timeline events, oldest first. Each
event is `{"agentId", "at", "message", "stage"?, "level"}`. **404** for an
unknown id.

### `POST /v1/agents`

Registers a run.

| Field | |
|---|---|
| `id` | Optional. A run the app created when it launched the agent (`$TREE_LAUNCHER_AGENT_ID`); the other fields update it. |
| `kind` | Required without `id`. |
| `repo` | Required without `id`, unless `worktreePath` is a worktree of a repo, which is then used. |
| `prompt`, `title`, `worktreePath`, `branch`, `model`, `effort` | Optional strings. |
| `prNumber` | Optional. A number. |
| `issueKey` / `issueKeys` | Optional. One key, or several as a list or a comma-separated string. |
| `stages` | Optional. The stage names in order, as a list or a comma-separated string. |

Without `id`, an unfinished, unarchived run with the same `kind`, `repo`,
`worktreePath` and issue keys is updated instead of starting another, e.g. a
resumed session (**200**). A new run is **201**. Both return the run.

**Errors:**
- 400: a missing `kind` or `repo`, an unknown kind, an invalid key, or a
  field the route doesn't take;
- 404: an unknown `id` or repo.

### `POST /v1/agents/<id>/status`

Reports progress. Every field is optional, but at least one is needed.

| Field | |
|---|---|
| `state` | `running`, `waiting`, `done`, `failed` or `stopped`. `waiting` (a gate, or any other need for a human) requires a `message` saying what is needed. |
| `stage` | The stage this report is about. A stage the run doesn't have yet is added. |
| `stageState` | That stage's new state. Needs `stage`; defaults to one that fits `state` (`running` without one). |
| `progress` | That stage's progress: `"4/7"` or `{"done": 4, "total": 7}`. Needs `stage`. |
| `stages` | Declares the stage names again, in order. Stages already known keep their state; stages left out are dropped. |
| `message` | One line for the timeline, also shown on the run's card. Longer than 2,000 characters is cut. |
| `level` | The timeline event's level. Defaults to one that fits `state`. |
| `links` | `{"label": "URL or path"}`, added to the run's links. A label already there is replaced. Relative paths are taken from the run's worktree. |
| `result` | The outcome in a few words, shown on a finished run. Longer than 200 characters is cut. |

How a report changes the run:
- **The first report** moves a run out of `starting`.
- **A stage becoming running or waiting** makes it the current stage, and
  completes any earlier stage that was still active.
- **`done` or `failed`** settles every active stage the same way.
- **A report without a message** still adds a timeline event when a stage or
  the state changed.

**200** returns the updated run.

**Errors:**
- 400: an invalid field, a field the route doesn't take, or an empty report;
- 404: an unknown id.

### A run

| Field | |
|---|---|
| `id` | `ag_` and 8 characters. |
| `kind`, `repo`, `prompt`, `title` | What it is and was started with. |
| `issueKeys`, `worktreePath`, `branch`, `prNumber` | What it works on. |
| `stages` | `[{"name", "state", "progress"?: {"done", "total"}}]`, in order. |
| `currentStage` | The stage it is on, or null. |
| `state` | See above. |
| `summary` | Its latest message. |
| `result` | Its outcome, once reported. |
| `links` | `[{"label", "target"}]`. |
| `model`, `effort` | The Claude model and effort it runs on, if known. |
| `claudeSessionId` | Its Claude Code session, when the app knows it (used to resume it). |
| `startedAt`, `updatedAt`, `finishedAt` | When it started, last changed, and finished (null while unfinished). |
| `archived` | Whether the user archived it. Archived runs older than 30 days are dropped. |

## Examples

```bash
TL=http://127.0.0.1:8765

# What was worked on this week, in one repo
curl -s "$TL/v1/activity?repo=au2office&filter=thisWeek"

# Log 1.5 hours of review
curl -s -X POST "$TL/v1/activity" -H 'Content-Type: application/json' \
  -d '{"repo": "au2office", "issueKey": "AU2-9", "hours": 1.5}'

# Create a worktree with a kickoff prompt from a file (jq escapes it)
jq -n --arg repo au2office --arg baseBranch develop --arg branch au2-6001 \
  --arg worktreeName au2-6001 --arg issueKey AU2-6001 \
  --rawfile kickoffPrompt /tmp/plan.md \
  '{repo: $repo, baseBranch: $baseBranch, branch: $branch,
    worktreeName: $worktreeName, issueKey: $issueKey,
    kickoffPrompt: $kickoffPrompt}' |
  curl -s -X POST "$TL/v1/worktrees" -H 'Content-Type: application/json' --data @-

# The issues in review in a fixVersion, then tag one
curl -s -G "$TL/v1/jira/issues" --data-urlencode project=AU2 \
  --data-urlencode 'fixVersion=au2office 2.41.3' --data-urlencode status=Review
curl -s -X PUT "$TL/v1/jira/issues/AU2-5928/tags" \
  -H 'Content-Type: application/json' -d '{"tags": ["Verified"]}'

# An agent reports a gate
curl -s -X POST "$TL/v1/agents/$TREE_LAUNCHER_AGENT_ID/status" \
  -H 'Content-Type: application/json' \
  -d '{"state": "waiting", "stage": "spec", "message": "Spec ready: 5 AC, approve?"}'
```

## Changing the API

1. Add the handler to the area's file in `lib/features/agent_api/data/routes/`,
   and mount it in that file's `mount`. Use the helpers in `api_http.dart`:
   - `readJsonObject` to read the body;
   - `stringField` for string fields;
   - `missingFields` and `unsupportedFields` for field errors;
   - `boolQuery` for boolean query parameters;
   - `serverError` for an unexpected failure.
2. Read and write through the app's controllers, via a small interface in the
   feature's `domain/` such as `WorktreeCreator` or `AgentRegistry`, never
   through the stores. That keeps the API and the UI in agreement.
3. Add tests to `test/agent_api_server_test.dart`.
4. Document the route here. `test/agent_api_doc_test.dart` fails while a
   mounted route is missing from this file.
