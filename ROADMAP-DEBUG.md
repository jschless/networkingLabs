# ContainerLab Debugging Labs Roadmap

This roadmap defines a new category of lab: **debug labs**. Rather than configuring a protocol from scratch, you deploy a fully-configured topology that contains one or more intentional misconfigurations and diagnose the fault using show commands — just like real-world network troubleshooting.

---

## Status Key
- ✅ Complete
- 🔲 Not yet built

---

## How Debug Labs Work

Each debug lab:
1. Deploys a working-looking topology with a hidden bug
2. Presents **observed symptoms** (what show commands reveal at the start)
3. Guides you to **diagnose the fault** using protocol-appropriate show commands
4. Provides **progressive hints** (three levels, spoiler-protected)
5. Reveals the **fix** and **verification** at the end

**The rule:** don't look at the config files. Start from symptoms, use show commands to narrow down the fault, then fix it in vtysh.

---

## Lab Directory Convention

```
labs/debug-<name>/
  topology.yml          # Topology (same as parent lab)
  README.md             # Debug-focused README (see template below)
  configs/
    daemons             # Same as parent lab
    vtysh.conf          # Same as parent lab
    <node>/frr.conf     # Full working config WITH the intentional bug(s)
    <node>/setup.sh     # (if needed) same as parent; bugs are in frr.conf only
```

Each debug lab is standalone — you can run it alongside the practice version.

---

## README Template

Every debug lab README follows this structure:

```
# debug-<name> — <one-line description>

## Scenario
[One paragraph: ops story framing — "a colleague made a change, something broke"]

## Topology
[ASCII diagram]

## IP / Node Reference
[Address table]

## Expected Behavior
[Bullet list of what should work when fully healthy]

## Deploy & Access
[Standard deploy commands]

## Observed Symptoms
[Copy-paste show command outputs demonstrating the failure state]

## Your Task
Identify the misconfiguration using show commands. Do not look at the config
files yet — diagnose from symptoms first.

## Useful Show Commands
[Protocol-specific diagnostic commands]

## Hints
<details><summary>Hint 1 — Where to start</summary>...</details>
<details><summary>Hint 2 — Narrowing it down</summary>...</details>
<details><summary>Hint 3 — The specific problem</summary>...</details>

## Solution
<details><summary>Fix (don't peek!)</summary>
[Exact vtysh commands to fix the bug]
</details>

## Verification
[Show command outputs expected after the fix is applied]
```

---

## Bug Selection Criteria

- **Realistic** — misconfigs that actually happen (wrong area, wrong remote-AS, missing keyword, typo in key)
- **Diagnosable via show commands** — the bug must be discoverable without reading config files
- **Protocol-appropriate** — each bug exercises the diagnostic tools for that specific protocol
- **Single root cause** (Phase 1 & 2) or **two related bugs** (Phase 3)

---

## Phase 1 — Foundational (OSPF + BGP Core)

| # | Lab | Parent | Status | Bug | Key Show Command |
|---|-----|--------|--------|-----|-----------------|
| 1 | `debug-ospf-multiarea` | ospf-multiarea | ✅ | r3's eth2 assigned to area 0 instead of area 2 → r4 can't form adjacency | `show ip ospf neighbor`, `show ip ospf interface eth2` |
| 2 | `debug-ospf-auth` | ospf-auth | ✅ | Key value mismatch: r1 uses `"secret"`, r2 uses `"secrt"` → adjacency stuck in INIT | `show ip ospf interface`, `show ip ospf neighbor` |
| 3 | `debug-bgp-basics` | bgp-basics | ✅ | `next-hop-self` missing on r2 for iBGP peer r3 → r3 sees prefix but can't install it (unreachable next-hop) | `show bgp ipv4 unicast`, `show bgp ipv4 unicast <prefix>`, `show ip route bgp` |
| 4 | `debug-bgp-path-selection` | bgp-path-selection | ✅ | `local-preference` route-map applied outbound on isp1 instead of inbound → path selection reversed | `show bgp ipv4 unicast`, `show bgp ipv4 unicast <prefix> detail` |
| 5 | `debug-ospf-bgp-redist` | ospf-bgp-redist | ✅ | BGP routes redistributed into OSPF but OSPF routes NOT redistributed into BGP → one-way reachability | `show ip route`, `show ip ospf database external`, `show bgp ipv4 unicast` |

---

## Phase 2 — Intermediate (EIGRP, IS-IS, BGP Advanced, VRF, DC)

| # | Lab | Parent | Status | Bug | Key Show Command |
|---|-----|--------|--------|-----|-----------------|
| 6 | `debug-eigrp-basics` | eigrp-basics | ✅ | r3 configured as `router eigrp 101` instead of `router eigrp 100` → no EIGRP adjacency with neighbors | `show ip eigrp neighbors`, `show ip eigrp topology` |
| 7 | `debug-bgp-filtering` | bgp-filtering | ✅ | Prefix-list applied with direction `in` instead of `out` on one peer → filters received routes instead of advertisements | `show bgp ipv4 unicast neighbors <ip> advertised-routes`, `show bgp ipv4 unicast neighbors <ip> received-routes` |
| 8 | `debug-isis-basics` | isis-basics | ✅ | r2's NET address uses area `49.0002` instead of `49.0001` → no L1 adjacency between r1 and r2 | `show isis neighbor`, `show isis database` |
| 9 | `debug-vrf-lite` | vrf-lite | ✅ | pe1's CE-A-facing interface enslaved to VRF-BLUE instead of VRF-RED → CE-A traffic in wrong VRF, routing table mismatch | `show ip vrf`, `show ip route vrf RED`, `ip vrf exec RED ping ...` |
| 10 | `debug-spine-leaf` | spine-leaf | ✅ | leaf2 missing `maximum-paths 2` and `bgp bestpath as-path multipath-relax` → no ECMP, only one path installed despite two spines | `show bgp ipv4 unicast summary`, `show ip route bgp`, `show bgp ipv4 unicast <prefix>` |

