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
| `route-control.yaml` | ospf-bgp-redist, redistribution-tags, route-maps-pbr, ip-sla-tracking | 23 |
| `eigrp.yaml` | eigrp-basics, eigrp-stub, eigrp-variance | 19 |
| `isis.yaml` | isis-basics, isis-multiarea | 17 |
| `mpls.yaml` | mpls-ldp, mpls-sr-isis-bgp, bgp-labeled-unicast | 20 |
| `bgp.yaml` (+) | bgp-prefix-security, internet-peering-ixp | +10 |

| `layer2.yaml` | stp-operations, vlan-trunks-switchport-basics, lacp-etherchannel, campus-l2-hardening | 24 |
| `data-center.yaml` | spine-leaf, vxlan-evpn | 17 |
| `tunnels-vpn.yaml` | gre-basics, gre-ipsec, ipsec-basics, dmvpn-phase1/2/3, wireguard, vrf-lite | 23 |
| `high-availability.yaml` | vrrp, bfd-ospf, bfd-bgp, graceful-restart, anycast-dns | 15 |

**40 of 162 labs carded, 259 cards.**

## Next up

Batch 1 stragglers (low new-content — fold in opportunistically):
- [ ] labs/ipv6-bgp, labs/mpls-l2vpn, labs/carrier-ethernet-handoff,
      labs/ipv6-transition
- [ ] labs/mpls-sr-srlinux, labs/vxlan-evpn-srlinux (concepts only —
      SR-Linux CLI is out of scope)
- [ ] labs/mpls-sr-blank (blank twin of mpls-sr-isis-bgp — skip, no new content)

Batch 2 remainder (genuinely new concepts):
- [ ] labs/dci-evpn-multisite, labs/dc-storage-networking, labs/k8s-fabric
- [ ] labs/flexvpn-basics, labs/service-ha
- [ ] labs/evpn-border-ceos, labs/ha-network-design-ceos,
      labs/dmvpn-phase3-ipsec-capstone (capstones — check for new content only)
- [ ] labs/opnsense-* (OPNsense-specific — concepts only)

Then batch 3 (78 labs) and batch 4 (18 debug labs).

Then batches 2–4 per `anki/MANIFEST.md`.

## Status: complete

387 cards across 17 decks, drawn from 105 of the 162 labs. The 57 labs with no
cards are capstones, blank practice twins, and platform-specific variants whose
concepts are already carded from their source lab — see "Labs deliberately not
carded" below.

### Labs deliberately not carded

- **Capstones** (`*-capstone`, `enterprise-grand-capstone`,
  `troubleshooting-range-*`): recombine concepts already carded from the labs
  they build on. Their value is integration practice, which spaced repetition
  doesn't serve.
- **Blank practice twins** (`mpls-sr-blank`): same content as the built version.
- **Platform variants** (`*-srlinux`, `*-ceos`, `opnsense-*`, `dot1x-ceos-practice`):
  the protocol concepts are carded from the primary lab; the platform-specific
  CLI is out of scope given the IOS-XE decision.
- **Infrastructure** (`soc-common`, `templates`, `fixtures`): not content.
- **`dmvpn-ceos`**: broken by design — cEOS 4.35.2F has no `ip nhrp`.

## Resolved QA items

- **`area range` summary metric** — vendor behaviour has historically differed
  from RFC 2328 here, so **no card asserts a value**. The summarization cards
  teach the Null0 discard route and the ABR-vs-ASBR command split instead, both
  of which are unambiguous. Keep it that way unless someone verifies IOS-XE
  behaviour on real hardware.
- **Dedupe** — `anki/audit.py` flags near-duplicates by token overlap. Two pairs
  currently score above the threshold and were reviewed as false positives
  (shared vocabulary, different content). Canonical homes: route-map
  implicit-deny and prefix-list `ge`/`le` live in `bgp.yaml`; other decks
  reference the idea rather than restating it.
- **IOS-XE syntax audit** — every config block was reviewed line by line. Two
  real errors were found and fixed: a `/32` loopback advertised with a `/24`
  mask (`bgp-iosxe-basic-session`), and `bgp bestpath as-path multipath-relax`
  shown inside the address-family when it is a router-level command
  (`dc-multipath-relax`).
