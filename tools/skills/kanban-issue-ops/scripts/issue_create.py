#!/usr/bin/env python3

import argparse

from kanban_issue_api import emit, request_json


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo-path", required=True)
    parser.add_argument("--project", required=True)
    parser.add_argument("--title", required=True)
    parser.add_argument("--description")
    parser.add_argument("--tag", action="append", default=[])
    parser.add_argument("--tags")
    parser.add_argument("--status")
    args = parser.parse_args()

    payload = {
        "repoPath": args.repo_path,
        "project": args.project,
        "title": args.title,
    }
    if args.description is not None:
        payload["description"] = args.description
    if args.tags is not None:
        payload["tags"] = args.tags
    elif args.tag:
        payload["tags"] = args.tag
    if args.status is not None:
        payload["status"] = args.status

    status_code, response = request_json("POST", "/api/issues", payload=payload)
    emit(status_code, response)


if __name__ == "__main__":
    main()
