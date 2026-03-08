#!/usr/bin/env python3

import os
from pathlib import Path


def _candidate_homes() -> list[Path]:
    env_homes = [
        os.environ.get("COPILOT_HOME"),
        os.environ.get("CODEX_HOME"),
    ]
    homes = [Path(raw).expanduser() for raw in env_homes if raw]
    homes.extend([Path.home() / ".copilot", Path.home() / ".codex"])

    unique_homes: list[Path] = []
    seen: set[Path] = set()
    for home in homes:
        if home in seen:
            continue
        seen.add(home)
        unique_homes.append(home)
    return unique_homes


def default_skills_dir() -> Path:
    candidates = [home / "skills" for home in _candidate_homes()]
    for candidate in candidates:
        if candidate.exists():
            return candidate
    return candidates[0]


def default_validator_path() -> Path:
    candidate_paths: list[Path] = []
    for skills_dir in (home / "skills" for home in _candidate_homes()):
        candidate_paths.extend(
            [
                skills_dir / "skill-creator" / "scripts" / "quick_validate.py",
                skills_dir
                / ".system"
                / "skill-creator"
                / "scripts"
                / "quick_validate.py",
            ]
        )

    for candidate in candidate_paths:
        if candidate.exists():
            return candidate
    return candidate_paths[0]
