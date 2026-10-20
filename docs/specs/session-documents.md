# Spec: Documents from sessions, with an in-app viewer

Status: implemented · 2026-10-20

## Goal

When a Claude session or agent run finishes its work, it writes a document
about the result: what was built and why, a clarification, a review, a
verification report. Today that document stays where the session wrote it
(the worktree's `.factory/`, the vault, a temp folder). At most it shows as a
link chip on the agent card, which opens it in another app. It disappears
with the worktree, and nothing lists the documents of an issue.

Tree Launcher should **keep** these documents, **tie** each one to the
session and issue it is about, and **show** them in an in-app viewer:

- A session saves a document in one request: Markdown, HTML or PDF.
- **A document is one self-contained file.** HTML carries its images,
  styles and scripts inline (`data:` URIs, `<style>`, `<script>`). The app
  stores that one file and nothing else.
- The app copies the file into its own data directory, so it outlives the
  worktree.
- Each document records the agent run, Claude session, worktree, repo,
  issue(s) and PR it is about.
- A **Documents** page per repo lists them. They also show on the agent
  card, on the worktree row and in the Jira issue dialog.
- One viewer, built on WKWebView, shows all three formats:
  - Markdown, rendered to HTML in the app's theme;
  - HTML, as written;
  - PDF, in WKWebView's own PDF view.

## Example

A build factory's ship stage writes `.factory/result.html`, with its
screenshots inlined as `data:` URIs, and saves it:

```bash
curl -s http://127.0.0.1:8765/v1/documents \
  -H 'Content-Type: application/json' \
  -d '{
    "agentId": "'"$TREE_LAUNCHER_AGENT_ID"'",
    "title": "Result: Vipps callback returns 500",
    "name": "result",
    "path": "/Users/estrup/Projects/au2-project/vipps-callback-au2-5407/.factory/result.html"
  }'
```

```json
{
  "id": "doc_k3m9q2xa",
  "repo": "au2office",
  "title": "Result: Vipps callback returns 500",
  "name": "result",
  "format": "html",
  "agentId": "ag_7f2kd91c",
  "agentKind": "build",
  "issueKeys": ["AU2-5407"],
  "worktreePath": "/Users/estrup/Projects/au2-project/vipps-callback-au2-5407",
  "branch": "feature/vipps-callback-au2-5407",
  "prNumber": 7123,
  "claudeSessionId": "5c1e…",
  "filePath": "/Users/estrup/Library/Application Support/com.treelauncher.treeLauncher/documents/doc_k3m9q2xa.html",
  "sizeBytes": 412893,
  "warnings": [],
  "createdAt": "2026-10-20T14:02:11.000",
  "updatedAt": "2026-10-20T14:02:11.000",
  "replaced": false
}
```

The repo, issue, worktree, branch, PR and Claude session come from the agent
run. The app shows a notice, *Document from Build AU2-5407: Result: Vipps
callback returns 500*, with **View**. The run's card gets a chip for the
document, and its timeline gets a *Document saved: Result: …* line.

The verify factory saves its PDF report the same way, with a `path` to the
`.pdf`.

With the tree-launcher skill's helper:

```bash
python3 scripts/agent.py doc --title "Result: Vipps callback returns 500" \
  --name result --file .factory/result.html
```

## What a document is

| Field | |
|---|---|
| `id` | `doc_` + 8 random characters, the same scheme as agent runs (`ag_…`). |
| `repo` | The repo name. Always set. |
| `title` | What the list and the viewer's header show. |
| `name` | Optional. A stable name within its agent run (`result`, `afklaring`, `review`). Saving the same name again in the same run **replaces** the document instead of adding one. |
| `format` | `markdown`, `html` or `pdf`. |
| `agentId`, `agentKind` | The agent run it came from, if any. The kind is copied, so filtering by kind still works after the run is deleted. |
| `claudeSessionId` | The Claude CLI session, if known. |
| `worktreePath`, `branch` | The worktree it is about, if any. Kept as text after the worktree is gone. |
| `issueKeys` | The Jira issues it is about, in order (a docs run can cover several). |
| `prNumber` | The PR it is about, if any. |
| `sourcePath` | Where the file was copied from, if it was a file. For information only: the app never reads it again. |
| `filePath` | The stored file in the data directory. |
| `sizeBytes` | The stored file's size. |
| `createdAt`, `updatedAt` | `updatedAt` changes when it is replaced. |

### Self-contained

The app stores exactly one file per document. It doesn't follow references,
copy neighbouring files or download anything. So:

- **HTML** puts its images in `data:` URIs, its CSS in `<style>` and its
  JavaScript in `<script>`.
- **Markdown** images use `data:` URIs too, or are left out. A report that
  needs screenshots is better written as HTML or PDF.
- **PDF** is self-contained by nature.

A relative reference (`<img src="shots/a.png">`, `![](shots/a.png)`,
`<link href="style.css">`) doesn't resolve in the viewer. A reference to the
web (`https://cdn…`) still loads while online. The convention is not to
rely on it, since a saved document should look the same offline and years
later.

To help a session get this right, saving still succeeds but the response
lists what won't resolve, for example:

```json
"warnings": ["relative reference won't resolve: shots/after.png", "remote reference: https://cdn.jsdelivr.net/npm/chart.js"]
```

The check is a pure function
(`features/documents/domain/document_references.dart`) over `src`, `srcset`,
`href` on stylesheets, `url(…)` in `<style>` and Markdown image targets. It
is not a full parser. PDFs aren't checked.

### Where it is stored

- **Metadata** in the database, in two new tables:
  - `documents`: one row per document with the fields above. `agentId` is
    plain text, not a foreign key, so a document outlives its run, as
    `worktree_events` outlive their worktrees.
  - `document_issues`: `documentId` (cascade on delete), `issueKey` and
    `position`, as `agent_run_issues`.
- **The file** in `<data dir>/documents/<id>.md`, `.html` or `.pdf`.
  `<data dir>` is `appDataDirectory()`, so `--dart-define=DATA_DIR=…` moves
  the documents too.
- **Rendered Markdown** goes in `<data dir>/documents/.view/<id>.html`. It
  is a cache, made when the document is viewed, and can be deleted at any
  time.

Replacing a document writes `<id>.<ext>.new`, then renames it over the old
file. If the format changed (say Markdown, then PDF), the old file is
removed after the rename. A viewer that has the document open reloads it.

## The agent API

Three routes in a new `DocumentRoutes`
(`lib/features/agent_api/data/routes/document_routes.dart`), all documented
in `docs/agent-api.md` (a **Documents** section and rows in the overview).

### `POST /v1/documents`

| Field | |
|---|---|
| `agentId` | Optional. The agent run it came from (`$TREE_LAUNCHER_AGENT_ID`). Its repo, worktree, branch, issues, PR and Claude session become the document's, unless given here. Unknown → **404**. |
| `repo` | Required without `agentId`. A repo name. With `agentId`, must be the run's repo if given. |
| `title` | Required. |
| `name` | Optional. See *What a document is*. Needs `agentId`; without it → **400**. |
| `content` | The document as text, for Markdown and HTML. Exactly one of `content` and `path`. Max 5 MB. |
| `path` | An absolute path to a `.md`, `.markdown`, `.html`, `.htm` or `.pdf` file to copy. Missing or unreadable → **400**. Max 50 MB. A PDF can only be given as a `path`. |
| `format` | `markdown` or `html`; required with `content`. With `path` it comes from the extension, and a `format` that disagrees → **400**. `pdf` with `content` → **400**. |
| `worktreePath` | Optional. The worktree it is about. Without `issueKeys`, the worktree's recorded Jira issue is used (`WorktreeMetadataController`). |
| `issueKeys` | Optional. A list of Jira keys, checked as elsewhere in the API. |
| `prNumber` | Optional. A number. |
| `claudeSessionId` | Optional. |
| `show` | Optional boolean, default `false`. Open the document in the app's viewer at once. Otherwise a notice offers **View**. |

A file given as `.pdf` must start with `%PDF-`. HTML and Markdown must be
valid UTF-8. Otherwise → **400**.

- **201** with the document (as in the example) when it is new.
- **200** with `"replaced": true` when `name` replaced the run's document of
  that name.
- **413** when `content` is over 5 MB or the file is over 50 MB. HTML with
  inlined screenshots gets large, which is why the file cap is the higher
  one.

Unknown fields → **400**, as on every route.

Saving through `agentId` also adds a timeline event to the run (*Document
saved: <title>*, or *Document updated: <title>*) through `AgentRegistry`,
and the run's card picks the document up from `DocumentsController`.

### `GET /v1/documents?repo=&agentId=&issueKey=&worktree=&kind=&format=`

The documents that match all the given filters, newest update first, as
metadata (no content). `repo` is optional. `worktree` is a folder name or a
path. `kind` is an agent kind. A filter's value that isn't valid (unknown
repo, kind, format) → **400**, as `GET /v1/agents` does.

### `GET /v1/documents/<id>`

The document's metadata, plus `content` (the file as text) for Markdown and
HTML. For a PDF there is no `content`; read it at `filePath`. So a refine
run started again can read its earlier *afklaring* and update it. **404**
when there is no such document.

There is no delete or update route. Documents are deleted in the app, and
replaced by saving under the same `name`.

### The seams

Following the existing pattern (`ManualPostWriter`, `AgentRegistry`):

- `DocumentLibrary` (in `features/documents/domain/`) reads documents and
  is implemented by `DocumentsController`.
- `DocumentSaver` (same place) is implemented by the use case
  `SaveDocument` (`lib/app/use_cases/save_document.dart`). It combines
  `AgentRegistry` (run lookup and the timeline event), the worktree
  metadata (issue from the worktree) and `DocumentsController` (the write).
  It is built in `AppDependencies` and passed to `AgentApiServer`.

### Sessions that aren't agent runs

Plain Claude sessions in the built-in terminal don't get
`TREE_LAUNCHER_AGENT_ID`. They save with `repo` + `worktreePath` (their
working directory) and get the worktree's issue from its metadata. To make
this possible without hard-coding the port, **every** Claude session the
app starts in the built-in terminal gets `TREE_LAUNCHER_URL`, not only
agent runs.

## The tree-launcher skill

Outside this repo (`~/.claude/skills/tree-launcher`):

- `scripts/agent.py doc --title … (--file <path> | --stdin --format markdown|html) [--name …]`.
  - It uses `$TREE_LAUNCHER_AGENT_ID` when set, and otherwise `--repo` plus
    the current directory as `worktreePath`.
  - It prints the response's `warnings`.
  - Like the helper's other commands, it prints a warning and exits 0 when
    the app can't be reached, so a session never fails over its report.
- The skill describes:
  - when to save a document: once, at the end, with the result, under a
    stable `name`;
  - that it must be self-contained, with screenshots inlined as `data:`
    URIs in HTML, or written as a PDF.
- The factory skills each call it in their final stage:
  - `factory`, `refine-factory`, `review-factory` and `docs-factory` save
    their Markdown or HTML result;
  - `verify-factory` saves the PDF report it already makes.

  Their existing files and Jira attachments stay as they are. That is a
  change in each skill, not in this app.

## In the app

### `DocumentsController`

`features/documents/presentation/controllers/documents_controller.dart`.
It is the one in-memory copy, built in `AppDependencies` and provided in
`app.dart`. It holds all documents' metadata (not their content) for all
repos and loads them at startup in the background, as the repos load.

- `documentsFor({repo, agentId, issueKey, worktreePath, kind, format})`
- `save(...)` and `delete(id)`: the store writes, then it notifies.
- `open(id)`: asks the shell to show the document (see below).
- `countFor(...)` for badges.

`DocumentStore` (`features/documents/data/`) owns the two tables and the
`documents/` folder. Deleting a document removes its row, its file and its
rendered cache.

### The Documents page

A new repo page (`documentsPageKey = 'documents'` in `repo_pages.dart`),
before Activity, shown when the repo has at least one document. Its icon is
`Icons.article_outlined`.

A list on the left and the viewer on the right:

- **List rows:**
  - the title;
  - the agent kind's icon and colour (`agent_kind_style.dart`), or a plain
    icon for a non-agent document;
  - a small format tag (MD, HTML, PDF);
  - the issue key chips;
  - the worktree's folder name;
  - the relative time.

  Rows are grouped Today / Yesterday / This week / Older.
- **Filters:** a search field (title, issue key, worktree), kind chips,
  and "This worktree's issue" when opened from a worktree. They work in
  memory, as `IssueListController`'s search does.
- **The selection** is remembered per repo while the app runs (in
  `DocumentsController`), not across restarts.
- **Right-click a row:** Open in default app, Reveal in Finder, Copy path,
  Delete (with a confirm).

### Elsewhere

- **The agent card** (`agent_card.dart`): one chip per document of the run,
  next to the link chips, with `Icons.article_outlined`, or
  `Icons.picture_as_pdf_outlined` for a PDF. Clicking it opens the viewer.

  Link chips that point to a local `.md`, `.html` or `.pdf` file also open
  in the viewer, read in place and not saved, with a *Save to Documents*
  button. Other links open as today.
- **The worktree row:** a small documents badge with a count, when the
  worktree or its issue has documents. Clicking it opens a menu of them, and
  choosing one opens the viewer.
- **The Jira issue dialog** (`jira_issue_dialog.dart`): a *Documents*
  section with the issue's documents across repos.
- **The sidebar's sessions:** an agent run's session counts the documents
  that run saved; a remembered Claude session counts those about its
  worktree or its issue. The count sits beside the session's Jira badge,
  and the session's right-click menu lists the documents.
- **The Jira list:** a count after an issue's summary, for the issue's
  documents across repos.
- **The PRs list:** a count after a PR's title, for the documents about
  that PR or its Jira issue.

Every count is the same badge (`DocumentsBadge`): a click lists the
documents, and choosing one opens it in the viewer dialog.
- **Notices:** a document saved through the API shows *Document from
  <run title or worktree>: <title>* with **View** (`showAppSnackBar`), unless
  `show` already opened it.

### Opening a document

There are two places, both using the same `DocumentViewer` widget:

1. **On the Documents page**, in its right-hand pane, when chosen from the
   list.
2. **In a large dialog** (`showDocumentDialog`, about 90 % of the window),
   when opened from anywhere else: card, worktree badge, issue dialog,
   notice, `show: true`. This keeps the user where they were. The dialog's
   header has *Open in Documents page*.

### The viewer

`DocumentViewer`
(`features/documents/presentation/widgets/document_viewer.dart`):

- **A header** with:
  - the title;
  - the issue key chips (a click opens the Jira issue dialog);
  - *From <run title>* (a click selects the run's agent page) or the
    worktree's name;
  - the time.

  Actions: Reload, Open in default app (`openExternal` on the file: the
  browser for HTML, Preview for PDF), Reveal in Finder, Copy path, Delete.
- **The body** is a WKWebView through `webview_flutter`
  (`webview_flutter_wkwebview` supports macOS). If the spike (see *Plan*)
  shows it can't, the fallback is `flutter_inappwebview`. Every format is
  loaded from a file with `loadFile`:
  - **HTML:** the stored `.html`, as written.
  - **Markdown:** rendered to HTML by a pure function
    (`features/documents/domain/markdown_html.dart`).
    - It uses the `markdown` package with GitHub-flavoured extensions
      (tables, task lists, fenced code, strikethrough, autolinks) and allows
      raw HTML.
    - The result is wrapped in a page whose stylesheet follows the app's
      palette, light or dark.
    - The page is written to `.view/<id>.html` and re-rendered when the
      document or the palette changes.
  - **PDF:** the stored `.pdf`, in WKWebView's built-in PDF view (scroll,
    zoom with pinch or Cmd +/-, select and copy text). It isn't themed.
- **Navigation:**
  - links within the document (`#anchors`) load in place;
  - `http(s)` and `mailto` links open outside with `openExternal`;
  - anything else is blocked.

  JavaScript is on, because agent-written HTML reports may use inline
  scripts for charts or collapsible sections.
- **Keys:** Cmd+R reloads and Esc closes the dialog. Text can be selected
  and copied, which WKWebView handles itself.

## Plan

1. **Spike the WebView:** `webview_flutter` 4.14 supports macOS (through
   `webview_flutter_wkwebview`), and its `loadFile` passes WebKit a read
   scope, so it is used; `flutter_inappwebview` isn't needed.
2. **Tables and store:** add `documents` and `document_issues`. Then
   regenerate, bump `schemaVersion` 3 → 4, add the migration step, dump the
   schema, generate the test helpers and add the step to
   `test/database_migration_test.dart`, as CLAUDE.md lists. Then
   `DocumentStore` with its files.
3. **`DocumentsController`, `SaveDocument`**, the reference check, the
   routes and `docs/agent-api.md`.
4. **`TREE_LAUNCHER_URL`** for every built-in-terminal Claude session.
5. **The viewer** and the Markdown renderer.
6. **The Documents page**, then the card chips, the worktree badge, the
   issue dialog section and the notice.
7. **The skill's `agent.py doc`** and a line in each factory skill (outside
   the repo).

