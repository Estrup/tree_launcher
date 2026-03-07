#!/usr/bin/env python3

import argparse
import os
import subprocess
import sys
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parent.parent
SKILLS_ROOT = REPO_ROOT / "tools" / "skills"
DEFAULT_VALIDATOR = (
    Path(os.environ.get("CODEX_HOME", Path.home() / ".codex"))
    / "skills"
    / ".system"
    / "skill-creator"
    / "scripts"
    / "quick_validate.py"
)
REQUIRED_FILES = ("SKILL.md", "agents/openai.yaml")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Validate repo-managed Codex skills.",
    )
    parser.add_argument(
        "--skill",
        action="append",
        dest="skills",
        help="Validate only the named skill. Repeat to validate more than one.",
    )
    parser.add_argument(
        "--validator",
        default=str(DEFAULT_VALIDATOR),
        help="Path to skill-creator quick_validate.py.",
    )
    return parser.parse_args()


def resolve_skill_dirs(skill_names: list[str] | None) -> list[Path]:
    if not SKILLS_ROOT.exists():
        raise SystemExit(f"Skills root does not exist: {SKILLS_ROOT}")

    if skill_names:
        skill_dirs = [SKILLS_ROOT / skill_name for skill_name in skill_names]
    else:
        skill_dirs = sorted(
            path for path in SKILLS_ROOT.iterdir() if path.is_dir() and not path.name.startswith(".")
        )

    if not skill_dirs:
        raise SystemExit(f"No skills found in {SKILLS_ROOT}")

    missing = [path for path in skill_dirs if not path.exists()]
    if missing:
        missing_names = ", ".join(path.name for path in missing)
        raise SystemExit(f"Unknown skill(s): {missing_names}")

    return skill_dirs


def check_required_files(skill_dir: Path) -> None:
    missing = [relative for relative in REQUIRED_FILES if not (skill_dir / relative).exists()]
    if missing:
        joined = ", ".join(missing)
        raise RuntimeError(f"{skill_dir.name} is missing required file(s): {joined}")


def run_external_validator(skill_dir: Path, validator_path: Path) -> None:
    if not validator_path.exists():
        raise RuntimeError(
            f"Validator not found at {validator_path}. "
            "Install the skill-creator system skill or pass --validator."
        )

    result = subprocess.run(
        [sys.executable, str(validator_path), str(skill_dir)],
        capture_output=True,
        text=True,
        check=False,
    )
    if result.returncode != 0:
        output = (result.stdout + result.stderr).strip()
        raise RuntimeError(output or f"Validation failed for {skill_dir.name}")


def main() -> int:
    args = parse_args()
    validator_path = Path(args.validator).expanduser()
    skill_dirs = resolve_skill_dirs(args.skills)

    for skill_dir in skill_dirs:
        check_required_files(skill_dir)
        run_external_validator(skill_dir, validator_path)
        print(f"[OK] {skill_dir.name}")

    print(f"Validated {len(skill_dirs)} skill(s) from {SKILLS_ROOT}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
