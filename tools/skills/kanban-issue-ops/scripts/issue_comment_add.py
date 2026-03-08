#!/usr/bin/env python3

import argparse

from kanban_issue_api import emit, request_json


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("issue_id")
    parser.add_argument("--repo-path")
    parser.add_argument("--project")
    parser.add_argument("--content", required=True)
    parser.add_argument("--author-name", default="Codex")
    parser.add_argument("--author-type", default="agent")
    args = parser.parse_args()

    query = {}
    if args.repo_path is not None:
        query["repoPath"] = args.repo_path
    if args.project is not None:
        query["project"] = args.project

    status_code, payload = request_json(
        "POST",
        f"/api/issues/{args.issue_id}/comments",
        query=query or None,
        payload={
            "content": args.content,
            "authorName": args.author_name,
            "authorType": args.author_type,
        },
    )
    emit(status_code, payload)


if __name__ == "__main__":
    main()
