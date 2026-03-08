#!/usr/bin/env python3

import argparse
import shutil
import subprocess
import sys
from pathlib import Path

from skill_paths import default_skills_dir


REPO_ROOT = Path(__file__).resolve().parent.parent
SKILLS_ROOT = REPO_ROOT / "tools" / "skills"
DEFAULT_DEST = default_skills_dir()
VALIDATOR_SCRIPT = REPO_ROOT / "tools" / "validate_codex_skills.py"
IGNORE_PATTERNS = shutil.ignore_patterns("__pycache__", "*.pyc", "*.pyo")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Install repo-managed Copilot/Codex skills into the active skills directory.",
    )
    parser.add_argument(
        "--skill",
        action="append",
        dest="skills",
        help="Install only the named skill. Repeat to install more than one.",
    )
    parser.add_argument(
        "--dest",
        default=str(DEFAULT_DEST),
        help="Destination skills directory. Defaults to COPILOT_HOME/CODEX_HOME if set, otherwise ~/.copilot/skills.",
    )
    parser.add_argument(
        "--skip-validate",
        action="store_true",
        help="Skip validation before copying.",
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


def validate_skills(skill_dirs: list[Path]) -> None:
    command = [sys.executable, str(VALIDATOR_SCRIPT)]
    for skill_dir in skill_dirs:
        command.extend(["--skill", skill_dir.name])

    result = subprocess.run(command, cwd=REPO_ROOT, check=False)
    if result.returncode != 0:
        raise SystemExit(result.returncode)


def copy_skill(skill_dir: Path, dest_root: Path) -> Path:
    dest_path = dest_root / skill_dir.name
    if dest_path.exists():
        shutil.rmtree(dest_path)
    shutil.copytree(
        skill_dir,
        dest_path,
        copy_function=shutil.copy2,
        ignore=IGNORE_PATTERNS,
    )
    return dest_path


def main() -> int:
    args = parse_args()
    skill_dirs = resolve_skill_dirs(args.skills)
    dest_root = Path(args.dest).expanduser()

    if not args.skip_validate:
        validate_skills(skill_dirs)

    dest_root.mkdir(parents=True, exist_ok=True)
    for skill_dir in skill_dirs:
        installed_path = copy_skill(skill_dir, dest_root)
        print(f"[OK] Installed {skill_dir.name} -> {installed_path}")

    print(f"Installed {len(skill_dirs)} skill(s) into {dest_root}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
