# Extraction progress

Working file. `anki/MANIFEST.md` is the full 162-lab work list; this tracks
what has actually been carded. Update it whenever a lab is finished.

## Decisions already made (don't re-litigate)

- **CLI syntax cards are Cisco IOS-XE only.** The labs run FRR / cEOS /
  SR-Linux / VyOS. Translate the concept to IOS-XE; where there is no IOS-XE
  equivalent (Linux VRF plumbing, `vtysh -b`, `net.mpls.platform_labels`,
  SR-Linux CLI, cEOS container quirks), write the concept card and **skip the
  syntax card** rather than invent a command.
- Debug-lab symptom→cause cards are kept when the symptom is protocol-level,
  and dropped when it is purely a container artifact.
- Excluded as non-content: `labs/soc-common`, `labs/templates`,
  `labs/dmvpn-ceos` (broken by design — cEOS 4.35.2F has no `ip nhrp`).
- One YAML file per deck in `anki/cards/`. Card `id` is permanent (it is the
  Anki GUID) — reword freely, never renumber.

## Done

| Deck file | Labs carded | Cards |
|---|---|---|
| `ospf.yaml` | two-routers, ospf-multiarea, ospf-auth, ospf-nssa, ospf-summarization, ospf-default-route, ospf-virtual-link, ipv6-ospf3 | 44 |
| `bgp.yaml` | bgp-basics, bgp-path-selection, bgp-communities, bgp-filtering, bgp-aggregation, bgp-rpki | 47 |

## Next up (batch 1 — routing)

- [ ] labs/ospf-bgp-redist (route-control overlap: mutual redistribution, tags)
- [ ] labs/bgp-prefix-security, labs/internet-peering-ixp, labs/ipv6-bgp,
      labs/bgp-labeled-unicast
- [ ] labs/eigrp-basics, labs/eigrp-stub, labs/eigrp-variance
- [ ] labs/isis-basics, labs/isis-multiarea
- [ ] labs/route-maps-pbr, labs/redistribution-tags, labs/ip-sla-tracking
- [ ] labs/mpls-ldp, labs/mpls-sr-isis-bgp, labs/mpls-l2vpn,
      labs/carrier-ethernet-handoff, labs/ipv6-transition

Then batches 2–4 per `anki/MANIFEST.md`.

## Open items for the final QA pass

- **Verify before shipping:** the metric an ABR puts on an `area range`
  summary LSA (lab says maximum of contributing routes; confirm Cisco IOS-XE
  behaviour, which has historically differed from RFC 2328). Card id
  `ospf-summarization-*` — currently no card asserts a value, keep it that way
  unless confirmed.
- Dedupe across decks: route-map implicit-deny, prefix-list `ge`/`le`, and
  soft-clear will recur in route-control, security, and enterprise labs —
  keep the canonical card in `bgp.yaml` and cross-reference rather than
  duplicating.
