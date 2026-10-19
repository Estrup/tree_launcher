# Spec: GitHub Issues tab

Status: agreed · 2026-10-19

## Goal

Add an **Issues** tab, next to the PRs tab, that does for a repo's GitHub
issues what the Jira tab does for Jira issues: list them grouped by milestone
(the GitHub counterpart of a fixVersion), search them, filter by state, change
their state one at a time or in bulk, assign them to me, tag them locally, and
start a worktree or a Claude session for one.

On top of what the Jira tab has, every issue can be **opened in a dialog**
inside the app and **opened in the browser** on github.com, both straight
from its row.

## Jira tab → Issues tab at a glance

| Jira tab | Issues tab |
|---|---|
| fixVersion picker: unreleased versions; typing also finds released ones | Milestone picker: **All open issues** plus open milestones; typing also finds closed ones |
| Search by key (`AU2-123`, `123`) or text | Search by number (`#123`, `123`) or text, plus GitHub search qualifiers (`label:bug`, `no:milestone`, `author:@me` …) |
| Status chips (Jira statuses, coloured by category) | State chips: **Open**, **Closed**, **Not planned**, followed by **label chips** |
| Issue-type icon | State icon (GitHub's open / closed / not-planned glyphs) |
| Key badge opens `JiraIssueDialog` | `#123` badge **and the title** open `GithubIssueDialog`; ⌘-click opens github.com instead |
| Summary + local tags | Title + GitHub labels + local tags |
| Status pill → workflow transitions | State pill → *Reopen* / *Close as completed* / *Close as not planned* |
| Assignee | Assignees (first one, then `+n`) |
| Assign to me | Assign to me (adds me and keeps the other assignees) |
| — | **Open in GitHub** row button (new) |
| Claude session · Create worktree | Same |
| Bulk: Change status | Bulk: Change state |

## Where it shows

- New repo page `issues`: label **Issues**, icon `Icons.adjust_rounded` (looks
  like GitHub's issue glyph). It sits right after **PRs**.
- Shown when the repo's GitHub connection is configured **and** the new repo
  setting **Show issues tab** is on. The setting defaults to off, because
  repos such as au2office have a GitHub connection for PRs but track their
  issues in Jira.
- Repo settings → GitHub:
  - add the **Show issues tab** switch (`GithubConfig.issuesEnabled`,
    default `false`; `GithubConfig.showsIssues` is "configured and on");
  - rename the heading from "GitHub Pull Requests" to "GitHub", and change
    the subtitle to "Configure GitHub connection to view pull requests and
    issues";
  - extend the token hint: a fine-grained token needs **Issues: read and
    write** to list and change issues (a classic token's `repo` scope already
    covers it).

## The tab

### Header

Same layout as the Jira tab, left to right:

1. **Milestone picker** (`DropdownMenu`, 300 wide, filterable):
   - The first entry, always present, is **All open issues**: open issues with
     any milestone or none.
   - Then open milestones, by due date (soonest first, those without a date
     last, then by title).
   - Closed milestones are listed only while the user is typing, newest
     closed first, each with a muted `closed` trailing label. This is how the
     Jira picker treats released versions.
   - Picking a milestone loads **all** its issues, open and closed, so the
     closed ones show under the Closed / Not planned chips the way Done issues
     show for a fixVersion.
   - The pick is remembered per repo (`RepoConfig.githubMilestoneNumber`,
     null = All open issues). If the remembered milestone no longer exists,
     the picker falls back to All open issues.
2. **Search field**, max 300 wide. It is the Jira search field (400 ms pause,
   Enter searches immediately, Esc or ✕ clears it) with these rules:
   - `123` or `#123` also fetches that issue directly and lists it first, the
     way a typed Jira key is listed first.
   - The text goes to GitHub search as `repo:<owner>/<repo> is:issue <text>`
     with **no sanitising**, so qualifiers like `label:bug`, `is:open`,
     `no:milestone` and `assignee:@me` work. Search covers open and closed
     issues unless the text narrows it.
   - GitHub search has no prefix matching, so while typing, only whole words
     match (Jira's search adds a `*` wildcard; GitHub's can't).
   - At most 50 results, most recently updated first. The count shows `50+`
     with a tooltip when there may be more.
   - Searching takes the picker's place, as in Jira. Picking a milestone ends
     the search.
3. **Count badge**: `visible / loaded` while a filter is on, otherwise
   `loaded`, with `+` when truncated.
4. Right side: "refreshed Xm ago", then the refresh button, or a spinner
   while loading.

### Filter chips

One wrapping row, shown when anything is loaded or a filter is on:

- **All** (n), then the **state chips** for the states present: Open (green),
  Closed (purple), Not planned (grey). They are multi-select like Jira's
  status chips.
- A thin divider, then **label chips** for the labels on the loaded issues,
  most-used first, coloured with the label's GitHub colour. They are
  multi-select. An issue shows when it has **any** selected label.
- An issue is visible when it passes both the state filter and the label
  filter. As in Jira, a filtered chip with zero matches is kept at the end so
  it can be switched off, and changing a filter drops hidden issues from the
  selection.
- The filters are kept across milestone switches, like Jira's status filter,
  and reset on a repo switch.

### List columns

Checkbox · state icon (22) · `#number` (72) · **title cell** (expands) ·
state pill (130) · assignees (160, dropped first in a narrow window, as in
Jira) · actions (166).

- **State icon**: open = `Icons.adjust_rounded` green; closed =
  `Icons.check_circle_outline_rounded` purple; not planned =
  `Icons.block_rounded` grey. The tooltip shows the state, plus the issue
  type when the repo uses GitHub issue types (`Bug · Open`).
- **`#number` badge**: monospace, opens the dialog; ⌘-click opens github.com.
- **Title cell**: the title (ellipsis, full title in a tooltip, click opens
  the dialog, ⌘-click opens github.com), then up to **2 GitHub label chips**
  and a `+n` chip whose tooltip lists the rest, then the local tags
  (`IssueTags`, unchanged). Labels and tags together take at most 60% of the
  cell, the same rule the tags follow today.
- **State pill**: same look and behaviour as the Jira status pill. It opens
  the state menu (below).
- **Assignees**: first login, `+n` when there are more (the tooltip lists
  them all), italic muted "Unassigned" when there are none.
- **Actions**, right-aligned:
  1. worktree indicator (green `account_tree` icon, tooltip `Worktree: <name>`)
     when a worktree is linked to the issue;
  2. **Assign to me**, hidden when I'm already an assignee;
  3. **Open in GitHub** (`Icons.open_in_new_rounded`, tooltip
     `Open #123 in GitHub`), which is new;
  4. **Claude session for #123…**;
  5. **Create worktree for #123…**.

Hover, selection colours, row padding and the select-all header checkbox all
match the Jira tab.

### State menu and state changes

GitHub issues have three states. The menu offers the two the issue isn't in:

| From | Menu |
|---|---|
| Open | Close as completed · Close as not planned |
| Closed | Reopen · Close as not planned |
| Not planned | Reopen · Close as completed |

`PATCH /repos/{o}/{r}/issues/{n}`, with `{"state":"closed","state_reason":"completed"|"not_planned"}`
or `{"state":"open"}`. After a change the list reloads. A failure shows a
snackbar `#123: <GitHub's message>`.

### Selection and bulk bar

Same as Jira: hover-revealed checkboxes, select-all in the header, and a bar
reading "*n* selected" with **Change state** and **Clear**.

- **Change state** opens the same three-item menu. An item is offered when at
  least one selected issue isn't in that state already, and it is applied
  only to those issues.
- The summary snackbar follows `bulkMoveSummary`, e.g. "Closed 3 of 5 issues
  as completed. #12: Validation failed. 1 was already closed."
- Issues that failed stay selected so they can be retried. The rest are
  deselected.

### Assign to me

`POST /repos/{o}/{r}/issues/{n}/assignees` with `{"assignees":["<me>"]}`, which
adds me and keeps the others. GitHub silently ignores assignees without push
access, so if the response doesn't list me, the snackbar says "GitHub didn't
assign you to #123. You may lack write access to owner/repo." My login comes
from `GET /user`. Look it up once per token and share it with the PRs
controller, which fetches the same thing today.

### Empty, loading and error states

- No milestones and no open issues: "No open issues in owner/repo".
- Milestone with no issues: "No issues in <milestone>".
- Search with no hits: `No issues match "<text>"`.
- Filters hide everything: "No issues match the filter".
- Errors use the Jira tab's red banner. Messages:
  - 401: "GitHub authentication failed. Check your token."
  - 403 with `x-ratelimit-remaining: 0`: "GitHub rate limit reached. Try again
    at HH:MM." (from `x-ratelimit-reset`)
  - Other 403: "The token can't access issues in owner/repo. It needs Issues
    read and write."
  - 404: "Repository not found: owner/repo"
  - 410: "Issues are turned off for owner/repo."
  - 422 on a change: GitHub's `message`.

No polling: the list reloads on the refresh button, on a repo switch, and
after a change, the same as Jira.

## Opening an issue

### In a dialog: `GithubIssueDialog`

This is a transient, self-contained dialog shaped like `JiraIssueDialog` (same
width rules, header, body and footer). It opens from the `#number` badge, the
row title, and the worktree card badge (see below).

- **Header**: state icon, `owner/repo#123` in monospace, the issue type when
  set, and the close button. The **title** is a 20 pt `SelectableText`. A
  facts `Wrap` holds:
  - the **state pill** with the state menu;
  - **assignees** with **Assign to me**;
  - the **milestone**;
  - "Opened by **login**" with a relative time;
  - "Updated x ago" (the absolute time is in a tooltip);
  - all **labels** as chips.
- **Body**:
  - **DESCRIPTION**: the issue body as `SelectableText` (raw markdown in v1;
    see Open questions), or a muted "No description".
  - **COMMENTS (n)**: oldest first, each with an initials avatar, login,
    relative time and body. This is the Jira comment layout.
- **Footer**: "Fetched x ago", **Refresh**, and the primary button **Open in
  GitHub**.
- **Data**: `GET /repos/{o}/{r}/issues/{n}` and
  `GET /repos/{o}/{r}/issues/{n}/comments` (100 per page, up to 3 pages).
  Results are cached in `github_issue_cache.json` in the app support
  directory, keyed `owner/repo#n` (same shape and "never throws" rules as
  `JiraIssueCache`).
- **Refreshing**: the issue is **fetched every time the dialog opens**. Until
  the fetch is done, the list's copy shows (without comments), and then the
  cached copy if the cache answers first. This differs from Jira's dialog,
  which only fetches on a cache miss. A failed fetch keeps whatever copy is
  showing and puts the error box above it. Writing the cache never holds up
  the dialog.
- `onIssueChanged` makes the tab reload after a state or assignee change made
  in the dialog.

### In the browser

`Process.run('open', [issue.htmlUrl])`, the pattern the PRs tab and Jira
dialog already use. The tab and dialog take an injectable `openUrl` callback
(defaulting to that) so widget tests can check it. Ways to reach it:

- the **Open in GitHub** button on the row;
- ⌘-click on the `#number` badge or the title;
- the **Open in GitHub** button in the dialog footer.

## Worktrees and Claude sessions

- **Name**: the new `worktreeNameForGithubIssue(number, title)` builds a slug
  of the title's first words followed by the number, e.g. #482 "Login
  redirect loops" → `login-redirect-loops-482`. It shares the slug rules
  (ASCII folding, 48 chars, 5 words) with `worktreeNameForJiraIssue` by
  extracting the common part. The id goes last, as with Jira keys.
- **Link**: a new `RepoConfig.githubIssues` map (worktree path → issue number)
  is hydrated into the new `Worktree.githubIssue` (`int?`). It works the same
  way as `jiraIssues` / `Worktree.jiraIssue`. `AddWorktreeDialog.show` and
  `startClaudeSession` get a `githubIssue` parameter that is passed to
  `WorkspaceController.addWorktree(..., githubIssue:)` and shown as a `#482`
  chip in the dialog header, where a Jira key would be. The Jira field stays
  as it is.
- **Create worktree** opens `AddWorktreeDialog.show` prefilled with the name,
  `githubIssue`, and the issue title as `contextTitle`.
- **Claude session** calls `AddWorktreeDialog.startClaudeSession` with
  `existingWorktree` set to the worktree linked to the issue (when there is
  one), plus:
  - `contextPrompt: githubIssueContextPrompt(issue, config)`;
  - `contextPromptLabel: 'Issue context'`;
  - `contextPromptId: githubIssueContextPromptId` (new, `':github-issue-context'`).

  The prompt reads:
  `Context: Working on GitHub issue #482 "Login redirect loops" in owner/repo (https://github.com/owner/repo/issues/482). Run "gh issue view 482 --comments" for its description and discussion.`
- **Sidebar grouping**: `sessionPageKey` maps `githubIssueContextPromptId` to
  the Issues page, and a worktree with a `githubIssues` entry also goes under
  Issues. That rule comes after the Jira rule and before the worktrees
  fallback.
- **Worktree list**: a worktree with `githubIssue` shows a `#482` badge in the
  Jira column (both badges, scaled to fit, when it has both). The column is
  headed "Issue" instead of "Jira" when the repo shows GitHub issues.
  Clicking the badge opens `GithubIssueDialog`; ⌘-click opens github.com.

## Local tags

These are the user's existing tags from Settings, shared with Jira issues
rather than a second set. They are stored in the same
`AppSettings.jiraTagsByIssue` map under the key `owner/repo#482`, which can
never collide with a Jira key. Nothing is ever sent to GitHub. The existing
Jira agent-API tag routes validate Jira keys, so they don't see these entries.

## Data layer

New feature folder `lib/features/github_issues/`:

```
domain/
  github_issue.dart          GithubIssue, GithubIssueComment, GithubIssueState,
                             githubIssueRef()
  github_milestone.dart      GithubMilestone, orderMilestonesForPicker()
  github_issue_search.dart   githubIssueNumberInQuery(), githubIssueSearchQuery()
data/
  github_issues_api_service.dart
  github_issue_cache.dart
presentation/
  controllers/github_issues_controller.dart
  widgets/github_issues_tab.dart
  widgets/github_issue_dialog.dart
  widgets/github_issue_styles.dart  state colours and icons, state menu,
                                    state pill, #number badge
  widgets/github_issue_badge.dart   the worktree list's #number badge
  github_issue_actions.dart  context prompt, bulk summary, open in browser
```

`worktreeNameForGithubIssue` lives next to `worktreeNameForJiraIssue` in
`workspace/domain/worktree_naming.dart`.

### API (REST, `X-GitHub-Api-Version: 2022-11-28`)

| Use | Call |
|---|---|
| Milestones | `GET /repos/{o}/{r}/milestones?state=all&per_page=100` |
| List | `GET /repos/{o}/{r}/issues?state=open\|all&milestone=<n>&sort=updated&direction=desc&per_page=100`, following `Link: rel="next"` for up to 5 pages; truncated → `500+` |
| Search | `GET /search/issues?q=repo:{o}/{r} is:issue <text>&sort=updated&order=desc&per_page=50` |
| One issue | `GET /repos/{o}/{r}/issues/{n}` |
| Comments | `GET /repos/{o}/{r}/issues/{n}/comments?per_page=100` |
| State | `PATCH /repos/{o}/{r}/issues/{n}` |
| Assign | `POST /repos/{o}/{r}/issues/{n}/assignees` |
| Me | `GET /user` |

- The list endpoint **returns pull requests too**: drop every item that has a
  `pull_request` key. Because of that a page can hold fewer than 100 issues,
  so pagination follows `Link`, not the item count.
- **State**: `open` → Open; `closed` with `state_reason` `not_planned` or
  `duplicate` → Not planned; any other closed issue → Closed.
- Header setup and status-code mapping are shared with `GithubApiService`
  through a small request helper next to it
  (`github_prs/data/github_http.dart`) rather than copied. `GithubConfig` and
  `GithubLabel` are reused from `github_prs/domain/`.

### Controller

`GithubIssuesController` mirrors `JiraIssuesController`:

- `syncToRepo(repo)` reloads when the repo, its owner/repo/token, or
  `issuesEnabled` changes; otherwise it only tracks the remembered
  milestone.
- A generation counter drops stale responses.
- It holds the search state, state and label filters, selection, `myLogin`,
  `refresh`, `search`, `selectMilestone`, `applyState`, `assignToMe`,
  and `onMilestoneSelected` (wired in `app.dart` to persist the pick through a
  new `WorkspaceController.updateGithubMilestone`).
- It is registered in `app.dart` as a
  `ChangeNotifierProxyProvider<WorkspaceController, GithubIssuesController>`,
  next to the Jira one.

### Config additions

Each new field needs the constructor, `fromJson`, `toJson` and `copyWith`;
nullable fields also need a `clearX` flag.

- `GithubConfig.issuesEnabled` (default `false`). The settings screen's
  debounced save rebuilds the config from its text fields, so it carries
  this flag over.
- `RepoConfig.githubMilestoneNumber` (`int?`, + `clearGithubMilestoneNumber`)
- `RepoConfig.githubIssues` (`Map<String, int>`)

### Shared UI lifted out of the Jira tab

These pieces are private in `jira_issues_tab.dart` / `jira_issue_dialog.dart`
today and would otherwise be copied. They move to
`lib/core/widgets/issue_list.dart` with no change in behaviour (the Jira tests
must still pass):

- the debounced search field;
- the filter chip (today's `_StatusChip`);
- the count badge;
- the error banner;
- the centred message;
- the "refreshed x ago" formatter;
- relative and absolute time formatting;
- the initials avatar;
- the dialog section label.

The GitHub label colour helpers (`_hexToColor`, `_readableForeground`) and
the label chip move out of `github_prs_tab.dart` into
`github_prs/presentation/widgets/github_styles.dart` (`githubLabelColor`,
`readableLabelForeground`, `GithubLabelChip`) so both tabs use them.

## Tests

Each mirrors an existing Jira test:

- `github_issue_test.dart`:
  - parsing (state reasons, PR items dropped, labels, assignees, type,
    missing fields);
  - cache JSON round trip.
- `github_issue_search_test.dart`: `123` / `#123` / text / qualifiers / empty.
- `github_milestone_test.dart`:
  - picker ordering;
  - fallback when the remembered milestone is gone.
- `github_issues_controller_test.dart` (fake service):
  - repo sync;
  - remembered milestone;
  - search in and out;
  - stale responses dropped;
  - state × label filtering;
  - selection pruning;
  - bulk change keeps failures selected;
  - assign to me, including the silently-ignored case.
- `github_issues_tab_test.dart`:
  - rows and columns;
  - chips;
  - bulk bar;
  - badge and title open the dialog;
  - ⌘-click and the row button call `openUrl`;
  - Assign to me hidden for my issues.
- `github_issue_dialog_test.dart`:
  - cached data shown, then refreshed;
  - state menu;
  - Open in GitHub.
- Additions to `worktree_naming_test.dart` (`worktreeNameForGithubIssue`),
  `repo_config_test.dart` (the new fields round-trip) and
  `repo_sidebar_sessions_test.dart` (sessions grouped under Issues).

## Done when

- A repo with GitHub configured and **Show issues tab** on has an Issues tab
  that does everything above, against a real repo. Run the debug instance on
  the alternate port:
  `flutter run -d macos --dart-define=AGENT_API_PORT=8766`.
- Repos without the setting look exactly as they do today.
- The Jira tab behaves exactly as before after the shared widgets move.
- `flutter analyze` is clean and `flutter test` passes.

## Out of scope (follow-ups)

- Agent API routes (`GET /v1/github/issues`, issue tags) and the matching
  tree-launcher skill docs.
- A `{github_issue}` placeholder for saved Claude prompts.
- Two-line sidebar session names with the GitHub issue title (the
  `JiraTitlesController` equivalent).
- Creating issues, editing title, body or labels, and commenting.
- GitHub Projects (v2) status fields (needs GraphQL).
- Linked PRs and branches in the dialog (timeline API).
- Notifications when an issue is assigned to me.
- A row-level "Open in Jira" button on the Jira tab, for symmetry.

## Decisions

1. **Opt-in per repo** (default off). The Jira tab and the Issues tab are
   independent: a repo can have both (Jira project key set and Show issues
   tab on), either one, or neither. A worktree can be linked to a Jira issue
   and a GitHub issue at the same time, and then shows both badges.
2. **Shared local tags** with Jira, not a separate GitHub tag set.
3. **Raw markdown** in the dialog for v1. Rendered markdown would need a new
   dependency (e.g. `flutter_markdown_plus`), and the app has none today.
4. **Label chips in the filter row.** Jira has no equivalent, but without
   them the default All open issues view has nothing useful to filter on.
5. **Worktree name** `<title-slug>-<number>`, with the id last as for Jira
   keys, not GitHub's own `<number>-<title-slug>`.
