#!/usr/bin/env python3

import argparse

from kanban_issue_api import emit, request_json


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo-path")
    parser.add_argument("--query")
    parser.add_argument("--include-archived", action="store_true")
    args = parser.parse_args()

    query = {}
    if args.repo_path is not None:
        query["repoPath"] = args.repo_path
    if args.query is not None:
        query["query"] = args.query
    query["includeArchived"] = str(args.include_archived).lower()

    status_code, payload = request_json(
        "GET",
        "/api/projects",
        query=query,
    )
    emit(status_code, payload)


if __name__ == "__main__":
    main()
