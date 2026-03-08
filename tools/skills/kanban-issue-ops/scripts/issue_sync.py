#!/usr/bin/env python3

import argparse
import json

from kanban_issue_api import emit, request_json


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo-path", required=True)
    parser.add_argument("--project", required=True)
    parser.add_argument(
        "--issues-json",
        required=True,
        help="JSON array of issue objects with title plus optional description, status, tags, and archive.",
    )
    args = parser.parse_args()

    try:
        issues = json.loads(args.issues_json)
    except json.JSONDecodeError as error:
        parser.error(f"--issues-json must be valid JSON: {error}")

    status_code, payload = request_json(
        "POST",
        "/api/issues/sync",
        payload={
            "repoPath": args.repo_path,
            "project": args.project,
            "issues": issues,
        },
    )
    emit(status_code, payload)


if __name__ == "__main__":
    main()
