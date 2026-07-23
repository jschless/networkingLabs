# Enterprise Design Track

Twenty labs covering campus design patterns, WAN edge, hybrid connectivity, SD-WAN concepts, DMZ architecture, load balancing, access security, multicast, services, and wireless architecture/authorization — primarily on Arista cEOS with Linux service nodes where needed.

## Reference Designs

| Lab | Type | What You Learn |
|-----|------|----------------|
| [enterprise-collapsed-core](enterprise-collapsed-core.md) | **Reference** | 2-tier campus: collapsed core/distribution, VRRP, STP, OSPF |
| [enterprise-campus](enterprise-campus.md) | **Reference** | 3-tier campus: core/distribution/access, eBGP upstream |
| [enterprise-routed-access](enterprise-routed-access.md) | **Reference** | L3-everywhere: routed access, no STP, OSPF+BFD |
| [enterprise-dmz](enterprise-dmz.md) | **Reference** | Screened-subnet DMZ, dual-firewall, nftables policy |
| [sdwan-concepts](sdwan-concepts.md) | **Reference** | Two transports, GRE overlay, DSCP path policy, probe-driven failover — each piece mapped to vManage/vSmart/OMP/BFD |

## Practice Labs

| Lab | Type | What You Learn |
|-----|------|----------------|
| [enterprise-wan-edge](enterprise-wan-edge.md) | Practice | Dual-ISP BGP edge, LP inbound policy, AS-path prepend outbound |
| [enterprise-access-security](enterprise-access-security.md) | Practice | DHCP snooping, dynamic ARP inspection, port security |
| [enterprise-edge-nat-firewall](enterprise-edge-nat-firewall.md) | Practice | PAT, nftables firewall policy, internet edge |
| [load-balancer-basics](load-balancer-basics.md) | Practice | HAProxy L4 vs L7, health checks, X-Forwarded-For, NAT-mode balancing, asymmetric-return break-it |
| [enterprise-multicast](enterprise-multicast.md) | Practice | IGMP, PIM-SM, multicast routing, RP configuration |
| [enterprise-services-infra](enterprise-services-infra.md) | Practice | DHCP relay, NTP, DNS, syslog, SNMP — supporting services |
| [enterprise-wireless-architecture](enterprise-wireless-architecture.md) | Practice | Enterprise WLAN design, controller modes, WLC architectures |
| [wireless-auth-control-operations](wireless-auth-control-operations.md) | Practice | EAP-TLS/RADIUS authorization, role VLAN policy, and certificate-trust incident; no live RF claim |
| [cloud-hybrid-networking](cloud-hybrid-networking.md) | Practice | Hybrid eBGP, transit route domains, inspection, private DNS, and asymmetric-return diagnosis |
| [carrier-ethernet-handoff](carrier-ethernet-handoff.md) | Practice | QinQ E-Line turn-up, MTU acceptance, evidence-only OAM/physical analysis, and wrong-cross-connect diagnosis |

## Capstone Labs

Build an entire design from scratch with only IPs and interfaces pre-configured.

| Lab | Type | What You Build |
|-----|------|----------------|
| [enterprise-campus-capstone](enterprise-campus-capstone.md) | Capstone | Full 3-tier campus (OSPF, VRRP, STP) |
| [enterprise-collapsed-core-capstone](enterprise-collapsed-core-capstone.md) | Capstone | 2-tier collapsed-core campus |
| [enterprise-dmz-capstone](enterprise-dmz-capstone.md) | Capstone | Dual-firewall screened-subnet DMZ with DNAT, SNAT, and segmentation policy |
| [enterprise-routed-access-capstone](enterprise-routed-access-capstone.md) | Capstone | L3-everywhere campus — OSPF multi-area, BFD |
| [enterprise-wan-edge-capstone](enterprise-wan-edge-capstone.md) | Capstone | Dual-homed BGP with traffic engineering |

## Platform

## Cross-track practice

The BGP track's [internet-peering-ixp](internet-peering-ixp.md) lab practises operational Internet peering and IXP incident evidence. It is counted in BGP only.

The Security track's [zero-trust-secure-access](../security/zero-trust-secure-access.md) lab complements enterprise designs with resource-centric OIDC, mTLS, route authorization, and origin segmentation. It is registered and counted in Security only.

- **Arista cEOS**: `docker import cEOS-lab-4.35.2F.tar ceos:4.35.2F`
- **DMZ Linux services/firewalls**: `docker build -t dmz-lab:local labs/enterprise-dmz-capstone/`
- **load-balancer-basics** (no cEOS needed): `docker build -t lb-lab:local labs/load-balancer-basics/`
- **sdwan-concepts** (no cEOS needed): `docker build -t sdwan-lab:local labs/sdwan-concepts/`
- **cloud-hybrid-networking**: `docker build -t cloud-lab:local labs/cloud-hybrid-networking/` and import cEOS 4.35.2F
- **wireless-auth-control-operations**: `docker build -t wireless-auth-control:local labs/wireless-auth-control-operations/`
