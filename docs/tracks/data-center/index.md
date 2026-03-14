# Data Center Track

Six labs covering BGP CLOS fabric design, VXLAN overlay, and BGP EVPN control plane across FRR, Arista cEOS, and Nokia SR-Linux.

| Lab | Type | Platform | What You Learn |
|-----|------|----------|----------------|
| [spine-leaf](spine-leaf.md) | Practice | FRR | BGP CLOS fabric, unique AS per device, ECMP |
| [spine-leaf-ceos](spine-leaf-ceos.md) | Practice | cEOS | BGP CLOS fabric on Arista cEOS |
| [vxlan-evpn](vxlan-evpn.md) | **Reference** | FRR | VXLAN + BGP EVPN control plane |
| [vxlan-evpn-srlinux](vxlan-evpn-srlinux.md) | **Reference** | SR-Linux | VXLAN + BGP EVPN on Nokia SR-Linux |
| [evpn-vxlan-ceos](evpn-vxlan-ceos.md) | Practice | cEOS | VXLAN + EVPN, L2VNI + L3VNI, symmetric IRB |
| [evpn-border-ceos](evpn-border-ceos.md) | Practice | cEOS | EVPN border leaf, external eBGP in VRF, type-5 routes |

## Recommended Order

```
# Prerequisites: bgp-basics, bgp-path-selection
spine-leaf → spine-leaf-ceos
vxlan-evpn (reference) → evpn-vxlan-ceos → evpn-border-ceos
vxlan-evpn-srlinux (reference)
```

## Platform Notes

- **FRR labs**: `docker build -t frr-lab:local images/frr/`
- **cEOS labs**: `docker import cEOS-lab-4.35.2F.tar ceos:4.35.2F`
- **SR-Linux**: `docker pull ghcr.io/nokia/srlinux:latest`
- cEOS EVPN: `send-community extended` is **required** on every eBGP neighbor — not automatic in EOS
