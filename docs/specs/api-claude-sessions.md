# Spec: Start a Claude session through the agent API

Status: implemented · 2026-10-20

## Goal

Let a local agent do in one request what the **Start Claude Session** dialog
does (the ✨ button on a Jira issue, PR or GitHub issue): pick a new or an
existing worktree, pick a prompt, model and effort, and start Claude there in
the built-in terminal. When the prompt has an agent kind, the session starts
as an agent run, exactly as from the dialog.

Today `POST /v1/worktrees` creates the worktree and can stage a kickoff
prompt, but starting Claude in it is a manual click in the app.

## Dialog → request at a glance

| Dialog | Request field |
|---|---|
| *New worktree* | No `existingWorktree` (default) |
| *Existing worktree* + its picker | `existingWorktree`: a worktree's folder name or path |
| Worktree name | `worktreeName`; derived from `issueKey` + `title` when left out, as the Jira button does |
| Jira issue no. | `issueKey` |
| Base branch | `baseBranch` |
| Create new branch + New branch | `branch` (without the prefix); defaults to the worktree name, as the dialog auto-fills it |
| Claude prompt: a saved prompt | `prompt`: the saved prompt's name, e.g. `"Factory: Refine"` |
| Claude prompt: *Issue context* | `prompt`: `":issue-context"` |
| Claude prompt: *Kickoff prompt* | `prompt`: `":kickoff"` |
| Claude prompt: none selected | No `prompt` |
| — | `promptText`: a first message of your own (new) |
| — | `kickoffPrompt`: stage a kickoff file in the new worktree, as `POST /v1/worktrees` does |
| Model | `model` |
| Effort | `effort` |
| The issue's summary in the header | `title` (an agent run's title; also names the worktree) |
| The PR the dialog was opened for | `prNumber` |

## The route: `POST /v1/claude/sessions`

### Fields

| Field | |
|---|---|
| `repo` | Required. A repo name. |
| `existingWorktree` | Optional. Start in this worktree of the repo instead of creating one: its folder name or its absolute path. |
| `worktreeName` | New worktree only. The folder name. Required unless `issueKey` and `title` are both given; then it defaults to `worktreeNameForJiraIssue(issueKey, title)`. |
| `baseBranch` | New worktree only. Required. The branch to start from. |
| `branch` | New worktree only. Optional. The new branch without the prefix; defaults to `worktreeName`. Becomes `<prefix>/<branch>` when Settings has a branch prefix. |
| `kickoffPrompt` | New worktree only. Optional. Text written to `<worktree>/.tree-launcher/kickoff-prompt.md`, as in `POST /v1/worktrees`. |
| `issueKey` | Optional. The Jira issue. A new worktree records it; in an existing worktree it is used for this session only, and defaults to the worktree's recorded issue. |
| `prompt` | Optional. A saved prompt's name in the repo (exact, ignoring case), or a built-in: `:issue-context`, `:kickoff`. Left out (and no `promptText`): Claude starts without a first message. |
| `promptText` | Optional. A first message of your own. Not with `prompt`. Placeholders are filled in the same way. |
| `prNumber` | Optional. A number: fills `{pr}` and is recorded on an agent run. |
| `title` | Optional. The agent run's title (the dialog passes the issue's summary). |
| `model` | Optional. `fable`, `opus` or `sonnet` (`claudeModelAliases`). Left out: no `--model`, so the CLI's own default. |
| `effort` | Optional. `low`, `medium`, `high`, `xhigh` or `max` (`claudeEffortLevels`). Left out: no `--effort`. |
| `show` | Optional boolean, default `false`. Bring the new terminal tab to the front. Otherwise it starts in the background and the usual "Started …" notice offers to show it. |

Giving `existingWorktree` together with `worktreeName`, `baseBranch`,
`branch` or `kickoffPrompt` → **400** (they only apply to a new worktree).

`worktreeName` and `branch` are normalised and validated exactly as in
`POST /v1/worktrees` (lowercased, spaces to dashes, then only `a-z 0-9 . - _`).
The two routes share that code.

### The first message

Resolved the way the dialog resolves it, after the worktree exists (so
`{path}` and `{worktree}` are real):

- **A saved prompt:** `resolveClaudePrompt` fills `{issue}`, `{pr}`,
  `{base_branch}`, `{worktree}`, `{path}` and `{repo}`. In an existing
  worktree, `{base_branch}` is the worktree's recorded base branch.
- **`:issue-context`:** `claudeContextPromptFor(issue, base)`, e.g.
  *Context: Working on issue AU2-5407 where the base branch is develop.*
- **`:kickoff`:** `kickoffPromptLaunchPrompt`, pointing Claude at the staged
  file. Needs a kickoff prompt: `kickoffPrompt` in this request for a new
  worktree, or one already staged in the existing worktree.
