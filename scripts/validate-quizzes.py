#!/usr/bin/env python3
"""Validate the topic-quiz bank without deploying any labs.

Run from anywhere:

    python3 scripts/validate-quizzes.py
    python3 scripts/validate-quizzes.py --coverage

Checks quiz/key pairing, section totals, catalog metadata, remediation lab
references, local Markdown links, and trailing whitespace.
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path


TOTAL_RE = re.compile(r"\*\*Total:\*\*\s*(\d+) points")
TIME_RE = re.compile(r"\*\*Time:\*\*\s*(\d+)\s+minutes")
SECTION_RE = re.compile(r"^## Section \d+ .* \((\d+) points\)$", re.MULTILINE)
LINK_RE = re.compile(r"\[[^\]]+\]\(([^)]+)\)")
TABLE_LINK_RE = re.compile(r"^\[[^\]]+\]\(([^)]+)\)$")
CODE_RE = re.compile(r"`([^`]+)`")
LAB_COVERAGE_EXCLUSIONS = {"fixtures", "soc-common", "templates"}


class QuizValidator:
    """Run all quiz-bank checks relative to a repository root."""

    def __init__(self, repo: Path) -> None:
        self.repo = repo.resolve()
        self.assessments = self.repo / "assessments"
        self.quizzes_dir = self.assessments / "quizzes"
        self.keys_dir = self.assessments / "answer-keys" / "quizzes"
        self.labs_dir = self.repo / "labs"
        self.errors: list[str] = []
        self.remediation_labs: set[str] = set()

    def relative(self, path: Path) -> str:
        try:
            return str(path.resolve().relative_to(self.repo))
        except ValueError:
            return str(path)

    def err(self, message: str) -> None:
        self.errors.append(message)

    def local_link_targets(self, document: Path) -> list[tuple[str, Path]]:
        targets: list[tuple[str, Path]] = []
        for raw in LINK_RE.findall(document.read_text()):
            target = raw.split("#", 1)[0].strip().strip("<>")
            if not target or re.match(
                r"^[a-z][a-z0-9+.-]*:", target, re.IGNORECASE
            ):
                continue
            targets.append((raw, (document.parent / target).resolve()))
        return targets

    def validate_remediation(self, key: Path, text: str) -> None:
        heading = re.search(r"^## Remediation(?: table)?\s*$", text, re.MULTILINE)
        if heading is None:
            self.err(f"{self.relative(key)}: missing remediation section")
            return

        references: list[str] = []
        for line in text[heading.end() :].splitlines():
            if not line.startswith("|") or re.match(r"^\|[\s:|-]+\|$", line):
                continue
            cells = [cell.strip() for cell in line.strip().strip("|").split("|")]
            if cells:
                references.extend(CODE_RE.findall(cells[-1]))

        if not references:
            self.err(f"{self.relative(key)}: remediation table lists no labs")
            return

        for reference in references:
            normalized = reference.strip().removeprefix("labs/").strip("/")
            target = self.labs_dir / normalized
            if "/" in normalized or not target.is_dir():
                self.err(
                    f"{self.relative(key)}: remediation lab {reference!r} "
                    "does not exist"
                )
                continue
            self.remediation_labs.add(normalized)

    def validate_quiz(
        self, quiz: Path, key: Path | None
    ) -> tuple[int, int] | None:
        text = quiz.read_text()
        total_match = TOTAL_RE.search(text)
        time_match = TIME_RE.search(text)
        if total_match is None:
            self.err(f"{self.relative(quiz)}: missing declared total")
            return None

        declared = int(total_match.group(1))
        sections = [int(value) for value in SECTION_RE.findall(text)]
        if not sections:
            self.err(f"{self.relative(quiz)}: no scored section headings found")
        elif sum(sections) != declared:
            self.err(
                f"{self.relative(quiz)}: section total {sum(sections)} "
                f"does not match declared total {declared}"
            )

        if time_match is None:
            self.err(f"{self.relative(quiz)}: missing or invalid time limit")
        if "**Closed book" not in text:
            self.err(f"{self.relative(quiz)}: missing allowed-resources statement")

        expected_key = (
            quiz.parent / ".." / "answer-keys" / "quizzes" / f"{quiz.stem}-key.md"
        ).resolve()
        linked_targets = [target for _, target in self.local_link_targets(quiz)]
        if expected_key not in linked_targets:
            self.err(
                f"{self.relative(quiz)}: missing link to "
                f"{self.relative(expected_key)}"
            )

        if key is None:
            self.err(f"{self.relative(quiz)}: missing answer key")
        else:
            key_text = key.read_text()
            key_total = TOTAL_RE.search(key_text)
            if key_total is None or int(key_total.group(1)) != declared:
                self.err(
                    f"{self.relative(key)}: total does not match quiz total "
                    f"{declared}"
                )
            self.validate_remediation(key, key_text)

        if time_match is None:
            return None
        return int(time_match.group(1)), declared

    def validate_catalog(
        self, catalog: Path, expected: set[Path], label: str
    ) -> None:
        linked = {
            target
            for _, target in self.local_link_targets(catalog)
            if target in expected
        }
        for path in sorted(expected - linked):
            self.err(
                f"{self.relative(catalog)}: missing {label} entry for "
                f"{self.relative(path)}"
            )

    def validate_quiz_catalog(
        self, expected_metadata: dict[Path, tuple[int, int]]
    ) -> None:
        catalog = self.quizzes_dir / "README.md"
        entries: dict[Path, tuple[int, int, int]] = {}
        seen: set[Path] = set()

        for line_number, line in enumerate(catalog.read_text().splitlines(), 1):
            if not line.startswith("|"):
                continue
            cells = [cell.strip() for cell in line.strip().strip("|").split("|")]
            if not cells:
                continue
            link_match = TABLE_LINK_RE.match(cells[0])
            if link_match is None:
                continue

            target_raw = link_match.group(1).split("#", 1)[0].strip().strip("<>")
            target = (catalog.parent / target_raw).resolve()
            if target not in expected_metadata:
                continue
            if target in seen:
                self.err(
                    f"{self.relative(catalog)}:{line_number}: duplicate quiz "
                    f"catalog entry for {self.relative(target)}"
                )
                continue
            seen.add(target)

            if len(cells) != 4:
                self.err(
                    f"{self.relative(catalog)}:{line_number}: quiz catalog "
                    "entry must have four columns"
                )
                continue
            time_match = re.fullmatch(r"(\d+)\s+min", cells[2])
            points_match = re.fullmatch(r"\d+", cells[3])
            if time_match is None or points_match is None:
                self.err(
                    f"{self.relative(catalog)}:{line_number}: invalid quiz "
                    "catalog time or points"
                )
                continue
            entries[target] = (
                int(time_match.group(1)),
                int(points_match.group(0)),
                line_number,
            )

        for quiz, (quiz_time, quiz_points) in sorted(
            expected_metadata.items(), key=lambda item: str(item[0])
        ):
            entry = entries.get(quiz)
            if entry is None:
                continue
            catalog_time, catalog_points, line_number = entry
            if catalog_time != quiz_time:
                self.err(
                    f"{self.relative(catalog)}:{line_number}: catalog time "
                    f"{catalog_time} does not match {self.relative(quiz)} "
                    f"time {quiz_time}"
                )
            if catalog_points != quiz_points:
                self.err(
                    f"{self.relative(catalog)}:{line_number}: catalog points "
                    f"{catalog_points} do not match {self.relative(quiz)} "
                    f"total {quiz_points}"
                )

    def coverage(self) -> tuple[set[str], set[str]]:
        if not self.labs_dir.is_dir():
            return set(), set()
        eligible = {
            path.name
            for path in self.labs_dir.iterdir()
            if path.is_dir() and path.name not in LAB_COVERAGE_EXCLUSIONS
        }
        return self.remediation_labs & eligible, eligible

    def validate(self) -> tuple[int, int]:
        quizzes = {
            path.stem: path.resolve()
            for path in self.quizzes_dir.glob("*.md")
            if path.name != "README.md"
        }
        keys = {
            path.stem.removesuffix("-key"): path.resolve()
            for path in self.keys_dir.glob("*-key.md")
        }
        metadata: dict[Path, tuple[int, int]] = {}

        for stem, quiz in sorted(quizzes.items()):
            result = self.validate_quiz(quiz, keys.get(stem))
            if result is not None:
                metadata[quiz] = result

        for stem, key in sorted(keys.items()):
            if stem not in quizzes:
                self.err(f"{self.relative(key)}: has no matching quiz")

        self.validate_catalog(
            self.quizzes_dir / "README.md", set(quizzes.values()), "quiz"
        )
        self.validate_quiz_catalog(metadata)
        self.validate_catalog(
            self.keys_dir / "README.md", set(keys.values()), "key"
        )

        for document in self.assessments.rglob("*.md"):
            for raw, target in self.local_link_targets(document):
                if not target.exists():
                    self.err(
                        f"{self.relative(document)}: broken local link {raw}"
                    )
            for line_number, line in enumerate(document.read_text().splitlines(), 1):
                if line.rstrip() != line:
                    self.err(
                        f"{self.relative(document)}:{line_number}: "
                        "trailing whitespace"
                    )

        return len(quizzes), len(keys)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--repo",
        type=Path,
        default=Path(__file__).resolve().parent.parent,
        help="repository root (default: parent of this script's directory)",
    )
    parser.add_argument(
        "--coverage",
        action="store_true",
        help="report which lab directories are named by quiz remediation tables",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    validator = QuizValidator(args.repo)
    quiz_count, key_count = validator.validate()

    if validator.errors:
        print(f"FAIL — {len(validator.errors)} quiz-bank finding(s):\n")
        for finding in validator.errors:
            print(f"  - {finding}")
        return 1

    print(
        f"OK — {quiz_count} quiz/key pairs; totals, catalog metadata, "
        "remediation labs, links, and whitespace validated"
    )

    if args.coverage:
        covered, eligible = validator.coverage()
        print(
            f"Coverage — {len(covered)}/{len(eligible)} lab directories are "
            "named in quiz remediation"
        )
        uncovered = sorted(eligible - covered)
        if uncovered:
            print("Not directly named (often capstones, debug variants, or fixtures):")
            for name in uncovered:
                print(f"  - {name}")

    if quiz_count != key_count:
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
