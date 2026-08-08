# Anki flashcards from the lab corpus

387 spaced-repetition cards distilled from the 162 labs in this repo — the
transferable knowledge, not the lab mechanics.

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
| Tunnels and VPN | 25 | GRE, IPsec, DMVPN phases, WireGuard, VRF-lite |
| Data Center | 25 | CLOS underlay, VXLAN, BGP EVPN, DCI, storage, Kubernetes fabric |
| Layer 2 | 24 | VLANs and trunks, STP, EtherChannel, edge hardening |
| Enterprise IT | 23 | Active Directory, Kerberos, PKI, DHCP/DDNS, GPO, SSO, RADIUS |
| Route Control | 23 | administrative distance, redistribution, PBR, IP SLA tracking |
| Security | 21 | ACLs, CoPP, uRPF, 802.1X/NAC, zero trust, MACsec |
| MPLS | 20 | LDP, segment routing, L3VPN, BGP-LU |
| EIGRP | 19 | DUAL, metrics, variance, stub |
| Operations | 18 | QoS, MTU/PMTUD, automation, observability, troubleshooting method |
| IS-IS | 17 | NET addressing, levels, attached bit, metrics |
| Enterprise | 16 | multicast, NAT/DMZ, voice, wireless, campus design |
| Troubleshooting Drills | 14 | symptom → cause, from the `debug-*` labs |
| SOC Operations | 13 | detection, threat intel, incident response, SIEM |
| Services and Delivery | 13 | load balancing, global delivery, OT/ICS, hybrid cloud |

271 concept cards, 68 symptom→cause, 38 syntax, 10 cloze.

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
