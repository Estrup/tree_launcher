#!/usr/bin/env python3

import argparse

from kanban_issue_api import emit, request_json


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--issue-id")
    args = parser.parse_args()

    query = {}
    if args.issue_id is not None:
        query["displayId"] = args.issue_id

    status_code, payload = request_json(
        "GET",
        "/api/issues/diagnostics",
        query=query or None,
    )
    emit(status_code, payload)


if __name__ == "__main__":
    main()
