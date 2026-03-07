#!/usr/bin/env python3

import argparse

from kanban_issue_api import emit, request_json


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("issue_id")
    parser.add_argument("--title")
    parser.add_argument("--description")
    parser.add_argument("--clear-description", action="store_true")
    parser.add_argument("--tag", action="append", default=[])
    parser.add_argument("--tags")
    parser.add_argument("--status")
    args = parser.parse_args()

    payload = {}
    if args.title is not None:
        payload["title"] = args.title
    if args.clear_description:
        payload["description"] = None
    elif args.description is not None:
        payload["description"] = args.description
    if args.tags is not None:
        payload["tags"] = args.tags
    elif args.tag:
        payload["tags"] = args.tag
    if args.status is not None:
        payload["status"] = args.status

    if not payload:
        parser.error("at least one field must be provided")

    status_code, response = request_json(
        "PATCH",
        f"/api/issues/{args.issue_id}",
        payload=payload,
    )
    emit(status_code, response)


if __name__ == "__main__":
    main()
