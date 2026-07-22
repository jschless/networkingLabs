# Data Center Track

Five labs covering BGP CLOS fabric design, VXLAN overlay, BGP EVPN control plane, and Kubernetes ↔ fabric integration across Arista cEOS, Nokia SR-Linux, and k3s/FRR.

| Lab | Type | Platform | What You Learn |
|-----|------|----------|----------------|
| [spine-leaf](spine-leaf.md) | Practice | cEOS | BGP CLOS fabric on Arista cEOS |
| [vxlan-evpn](vxlan-evpn.md) | Practice | cEOS | VXLAN + EVPN, L2VNI + L3VNI, symmetric IRB |
| [vxlan-evpn-srlinux](vxlan-evpn-srlinux.md) | **Reference** | SR-Linux | VXLAN + BGP EVPN on Nokia SR-Linux |
| [evpn-border-ceos](evpn-border-ceos.md) | Practice | cEOS | EVPN border leaf, external eBGP in VRF, type-5 routes |
| [k8s-fabric](k8s-fabric.md) | Practice | k3s + FRR | Kubernetes LoadBalancer VIPs advertised by MetalLB/BGP to a ToR, ECMP across nodes, externalTrafficPolicy |

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
- **k8s-fabric** (no cEOS needed): `docker build -t frr-lab:local images/frr/` and `docker build -t ops-lab:local images/ops-lab/`; k3s + MetalLB + nginx images pull from the internet at deploy, so this lab needs internet access

The five labs above are the maintained data-center track inventory. The
[Enterprise Coverage Map](../../enterprise-coverage-map.md) records the planned
DCI and storage additions separately, without presenting them as delivered labs.
