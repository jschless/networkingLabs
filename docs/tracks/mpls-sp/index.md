# MPLS & Service Provider Track

Six labs covering the full SP stack: LDP label distribution, Segment Routing, IS-IS underlay, BGP VPNv4 L3VPN, L2VPN pseudowires, and IPv6 transition via 6PE.

| Lab | Type | Platform | What You Learn |
|-----|------|----------|----------------|
| [mpls-ldp](mpls-ldp.md) | Practice | FRR | LDP on an OSPF core — sessions, label bindings, PHP, and a mid-path LSP blackhole the IGP can't see |
| [mpls-sr-blank](mpls-sr-blank.md) | Practice | FRR | Build full SP stack from scratch — IS-IS + SR + BGP VPNv4 |
| [mpls-sr-isis-bgp](mpls-sr-isis-bgp.md) | **Reference** | FRR | IS-IS + SR-MPLS + BGP VPNv4 + L3VPN fully working |
| [mpls-sr-srlinux](mpls-sr-srlinux.md) | **Reference** | SR-Linux | Same SP stack on Nokia SR-Linux — compare platforms |
| [mpls-l2vpn](mpls-l2vpn.md) | Practice | FRR | MPLS pseudowire L2VPN (VPWS), transparent Ethernet over MPLS |
| [ipv6-transition](ipv6-transition.md) | Practice | FRR | 6PE (RFC 4798) — IPv6 over IPv4 MPLS/SR core |

## Recommended Order

```
# Prerequisites: isis-basics, bgp-labeled-unicast (mpls-ldp needs only OSPF basics)
mpls-ldp → mpls-sr-blank → mpls-sr-isis-bgp (reference) → mpls-sr-srlinux (reference)
mpls-l2vpn → ipv6-transition
```

## Platform Notes

- **FRR labs**: `docker build -t frr-lab:local images/frr/`
- **SR-Linux**: `docker pull ghcr.io/nokia/srlinux:latest`
- MPLS labs require `net.mpls.platform_labels` set via `sysctls:` in topology (not exec)
