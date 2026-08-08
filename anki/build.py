#!/usr/bin/env python3
"""Build an Anki .apkg from the YAML card sources in anki/cards/.

Usage:
    python3 anki/build.py                 # build anki/dist/networking-labs.apkg
    python3 anki/build.py --check         # validate sources only, no output
    python3 anki/build.py --stats         # per-deck / per-type counts

Card sources are one YAML file per track (see anki/cards/README.md for the
schema). Note GUIDs are derived from each card's stable `id`, so rebuilding
and re-importing updates existing notes instead of duplicating them.
"""

from __future__ import annotations

import argparse
import hashlib
import pathlib
import re
import sys
from collections import Counter, defaultdict

try:
    import genanki
    import yaml
except ImportError as exc:  # pragma: no cover
    sys.exit(f"missing dependency: {exc}. Run: python3 -m pip install --user genanki pyyaml")

ROOT = pathlib.Path(__file__).resolve().parent
CARDS_DIR = ROOT / "cards"
DIST_DIR = ROOT / "dist"

TOP_DECK = "Networking Labs"
CLOZE_RE = re.compile(r"\{\{c\d+::")

CSS = """
.card {
  font-family: -apple-system, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
  font-size: 19px;
  line-height: 1.55;
  text-align: left;
  color: #1a1a1a;
  background: #fbfbfa;
  padding: 12px 4px;
}
.nightMode .card, .card.nightMode { color: #e8e8e6; background: #202124; }
code, kbd {
  font-family: "SF Mono", "JetBrains Mono", Menlo, Consolas, monospace;
  font-size: 0.88em;
  background: rgba(128,128,128,.16);
  padding: 1px 5px;
  border-radius: 4px;
}
pre {
  font-family: "SF Mono", "JetBrains Mono", Menlo, Consolas, monospace;
  font-size: 0.84em;
  line-height: 1.45;
  background: rgba(128,128,128,.12);
  border-left: 3px solid #4778ff;
  padding: 10px 12px;
  border-radius: 4px;
  overflow-x: auto;
  white-space: pre;
}
pre code { background: none; padding: 0; font-size: 1em; }
hr#answer { border: none; border-top: 1px solid rgba(128,128,128,.35); margin: 14px 0; }
table.md { border-collapse: collapse; margin: 10px 0; font-size: .88em; width: 100%; }
table.md th, table.md td {
  border: 1px solid rgba(128,128,128,.35);
  padding: 5px 9px;
  text-align: left;
  vertical-align: top;
}
table.md th { background: rgba(128,128,128,.14); font-weight: 600; }
ul { margin: 8px 0 8px 0; padding-left: 22px; }
li { margin: 3px 0; }
.cloze { font-weight: 600; color: #4778ff; }
.nightMode .cloze { color: #7fa5ff; }
.extra { font-size: 0.9em; opacity: .85; margin-top: 10px; }
.src {
  font-size: 0.72em;
  opacity: .5;
  margin-top: 16px;
  font-family: "SF Mono", Menlo, monospace;
}
.tag-platform {
  display: inline-block;
  font-size: 0.68em;
  letter-spacing: .05em;
  text-transform: uppercase;
  background: #4778ff;
  color: #fff;
  padding: 2px 7px;
  border-radius: 3px;
  margin-bottom: 10px;
}
"""

BASIC_MODEL = genanki.Model(
    1727384501,
    "ContainerLab Basic",
    fields=[
        {"name": "Front"},
        {"name": "Back"},
        {"name": "Extra"},
        {"name": "Source"},
    ],
    templates=[
        {
            "name": "Recall",
            "qfmt": "{{Front}}",
            "afmt": (
                '{{FrontSide}}<hr id="answer">{{Back}}'
                '{{#Extra}}<div class="extra">{{Extra}}</div>{{/Extra}}'
                '{{#Source}}<div class="src">{{Source}}</div>{{/Source}}'
            ),
        }
    ],
    css=CSS,
)

CLOZE_MODEL = genanki.Model(
    1727384502,
    "ContainerLab Cloze",
    fields=[
        {"name": "Text"},
        {"name": "Extra"},
        {"name": "Source"},
    ],
    templates=[
        {
            "name": "Cloze",
            "qfmt": "{{cloze:Text}}",
            "afmt": (
                "{{cloze:Text}}"
                '{{#Extra}}<div class="extra">{{Extra}}</div>{{/Extra}}'
                '{{#Source}}<div class="src">{{Source}}</div>{{/Source}}'
            ),
        }
    ],
    css=CSS,
    model_type=genanki.Model.CLOZE,
)


