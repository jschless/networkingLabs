#!/usr/bin/env python3
"""Quality audit over the card sources.

Reports deck coverage, tag distribution, and three classes of problem:
overlong question text, non-IOS-XE syntax that isn't explicitly framed as a
cross-platform contrast, and near-duplicate cards.

    python3 anki/audit.py
"""

import collections
import pathlib
import re
import sys

import yaml

CARDS = pathlib.Path(__file__).resolve().parent / "cards"

# Syntax that belongs to a platform other than IOS-XE. A hit is only a problem
# when the card is not deliberately contrasting platforms.
FOREIGN_SYNTAX = [
    (r"\bospf router-id\b", "EOS: IOS-XE uses 'router-id'"),
    (r"\bmaximum-routes\b", "EOS: IOS-XE uses 'maximum-prefix'"),
    (r"\bnetwork\s+\d[\d.]*/\d+", "slash notation: IOS-XE uses wildcard or mask"),
    (r"\bvrf instance\b", "EOS: IOS-XE uses 'vrf definition'"),
    (r"\blacp timer\b", "EOS: IOS-XE uses 'lacp rate'"),
    (r"\bclear bgp \* soft", "FRR/EOS: IOS-XE uses 'clear ip bgp * soft'"),
    (r"\brouter ospf6\b|\bipv6 ospf6\b", "FRR OSPFv3"),
    (r"\bvtysh\b|\bmpls enable\b", "FRR"),
    (r"\bvxlan source-interface\b", "EOS VXLAN"),
    (r"\broute-server-client\b", "FRR/BIRD"),
]
CONTRAST_HINT = re.compile(
    r"\bEOS\b|\bArista\b|\bFRR\b|\bSR-Linux\b|\bVyOS\b|\bNX-OS\b"
    r"|contrast|has no\b|equivalent|spells this",
    re.I,
)

# Cloze text is the whole card, so it is legitimately longer than a question.
MAX_FRONT = 320


def body(card: dict) -> str:
    return "\n".join(str(card.get(k, "")) for k in ("front", "back", "extra", "text"))


def tokens(card: dict) -> set:
    text = (card.get("front", "") + " " + card.get("text", "")).lower()
    return set(re.findall(r"[a-z][a-z0-9-]{3,}", text))


def main() -> int:
    cards = []
    for path in sorted(CARDS.glob("*.yaml")):
        data = yaml.safe_load(path.read_text()) or {}
        for card in data.get("cards", []):
            cards.append((path.name, data["deck"], card))

    tag_counts = collections.Counter()
    type_counts = collections.Counter()
    sources = set()
    problems = []

    for fname, _deck, card in cards:
        type_counts[card.get("type", "basic")] += 1
        sources.add(card.get("source", ""))
        for tag in card.get("tags", []):
            tag_counts[tag] += 1

        if card.get("type", "basic") != "cloze":
            front = card.get("front", "")
            if len(front) > MAX_FRONT:
                problems.append(
                    f"{card['id']}: question is {len(front)} chars (>{MAX_FRONT})"
                )

        text = body(card)
        for pattern, why in FOREIGN_SYNTAX:
            if re.search(pattern, text, re.M) and not CONTRAST_HINT.search(text):
                problems.append(f"{card['id']}: {why}, with no cross-platform framing")

    dupes = []
    for i in range(len(cards)):
        for j in range(i + 1, len(cards)):
            a, b = tokens(cards[i][2]), tokens(cards[j][2])
            if not a or not b:
                continue
            overlap = len(a & b) / len(a | b)
            if overlap > 0.45:
                dupes.append((round(overlap, 2), cards[i][2]["id"], cards[j][2]["id"]))

    print(f"{len(cards)} cards from {len(sources)} labs, {len(set(d for _, d, _ in cards))} decks")
    print(f"types: {dict(type_counts)}")
    platform = {k: v for k, v in tag_counts.items()
                if k in ("ios-xe", "windows", "linux", "ipv6")}
    kind = {k: v for k, v in tag_counts.items()
            if k in ("concept", "syntax", "symptom-cause", "cloze")}
    print(f"platform tags: {platform}")
    print(f"kind tags: {kind}")

    print(f"\ntop topics: {', '.join(f'{t}({n})' for t, n in tag_counts.most_common(12))}")

    if dupes:
        print(f"\n{len(dupes)} near-duplicate pair(s) to review:")
        for score, a, b in sorted(dupes, reverse=True):
            print(f"  {score}  {a}  <->  {b}")

    if problems:
        print(f"\n{len(problems)} problem(s):")
        for p in problems:
            print(f"  {p}")
        return 1

    print("\nno problems found")
    return 0


if __name__ == "__main__":
    sys.exit(main())
