#!/usr/bin/env python3

import json
import os
import sys
import urllib.error
import urllib.parse
import urllib.request


def base_url():
    return os.environ.get("KANBAN_API_BASE_URL", "http://127.0.0.1:8422").rstrip("/")


def request_json(method, path, *, query=None, payload=None):
    url = f"{base_url()}{path}"
    if query:
        encoded_query = urllib.parse.urlencode(query)
        if encoded_query:
            url = f"{url}?{encoded_query}"

    body = None
    headers = {"Accept": "application/json"}
    if payload is not None:
        body = json.dumps(payload).encode("utf-8")
        headers["Content-Type"] = "application/json"

    request = urllib.request.Request(url, data=body, headers=headers, method=method)
    try:
        with urllib.request.urlopen(request) as response:
            return response.getcode(), json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as error:
        try:
            payload = json.loads(error.read().decode("utf-8"))
        except Exception:
            payload = {"ok": False, "summary": str(error), "data": {}}
        return error.code, payload
    except urllib.error.URLError as error:
        return 1, {
            "ok": False,
            "summary": f"Could not reach TreeLauncher API at {base_url()}: {error.reason}",
            "data": {},
        }


def emit(status_code, payload):
    sys.stdout.write(json.dumps(payload, indent=2, sort_keys=True))
    sys.stdout.write("\n")
    if not payload.get("ok", False) or status_code >= 400:
        raise SystemExit(1)
