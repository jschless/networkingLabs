# Enterprise Design Track

Fifteen labs covering campus design patterns, WAN edge, DMZ architecture, access security, multicast, services, and wireless architecture — primarily on Arista cEOS with Linux service nodes where needed.

## Reference Designs

| Lab | Type | What You Learn |
|-----|------|----------------|
| [enterprise-collapsed-core](enterprise-collapsed-core.md) | **Reference** | 2-tier campus: collapsed core/distribution, VRRP, STP, OSPF |
| [enterprise-campus](enterprise-campus.md) | **Reference** | 3-tier campus: core/distribution/access, eBGP upstream |
| [enterprise-routed-access](enterprise-routed-access.md) | **Reference** | L3-everywhere: routed access, no STP, OSPF+BFD |
| [enterprise-dmz](enterprise-dmz.md) | **Reference** | Screened-subnet DMZ, dual-firewall, nftables policy |

## Practice Labs

| Lab | Type | What You Learn |
|-----|------|----------------|
| [enterprise-wan-edge](enterprise-wan-edge.md) | Practice | Dual-ISP BGP edge, LP inbound policy, AS-path prepend outbound |
| [enterprise-access-security](enterprise-access-security.md) | Practice | DHCP snooping, dynamic ARP inspection, port security |
| [enterprise-edge-nat-firewall](enterprise-edge-nat-firewall.md) | Practice | PAT, nftables firewall policy, internet edge |
| [enterprise-multicast](enterprise-multicast.md) | Practice | IGMP, PIM-SM, multicast routing, RP configuration |
| [enterprise-services-infra](enterprise-services-infra.md) | Practice | DHCP relay, NTP, DNS, syslog, SNMP — supporting services |
| [enterprise-wireless-architecture](enterprise-wireless-architecture.md) | Practice | Enterprise WLAN design, controller modes, WLC architectures |

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

- **Arista cEOS**: `docker import cEOS-lab-4.35.2F.tar ceos:4.35.2F`
- **DMZ Linux services/firewalls**: `docker build -t dmz-lab:local labs/enterprise-dmz-capstone/`
