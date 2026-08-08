# Anki flashcards from the lab corpus

467 spaced-repetition notes (564 cards) distilled from the 162 labs in this
repo — the transferable knowledge, not the lab mechanics.

## Get the deck

```bash
python3 -m pip install --user genanki pyyaml
python3 anki/build.py
```

Import `anki/dist/networking-labs.apkg` into Anki. It creates a top-level
**Networking Labs** deck with one subdeck per topic.

Note GUIDs are derived from each card's stable `id`, so **rebuilding and
re-importing updates the existing notes in place** — your review history
survives. It never creates duplicates.

## What's in it

| Deck | Cards | |
|---|---:|---|
| BGP | 57 | sessions, next-hop, path selection, communities, filtering, aggregation, RPKI, prefix security, IXP |
| OSPF | 44 | areas, LSA types, NSSA, summarization, default origination, auth, virtual links, OSPFv3 |
| Enterprise IT | 39 | Active Directory, Kerberos, PKI, DNS, SMB, mail, proxy, backup, monitoring |
| Operations | 33 | QoS, MTU/PMTUD, AAA, automation, observability, packet analysis, troubleshooting method |
| MPLS | 28 | LDP, segment routing, L3VPN, BGP-LU, L2VPN, carrier Ethernet |
| Data Center | 27 | CLOS underlay, VXLAN, BGP EVPN, border leaf, DCI, storage, Kubernetes fabric |
| Security | 27 | ACLs, CoPP, uRPF, 802.1X/NAC, zero trust, MACsec, architecture |
| Enterprise | 25 | multicast, NAT/DMZ, voice, wireless, campus and WAN design, services |
| Tunnels and VPN | 27 | GRE, IPsec, DMVPN, WireGuard, remote access, VRF-lite |
| Layer 2 | 24 | VLANs and trunks, STP, EtherChannel, edge hardening |
| Route Control | 23 | administrative distance, redistribution, PBR, IP SLA tracking |
| EIGRP | 19 | DUAL, metrics, variance, stub |
| High Availability | 17 | FHRP, BFD, graceful restart, anycast, stateful failover |
| IPv6 | 17 | ND/SLAAC, first-hop security, MP-BGP, transition mechanisms |
| IS-IS | 17 | NET addressing, levels, attached bit, metrics |
| SOC Operations | 16 | detection, threat intel, incident response, SIEM, ATT&CK coverage |
| Troubleshooting Drills | 14 | symptom → cause, from the `debug-*` labs |
| Services and Delivery | 13 | load balancing, global delivery, OT/ICS, hybrid cloud |

**467 notes → 564 cards to study.** Roughly 300 concept, 84 symptom→cause and
39 syntax notes, plus **33 reverse cards** on the syntax set (see below) and 11
cloze notes that expand to 75 cards (one per deletion).

Drawn from **135 of the 162 labs**. The 27 without cards are capstones (which
recombine concepts already carded), platform variants of a lab whose concepts
are covered, and repo scaffolding — see `PROGRESS.md` for the list and the
reasoning.

## Reverse cards on the syntax set

Every `syntax` card is studied in **both directions**:

- **Recall** — "IOS-XE: enable OSPF MD5 authentication on an interface" → the config
- **Identify** — the config → "What does this configuration do?"

Both directions live on one note, so a reworded card stays in sync. 33 of the 39
syntax cards qualify; the rest either answer with a reference table rather than a
config block, or ask for two commands at once (opted out with `reverse: false`).

> **Re-importing over an earlier build:** this added a `Config` field and a
> second template to the *existing* `ContainerLab Basic` note type. Anki will
> update the note type on import — existing cards keep their scheduling, and the
> new reverse cards arrive as fresh cards.

## Two decisions worth knowing

**CLI syntax cards are Cisco IOS-XE**, not the syntax the labs run on. The labs
use FRR, Arista cEOS, SR-Linux and VyOS; the cards translate to IOS-XE because
that's the target platform for study. Where a concept has no IOS-XE equivalent
(Linux VRF plumbing, `vtysh -b`, SR-Linux CLI), there's a concept card and no
syntax card rather than an invented command. Where the platforms genuinely
differ in an interesting way, the card says so explicitly — e.g. IOS-XE has
`suppress-map` where EOS folds it into `summary-only match-map`.

**Lab-local detail is excluded.** Node names, lab IP addressing, task numbers
and `lab.sh` mechanics are scaffolding, not knowledge. Every card should still
make sense to someone who has never opened this repo.

## Working on the cards

Sources are YAML, one file per deck, in `anki/cards/` —
see [cards/README.md](cards/README.md) for the schema.

```bash
python3 anki/build.py --check    # validate sources
python3 anki/build.py --stats    # per-deck counts
python3 anki/build.py            # write the .apkg
python3 anki/audit.py            # duplicates, overlong questions, syntax leakage
python3 anki/make_manifest.py    # regenerate the lab -> track work list
```

`MANIFEST.md` maps every lab to its track; `PROGRESS.md` records which labs
have been mined and the decisions behind the extraction.

**A card `id` is permanent** — it generates the Anki GUID. Reword freely;
never renumber, or the note is orphaned and its review history is lost.
