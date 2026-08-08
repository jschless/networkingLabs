# Extraction progress and handoff notes

**Status: the deck is complete and shippable.**
467 cards across 18 decks, drawn from **135 of the 162 labs (83%)**.

`anki/MANIFEST.md` is the full lab→track work list. This file records what was
carded, what wasn't and why, and what a future pass could still do.

```bash
python3 anki/build.py --stats   # per-deck breakdown
python3 anki/audit.py           # coverage, duplicates, syntax leakage
```

---

## Decisions already made — don't re-litigate these

1. **CLI syntax cards are Cisco IOS-XE only.** The labs run FRR, Arista cEOS,
   SR-Linux and VyOS. Translate the concept to IOS-XE. Where there is no IOS-XE
   equivalent (Linux VRF plumbing, `vtysh -b`, `net.mpls.platform_labels`,
   SR-Linux CLI, cEOS container quirks), write the **concept card and skip the
   syntax card** rather than invent a command. Where the platforms differ in an
   interesting way, say so explicitly on the card.
2. **No lab-local trivia.** Node names, lab IP addressing, task numbers and
   `lab.sh` mechanics are scaffolding. Every card must make sense to someone who
   has never opened this repo.
3. **Debug-lab cards** are kept when the symptom is protocol-level, dropped when
   it is purely a container artifact.
4. **A card `id` is permanent** — it generates the Anki GUID. Reword freely;
   renumbering orphans the note and destroys its review history.
5. **One YAML file per deck** in `anki/cards/`. Schema in `cards/README.md`.
6. **Density is ~9 cards per lab**, favouring depth: each card carries the
   *why*, not just the fact. This was an explicit choice, confirmed with the
   requester.

---

## The 27 labs deliberately not carded

- **Capstones (10)** — `enterprise-*-capstone`, `enterprise-grand-capstone`,
  `dmvpn-phase3-ipsec-capstone`, `troubleshooting-range-*`,
  `enterprise-it-101/16-capstone`. They recombine concepts already carded from
  the labs they build on; their value is integration practice, which spaced
  repetition doesn't serve.
- **Platform variants (6)** — `mpls-sr-srlinux`, `vxlan-evpn-srlinux`,
  `ha-network-design-ceos`, `dot1x-ceos-practice`, `opnsense-ipsec-nat-t`,
  `orchestrated-wan-overlay`. Protocol concepts are carded from the primary
  lab; platform-specific CLI is out of scope under decision 1.
- **Blank practice twin (1)** — `mpls-sr-blank` is `mpls-sr-isis-bgp` with the
  config removed.
- **Already covered by pattern cards (5)** — `debug-ospf-auth` and
  `debug-dmvpn-phase1` (carded as the auth-failure signature and the DMVPN
  shortcut card), `enterprise-access-security` (campus-l2-hardening + 802.1X),
  `soc-zeek-analysis` and `soc-kibana-hvt-dashboard` (carded from the Suricata
  and SIEM labs).
- **Repo scaffolding (3)** — `soc-common`, `templates`, `fixtures`.
- **`dmvpn-ceos` (1)** — broken by design; cEOS 4.35.2F has no `ip nhrp`.

To re-derive this list at any time, diff the `source:` fields in
`anki/cards/*.yaml` against `anki/MANIFEST.md` — `anki/audit.py` prints the
carded count, and the snippet in the git history of this file prints the names.

---

## If you want to take it further

Nothing here is required — the deck stands on its own. In rough order of value:

- **Study-order tags.** The decks are topic-shaped, not difficulty-shaped. A
  `level:` tag (fundamentals / intermediate / advanced) would let Anki build a
  filtered deck that follows `docs/study-paths.md` instead of firing advanced
  EVPN cards in week one.
- **Reverse cards for the syntax set.** The 39 `syntax` cards are all
  recall-the-command. Command→meaning in the other direction is a genuinely
  different skill and is cheap to generate from the same YAML.
- **Verify the `area range` metric** (see caveats below) and add the card if
  IOS-XE behaviour is confirmed on real hardware.
- **Card the capstones as scenario cards.** They were skipped as
  concept-duplicates, but a small number of "given this design, what breaks
  first" cards would exercise integration rather than recall. Different card
  shape; would want its own subdeck.
- **Images.** Several topics (CLOS fabric, EVPN label stack, DMVPN phases,
  OSPF LSA flooding scopes) would carry better as a diagram. `build.py` would
  need media-file support in `genanki.Package`.

---

## Known caveats

- **`area range` summary metric** — vendor behaviour has historically diverged
  from RFC 2328, so **no card asserts a value**. The summarization cards teach
  the Null0 discard route and the ABR-vs-ASBR command split instead, both
  unambiguous. Leave it that way unless someone verifies IOS-XE on real gear.
- **Near-duplicate detector** — `audit.py` flags pairs by token overlap. One
  pair currently trips the threshold (`bgp-as-set-purpose` ↔ `mpls-qinq`) and
  was reviewed as a **false positive**: shared vocabulary (provider, customer,
  tag), unrelated content. Re-review rather than assume if it changes.
- **Canonical homes for cross-cutting ideas** — route-map implicit-deny and
  prefix-list `ge`/`le` live in `bgp.yaml`; other decks reference the idea
  rather than restating it. Keep it that way to avoid drift between copies.
- **`genanki` is a user-site install** (`pip install --user genanki pyyaml`);
  there is no venv checked in, and `anki/dist/` is gitignored because the
  `.apkg` is a build artifact.

---

## Audit history

Both passes were verified, not assumed:

- **IOS-XE syntax audit** — every config block reviewed line by line. Two real
  errors found and fixed: a `/32` loopback advertised with a `/24` mask
  (`bgp-iosxe-basic-session`), and `bgp bestpath as-path multipath-relax` shown
  inside the address-family when it is a router-level command on IOS-XE
  (`dc-multipath-relax`).
- **Renderer bug** — prose containing `<` ("IGP < EGP < incomplete", "RD < FD")
  was being swallowed by Anki as HTML. Fixed by escaping before applying inline
  markdown; ordered-list rendering added at the same time.
- **Coverage check after the first build** — the first pass reached 105 labs /
  387 cards. Diffing sources against the manifest showed IPv6 was missing
  almost entirely, along with MPLS L2VPN, half the Windows/AD track, and
  several operations labs. The second pass closed those, +80 cards.
