# Card source schema

One YAML file per track. `anki/build.py` turns them into
`anki/dist/networking-labs.apkg`.

```yaml
deck: BGP                    # becomes "Networking Labs::BGP"
cards:
  - id: bgp-no-export-scope  # STABLE + globally unique — the note GUID
    type: basic              # basic | cloze  (default: basic)
    subdeck: Communities     # optional → "Networking Labs::BGP::Communities"
    front: |
      Question text.
    back: |
      Answer text.
    extra: |
      Optional context shown under the answer.
    tags: [bgp, ios-xe, concept]
    source: labs/bgp-communities
```

Cloze cards use `text:` instead of `front`/`back`:

```yaml
  - id: bgp-path-selection-order
    type: cloze
    text: |
      BGP prefers highest {{c1::weight}}, then highest {{c2::local-preference}}.
    tags: [bgp, cloze]
    source: labs/bgp-path-selection
```

## Rules

- **`id` is permanent.** It generates the Anki GUID. Changing an `id` orphans
  the old note and creates a new one, losing its review history. Fix wording
  freely; never renumber ids.
- **CLI syntax is Cisco IOS-XE.** The labs run FRR / cEOS / SR-Linux / VyOS,
  but syntax cards target IOS-XE. If a concept has no IOS-XE equivalent
  (Linux VRF plumbing, `vtysh -b`, SR-Linux CLI), write the concept card and
  skip the syntax card rather than inventing a command.
- **No lab-local trivia.** Node names, lab IP addressing, task numbers, and
  `lab.sh` mechanics are not flashcard material. Card the transferable idea.
- **`source`** points at the lab the card came from, for traceability.

## Body markup

A small markdown subset is rendered: fenced code blocks, `` `inline code` ``,
`**bold**`, and blank-line paragraph breaks. Use fenced blocks for
multi-line configuration.

## Tags

- Platform: `ios-xe`, `nx-os`, `frr`, `eos`, `srlinux`, `vyos`, `linux`,
  `windows` — the first one found renders as a badge on the card front.
- Kind: `concept`, `syntax`, `symptom-cause`, `cloze`.
- Topic: free-form (`bgp`, `ospf`, `evpn`, `qos`, …).

## Commands

```bash
python3 anki/build.py --check    # validate sources
python3 anki/build.py --stats    # per-deck counts
python3 anki/build.py            # write the .apkg
```