## Tests

- **Reference check** (`document_references.dart`):
  - relative `src`, `srcset`, stylesheets, `url()` and Markdown images are
    reported as not resolving;
  - `https:` references are reported as remote;
  - `data:` URIs and `#anchors` aren't reported.
- **Markdown → HTML:** tables, task lists, fenced code, raw HTML pass
  through, the stylesheet switches with the palette, and the title is
  escaped.
- **Store** (`testDatabase()` and a temp folder):
  - saving with content, with an HTML path and with a PDF path;
  - replacing by name: the file is swapped, `updatedAt` changes, and a
    format change removes the old file;
  - deleting: row, file and cache gone, issues cascade;
  - filters.
- **`SaveDocument`:** the run's repo, worktree, issues, PR and session are
  inherited; given fields win; the worktree's recorded issue is used without
  `issueKeys`; a timeline event is added; an unknown run → not found.
- **Routes** (`test/agent_api_server_test.dart`, with a fake saver and
  library):
  - each 400:
    - neither or both of `content`/`path`;
    - a format that disagrees with the extension;
    - `pdf` as `content`;
    - a `.pdf` that isn't one;
    - `name` without `agentId`;
    - unknown fields;
    - a bad issue key;
  - 404 for an unknown run or document; 413 over each cap;
  - 201 vs 200 `replaced`, and `warnings` in the body.

  `test/agent_api_doc_test.dart` covers the doc sections.
