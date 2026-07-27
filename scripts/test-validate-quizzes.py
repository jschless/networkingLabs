#!/usr/bin/env python3
"""Regression tests for validate-quizzes.py using disposable repositories."""

from __future__ import annotations

import subprocess
import sys
import tempfile
from collections.abc import Callable
from pathlib import Path


VALIDATOR = Path(__file__).resolve().with_name("validate-quizzes.py")

QUIZ = """\
# Sample Quiz

**Time:** 25 minutes · **Total:** 20 points · **Closed book, no CLI**

## Section 1 — Mechanisms (5 points)

1. Explain a mechanism. (5)

## Section 2 — Evidence (5 points)

1. Read supplied evidence. (5)

## Section 3 — Application (5 points)

1. Apply the mechanism. (5)

## Section 4 — Troubleshooting (5 points)

1. Troubleshoot a changed topology. (5)

[Answer key](../answer-keys/quizzes/sample-key.md)
"""

KEY = """\
# Sample Quiz — Answer Key

**Total:** 20 points

## Section 1 — Mechanisms (5 points)

1. Model answer. (5)

## Remediation

| Weak area | Review |
|---|---|
| Sample objective | `labs/sample-lab/` |
"""

QUIZ_CATALOG = """\
# Topic Quizzes

| Quiz | Prerequisite labs | Time | Points |
|---|---|---:|---:|
| [Sample](sample.md) | `sample-lab` | 25 min | 20 |
"""

KEY_CATALOG = """\
# Topic Quiz Answer Keys

| Key | Quiz |
|---|---|
| [sample-key.md](sample-key.md) | [Sample](../../quizzes/sample.md) |
"""


def make_fixture(root: Path) -> None:
    quiz_dir = root / "assessments" / "quizzes"
    key_dir = root / "assessments" / "answer-keys" / "quizzes"
    quiz_dir.mkdir(parents=True)
    key_dir.mkdir(parents=True)
    (root / "labs" / "sample-lab").mkdir(parents=True)
    (quiz_dir / "sample.md").write_text(QUIZ)
    (quiz_dir / "README.md").write_text(QUIZ_CATALOG)
    (key_dir / "sample-key.md").write_text(KEY)
    (key_dir / "README.md").write_text(KEY_CATALOG)


def run_validator(root: Path) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [sys.executable, str(VALIDATOR), "--repo", str(root)],
        check=False,
        capture_output=True,
        text=True,
    )


def assert_valid() -> None:
    with tempfile.TemporaryDirectory() as directory:
        root = Path(directory)
        make_fixture(root)
        result = run_validator(root)
        if result.returncode != 0:
            raise AssertionError(f"valid fixture failed:\n{result.stdout}")


def assert_rejected(
    name: str, mutate: Callable[[Path], object], expected_message: str
) -> None:
    with tempfile.TemporaryDirectory() as directory:
        root = Path(directory)
        make_fixture(root)
        mutate(root)
        result = run_validator(root)
        if result.returncode == 0:
            raise AssertionError(f"{name}: invalid fixture unexpectedly passed")
        if expected_message not in result.stdout:
            raise AssertionError(
                f"{name}: expected {expected_message!r} in:\n{result.stdout}"
            )


def replace(path: Path, old: str, new: str) -> None:
    path.write_text(path.read_text().replace(old, new, 1))


def main() -> int:
    assert_valid()

    cases = [
        (
            "catalog points",
            lambda root: replace(
                root / "assessments/quizzes/README.md",
                "| 25 min | 20 |",
                "| 25 min | 30 |",
            ),
            "catalog points 30",
        ),
        (
            "malformed catalog metadata",
            lambda root: replace(
                root / "assessments/quizzes/README.md",
                "| 25 min | 20 |",
                "| twenty-five minutes | twenty |",
            ),
            "invalid quiz catalog time or points",
        ),
        (
            "section total",
            lambda root: replace(
                root / "assessments/quizzes/sample.md",
                "Section 4 — Troubleshooting (5 points)",
                "Section 4 — Troubleshooting (4 points)",
            ),
            "section total 19",
        ),
        (
            "missing key",
            lambda root: (root / "assessments/answer-keys/quizzes/sample-key.md").unlink(),
            "missing answer key",
        ),
        (
            "missing remediation lab",
            lambda root: replace(
                root / "assessments/answer-keys/quizzes/sample-key.md",
                "labs/sample-lab/",
                "labs/missing-lab/",
            ),
            "remediation lab 'labs/missing-lab/' does not exist",
        ),
        (
            "broken local link",
            lambda root: (
                root / "assessments/quizzes/sample.md"
            ).write_text(QUIZ + "\n[Missing](missing.md)\n"),
            "broken local link missing.md",
        ),
    ]

    for name, mutate, expected_message in cases:
        assert_rejected(name, mutate, expected_message)

    print(f"OK — {len(cases) + 1} quiz-validator regression cases")
    return 0


if __name__ == "__main__":
    sys.exit(main())
