#!/usr/bin/env python3
"""Static consistency checks for the ContainerLab labs and their docs.

Run from anywhere: python3 scripts/lint-labs.py

Checks (no lab deploys, no docker):
  1. every labs/*/topology.clab.yml parses as YAML
  2. every lab directory with a topology has a README.md
  3. every image referenced by a topology is documented in docs/getting-started.md
     (that page claims to track "what each lab's topology.clab.yml actually
     references" — this makes the claim enforceable)
  4. every lab with a topology is referenced in the mkdocs.yml nav
     (exceptions listed in NAV_EXEMPT)
  5. the "(N labs)" counts on the docs/index.md track cards match the nav

Exit code 0 = clean, 1 = findings printed to stdout.
"""

import re
import sys
from pathlib import Path

import yaml

REPO = Path(__file__).resolve().parent.parent
LABS = REPO / "labs"

# Lab dirs intentionally absent from the docs nav.
NAV_EXEMPT = {
    "dmvpn-ceos",  # deprecated placeholder; see its README
}

errors: list[str] = []


def err(msg: str) -> None:
    errors.append(msg)


def topologies() -> dict[str, Path]:
    out = {}
    for lab in sorted(p for p in LABS.iterdir() if p.is_dir()):
        for name in ("topology.clab.yml", "topology.yml"):
            if (lab / name).is_file():
                out[lab.name] = lab / name
                break
    return out


def main() -> int:
    topos = topologies()
    nav = (REPO / "mkdocs.yml").read_text()
    getting_started = (REPO / "docs" / "getting-started.md").read_text()
    index_md = (REPO / "docs" / "index.md").read_text()

    # 1 + 3: topology parse and image documentation
    images: dict[str, set[str]] = {}
    for lab, topo in topos.items():
        try:
            data = yaml.safe_load(topo.read_text())
        except yaml.YAMLError as e:
            err(f"{topo.relative_to(REPO)}: YAML parse error: {e}")
            continue
        if not isinstance(data, dict) or "topology" not in data:
            err(f"{topo.relative_to(REPO)}: no top-level 'topology' key")
            continue
        for m in re.finditer(r"^\s*image:\s*(\S+)", topo.read_text(), re.M):
            images.setdefault(m.group(1), set()).add(lab)

    for image, labs in sorted(images.items()):
        if image not in getting_started:
            some = ", ".join(sorted(labs)[:4])
            err(
                f"image '{image}' (used by {some}) is not documented in "
                "docs/getting-started.md — add it to the image tables there"
            )

    # 2: README presence
    for lab in topos:
        if not (LABS / lab / "README.md").is_file():
            err(f"labs/{lab}: has a topology but no README.md")

    # 4: nav presence
    for lab in topos:
        if lab in NAV_EXEMPT:
            continue
        if not re.search(rf"tracks/[\w-]+/{re.escape(lab)}\.md", nav):
            err(
                f"labs/{lab}: not referenced in mkdocs.yml nav — add a wrapper "
                "page under docs/tracks/<track>/ (see docs/contributing.md)"
            )

    # 5: index.md track-card counts vs nav
    nav_counts: dict[str, int] = {}
    for m in re.finditer(r"tracks/([\w-]+)/(?!index)[\w-]+\.md", nav):
        nav_counts[m.group(1)] = nav_counts.get(m.group(1), 0) + 1
    for card in re.finditer(
        r"\*\*(?P<name>[^*]+)\*\*\s+\((?P<n>\d+) labs?[^)]*\)"
        r".*?tracks/(?P<track>[\w-]+)/index\.md",
        index_md,
        re.S,
    ):
        track, claimed = card.group("track"), int(card.group("n"))
        actual = nav_counts.get(track)
        if track == "enterprise-it-101":
            continue  # compose track; labs live outside labs/, counted by hand
        if actual is not None and actual != claimed:
            err(
                f"docs/index.md: card '{card.group('name').strip()}' says "
                f"{claimed} labs but mkdocs.yml nav has {actual} under tracks/{track}/"
            )

    if errors:
        print(f"FAIL — {len(errors)} finding(s):\n")
        for e in errors:
            print(f"  - {e}")
        return 1
    print(f"OK — {len(topos)} labs checked, {len(images)} distinct images, all consistent")
    return 0


if __name__ == "__main__":
    sys.exit(main())