- **Widgets** (in-memory fakes): the Documents page appears with the first
  document, the list filters, the card shows a chip per document with the
  PDF icon for a PDF, and the worktree badge counts. The WebView itself is
  replaced by a fake in widget tests.

## Done when

- The example request, sent to a debug instance
  (`flutter run -d macos --dart-define=AGENT_API_PORT=8766`) from an agent
  run, saves the HTML report. The notice offers View, and the viewer shows
  it as written, inlined screenshots included. Its external links open in
  the browser.
- A Markdown result shows rendered in the app's theme, light and dark.
- A verify-factory PDF report saves and shows in the viewer, scrollable and
  zoomable.
- An HTML file with a relative `<img src>` saves with a warning naming it.
- Sending a document again with the same `name` replaces it (200,
  `replaced`), and an open viewer reloads.
- The document is listed on the repo's Documents page, on the run's card,
  on the worktree row and in AU2-5407's issue dialog. It is still there
  after the worktree is deleted.
- A plain Claude session in a worktree can save with `repo` +
  `worktreePath` and gets the worktree's issue.
- `docs/agent-api.md` documents the three routes, `flutter analyze` is
  clean and `flutter test` passes.

## Out of scope (follow-ups)

- **Bundling referenced files** (copying the images or stylesheets next to
  an HTML file). Documents are self-contained by convention; see
  Decisions 3.