- **`promptText`:** filled with the same placeholders.

A prompt that uses `{issue}` with no issue key, or `{pr}` with no
`prNumber`, → **400** (as the Start Agent dialog refuses it). The dialog's
look-up of the branch's open PR is not done here; pass `prNumber`.

### What starts

The same as the dialog, through `StartClaudeSession`:

- **The saved prompt has an agent kind** (refine, build, verify, review,
  docs): `AgentLauncher.start` creates the run, then opens its session with
  `TREE_LAUNCHER_AGENT_ID` and `TREE_LAUNCHER_URL` in the environment. The
  run shows in the kind's tab at once. A build agent's worktree is remembered
  as a sidebar session.
- **Anything else:** `ClaudeSessionLauncher.start` opens a plain Claude
  session and remembers it as a sidebar session, with the prompt id.

Either way it runs `claude <Settings' extra CLI args> [--model …] [--effort …]
[first message]` in the built-in terminal. A session already running in an
existing worktree is left alone: the new one starts next to it, as sessions
in a shared checkout do.

**The API doesn't change remembered choices.** The dialog saves the picked
model, effort and prompt, the last base branch, and the shared checkout
picked for "Existing worktree"; a request does none of that, so an agent
calling the API doesn't change what the dialog preselects next time.

### Order of checks

Everything that can be checked before creating the worktree is checked
first, so a bad request never leaves a worktree behind:

1. Field shapes: unknown fields, missing fields, mutual exclusions,
   names, issue key format, `model`, `effort`, `prNumber`, `show`.
2. The repo (404).
3. The prompt: it exists (400, listing the names), `:kickoff` has a kickoff
   prompt, the placeholders it needs have values.
4. The existing worktree, if one was asked for (404).
5. Create the worktree, if a new one (409 on a conflict, as today).
6. Resolve the first message and start Claude.

### Responses

**201:**

```json
{
  "repo": "au2office",
  "worktree": {
    "name": "vipps-mobilepay-callback-http-500-au2-5407",
    "path": "/Users/me/Projects/au2-project/vipps-mobilepay-callback-http-500-au2-5407",
    "branch": "sen/vipps-mobilepay-callback-http-500-au2-5407",
    "baseBranch": "develop",
    "issueKey": "AU2-5407",
    "created": true,
    "kickoffPromptPath": null
  },
  "session": {
    "title": "Refinement: AU2-5407",
    "promptId": "Factory: Refine",
    "prompt": "kør /refine-factory AU2-5407",
    "model": "opus",
    "effort": "medium"
  },
  "agent": { "id": "ag_k3j9x2pq", "kind": "refine", "state": "starting", "…": "…" }
}
```

- `worktree.created` is false for an existing worktree.
- `session.prompt` is the first message as sent (null for none);
  `session.promptId` is what the session is recorded with: a saved prompt's
  name, `:issue-context`, `:kickoff`, or null.
- `agent` is the run (the same shape as `GET /v1/agents/<id>`) when the
  prompt has a kind, else null. Follow it with `GET /v1/agents/<id>`.

**Errors:**
- 400: a missing or invalid field, a field the route doesn't take, new-worktree
  fields with `existingWorktree`, `prompt` with `promptText`, an unknown
  prompt (with `prompts`: the saved names and the built-ins), `:kickoff`
  without a kickoff prompt, a placeholder without a value, an unknown model
  or effort (with `models` / `efforts`);
- 404: no repo with that name, or no such worktree in it;
- 409: the folder, branch or worktree already exists. Nothing was created;
- 500: the worktree was created but Claude didn't start. The body has
  `error` **and** `worktree`, so the caller knows the worktree exists and
  can start Claude in it with `existingWorktree`. The worktree isn't removed.

### Example

The dialog in the screenshot, as one request:

```bash
curl -s -X POST $TL/v1/claude/sessions -H 'Content-Type: application/json' -d '{
  "repo": "au2office",
  "issueKey": "AU2-5407",
  "title": "Vipps Mobilepay callback http 500",
  "baseBranch": "develop",
  "prompt": "Factory: Refine",
  "model": "opus",
  "effort": "medium"
}'
```

`worktreeName` comes out as `vipps-mobilepay-callback-http-500-au2-5407` and
the branch as `sen/vipps-mobilepay-callback-http-500-au2-5407`.

## Code

- **Domain seam** `ClaudeSessionStarter` in
  `lib/features/agents/domain/claude_session_starter.dart`, next to
  `AgentRegistry`: one method taking a `ClaudeSessionRequest` and returning a
  `StartedClaudeSession` (worktree, session, run). Typed exceptions for the
  route to map: `RepoNotFoundException` (404), a new
  `WorktreeNotFoundException` (404), `WorktreeConflictException` (409), a new
  `ClaudePromptException` (400, carrying the extra keys such as `prompts`),
  and a new `ClaudeStartFailedException` (500, carrying the created
  worktree).
