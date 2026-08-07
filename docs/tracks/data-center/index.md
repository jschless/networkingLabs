# Data Center Track

Seven labs covering BGP CLOS fabric design, VXLAN overlay, BGP EVPN control
plane, routed DCI, Kubernetes ↔ fabric integration, and redundant IP storage
across Arista cEOS, Nokia SR-Linux, Linux/KVM, and k3s.

| Lab | Type | Platform | What You Learn |
|-----|------|----------|----------------|
| [spine-leaf](spine-leaf.md) | Practice | cEOS | BGP CLOS fabric on Arista cEOS |
| [vxlan-evpn](vxlan-evpn.md) | Practice | cEOS | VXLAN + EVPN, L2VNI + L3VNI, symmetric IRB |
| [vxlan-evpn-srlinux](vxlan-evpn-srlinux.md) | **Reference** | SR-Linux | VXLAN + BGP EVPN on Nokia SR-Linux |
| [evpn-border-ceos](evpn-border-ceos.md) | Practice | cEOS | EVPN border leaf, external eBGP in VRF, type-5 routes |
| [dci-evpn-multisite](dci-evpn-multisite.md) | Practice | cEOS + Linux | Routed multi-site EVPN, type-5 RT policy, DCI fault diagnosis |
| [k8s-fabric](k8s-fabric.md) | Build | k3s + cEOS | Kubernetes LoadBalancer /32 from MetalLB speakers into a native EOS RIB/FIB, ECMP, and endpoint-locality withdrawal |
| [dc-storage-networking](dc-storage-networking.md) | Practice | Linux + KVM | iSCSI/CHAP, two-path multipath, jumbo MTU, failure recovery, and bounded contention |

## Recommended Order

```
# Prerequisites: bgp-basics, bgp-path-selection
spine-leaf
vxlan-evpn → evpn-border-ceos → dci-evpn-multisite
vxlan-evpn-srlinux (reference)
k8s-fabric (after bgp-basics; independent of the EVPN chain)
dc-storage-networking (after basic Linux operations)
```

## Platform Notes

- **cEOS labs**: `docker import cEOS-lab-4.35.2F.tar ceos:4.35.2F`
- **SR-Linux**: `docker pull ghcr.io/nokia/srlinux:latest`
- cEOS EVPN: `send-community extended` is **required** on every eBGP neighbor — not automatic in EOS
- **k8s-fabric**: prepare the canonical `ceos:4.35.2F` tag (EOS 4.35.2F on
  amd64; cEOSarm 4.36.1F on arm64) and build `ops-lab:local`; k3s
  v1.30.6+k3s1, MetalLB v0.14.8, and nginx 1.27-alpine use exact digest pins
  and require registry access on a cold deploy
- **dc-storage-networking** (Linux/amd64 + KVM): `docker build -t dc-storage-tools:1.0.0 labs/dc-storage-networking/`; the build downloads a checksum-pinned dated Ubuntu guest, then deploy needs no internet

The seven labs above are the maintained data-center track inventory. The
[Enterprise Coverage Map](../../enterprise-coverage-map.md) distinguishes live
IP storage from evidence-only FC/FCoE/RoCE behavior.