def deck_id(name: str) -> int:
    """Stable deck id derived from the deck name."""
    digest = hashlib.sha256(name.encode()).hexdigest()
    return 1 << 30 | int(digest[:8], 16) % (1 << 30)


def load_sources() -> list[tuple[pathlib.Path, dict]]:
    files = sorted(CARDS_DIR.glob("*.yaml"))
    out = []
    for path in files:
        data = yaml.safe_load(path.read_text()) or {}
        if not data.get("cards"):
            continue
        out.append((path, data))
    return out


def validate(path: pathlib.Path, data: dict, seen: dict[str, pathlib.Path]) -> list[str]:
    errors: list[str] = []
    deck = data.get("deck")
    if not deck:
        errors.append(f"{path.name}: missing top-level `deck:`")
    for idx, card in enumerate(data.get("cards", [])):
        loc = f"{path.name}[{idx}] id={card.get('id', '<none>')}"
        cid = card.get("id")
        if not cid:
            errors.append(f"{loc}: missing `id`")
        elif cid in seen:
            errors.append(f"{loc}: duplicate id (also in {seen[cid].name})")
        else:
            seen[cid] = path
        ctype = card.get("type", "basic")
        if ctype == "basic":
            if not card.get("front"):
                errors.append(f"{loc}: basic card missing `front`")
            if not card.get("back"):
                errors.append(f"{loc}: basic card missing `back`")
            for field in ("front", "back"):
                if CLOZE_RE.search(str(card.get(field, ""))):
                    errors.append(f"{loc}: cloze markup in `{field}` of a basic card")
        elif ctype == "cloze":
            text = card.get("text", "")
            if not text:
                errors.append(f"{loc}: cloze card missing `text`")
            elif not CLOZE_RE.search(text):
                errors.append(f"{loc}: cloze card has no {{{{c1::…}}}} deletion")
        else:
            errors.append(f"{loc}: unknown type {ctype!r}")
        if not card.get("source"):
            errors.append(f"{loc}: missing `source`")
    return errors


def render_table(lines: list[str]) -> str:
    """Render a pipe-delimited markdown table (header row + --- separator)."""
    def cells(row: str) -> list[str]:
        return [c.strip() for c in row.strip().strip("|").split("|")]

    head = cells(lines[0])
    body = [cells(r) for r in lines[2:] if r.strip()]
    out = ['<table class="md"><thead><tr>']
    out += [f"<th>{c}</th>" for c in head]
    out.append("</tr></thead><tbody>")
    for row in body:
        out.append("<tr>" + "".join(f"<td>{c}</td>" for c in row) + "</tr>")
    out.append("</tbody></table>")
    return "".join(out)


def render_inline(chunk: str) -> str:
    chunk = re.sub(r"`([^`]+)`", r"<code>\1</code>", chunk)
    chunk = re.sub(r"\*\*([^*]+)\*\*", r"<b>\1</b>", chunk)
    return chunk


def render_block(chunk: str) -> str:
    """Render one non-code chunk: markdown tables, bullet lists, paragraphs."""
    out: list[str] = []
    lines = chunk.split("\n")
    i = 0
    while i < len(lines):
        line = lines[i]
        is_table = (
            line.strip().startswith("|")
            and i + 1 < len(lines)
            and set(lines[i + 1].strip()) <= set("|-: ")
            and "-" in lines[i + 1]
        )
        if is_table:
            j = i
            while j < len(lines) and lines[j].strip().startswith("|"):
                j += 1
            out.append(render_table([render_inline(x) for x in lines[i:j]]))
            i = j
            continue
        if line.strip().startswith("- "):
            j = i
            items = []
            while j < len(lines) and (lines[j].strip().startswith("- ") or
                                      (lines[j].startswith("  ") and lines[j].strip())):
                if lines[j].strip().startswith("- "):
                    items.append(lines[j].strip()[2:])
                else:
                    items[-1] += " " + lines[j].strip()
                j += 1
            out.append("<ul>" + "".join(f"<li>{render_inline(x)}</li>" for x in items) + "</ul>")
            i = j
            continue
        j = i
        para: list[str] = []
        while j < len(lines) and lines[j].strip() and not lines[j].strip().startswith(("|", "- ")):
            para.append(lines[j].strip())
            j += 1
        if para:
            out.append(f"<div>{render_inline(' '.join(para))}</div>")
            i = j
            continue
        i += 1
    return "".join(out)


