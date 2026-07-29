#!/usr/bin/env python3
"""Validate the repository troubleshooting-ticket directory contract."""

from __future__ import annotations

import os
import re
import subprocess
import sys
from pathlib import Path


REQUIRED = {
    "metadata.env",
    "ticket.md",
    "inject.sh",
    "clear.sh",
    "verify.sh",
    "rubric.md",
}
METADATA_KEYS = {
    "tier",
    "domain",
    "estimated_time",
    "topology_version",
    "parameterization",
}
TICKET_FIELDS = (
    "reported by",
    "impact",
    "symptom",
    "diagnose",
    "fix",
    "verify",
    "write-up",
)
RUBRIC_FIELDS = (
    "root cause",
    "pass threshold",
    "time band",
    "diagnostic decision path",
    "weighted evidence milestones",
    "deduction",
    "red flags",
    "verify.sh",
)
SPOILERS = (
    r"\biptables\b",
    r"\bip6tables\b",
    r"\bnft(?:ables)?\b",
    r"\bcloud-edge\b",
    r"\borigin-[a-z0-9-]+\b",
    r"\bmanaged-client\b",
    r"\bcontainerlab\b",
    r"\bdocker exec\b",
    r"\broot cause\b",
)


def fail(messages: list[str]) -> None:
    for message in messages:
        print(f"ERROR: {message}", file=sys.stderr)
    raise SystemExit(1)


def parse_metadata(path: Path, errors: list[str]) -> dict[str, str]:
    data: dict[str, str] = {}
    for number, raw in enumerate(path.read_text().splitlines(), 1):
        if not raw or raw.startswith("#"):
            continue
        if not re.fullmatch(r"[a-z_]+=[A-Za-z0-9._:/+-]+", raw):
            errors.append(f"{path}:{number}: invalid metadata assignment")
            continue
        key, value = raw.split("=", 1)
        if key in data:
            errors.append(f"{path}:{number}: duplicate metadata key {key}")
        data[key] = value
    missing = METADATA_KEYS - data.keys()
    extra = data.keys() - METADATA_KEYS
    if missing:
        errors.append(f"metadata missing keys: {', '.join(sorted(missing))}")
    if extra:
        errors.append(f"metadata has unknown keys: {', '.join(sorted(extra))}")
    return data


def main() -> None:
    if len(sys.argv) != 2:
        fail(["usage: scripts/validate_ticket.py <scenario-dir>"])
    scenario = Path(sys.argv[1]).resolve()
    errors: list[str] = []
    if not scenario.is_dir():
        fail([f"not a scenario directory: {scenario}"])

    present = {path.name for path in scenario.iterdir() if path.is_file()}
    missing = REQUIRED - present
    if missing:
        errors.append(f"missing required files: {', '.join(sorted(missing))}")
    if errors:
        fail(errors)

    metadata = parse_metadata(scenario / "metadata.env", errors)
    match = re.fullmatch(r"t([123])-[a-z0-9]+(?:-[a-z0-9]+)*", scenario.name)
    if not match:
        errors.append("scenario directory must match t<tier>-<slug>")
    elif metadata.get("tier") != match.group(1):
        errors.append("metadata tier does not match directory tier")
    if metadata.get("estimated_time") and not re.fullmatch(
        r"[1-9][0-9]*m", metadata["estimated_time"]
    ):
        errors.append("estimated_time must be a positive minute value such as 20m")
    if metadata.get("topology_version") and not re.fullmatch(
        r"[0-9]+\.[0-9]+\.[0-9]+(?:-draft)?", metadata["topology_version"]
    ):
        errors.append("topology_version must be semantic version or semantic version-draft")

    ticket = (scenario / "ticket.md").read_text()
    ticket_lower = ticket.lower()
    if not re.search(r"^# Ticket [A-Z0-9-]+ — ", ticket, re.MULTILINE):
        errors.append("ticket must begin with a ticket number and title")
    for field in TICKET_FIELDS:
        if field not in ticket_lower:
            errors.append(f"ticket missing standard field/request: {field}")
    for pattern in SPOILERS:
        if re.search(pattern, ticket_lower):
            errors.append(f"ticket contains proctor-only/spoiling term matching {pattern}")

    rubric = (scenario / "rubric.md").read_text().lower()
    for field in RUBRIC_FIELDS:
        if field not in rubric:
            errors.append(f"rubric missing required content: {field}")
    if not re.search(r"\b100\b", rubric):
        errors.append("rubric must define a 100-point scorecard")

    for script_name in ("inject.sh", "clear.sh", "verify.sh"):
        script = scenario / script_name
        if not os.access(script, os.X_OK):
            errors.append(f"{script_name} is not executable")
            continue
        result = subprocess.run(
            ["bash", "-n", str(script)], capture_output=True, text=True, check=False
        )
        if result.returncode:
            errors.append(f"{script_name} fails bash -n: {result.stderr.strip()}")

    if errors:
        fail(errors)
    print(f"OK — ticket contract validated: {scenario}")


if __name__ == "__main__":
    main()
