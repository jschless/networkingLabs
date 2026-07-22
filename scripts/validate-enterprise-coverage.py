#!/usr/bin/env python3
"""Validate the machine-readable enterprise coverage inventory.

Run from anywhere:
    python3 scripts/validate-enterprise-coverage.py [coverage-file]

The validator deliberately checks repository evidence rather than trusting a
label in the inventory.  A practice/troubleshooting topic (level 3+) must point
at labs that have an automated ``check.sh``.  Blind-assessed topics (level 5)
also need explicit scenario metadata.
"""

from __future__ import annotations

import sys
from pathlib import Path
from typing import Any

import yaml


REPO = Path(__file__).resolve().parent.parent
DEFAULT_INVENTORY = REPO / "docs" / "enterprise-coverage.yaml"
REQUIRED_FIELDS = {
    "domain",
    "topic",
    "level",
    "labs",
    "fidelity",
    "last_live_validation",
    "owner",
    "notes",
}
VALID_LEVELS = set(range(6))


def display(path: Path) -> str:
    try:
        return str(path.relative_to(REPO))
    except ValueError:
        return str(path)


def error(errors: list[str], row: int, message: str) -> None:
    errors.append(f"topic #{row}: {message}")


def validate_topic(topic: Any, row: int, errors: list[str]) -> None:
    if not isinstance(topic, dict):
        error(errors, row, "must be a mapping")
        return

    missing = sorted(REQUIRED_FIELDS - set(topic))
    if missing:
        error(errors, row, f"missing required field(s): {', '.join(missing)}")
        return

    for field in ("domain", "topic", "fidelity", "owner", "notes"):
        if not isinstance(topic[field], str) or not topic[field].strip():
            error(errors, row, f"{field!r} must be a non-empty string")

    level = topic["level"]
    if isinstance(level, bool) or not isinstance(level, int) or level not in VALID_LEVELS:
        error(errors, row, "level must be an integer from 0 through 5")
        return

    labs = topic["labs"]
    if not isinstance(labs, list) or not all(isinstance(lab, str) for lab in labs):
        error(errors, row, "labs must be a list of repository-relative paths")
        return
    if level >= 3 and not labs:
        error(errors, row, f"level {level} topic must register at least one checked lab")

    for lab in labs:
        relative_lab = Path(lab)
        lab_path = REPO / relative_lab
        if (
            len(relative_lab.parts) != 2
            or relative_lab.parts[0] != "labs"
            or not lab_path.is_dir()
        ):
            error(errors, row, f"lab path does not exist: {lab}")
            continue
        if level >= 3 and not (lab_path / "check.sh").is_file():
            error(errors, row, f"level {level} lab lacks check.sh: {lab}")

    if level == 5:
        metadata = topic.get("scenario_metadata")
        if not isinstance(metadata, dict) or not metadata:
            error(errors, row, "level 5 topic requires non-empty scenario_metadata")
            return
        root = metadata.get("root")
        if not isinstance(root, str) or not (REPO / root).is_dir():
            error(errors, row, "level 5 scenario_metadata.root must be an existing directory")


def main() -> int:
    inventory = Path(sys.argv[1]).resolve() if len(sys.argv) == 2 else DEFAULT_INVENTORY
    if len(sys.argv) > 2:
        print("usage: validate-enterprise-coverage.py [coverage-file]", file=sys.stderr)
        return 2
    if not inventory.is_file():
        print(f"FAIL — inventory does not exist: {display(inventory)}")
        return 1

    try:
        document = yaml.safe_load(inventory.read_text())
    except yaml.YAMLError as exc:
        print(f"FAIL — YAML parse error in {display(inventory)}: {exc}")
        return 1

    if not isinstance(document, dict) or not isinstance(document.get("topics"), list):
        print(f"FAIL — {display(inventory)} must contain a top-level topics list")
        return 1

    errors: list[str] = []
    for row, topic in enumerate(document["topics"], start=1):
        validate_topic(topic, row, errors)

    if errors:
        print(f"FAIL — {len(errors)} finding(s) in {display(inventory)}:")
        for finding in errors:
            print(f"  - {finding}")
        return 1

    print(f"OK — {len(document['topics'])} enterprise coverage topic(s) validated")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
