#!/usr/bin/env python3

import argparse

from kanban_issue_api import emit, request_json


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo-path", required=True)
    parser.add_argument("--project", required=True)
    parser.add_argument("--include-archived", action="store_true")
    args = parser.parse_args()

    status_code, payload = request_json(
        "GET",
        "/api/issues",
        query={
            "repoPath": args.repo_path,
            "project": args.project,
            "includeArchived": str(args.include_archived).lower(),
        },
    )
    emit(status_code, payload)


if __name__ == "__main__":
    main()