- **Use case** `StartClaudeInWorktree` in
  `lib/app/use_cases/start_claude_in_worktree.dart`, implementing the seam.
  It composes `RepoCatalog`, `WorktreeCreator`, the worktree metadata (an
  existing worktree's issue, base branch and kickoff file), `GitService` (to
  list the worktrees of a repo that isn't selected) and `StartClaudeSession`.
  Built in `AppDependencies` after `startClaudeSession` and passed to
  `AgentApiServer`.
- **`StartClaudeSession`** splits into `call()` (remembers the choices, as
  today) and `launch()` (starts only), which the use case calls. `launch()`
  returns the started run, if any, and the session's title. A `show` flag
  goes through to the launchers' `show:`.
- **Prompt lookup and resolving** move out of `_AddWorktreeDialogState` into
  `features/workspace/domain/worktree_prompts.dart` (a function from prompt
  choice + worktree values to the first message), so the dialog and the use
  case resolve prompts the same way. Placeholder checks (`{issue}`, `{pr}`)
  join them.
- **Route** `ClaudeSessionRoutes` in
  `lib/features/agent_api/data/routes/claude_session_routes.dart`: shape
  validation with the helpers in `api_http.dart`, then the starter. The
  name/branch normalising and validation in `WorktreeRoutes` moves to a
  shared function both routes use.

## Docs

- `docs/agent-api.md`: a **Claude sessions** section with the route, a row in
  the overview table, and the example. `test/agent_api_doc_test.dart` fails
  until it is there.
- The tree-launcher skill (`~/.claude/skills/tree-launcher`): document the
  route. Its helper `scripts/agent.py` is for an agent reporting on itself
  and never fails its caller, so it doesn't get a `start` command; curl
  covers starting.

## Tests

- **Route** (`test/agent_api_server_test.dart`, with a fake
  `ClaudeSessionStarter`): unknown/missing fields, `existingWorktree` with
  new-worktree fields, `prompt` with `promptText`, bad model/effort/issue
  key/`prNumber`, the derived worktree name and default branch, each
  exception's status and body, the 201 body.
- **Use case** (fake creator, launchers and git): a saved prompt with a kind
  starts an agent with the resolved prompt, issue, PR, title, model and
  effort; one without starts a plain session; `:issue-context` and
  `:kickoff` resolve as in the dialog; placeholder errors and an unknown
  prompt fail **before** a worktree is created; an existing worktree's
  recorded issue and base branch are used; remembered choices are untouched;
  a failed start after creation raises `ClaudeStartFailedException` with the
  worktree.
- **Dialog**: unchanged behaviour after the prompt-resolving move (existing
  widget tests keep passing).

## Done when

- The example above, sent to a debug instance
  (`flutter run -d macos --dart-define=AGENT_API_PORT=8766`), creates the
  worktree, starts the refine agent in the built-in terminal and shows it in
  the Refine tab, the same as clicking Start in the dialog.
- The same with `existingWorktree` and a plain saved prompt starts a plain
  session there.
- `docs/agent-api.md` documents the route; `flutter analyze` is clean and
  `flutter test` passes.

## Out of scope (follow-ups)

- A worktree on an existing branch (the dialog with *Create new branch*
  unchecked, as the PR tab uses). `WorktreeCreator` needs an optional
  `newBranch` first.
- Looking up the branch's open PR for `{pr}` when `prNumber` isn't given.
- GitHub-issue worktrees (`githubIssue`, `prAuthor` metadata) and the
  `:pr-context` / `:github-issue-context` built-ins.
- Starting Claude outside the app (Terminal.app, iTerm); this route only uses
  the built-in terminal.
- A route to start Claude in a worktree without the new/existing choice, e.g.
  `POST /v1/worktrees/<name>/claude`; `existingWorktree` covers it.
- Switching the spin-up-issue skill to this route.

## Decisions

1. **One route for both cases**, new or existing worktree, as the dialog has
   one Start button; not a `claude` object bolted onto `POST /v1/worktrees`,
   which keeps that route about worktrees only.
2. **Explicit, no hidden state.** No remembered model, effort, prompt or base
   branch is read or written; what isn't given isn't sent. The one default is
   the worktree name/branch derivation, because it is a pure function of the
   request.
3. **No automatic switch to an existing worktree** for non-build agents. The
   dialog moves refine/review/verify/docs prompts to the shared checkout
   unless the user picked; an API caller says which it wants.
4. **Validate before creating.** A request that would fail at the prompt
   never creates a worktree. A start failure after creation keeps the
   worktree and says so (500 with `worktree`), rather than deleting work.
5. **Always start a new session**, next to any running one, rather than
   focusing the running one as the Jira button does for the issue's own
   worktree: an API caller asked for a session and gets one.
