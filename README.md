# ContainerLab Networking Labs

A self-hosted lab environment with **104 hands-on networking labs** covering OSPF, BGP, MPLS,
VPN, data center, enterprise design, security, operations, and more. Labs run locally using
[ContainerLab](https://containerlab.dev/) with [FRRouting](https://frrouting.org/),
[Arista cEOS](https://www.arista.com/en/support/software-download),
[VyOS](https://vyos.io/), and [Nokia SR-Linux](https://learn.srlinux.dev/).

---

## Quick Start

```bash
# Deploy a lab
sudo containerlab deploy -t labs/<name>/topology.clab.yml

# Attach to an FRR node's CLI
docker exec -it clab-<name>-<node> vtysh

# Attach to a cEOS node's CLI
docker exec -it clab-<name>-<node> Cli

# Attach to a node's shell
docker exec -it clab-<name>-<node> bash

# Destroy the lab (removes containers)
sudo containerlab destroy -t labs/<name>/topology.clab.yml --cleanup
```

**Example:**
```bash
sudo containerlab deploy -t labs/ospf-multiarea/topology.clab.yml
docker exec -it clab-ospf-multiarea-r1 vtysh
sudo containerlab destroy -t labs/ospf-multiarea/topology.clab.yml --cleanup
```

---

## How the Labs Work

Each lab directory contains:

```
labs/<name>/
  topology.clab.yml   <- ContainerLab topology (nodes + links)
  README.md           <- Lab guide, tasks, verification commands
  configs/
    daemons           <- Which FRR daemons to enable (shared)
    vtysh.conf        <- FRR vtysh setting (shared)
    <node>/
      frr.conf        <- FRR config for this node
      startup-config  <- cEOS EOS startup config
      setup.sh        <- (some labs) Linux network setup script
```

**Practice labs**: IP addressing is pre-configured. You implement the protocol or feature
using the platform-native workflow (`vtysh`, `Cli`, or VyOS `configure` mode).

**Reference labs**: Fully working out of the box. Deploy and observe/explore.

**Debug labs**: Fully working topologies with one intentional bug. The README gives you
the scenario, symptoms, hints, and the hidden fix.

**Capstones**: Larger end-to-end labs that combine multiple features or workflows.

---

## Prerequisites

```bash
# Check ContainerLab is installed
containerlab version

# Check Docker is running
docker ps

# Pull the FRR image and build the enhanced version (required for ALL FRR labs)
docker pull frrouting/frr:latest
docker build -t frr-lab:local images/frr/
```

### Labs requiring custom images

```bash
# wireguard
docker build -t wireguard-lab:local labs/wireguard/

# dot1x-nac
docker build -t nac-lab:local labs/dot1x-nac/

# network-assurance
docker build -t assurance-lab:local labs/network-assurance/

# qos-enterprise
docker build -t qos-lab:local labs/qos-enterprise/

# management-access-control, dhcp-dns-troubleshooting, ipv6-access-services
docker build -t ops-lab:local images/ops-lab/

# aaa-ops-troubleshooting
docker build -f labs/enterprise-services-infra/Dockerfile.tacacs -t enterprise-tacacs:local labs/enterprise-services-infra/

# telemetry-monitoring-hybrid
docker build -t telemetry-lab:local labs/telemetry-monitoring-hybrid/

# network-automation-netbox
docker build -t netbox-automation:local labs/network-automation-netbox/

# enterprise-services-infra
docker build -t enterprise-services-infra:local labs/enterprise-services-infra/

# enterprise-edge-nat-firewall
docker build -t dmz-lab:local labs/enterprise-edge-nat-firewall/

# enterprise-access-security
docker build -t enterprise-access-tools:local labs/enterprise-access-security/

# dot1x-ceos-practice
docker build -t nac-practice:local labs/dot1x-ceos-practice/
```

### Labs requiring Arista cEOS

Import the cEOS image once:
```bash
docker import cEOS-lab-4.35.2F.tar ceos:4.35.2F
```
Used by: `gre-ceos`, `spine-leaf-ceos`, `evpn-vxlan-ceos`,
`evpn-border-ceos`, `vrf-lite`, `enterprise-*`, `ha-network-design-ceos`.

### Labs requiring VyOS

Build the local VyOS router image:
```bash
docker build -t vyos:local -f Dockerfile.vyos .
```
Used by: `ipsec-basics`, `gre-ipsec`, `macsec-basics`, `dmvpn-phase1`,
`dmvpn-phase2`, `dmvpn-phase3`, `dmvpn-phase3-ipsec-capstone`, `debug-dmvpn-phase1`.

### Labs requiring Nokia SR-Linux

```bash
docker pull ghcr.io/nokia/srlinux:latest
```
Used by: `mpls-sr-srlinux`, `vxlan-evpn-srlinux`.

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
| [ipv6-ospf3](labs/ipv6-ospf3/) | Practice | OSPFv3, link-local next-hops, IPv6 areas |

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
| [bgp-filtering](labs/bgp-filtering/) | Practice | Prefix-lists, AS-path ACLs, distribute-lists |
| [bgp-communities](labs/bgp-communities/) | Practice | Standard/extended communities, route-map tagging |
| [bgp-aggregation](labs/bgp-aggregation/) | Practice | `aggregate-address`, summary-only, selective suppression |
| [bgp-prefix-security](labs/bgp-prefix-security/) | Practice | Route hijacking demo, prefix-list defenses, RPKI concepts |
| [bgp-rpki](labs/bgp-rpki/) | Practice | BGP RPKI, Route Origin Validation, ROA validation with rpkid |
| [bgp-labeled-unicast](labs/bgp-labeled-unicast/) | Practice | BGP-LU (RFC 3107), inter-AS MPLS label distribution |
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

### Track 6 — Tunnels & VPN

| Lab | Type | What You Learn |
|-----|------|----------------|
| [gre-basics](labs/gre-basics/) | Practice | GRE tunnel, routing over GRE, recursive routing pitfall |
| [gre-ceos](labs/gre-ceos/) | Practice | GRE on Arista cEOS, EOS tunnel syntax, OSPF over GRE |
| [gre-ipsec](labs/gre-ipsec/) | Practice | GRE + IPsec transport mode on VyOS |
| [ipsec-basics](labs/ipsec-basics/) | Practice | IKEv2 site-to-site IPsec, PSK, tunnel mode |
| [dmvpn-phase1](labs/dmvpn-phase1/) | Practice | Hub-and-spoke DMVPN, mGRE, NHRP, OSPF over tunnel (VyOS) |
| [dmvpn-phase2](labs/dmvpn-phase2/) | Practice | DMVPN Phase 2 — spoke-to-spoke tunnels, NHRP shortcuts (VyOS) |
| [dmvpn-phase3](labs/dmvpn-phase3/) | Practice | DMVPN Phase 3 — NHRP shortcuts with OSPF p2mp (VyOS) |
| [dmvpn-phase3-ipsec-capstone](labs/dmvpn-phase3-ipsec-capstone/) | Capstone | DMVPN Phase 3 with in-lab PKI and certificate-based IPsec (VyOS) |
| [flexvpn-basics](labs/flexvpn-basics/) | Practice | IKEv2 FlexVPN, Virtual Tunnel Interfaces, strongSwan |
| [wireguard](labs/wireguard/) | Practice | WireGuard VPN, key pairs, hub-and-spoke topology |
| [vrf-lite](labs/vrf-lite/) | Practice | VRF-Lite on cEOS, per-VRF routing tables, route leaking |

---

### Track 7 — MPLS & Service Provider

| Lab | Type | What You Learn |
|-----|------|----------------|
| [mpls-sr-blank](labs/mpls-sr-blank/) | Practice | Build the full SP stack yourself from scratch (FRR) |
| [mpls-sr-isis-bgp](labs/mpls-sr-isis-bgp/) | **Reference** | IS-IS + SR-MPLS + BGP VPNv4 + L3VPN (FRR) |
| [mpls-sr-srlinux](labs/mpls-sr-srlinux/) | **Reference** | Same SP stack on Nokia SR-Linux — compare platforms |
| [mpls-l2vpn](labs/mpls-l2vpn/) | Practice | MPLS pseudowire L2VPN (VPWS), transparent Ethernet over MPLS |
| [ipv6-transition](labs/ipv6-transition/) | Practice | 6PE (RFC 4798) — IPv6 over IPv4 MPLS/SR core |

---

### Track 8 — Data Center

| Lab | Type | What You Learn |
|-----|------|----------------|
| [spine-leaf](labs/spine-leaf/) | Practice | BGP CLOS fabric (FRR), unique AS per device, ECMP |
| [spine-leaf-ceos](labs/spine-leaf-ceos/) | Practice | BGP CLOS fabric on Arista cEOS |
| [vxlan-evpn](labs/vxlan-evpn/) | **Reference** | VXLAN + BGP EVPN control plane (FRR) |
| [vxlan-evpn-srlinux](labs/vxlan-evpn-srlinux/) | **Reference** | VXLAN + BGP EVPN on Nokia SR-Linux |
| [evpn-vxlan-ceos](labs/evpn-vxlan-ceos/) | Practice | VXLAN + EVPN on Arista cEOS, L2VNI + L3VNI, symmetric IRB |
| [evpn-border-ceos](labs/evpn-border-ceos/) | Practice | EVPN border leaf, external eBGP in VRF, type-5 routes |

---

### Track 9 — High Availability & Fast Convergence

| Lab | Type | What You Learn |
|-----|------|----------------|
| [bfd-ospf](labs/bfd-ospf/) | Practice | BFD with OSPF, sub-second link failure detection |
| [bfd-bgp](labs/bfd-bgp/) | Practice | BFD with BGP, fast session teardown vs hold timer |
| [vrrp](labs/vrrp/) | Practice | VRRP master/backup, virtual IP, priority, preemption |
| [ha-network-design-ceos](labs/ha-network-design-ceos/) | Practice | MLAG, VRRP tracking, OSPF+BFD+ECMP, dual-ISP BGP combined |
| [graceful-restart](labs/graceful-restart/) | Practice | Graceful Restart for BGP on cEOS, using a route reflector and BGP-only service routes |

---

### Track 10 — Enterprise Design

| Lab | Type | What You Learn |
|-----|------|----------------|
| [enterprise-collapsed-core](labs/enterprise-collapsed-core/) | **Reference** | 2-tier campus: collapsed core/distribution, VRRP, STP, OSPF |
| [enterprise-campus](labs/enterprise-campus/) | **Reference** | 3-tier campus: core/distribution/access, eBGP upstream |
| [enterprise-routed-access](labs/enterprise-routed-access/) | **Reference** | L3-everywhere: routed access layer, no STP, OSPF+BFD |
| [enterprise-dmz](labs/enterprise-dmz/) | **Reference** | Screened-subnet DMZ, dual-firewall, nftables policy |
| [enterprise-wan-edge](labs/enterprise-wan-edge/) | Practice | Dual-ISP BGP edge, LP inbound policy, AS-path prepend outbound |
| [enterprise-access-security](labs/enterprise-access-security/) | Practice | DHCP snooping, dynamic ARP inspection, port security |
| [enterprise-edge-nat-firewall](labs/enterprise-edge-nat-firewall/) | Practice | PAT, nftables firewall policy, internet edge |
| [enterprise-multicast](labs/enterprise-multicast/) | Practice | IGMP, PIM-SM, multicast routing, RP configuration |
| [enterprise-services-infra](labs/enterprise-services-infra/) | Practice | DHCP relay, NTP, DNS, syslog, SNMP — supporting services |
| [enterprise-wireless-architecture](labs/enterprise-wireless-architecture/) | Practice | Enterprise WLAN design, controller modes, WLC architectures |

#### Capstone Labs

| Lab | Type | What You Build |
|-----|------|----------------|
| [enterprise-campus-capstone](labs/enterprise-campus-capstone/) | Practice | Configure full 3-tier campus from scratch (OSPF, VRRP, STP) |
| [enterprise-collapsed-core-capstone](labs/enterprise-collapsed-core-capstone/) | Practice | Configure 2-tier collapsed-core campus from scratch |
| [enterprise-dmz-capstone](labs/enterprise-dmz-capstone/) | Capstone | Build a screened-subnet DMZ with dual firewalls, DNAT, SNAT, and segmentation policy |
| [enterprise-routed-access-capstone](labs/enterprise-routed-access-capstone/) | Practice | Configure L3-everywhere campus — OSPF multi-area, BFD |
| [enterprise-wan-edge-capstone](labs/enterprise-wan-edge-capstone/) | Practice | Configure dual-homed BGP with traffic engineering from scratch |

---

### Track 11 — Security

| Lab | Type | What You Learn |
|-----|------|----------------|
| [acl-basics](labs/acl-basics/) | Practice | Interface ACLs for router-local services, default deny, protocol/port filtering, counters |
| [macsec-basics](labs/macsec-basics/) | Practice | IEEE 802.1AE MACsec, MKA key agreement, infrastructure + endpoint modes |
| [dot1x-nac](labs/dot1x-nac/) | Practice | 802.1X port authentication, RADIUS, EAP, NAC enforcement |
| [urpf-antispoofing](labs/urpf-antispoofing/) | Practice | Unicast RPF, source IP anti-spoofing, strict vs loose mode |
| [copp-basics](labs/copp-basics/) | Practice | Control Plane Policing, traffic classification, rate limiting |
| [dot1x-ceos-practice](labs/dot1x-ceos-practice/) | Practice | 802.1X wired NAC on Arista EOS, RADIUS, MAB |

---

### Track 12 — Network Operations

| Lab | Type | What You Learn |
|-----|------|----------------|
| [management-access-control](labs/management-access-control/) | Practice | Restrict SSH/UI access by source subnet and interface, verify with counters |
| [dhcp-dns-troubleshooting](labs/dhcp-dns-troubleshooting/) | Practice | Diagnose DHCP option issues and DNS correctness from the client side |
| [aaa-ops-troubleshooting](labs/aaa-ops-troubleshooting/) | Practice | TACACS reachability, shared secrets, local fallback, break-glass access |
| [ipv6-access-services](labs/ipv6-access-services/) | Practice | Router advertisements, SLAAC, default route learning, DNS over IPv6 |
| [packet-analysis-basics](labs/packet-analysis-basics/) | Practice | ARP, OSPF, ICMP, TCP handshake capture, mirrored traffic, Wireshark workflow |
| [mtu-pmtud-troubleshooting](labs/mtu-pmtud-troubleshooting/) | Practice | GRE overhead, exact-size probes, PMTUD, tunnel MTU correction |
| [network-assurance](labs/network-assurance/) | Practice | SNMP, syslog, SPAN, NetFlow — four observability mechanisms |
| [qos-enterprise](labs/qos-enterprise/) | Practice | Linux `tc` QoS: DSCP marking, HTB scheduling, WRED, SFQ |
| [network-automation-netbox](labs/network-automation-netbox/) | Practice | NetBox inventory, automation workflow, programmatic config |
| [telemetry-monitoring-hybrid](labs/telemetry-monitoring-hybrid/) | Practice | gNMI telemetry, Prometheus, Grafana, classic NMS |

---

### Track 13 — Layer 2

| Lab | Type | What You Learn |
|-----|------|----------------|
| [vlan-trunks-switchport-basics](labs/vlan-trunks-switchport-basics/) | Practice | VLAN creation, access ports, trunks, allowed VLANs, pruning symptoms |
| [campus-l2-hardening](labs/campus-l2-hardening/) | Practice | PortFast, BPDU Guard, Root Guard, storm control on a compact campus edge |
| [stp-operations](labs/stp-operations/) | Practice | Spanning Tree operations, port states, failure handling |
| [lacp-etherchannel](labs/lacp-etherchannel/) | Practice | 802.3ad LACP EtherChannel, Port-Channel, link aggregation |

---

### Debug Labs

Each debug lab is a fully-working topology with **one intentional bug**. The README gives
you the scenario, symptoms, three-level hints, and the solution. Use them to practice
structured troubleshooting.

| Lab | Bug Domain |
|-----|-----------|
| [debug-ospf-multiarea](labs/debug-ospf-multiarea/) | OSPF multi-area |
| [debug-ospf-auth](labs/debug-ospf-auth/) | OSPF authentication |
| [debug-ospf-nssa](labs/debug-ospf-nssa/) | OSPF NSSA |
| [debug-ospf-bgp-redist](labs/debug-ospf-bgp-redist/) | OSPF↔BGP redistribution |
| [debug-eigrp-basics](labs/debug-eigrp-basics/) | EIGRP |
| [debug-isis-basics](labs/debug-isis-basics/) | IS-IS |
| [debug-bgp-basics](labs/debug-bgp-basics/) | BGP sessions |
| [debug-bgp-path-selection](labs/debug-bgp-path-selection/) | BGP path selection |
| [debug-bgp-filtering](labs/debug-bgp-filtering/) | BGP filtering |
| [debug-gre-basics](labs/debug-gre-basics/) | GRE tunnels |
| [debug-dmvpn-phase1](labs/debug-dmvpn-phase1/) | DMVPN |
| [debug-vrf-lite](labs/debug-vrf-lite/) | VRF-Lite (cEOS) |
| [debug-spine-leaf](labs/debug-spine-leaf/) | BGP spine-leaf |
| [debug-mpls-sr-isis-bgp](labs/debug-mpls-sr-isis-bgp/) | MPLS SR + BGP L3VPN |
| [debug-vxlan-evpn](labs/debug-vxlan-evpn/) | VXLAN + EVPN |

---

## Suggested Study Paths

### CCNP Enterprise (ENCOR + ENARSI)

```
OSPF:     two-routers -> ospf-multiarea -> ospf-auth -> ospf-summarization
          -> ospf-default-route -> ospf-nssa -> ospf-virtual-link
EIGRP:    eigrp-basics -> eigrp-variance -> eigrp-stub
BGP:      bgp-basics -> bgp-path-selection -> bgp-filtering -> bgp-communities -> bgp-aggregation
Redist:   ospf-bgp-redist -> redistribution-tags -> route-maps-pbr
Tunnels:  gre-basics -> ipsec-basics -> gre-ipsec -> dmvpn-phase1
HA:       bfd-ospf -> bfd-bgp -> vrrp
IS-IS:    isis-basics -> isis-multiarea
IPv6:     ipv6-ospf3 -> ipv6-bgp
```

### Service Provider

```
Prereq:   CCNP path above
BGP-LU:   bgp-labeled-unicast
MPLS:     mpls-sr-blank -> mpls-sr-isis-bgp (reference) -> mpls-sr-srlinux (reference)
```

### Data Center / EVPN

```
Prereq:   bgp-basics -> bgp-path-selection
Fabric:   spine-leaf -> spine-leaf-ceos
VXLAN:    vxlan-evpn (reference) -> evpn-vxlan-ceos -> evpn-border-ceos
SR-Linux: vxlan-evpn-srlinux (reference)
VRF:      vrf-lite
```

### Enterprise Design

```
Prereq:   ospf-multiarea, bgp-basics, vrrp
Designs:  enterprise-collapsed-core -> enterprise-campus -> enterprise-routed-access
Edge:     enterprise-wan-edge
DMZ:      enterprise-dmz
Capstone: enterprise-dmz-capstone
HA:       ha-network-design-ceos
```

### Security

```
acl-basics -> bgp-prefix-security -> ipsec-basics -> gre-ipsec
-> macsec-basics -> dot1x-nac
```

### Network Operations

```
management-access-control -> dhcp-dns-troubleshooting -> aaa-ops-troubleshooting
-> packet-analysis-basics -> mtu-pmtud-troubleshooting -> ipv6-access-services
-> telemetry-monitoring-hybrid -> network-automation-netbox
```

### Troubleshooting Practice

```
debug-ospf-multiarea -> debug-bgp-basics -> debug-eigrp-basics -> debug-isis-basics
-> debug-bgp-filtering -> debug-gre-basics -> debug-spine-leaf
-> debug-vxlan-evpn -> debug-mpls-sr-isis-bgp
```

---

## Common Commands

### FRR (vtysh)

```
show version                          # FRR version and enabled daemons
show running-config                   # current config
write memory                          # save config to frr.conf

show ip ospf neighbor                 # OSPF adjacency state
show ip ospf database                 # OSPF LSDB
show ip route ospf                    # OSPF routes in RIB

show bgp ipv4 unicast summary         # BGP session state and prefix counts
show bgp ipv4 unicast                 # full BGP table
show ip route bgp                     # BGP routes in RIB

show isis neighbor                    # IS-IS adjacency state
show isis database                    # IS-IS LSDB

show mpls table                       # MPLS forwarding table
show bfd peers                        # BFD session state
show ip route                         # full routing table
```

### Arista cEOS (Cli)

```
show version                          # EOS version
show running-config                   # current config

show ip ospf neighbor                 # OSPF adjacency state
show bgp ipv4 unicast summary         # BGP session state
show bgp ipv4 unicast                 # full BGP table
show vxlan vtep                       # VXLAN remote VTEPs
show bgp evpn                         # EVPN routes
show vrf                              # VRF summary
show ip route vrf <name>              # routes in a specific VRF
```

### Nokia SR-Linux (sr_cli)

```
show version
show network-instance default route-table
show bgp neighbor
show tunnel-interface
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
| `leaf1`-`leaf4` | DC leaf switches |
| `vtep1`, `vtep2` | VXLAN Tunnel Endpoints |
| `gw-a`, `gw-b` | Gateway / edge nodes in VPN labs |
| `hub`, `spoke1`-`spoke3` | DMVPN hub and spokes |
| `host-a`, `host-b` | End hosts (test traffic source/sink) |
| `edge`, `core1`, `core2` | Enterprise WAN/core nodes |
| `dist1`, `dist2` | Enterprise distribution layer |

---

## Tips

- **Always wait for convergence** after deploy — OSPF/BGP need 15–60 seconds
- **`vtysh -b`** is run automatically on deploy to reload FRR configs after interfaces come up
- **cEOS**: use `Cli` (capital C) to access the EOS CLI; startup-config loads automatically on boot
- **SR-Linux**: use `sr_cli` to access the CLI; startup-config loads automatically on boot
- **Custom images**: build the required image before deploying labs that need one (see Prerequisites)
- **MPLS labs**: kernel label space is set via `sysctls` in `topology.clab.yml` — do not try to set it via exec
- **VRF labs (FRR)**: Linux VRFs are created by `setup.sh` — check that script if interfaces look wrong
- See `ROADMAP.md` for a topic-by-topic breakdown with study order guidance