def render(text: str) -> str:
    """Convert the small markdown subset used in card bodies to HTML.

    Supported: fenced code blocks, markdown tables, `- ` bullet lists,
    `inline code`, **bold**, and blank-line paragraph breaks.
    """
    if text is None:
        return ""
    text = str(text).rstrip()
    parts = re.split(r"```(?:\w+)?\n(.*?)```", text, flags=re.DOTALL)
    out = []
    for i, part in enumerate(parts):
        if i % 2 == 1:
            escaped = part.rstrip().replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
            out.append(f"<pre><code>{escaped}</code></pre>")
            continue
        chunk = part.strip("\n")
        if not chunk:
            continue
        out.append(render_block(chunk))
    return "".join(out)


def platform_badge(tags: list[str]) -> str:
    for tag in tags:
        if tag in ("ios-xe", "nx-os", "frr", "eos", "srlinux", "vyos", "linux", "windows"):
            label = {"ios-xe": "IOS-XE", "nx-os": "NX-OS"}.get(tag, tag.upper())
            return f'<div class="tag-platform">{label}</div>'
    return ""


def build(check_only: bool = False, stats: bool = False) -> int:
    sources = load_sources()
    if not sources:
        print("no card sources found in anki/cards/", file=sys.stderr)
        return 1

    seen: dict[str, pathlib.Path] = {}
    errors: list[str] = []
    for path, data in sources:
        errors.extend(validate(path, data, seen))
    if errors:
        print(f"{len(errors)} validation error(s):", file=sys.stderr)
        for err in errors[:60]:
            print(f"  {err}", file=sys.stderr)
        if len(errors) > 60:
            print(f"  … and {len(errors) - 60} more", file=sys.stderr)
        return 1

    decks: dict[str, genanki.Deck] = {}
    counts: dict[str, Counter] = defaultdict(Counter)
    total = 0

    for path, data in sources:
        deck_name = f"{TOP_DECK}::{data['deck']}"
        for card in data["cards"]:
            sub = card.get("subdeck")
            name = f"{deck_name}::{sub}" if sub else deck_name
            if name not in decks:
                decks[name] = genanki.Deck(deck_id(name), name)
            tags = [str(t) for t in card.get("tags", [])]
            source = card.get("source", "")
            src_html = f"↳ {source}" if source else ""
            ctype = card.get("type", "basic")
            if ctype == "cloze":
                note = genanki.Note(
                    model=CLOZE_MODEL,
                    fields=[render(card["text"]), render(card.get("extra", "")), src_html],
                    tags=tags,
                    guid=genanki.guid_for(card["id"]),
                )
            else:
                note = genanki.Note(
                    model=BASIC_MODEL,
                    fields=[
                        platform_badge(tags) + render(card["front"]),
                        render(card["back"]),
                        render(card.get("extra", "")),
                        src_html,
                    ],
                    tags=tags,
                    guid=genanki.guid_for(card["id"]),
                )
            decks[name].add_note(note)
            counts[data["deck"]][ctype] += 1
            total += 1

    if stats:
        print(f"{'deck':<34} {'basic':>7} {'cloze':>7} {'total':>7}")
        print("-" * 58)
        for deck in sorted(counts):
            c = counts[deck]
            print(f"{deck:<34} {c['basic']:>7} {c['cloze']:>7} {sum(c.values()):>7}")
        print("-" * 58)
        print(f"{'ALL':<34} {sum(c['basic'] for c in counts.values()):>7} "
              f"{sum(c['cloze'] for c in counts.values()):>7} {total:>7}")

    if check_only:
        print(f"OK: {total} cards across {len(decks)} decks, no errors")
        return 0

    DIST_DIR.mkdir(exist_ok=True)
    out = DIST_DIR / "networking-labs.apkg"
    package = genanki.Package(list(decks.values()))
    package.write_to_file(out)
    print(f"wrote {out} — {total} cards, {len(decks)} decks")
    return 0


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true", help="validate only")
    ap.add_argument("--stats", action="store_true", help="print per-deck counts")
    args = ap.parse_args()
    sys.exit(build(check_only=args.check, stats=args.stats))
