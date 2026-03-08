#!/usr/bin/env python3

import argparse

from kanban_issue_api import emit, request_json


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo-path", required=True)
    parser.add_argument("--name", required=True)
    parser.add_argument("--key", required=True)
    args = parser.parse_args()

    status_code, payload = request_json(
        "POST",
        "/api/projects",
        payload={
            "repoPath": args.repo_path,
            "name": args.name,
            "key": args.key,
        },
    )
    emit(status_code, payload)


if __name__ == "__main__":
    main()
