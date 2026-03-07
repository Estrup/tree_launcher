#!/usr/bin/env python3

import argparse

from kanban_issue_api import emit, request_json


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo-path", required=True)
    parser.add_argument("--project", required=True)
    parser.add_argument("--title", required=True)
    parser.add_argument("--description")
    args = parser.parse_args()

    payload = {
        "repoPath": args.repo_path,
        "project": args.project,
        "title": args.title,
    }
    if args.description is not None:
        payload["description"] = args.description

    status_code, response = request_json("POST", "/api/issues", payload=payload)
    emit(status_code, response)


if __name__ == "__main__":
    main()