- **Version history** of a replaced document. Replace overwrites. A new
  run with the same `name` makes a new document, so runs already give a
  history per run.
- **Documents in the daily backup.** `backups/` copies only the database;
  the `documents/` folder isn't backed up.
- **GitHub issues** as a link (`githubIssue` number) next to Jira keys, and
  a Documents section in the GitHub issue dialog.
- **Find in page and printing.** *Open in default app* covers these for
  now.
- **Mermaid diagrams and syntax highlighting** in Markdown. Both mean
  bundling a JS library with the app.
- **Editing documents** in the app.
- **Picking documents up automatically** from a folder in the worktree
  (see Decisions 1).
- **A delete route** in the API.
- **Retention** or automatic clean-up.

## Decisions

1. **The session saves its document explicitly through the API.** The app
   doesn't watch a folder (`<worktree>/.tree-launcher/documents/`) or scrape
   transcripts. An explicit save has a title and links, happens once, at the
   point the session knows it is done, and works for files anywhere (vault,
   `.factory/`, temp). A watched folder would need its own conventions for
   titles and replacing, and lives in the worktree that is about to be
   deleted.
2. **The document is copied in.** The app doesn't keep a reference to the
   session's file. That is the point of the feature: the worktree, its
   `.factory/` and temp files go away, and the document must not.
