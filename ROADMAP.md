# ContainerLab CCNP Study Roadmap

All labs live in `labs/<name>/`. Deploy any lab with:
```bash
sudo containerlab deploy -t labs/<name>/topology.yml
```
Access a node's FRR CLI: `docker exec -it clab-<name>-<node> vtysh`

---

## Status key
- ✅ Complete
- 🔲 Not yet built

---

## Track 1 — OSPF

| # | Lab | Status | Key topics |
|---|-----|--------|------------|
| 1 | `two-routers` | ✅ | Single-area OSPF, neighbour adjacency, point-to-point links |
| 2 | `ospf-multiarea` | ✅ | Areas 0/1/2, ABRs, stub area, Type-3 LSAs |
| 3 | `ospf-auth` | ✅ | MD5 interface authentication, key mismatches, troubleshoot |
| 4 | `ospf-summarization` | ✅ | Inter-area summarization (ABR), external summarization (ASBR) |
| 5 | `ospf-default-route` | ✅ | `default-information originate`, always flag, conditional default |
| 6 | `ospf-nssa` | ✅ | Not-So-Stubby Area, Type-7 LSAs, NSSA ASBR, ABR translation |
| 7 | `ospf-virtual-link` | ✅ | Virtual link through transit area, discontiguous area 0 |
| 8 | `ospf-bgp-redist` | ✅ | Mutual OSPF↔BGP redistribution, default metric, route types |

---

## Track 2 — EIGRP

| # | Lab | Status | Key topics |
|---|-----|--------|------------|
| 9  | `eigrp-basics` | ✅ | Hello/dead, topology table, successor, feasible successor, AD |
| 10 | `eigrp-variance` | ✅ | Unequal-cost load balancing, variance multiplier |
| 11 | `eigrp-stub` | ✅ | Stub router, leak-map, query scope reduction |

---

## Track 3 — BGP

| # | Lab | Status | Key topics |
|---|-----|--------|------------|
| 12 | `bgp-basics` | ✅ | eBGP/iBGP sessions, network statement, next-hop issue, split-horizon |
| 13 | `bgp-path-selection` | ✅ | Weight, local-pref, AS-path length, origin, MED — step-by-step |
| 14 | `bgp-communities` | ✅ | Standard and extended communities, route-maps, filtering by community |
| 15 | `bgp-filtering` | ✅ | Prefix-lists, AS-path access-lists, distribute-lists, route-maps |
| 16 | `bgp-aggregation` | ✅ | aggregate-address, summary-only, as-set, atomic-aggregate |
| 17 | `bgp-prefix-security` | ✅ | Route hijack demo, prefix-list filtering, max-prefix limits, RPKI concepts |
| 18 | `bgp-labeled-unicast` | ✅ | BGP-LU (RFC 3107), labeled IPv4 unicast, inter-AS MPLS Option C |
| 19 | `ipv6-bgp` | ✅ | BGP dual-stack (IPv4+IPv6 AFI), extended next-hop, native IPv6 sessions |

---

## Track 4 — IS-IS

| # | Lab | Status | Key topics |
|---|-----|--------|------------|
| 20 | `isis-basics` | ✅ | IS-IS area, NET address, Level-1/Level-2, DIS election, LSP flooding |
| 21 | `isis-multiarea` | ✅ | L1/L2/L1L2 routers, inter-area routing, route leaking |

---

## Track 5 — Route Control & Redistribution

| # | Lab | Status | Key topics |
|---|-----|--------|------------|
| 22 | `redistribution-tags` | ✅ | Tag-based loop prevention in mutual redistribution (OSPF↔EIGRP) |
| 23 | `route-maps-pbr` | ✅ | Policy-based routing, set next-hop, set interface, ip local policy |
| 24 | `ip-sla-tracking` | ✅ | IP SLA probes, track objects, floating static routes, route failover |

---

## Track 6 — IPv6

| # | Lab | Status | Key topics |
|---|-----|--------|------------|
| 25 | `ipv6-ospf3` | ✅ | OSPFv3, link-local next-hops, dual-stack, IPv6 area types |
| 26 | `ipv6-bgp` | ✅ | BGP dual-stack — see Track 3 #19 |

---

## Track 7 — Tunnels & VPN

| # | Lab | Status | Key topics |
|---|-----|--------|------------|
| 27 | `gre-basics` | ✅ | GRE point-to-point tunnel, routing over GRE, recursive routing pitfall |
| 28 | `gre-ipsec` | ✅ | GRE tunnel protected by IPsec transport mode (strongSwan) |
| 29 | `ipsec-basics` | ✅ | IKEv2 site-to-site IPsec, PSK, tunnel mode, strongSwan |
| 30 | `dmvpn-phase1` | ✅ | Hub-and-spoke DMVPN, mGRE, NHRP registration, OSPF over tunnel |
| 31 | `wireguard` | ✅ | WireGuard VPN, keypair setup, wg interface, routing over WireGuard |
| 32 | `vrf-lite` | ✅ | VRF-Lite segmentation without MPLS, per-VRF routing tables |

---

## Track 8 — MPLS & SP

| # | Lab | Status | Key topics |
|---|-----|--------|------------|
| 33 | `mpls-sr-isis-bgp` | ✅ | IS-IS SR-MPLS, BGP VPNv4, L3VPN, route reflector — full SP stack |
| 34 | `mpls-sr-blank` | ✅ | Practice version of above (IP addressing only, you build the stack) |

---

## Track 9 — High Availability & Fast Convergence

| # | Lab | Status | Key topics |
|---|-----|--------|------------|
| 35 | `bfd-ospf` | ✅ | BFD timers, OSPF integration, sub-second link failure detection |
| 36 | `bfd-bgp` | ✅ | BFD with BGP sessions, fast session teardown vs hold timer |
| 37 | `vrrp` | ✅ | VRRP master/backup, virtual IP, priority, preemption, failover |

---

## Track 10 — Data Center

| # | Lab | Status | Key topics |
|---|-----|--------|------------|
| 38 | `spine-leaf` | ✅ | BGP CLOS fabric (RFC 7938), unique AS per device, ECMP, /31 links |
| 39 | `vxlan-evpn` | ✅ | VXLAN VTEPs, BGP EVPN control plane, type-2/type-3 routes |

---

## Suggested study order

If you're working toward **CCNP Enterprise (ENCOR + ENARSI)**:

1. OSPF track (1–8) — foundation IGP
2. EIGRP track (9–11) — second IGP, ENARSI focus
3. BGP basics and path selection (12–13) — core eBGP/iBGP
4. Route control (22–24) — redistribution and policy
5. Tunnels/VPN (27–32) — overlay networking
6. BGP advanced (14–19) — communities, filtering, aggregation, security
7. HA track (35–37) — fast convergence
8. IS-IS (20–21) — often tested lightly
9. MPLS/SP track (33–34) — deepest SP content

Then branch into:
- **Data center track** (38–39) for DC/cloud engineers
- **IPv6 track** (25–26) for modern dual-stack networks

---

## Node naming conventions

- **CE** — Customer Edge (end-site routers, often OSPF or static)
- **PE** — Provider Edge (faces both customer and provider networks)
- **P** — Provider core (transit-only)
- **RR** — BGP Route Reflector
- **ABR** — OSPF Area Border Router
- **ASBR** — Autonomous System Boundary Router
- **gw-x** — gateway / edge router in tunnel labs
- **isp1/isp2** — simulated upstream ISP routers in BGP labs
- **spine-x / leaf-x** — data center fabric nodes
- **vtep1/vtep2** — VXLAN Tunnel Endpoints
