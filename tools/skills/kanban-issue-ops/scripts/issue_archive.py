#!/usr/bin/env python3

import argparse

from kanban_issue_api import emit, request_json


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("issue_id")
    args = parser.parse_args()

    status_code, payload = request_json(
        "POST",
        f"/api/issues/{args.issue_id}/archive",
    )
    emit(status_code, payload)


if __name__ == "__main__":
    main()
