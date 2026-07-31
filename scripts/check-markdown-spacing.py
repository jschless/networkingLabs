#!/usr/bin/env python3
"""Check block-spacing that Python-Markdown otherwise mis-renders silently.

The docs site includes Markdown from several directories, not only ``docs/``.
Python-Markdown accepts a build with missing blank lines around block elements,
but lists and tables can then become literal text inside a paragraph and fenced
code can produce invalid ``<p><div>`` nesting.  Run with ``--fix`` to insert the
required blank lines mechanically.
"""

from __future__ import annotations

import argparse
import re
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parent.parent

HEADING_RE = re.compile(r"^#{1,6}\s")
LIST_RE = re.compile(r"^(\s*)(?:[-+*]|\d+[.)])\s+")
FENCE_RE = re.compile(r"^(\s*)(```|~~~)")
TABLE_HEADER_RE = re.compile(r"^\s*\|")
TABLE_SEPARATOR_RE = re.compile(r"^\s*\|\s*:?-{3,}")
STANDALONE_BOLD_RE = re.compile(r"^\*\*.+\*\*[.:]?\s*$")
CONTAINER_RE = re.compile(r"^\s*(?:[!?]{3}\+?|===)\s")


def published_markdown() -> list[Path]:
    """Return Markdown sources that are rendered directly or included by MkDocs."""
    paths: set[Path] = set((REPO_ROOT / "docs").rglob("*.md"))
    paths.update((REPO_ROOT / "labs").glob("*/README.md"))
    paths.add(REPO_ROOT / "enterprise-it-101" / "README.md")
    paths.update((REPO_ROOT / "enterprise-it-101" / "labs").glob("*/README.md"))
    paths.update((REPO_ROOT / "assessments").glob("*.md"))
    paths.update((REPO_ROOT / "assessments" / "quizzes").glob("*.md"))
    return sorted(path for path in paths if path.is_file())


def structural_lines(lines: list[str]) -> tuple[set[int], set[int]]:
    """Return line indexes that need a blank line before or after them."""
    before: set[int] = set()
    after: set[int] = set()
    in_fence = False
    fence = ""

    for index, line in enumerate(lines):
        previous = lines[index - 1] if index else ""
        following = lines[index + 1] if index + 1 < len(lines) else ""

        fence_match = FENCE_RE.match(line)
        if fence_match:
            if in_fence and line.lstrip().startswith(fence):
                in_fence = False
                fence = ""
                if following.strip():
                    after.add(index)
            elif not in_fence:
                if previous.strip() and not CONTAINER_RE.match(previous):
                    before.add(index)
                in_fence = True
                fence = fence_match.group(2)
            continue

        if in_fence:
            continue

        if HEADING_RE.match(line):
            # Front matter closes with `---`; do not mistake it for prose.
            if previous.strip() and previous != "---":
                before.add(index)
            if following.strip():
                after.add(index)

        is_table_header = TABLE_HEADER_RE.match(line) and TABLE_SEPARATOR_RE.match(following)
        if is_table_header and previous.strip():
            before.add(index)

        # Python-Markdown needs a blank before a new top-level list.  Restrict
        # the check to unambiguous list introductions so lazy continuation
        # lines such as a later numbered question are not false positives.
        starts_list = LIST_RE.match(line)
        introduces_list = (
            previous.rstrip().endswith(":")
            or STANDALONE_BOLD_RE.match(previous.strip())
            or HEADING_RE.match(previous.lstrip())
        )
        if (
            starts_list
            and previous.strip()
            and introduces_list
            and not CONTAINER_RE.match(previous)
        ):
            before.add(index)

    return before, after


def format_lines(lines: list[str], before: set[int], after: set[int]) -> list[str]:
    output: list[str] = []
    for index, line in enumerate(lines):
        if index in before and output and output[-1].strip():
            output.append("")
        output.append(line)
        if index in after and (index + 1 == len(lines) or lines[index + 1].strip()):
            output.append("")
    return output


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--fix",
        action="store_true",
        help="insert missing blank lines instead of only reporting them",
    )
    args = parser.parse_args()

    failures = 0
    changed = 0
    for path in published_markdown():
        original = path.read_text(encoding="utf-8")
        had_final_newline = original.endswith("\n")
        lines = original.splitlines()
        before, after = structural_lines(lines)
        if not before and not after:
            continue

        if args.fix:
            formatted = "\n".join(format_lines(lines, before, after))
            if had_final_newline:
                formatted += "\n"
            if formatted != original:
                path.write_text(formatted, encoding="utf-8")
                changed += 1
            continue

        relative = path.relative_to(REPO_ROOT)
        for index in sorted(before):
            print(f"FAIL {relative}:{index + 1}: add a blank line before this block")
            failures += 1
        for index in sorted(after):
            print(f"FAIL {relative}:{index + 1}: add a blank line after this block")
            failures += 1

    if args.fix:
        print(f"OK: formatted Markdown block spacing in {changed} files")
        return 0
    if failures:
        print(f"\n{failures} Markdown block-spacing error(s) found")
        return 1
    print("OK: Markdown block spacing is valid")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