3. **One self-contained file per document.** HTML inlines its assets, so
   the app stores, replaces and deletes exactly one file. It never has to
   guess which neighbouring files belong to a document, and a document can
   be opened, mailed or attached to Jira on its own and still look right.
   The cost is larger HTML files (base64 images), which the 50 MB cap
   allows for. The warnings tell a session when it got this wrong, without
   failing its save.
4. **Files on disk, metadata in the database.** PDFs are binary, and
   WKWebView loads files best, so the content isn't put in a database blob.
   The metadata goes in the database, so filters, counts and joins with
   issues are queries like the rest.
5. **One WebView viewer for all three formats.** Markdown is rendered to
   HTML rather than shown with a Flutter Markdown widget, and PDFs use
   WKWebView's own PDF view rather than a Flutter PDF package. So every
   format scrolls, selects and links the same, with one widget to maintain.
   (The Flutter Markdown packages were also in flux: `flutter_markdown` is
   discontinued.) HTML and PDF are shown as written, not restyled: they are
   the author's layout.
6. **PDF only as a file.** Agents make PDFs as files (the verify factory
   already does), so `path` covers it. That keeps the JSON route free of
   base64 payloads.
7. **Replace by `name` within an agent run, never across runs.** A refine
   factory re-run that wants the same document passes the earlier
   document's content forward (it can `GET` it) and saves under its own run.
   This keeps "which run produced this" true for every document.
8. **Dialog from elsewhere, pane on the Documents page.** Opening a
   document from a card or issue doesn't move the user off the page they
   are on. Browsing many documents happens on the page.
9. **JavaScript on, navigation contained.** Reports are written by the
   user's own agents on their own machine. Disabling JS would break inline
   scripts in legitimate reports. The protection that matters is that
   clicks never navigate the viewer away to the web or to local files.
