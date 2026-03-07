---
name: kanban-issue-ops
description: Read, create, update, archive, and comment on TreeLauncher's local SQLite-backed kanban issues through the app's local HTTP API. Use when an agent needs to inspect projects or issues, create a new issue, change title/description/tags/status, archive an issue, or add issue comments without touching the database directly.
---

# Kanban Issue Ops

## Overview

Use the local API exposed by the running TreeLauncher app instead of reading SQLite directly. Prefer the bundled scripts so request shapes stay consistent and failures return structured JSON.

## Preconditions

- Ensure TreeLauncher is running.
- Ensure remote control is enabled in the app settings.
- Assume the local API base URL is `http://127.0.0.1:8422` unless `KANBAN_API_BASE_URL` is set.
- Never mutate an issue until it has been resolved to a single display ID like `PRO-001`.

## Workflow

1. Discover the target project or issue.
2. Resolve ambiguous names before mutating anything.
3. Perform the mutation with the smallest script that fits the task.
4. Read back the updated issue when the user asked for confirmation or when the mutation changes multiple fields.

## Discovery

- List projects for a repo with `scripts/project_list.py --repo-path /abs/repo/path`.
- List issues for a project with `scripts/issue_list.py --repo-path /abs/repo/path --project PRO`.
- Fetch a specific issue with `scripts/issue_get.py PRO-001`.
- If multiple repos could contain the same display ID, do not guess. Ask for the repo or project context, or inspect project lists first.

## Mutations

- Create: `scripts/issue_create.py --repo-path /abs/repo/path --project PRO --title "Add API" --description "..."`
- Update title, description, tags, or status: `scripts/issue_update.py PRO-001 ...`
- Archive: `scripts/issue_archive.py PRO-001`
- Comment: `scripts/issue_comment_add.py PRO-001 --content "..." --author-name Codex`

Use these rules:

- Use `--clear-description` when the intent is to remove the description.
- Use status values exactly as `todo`, `inProgress`, `inReview`, or `done`.
- Pass tags either with repeated `--tag` flags or `--tags a,b`.
- Default comment authors to `agent` unless the task explicitly needs `user`.

## Scripts

- `scripts/project_list.py`: list projects in a repo.
- `scripts/issue_list.py`: list issues in one project.
- `scripts/issue_get.py`: fetch one issue by display ID.
- `scripts/issue_create.py`: create an issue in a project.
- `scripts/issue_update.py`: update title, description, tags, or status.
- `scripts/issue_archive.py`: archive one issue.
- `scripts/issue_comment_add.py`: add a comment to one issue.

All scripts print JSON. Treat non-zero exit codes as failed API calls and surface the API summary to the user instead of inventing success.
