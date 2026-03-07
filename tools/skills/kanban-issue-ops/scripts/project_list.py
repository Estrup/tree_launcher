#!/usr/bin/env python3

import argparse

from kanban_issue_api import emit, request_json


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo-path", required=True)
    args = parser.parse_args()

    status_code, payload = request_json(
        "GET",
        "/api/projects",
        query={"repoPath": args.repo_path},
    )
    emit(status_code, payload)


if __name__ == "__main__":
    main()
