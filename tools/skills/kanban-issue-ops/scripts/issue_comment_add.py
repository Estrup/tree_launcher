#!/usr/bin/env python3

import argparse

from kanban_issue_api import emit, request_json


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("issue_id")
    parser.add_argument("--content", required=True)
    parser.add_argument("--author-name", default="Codex")
    parser.add_argument("--author-type", default="agent")
    args = parser.parse_args()

    status_code, payload = request_json(
        "POST",
        f"/api/issues/{args.issue_id}/comments",
        payload={
            "content": args.content,
            "authorName": args.author_name,
            "authorType": args.author_type,
        },
    )
    emit(status_code, payload)


if __name__ == "__main__":
    main()