---

## Phase 3 — Advanced (Tunnels, MPLS, DC Overlay)

| # | Lab | Parent | Status | Bug | Key Show Command |
|---|-----|--------|--------|-----|-----------------|
| 11 | `debug-gre-basics` | gre-basics | ✅ | gw-b's tunnel remote endpoint uses gw-a's LAN IP instead of WAN IP → tunnel comes up but traffic loops / drops | `ip tunnel show tun0`, `ping <dest>`, `traceroute` |
| 12 | `debug-ospf-nssa` | ospf-nssa | ✅ | r1 (ASBR inside NSSA area) configured as `stub` instead of `nssa` → area-type mismatch, adjacency never forms, Type-7 LSAs never generated | `show ip ospf interface`, `show ip ospf neighbor`, `show ip ospf database nssa-external` |
| 13 | `debug-dmvpn-phase1` | dmvpn-phase1 | ✅ | spoke1's `ip nhrp nhs` points to hub's WAN IP (10.0.0.1) instead of hub's tunnel IP (172.16.0.1) → NHRP registration fails, spoke1 isolated | `show ip nhrp`, `show ip nhrp nhs`, `show ip ospf neighbor` |
| 14 | `debug-mpls-sr-isis-bgp` | mpls-sr-isis-bgp | ✅ | pe2's SR node-SID index is `2` (same as pe1) instead of `3` → label collision, MPLS forwarding table incorrect | `show isis segment-routing node-list`, `show mpls table`, `show bgp ipv4 vpn` |
| 15 | `debug-vxlan-evpn` | vxlan-evpn | ✅ | vtep2's vxlan interface has `local 10.0.0.1` instead of `local 10.0.0.2` → EVPN routes advertised with wrong next-hop, frames delivered incorrectly | `show bgp l2vpn evpn`, `ip link show vxlan100`, `bridge fdb show` |

---

## Phase 4 — Real Router Image Labs (cEOS + SR-Linux)

| # | Lab | Parent | Status | Bug | Key Show Command |
|---|-----|--------|--------|-----|-----------------|
| 16 | `debug-gre-ceos` | gre-ceos | 🔲 | gw-b's `tunnel destination` set to gw-a's LAN IP (192.168.1.1) instead of WAN IP (203.0.113.1) → tunnel stays down | `show interfaces Tunnel0`, `ping 203.0.113.1` |
| 17 | `debug-dmvpn-ceos` | dmvpn-ceos | 🔲 | spoke2's `ip nhrp nhs` has wrong NBMA IP: `10.0.0.11` (spoke1's WAN) instead of `10.0.0.1` (hub's WAN) → spoke2 NHRP registration fails | `show ip nhrp`, `show ip nhrp nhs`, `show ip ospf neighbor` |
| 18 | `debug-vxlan-evpn-srlinux` | vxlan-evpn-srlinux | 🔲 | vtep2's `egress.source-ip` set to `10.0.0.1` (vtep1's loopback) instead of `10.0.0.2` → EVPN routes advertised with wrong VTEP next-hop | `show network-instance default protocols bgp routes evpn`, `show tunnel-interface vxlan1` |

*(Build parent labs first; debug variants are lower priority)*

---

## Suggested Study Order

Work through debug labs **after** completing the corresponding practice lab. The practice lab builds the skill; the debug lab tests whether you can recognize when it's broken.

**CCNP path:**
1. `debug-ospf-multiarea` (after ospf-multiarea)
2. `debug-ospf-auth` (after ospf-auth)
3. `debug-bgp-basics` (after bgp-basics)
4. `debug-bgp-path-selection` (after bgp-path-selection)
5. `debug-ospf-bgp-redist` (after ospf-bgp-redist)
6. `debug-eigrp-basics` (after eigrp-basics)
7. `debug-bgp-filtering` (after bgp-filtering)

**Service provider path:**
8. `debug-isis-basics` (after isis-basics)
9. `debug-mpls-sr-isis-bgp` (after mpls-sr-isis-bgp)

**Data center path:**
10. `debug-spine-leaf` (after spine-leaf)
11. `debug-vxlan-evpn` (after vxlan-evpn)

**Tunnels / VPN:**
12. `debug-gre-basics` (after gre-basics)
13. `debug-ospf-nssa` (after ospf-nssa)
14. `debug-dmvpn-phase1` (after dmvpn-phase1)
15. `debug-vrf-lite` (after vrf-lite)

**Real router image labs (optional, after FRR counterparts):**
16. `debug-gre-ceos` (after gre-ceos)
17. `debug-dmvpn-ceos` (after dmvpn-ceos)
18. `debug-vxlan-evpn-srlinux` (after vxlan-evpn-srlinux)
