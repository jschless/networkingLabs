# Study Paths

## CCNP Enterprise (ENCOR + ENARSI)

```
OSPF:     two-routers → ospf-multiarea → ospf-auth → ospf-summarization
          → ospf-default-route → ospf-nssa → ospf-virtual-link
EIGRP:    eigrp-basics → eigrp-variance → eigrp-stub
BGP:      bgp-basics → bgp-path-selection → bgp-filtering → bgp-communities → bgp-aggregation
Redist:   ospf-bgp-redist → redistribution-tags → route-maps-pbr
Tunnels:  gre-basics → ipsec-basics → gre-ipsec → dmvpn-phase1
HA:       bfd-ospf → bfd-bgp → vrrp
IS-IS:    isis-basics → isis-multiarea
IPv6:     ipv6-ospf3 → ipv6-bgp
```

## Service Provider

```
Prereq:   CCNP path above
BGP-LU:   bgp-labeled-unicast
IS-IS:    isis-basics → isis-multiarea
MPLS:     mpls-sr-blank → mpls-sr-isis-bgp (reference) → mpls-sr-srlinux (reference)
L2VPN:    mpls-l2vpn
IPv6:     ipv6-transition
```

## Data Center / EVPN

```
Prereq:   bgp-basics → bgp-path-selection
Fabric:   spine-leaf
VXLAN:    vxlan-evpn → evpn-border-ceos
SR-Linux: vxlan-evpn-srlinux (reference)
VRF:      vrf-lite
```

## Enterprise Design

```
Prereq:   ospf-multiarea, bgp-basics, vrrp
Reference: enterprise-collapsed-core → enterprise-campus → enterprise-routed-access
Edge:     enterprise-wan-edge
DMZ:      enterprise-dmz
Security: enterprise-access-security → enterprise-edge-nat-firewall
Services: enterprise-services-infra
Multicast: enterprise-multicast
HA:       ha-network-design-ceos
Capstones: enterprise-collapsed-core-capstone → enterprise-campus-capstone
           → enterprise-routed-access-capstone → enterprise-wan-edge-capstone
```

## Security

```
acl-basics → bgp-prefix-security → bgp-rpki
ipsec-basics → gre-ipsec → black-core-routing → flexvpn-basics
macsec-basics → dot1x-nac → dot1x-ceos-practice
urpf-antispoofing → copp-basics
enterprise-edge-nat-firewall → fortigate-firewall-capstone
```

## Network Operations

```
management-access-control → dhcp-dns-troubleshooting → aaa-ops-troubleshooting
→ packet-analysis-basics → mtu-pmtud-troubleshooting → ipv6-access-services
→ telemetry-monitoring-hybrid → network-automation-netbox
```

## DMVPN Progression

```
dmvpn-phase1 (VyOS) → dmvpn-phase2 → dmvpn-phase3
```

## Troubleshooting Practice

```
debug-ospf-multiarea → debug-bgp-basics → debug-eigrp-basics → debug-isis-basics
→ debug-bgp-filtering → debug-gre-basics → debug-spine-leaf
→ debug-vxlan-evpn → debug-mpls-sr-isis-bgp
```
