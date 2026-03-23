# Data Center Track

Four labs covering BGP CLOS fabric design, VXLAN overlay, and BGP EVPN control plane across Arista cEOS and Nokia SR-Linux.

| Lab | Type | Platform | What You Learn |
|-----|------|----------|----------------|
| [spine-leaf](spine-leaf.md) | Practice | cEOS | BGP CLOS fabric on Arista cEOS |
| [vxlan-evpn](vxlan-evpn.md) | Practice | cEOS | VXLAN + EVPN, L2VNI + L3VNI, symmetric IRB |
| [vxlan-evpn-srlinux](vxlan-evpn-srlinux.md) | **Reference** | SR-Linux | VXLAN + BGP EVPN on Nokia SR-Linux |
| [evpn-border-ceos](evpn-border-ceos.md) | Practice | cEOS | EVPN border leaf, external eBGP in VRF, type-5 routes |

## Recommended Order

```
# Prerequisites: bgp-basics, bgp-path-selection
spine-leaf
vxlan-evpn → evpn-border-ceos
vxlan-evpn-srlinux (reference)
```

## Platform Notes

- **cEOS labs**: `docker import cEOS-lab-4.35.2F.tar ceos:4.35.2F`
- **SR-Linux**: `docker pull ghcr.io/nokia/srlinux:latest`
- cEOS EVPN: `send-community extended` is **required** on every eBGP neighbor — not automatic in EOS
