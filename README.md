# ContainerLab Networking Labs

A self-hosted lab environment with **38 hands-on networking labs** covering OSPF, BGP, MPLS,
VPN, data center, and more. All labs run locally using [ContainerLab](https://containerlab.dev/)
and [FRRouting (FRR)](https://frrouting.org/) inside Docker containers.

---

## Quick Start

```bash
# Deploy a lab
sudo containerlab deploy -t labs/<name>/topology.yml

# Attach to a node's FRR CLI
docker exec -it clab-<name>-<node> vtysh

# Attach to a node's shell
docker exec -it clab-<name>-<node> bash

# Destroy the lab (removes containers)
sudo containerlab destroy -t labs/<name>/topology.yml --cleanup
```

**Example:**
```bash
sudo containerlab deploy -t labs/ospf-multiarea/topology.yml
docker exec -it clab-ospf-multiarea-r1 vtysh
sudo containerlab destroy -t labs/ospf-multiarea/topology.yml --cleanup
```

---

## How the Labs Work

Each lab directory contains:

```
labs/<name>/
  topology.yml        ← ContainerLab topology (nodes + links)
  README.md           ← Lab guide, tasks, verification commands
  configs/
    daemons           ← Which FRR daemons to enable (shared)
    vtysh.conf        ← FRR vtysh setting (shared)
    <node>/
      frr.conf        ← FRR config for this node
      setup.sh        ← (some labs) Linux network setup script
```

**Practice labs**: IP addressing is pre-configured. You implement the routing protocol
or feature by running `vtysh` and entering config. Each `frr.conf` has commented-out
hints showing the expected config.

**Reference labs**: Fully working out of the box. Deploy and observe/explore.

---

## Prerequisites

```bash
# Check ContainerLab is installed
containerlab version

# Check Docker is running
docker ps

# Pull the FRR image (if not already done)
docker pull frrouting/frr:latest
```

### Labs requiring custom images

Two labs need a custom image built first:

```bash
# ipsec-basics AND gre-ipsec (both use this image)
docker build -t ipsec-lab:local labs/ipsec-basics/

# wireguard
docker build -t wireguard-lab:local labs/wireguard/
```

---

## All Labs

### Track 1 — OSPF

| Lab | Type | What You Learn |
|-----|------|----------------|
| [two-routers](labs/two-routers/) | Practice | Single-area OSPF, ContainerLab basics |
| [ospf-multiarea](labs/ospf-multiarea/) | Practice | Multi-area OSPF, ABRs, stub areas |
| [ospf-auth](labs/ospf-auth/) | Practice | OSPF MD5 authentication, key mismatches |
| [ospf-summarization](labs/ospf-summarization/) | Practice | Inter-area and external summarization |
| [ospf-default-route](labs/ospf-default-route/) | Practice | `default-information originate`, conditional default |
| [ospf-nssa](labs/ospf-nssa/) | Practice | Not-So-Stubby Area, Type-7 LSAs |
| [ospf-virtual-link](labs/ospf-virtual-link/) | Practice | Virtual links, discontiguous area 0 |
| [ospf-bgp-redist](labs/ospf-bgp-redist/) | Practice | Mutual OSPF↔BGP redistribution at an ASBR |

---

### Track 2 — EIGRP

| Lab | Type | What You Learn |
|-----|------|----------------|
| [eigrp-basics](labs/eigrp-basics/) | Practice | Hello/dead timers, successor/FS, DUAL convergence |
| [eigrp-variance](labs/eigrp-variance/) | Practice | Unequal-cost load balancing, variance multiplier |
| [eigrp-stub](labs/eigrp-stub/) | Practice | Stub routers, leak-map, query scope reduction |

---

### Track 3 — BGP

| Lab | Type | What You Learn |
|-----|------|----------------|
| [bgp-basics](labs/bgp-basics/) | Practice | eBGP/iBGP sessions, next-hop problem, split-horizon |
| [bgp-path-selection](labs/bgp-path-selection/) | Practice | Weight → LP → AS-path → MED, step by step |
| [bgp-communities](labs/bgp-communities/) | Practice | Standard/extended communities, route-map tagging |
| [bgp-filtering](labs/bgp-filtering/) | Practice | Prefix-lists, AS-path ACLs, distribute-lists |
| [bgp-aggregation](labs/bgp-aggregation/) | Practice | `aggregate-address`, summary-only, as-set |
| [bgp-prefix-security](labs/bgp-prefix-security/) | Practice | Route hijacking demo, prefix-list defenses, RPKI concepts |
| [bgp-labeled-unicast](labs/bgp-labeled-unicast/) | Practice | BGP-LU (RFC 3107), inter-AS MPLS Option C |
| [ipv6-bgp](labs/ipv6-bgp/) | Practice | Dual-stack BGP, extended next-hop, native IPv6 sessions |

---

### Track 4 — IS-IS

| Lab | Type | What You Learn |
|-----|------|----------------|
| [isis-basics](labs/isis-basics/) | Practice | NET address, Level-1/2, DIS election, LSP flooding |
| [isis-multiarea](labs/isis-multiarea/) | Practice | L1/L2/L1L2 routers, inter-area routing, route leaking |

---

### Track 5 — Route Control & Redistribution

| Lab | Type | What You Learn |
|-----|------|----------------|
| [redistribution-tags](labs/redistribution-tags/) | Practice | Tag-based loop prevention in OSPF↔EIGRP redistribution |
| [route-maps-pbr](labs/route-maps-pbr/) | Practice | Policy-based routing, match source/dest, set next-hop |
| [ip-sla-tracking](labs/ip-sla-tracking/) | Practice | IP SLA probes, object tracking, floating static routes |

---

### Track 6 — IPv6

| Lab | Type | What You Learn |
|-----|------|----------------|
| [ipv6-ospf3](labs/ipv6-ospf3/) | Practice | OSPFv3, link-local next-hops, IPv6 areas |
| [ipv6-bgp](labs/ipv6-bgp/) | Practice | Dual-stack BGP (see Track 3 above) |

---

### Track 7 — Tunnels & VPN

| Lab | Type | What You Learn |
|-----|------|----------------|
| [gre-basics](labs/gre-basics/) | Practice | GRE tunnel, routing over GRE, recursive routing pitfall |
| [gre-ipsec](labs/gre-ipsec/) | Practice | GRE + IPsec transport mode, strongSwan |
| [ipsec-basics](labs/ipsec-basics/) | Practice | IKEv2 site-to-site IPsec, PSK, tunnel mode |
| [dmvpn-phase1](labs/dmvpn-phase1/) | Practice | Hub-and-spoke DMVPN, mGRE, NHRP, OSPF over tunnel |
| [wireguard](labs/wireguard/) | Practice | WireGuard VPN, key pairs, hub-and-spoke topology |
| [vrf-lite](labs/vrf-lite/) | Practice | VRF-Lite, per-VRF routing tables, route leaking |

---

### Track 8 — MPLS & Service Provider

| Lab | Type | What You Learn |
|-----|------|----------------|
| [mpls-sr-isis-bgp](labs/mpls-sr-isis-bgp/) | **Reference** | Full SP stack: IS-IS + SR-MPLS + BGP VPNv4 + L3VPN |
| [mpls-sr-blank](labs/mpls-sr-blank/) | Practice | Build the SP stack yourself from scratch |

---

### Track 9 — High Availability & Fast Convergence

| Lab | Type | What You Learn |
|-----|------|----------------|
| [bfd-ospf](labs/bfd-ospf/) | Practice | BFD with OSPF, sub-second link failure detection |
| [bfd-bgp](labs/bfd-bgp/) | Practice | BFD with BGP, fast session teardown vs hold timer |
| [vrrp](labs/vrrp/) | Practice | VRRP master/backup, virtual IP, priority, preemption |

---

### Track 10 — Data Center

| Lab | Type | What You Learn |
|-----|------|----------------|
| [spine-leaf](labs/spine-leaf/) | Practice | BGP CLOS fabric, unique AS per device, ECMP |
| [vxlan-evpn](labs/vxlan-evpn/) | **Reference** | VXLAN tunnels, BGP EVPN control plane, MAC/IP distribution |

---

## Suggested Study Order

**CCNP Enterprise path (ENCOR + ENARSI):**
1. `two-routers` → `ospf-multiarea` → `ospf-auth` → `ospf-summarization` → `ospf-default-route` → `ospf-nssa` → `ospf-virtual-link`
2. `eigrp-basics` → `eigrp-variance` → `eigrp-stub`
3. `bgp-basics` → `bgp-path-selection`
4. `ospf-bgp-redist` → `redistribution-tags` → `route-maps-pbr`
5. `gre-basics` → `ipsec-basics` → `gre-ipsec` → `dmvpn-phase1`
6. `bgp-communities` → `bgp-filtering` → `bgp-aggregation`
7. `bfd-ospf` → `bfd-bgp` → `vrrp`
8. `isis-basics` → `isis-multiarea`

**Service Provider path:**
1. Complete CCNP path above
2. `isis-basics` → `isis-multiarea`
3. `bgp-labeled-unicast`
4. `mpls-sr-blank` (practice) → `mpls-sr-isis-bgp` (reference)

**Data Center path:**
1. `bgp-basics` → `bgp-path-selection`
2. `spine-leaf`
3. `vxlan-evpn`
4. `vrf-lite`

---

## Common FRR Commands

```
# General
show version               # FRR version and enabled daemons
show running-config        # current config
write memory               # save config to frr.conf

# OSPF
show ip ospf neighbor      # adjacency state
show ip ospf database      # LSDB
show ip route ospf         # OSPF routes in RIB

# BGP
show bgp ipv4 unicast summary      # session state and prefix counts
show bgp ipv4 unicast              # full BGP table
show ip route bgp                  # BGP routes in RIB

# IS-IS
show isis neighbor         # adjacency state
show isis database         # LSDB
show isis route            # IS-IS routes

# MPLS
show mpls table            # MPLS forwarding table
show bgp l2vpn evpn        # EVPN routes (vxlan-evpn lab)

# BFD
show bfd peers             # BFD session state

# General
show ip route              # full routing table
show interface brief       # interface state and IPs
```

---

## Node Naming Conventions

| Name | Role |
|------|------|
| `r1`, `r2`, ... | Generic routers |
| `ce1`, `ce2` | Customer Edge |
| `pe1`, `pe2` | Provider Edge |
| `p1`, `p2` | Provider core (transit) |
| `rr1` | BGP Route Reflector |
| `spine1`, `spine2` | DC spine switches |
| `leaf1`–`leaf4` | DC leaf switches |
| `vtep1`, `vtep2` | VXLAN Tunnel Endpoints |
| `gw-a`, `gw-b` | Gateway / edge nodes in VPN labs |
| `hub`, `spoke1`–`spoke3` | DMVPN hub and spokes |
| `host-a`, `host-b` | End hosts (test traffic source/sink) |

---

## Tips

- **Always wait for convergence** after deploy — OSPF/BGP need 15–60 seconds
- **`vtysh -b`** is run automatically on deploy to reload configs after interfaces come up
- **Custom images**: build `ipsec-lab:local` and `wireguard-lab:local` before those labs
- **MPLS labs**: kernel MPLS must be enabled — the topologies set `net.mpls.platform_labels` via `sysctls`
- **VRF labs** (`vrf-lite`, `mpls-sr-isis-bgp`): Linux VRFs are created by `setup.sh` — check that script if something seems wrong
- See `ROADMAP.md` for a topic-by-topic breakdown with study order guidance
