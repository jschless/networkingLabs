# Tunnels & VPN Track

Twelve labs covering GRE, IPsec, NAT traversal, DMVPN (Phase 1/2/3 plus a certificate-IPsec capstone), FlexVPN, WireGuard, remote-access concentration, and VRF-Lite across Arista cEOS, VyOS, Linux/strongSwan, WireGuard, and OPNsense.

| Lab | Type | Platform | What You Learn |
|-----|------|----------|----------------|
| [gre-basics](gre-basics.md) | Practice | cEOS | GRE on Arista cEOS, EOS tunnel syntax, OSPF over GRE |
| [ipsec-basics](ipsec-basics.md) | Build | VyOS + ops Linux | IKEv2 site-to-site IPsec, policy ownership, encrypted evidence, proposal triage |
| [gre-ipsec](gre-ipsec.md) | Build | VyOS + ops Linux | Transport-mode ESP for GRE, layered capture evidence, confidentiality-failure triage |
| [dmvpn-phase1](dmvpn-phase1.md) | Practice | VyOS | Hub-and-spoke DMVPN, mGRE, NHRP, OSPF |
| [dmvpn-phase2](dmvpn-phase2.md) | Practice | VyOS | DMVPN Phase 2 — spoke-to-spoke tunnels, NHRP shortcuts |
| [dmvpn-phase3](dmvpn-phase3.md) | Practice | VyOS | DMVPN Phase 3 — NHRP shortcuts with OSPF p2mp |
| [dmvpn-phase3-ipsec-capstone](dmvpn-phase3-ipsec-capstone.md) | Capstone | VyOS | DMVPN Phase 3 with in-lab PKI and certificate-based IPsec |
| [flexvpn-basics](flexvpn-basics.md) | Practice | strongSwan | IKEv2 FlexVPN, Virtual Tunnel Interfaces |
| [wireguard](wireguard.md) | Build | Linux WireGuard | Public-key identity, cryptokey routing, encrypted capture, hub forwarding |
| [opnsense-ipsec-nat-t](opnsense-ipsec-nat-t.md) | Practice | OPNsense | IKEv2 IPsec through NAT, UDP/4500, failure triage |
| [opnsense-remote-access-concentrator](opnsense-remote-access-concentrator.md) | Practice | OPNsense + WireGuard | Remote-access concentration, split tunnel, per-peer policy |
| [vrf-lite](vrf-lite.md) | Practice | cEOS | VRF-Lite, per-VRF routing tables, route leaking |

## Platform Notes

- **VyOS labs**: `vyos:local` — one-time build from a VyOS ISO, see [VyOS platform notes](../../platforms/vyos.md)
- **IPsec/GRE protection labs**: `ipsec-basics` and `gre-ipsec` use
  `vyos:local` gateways plus incidental hosts/transit from
  `docker build -t ops-lab:local images/ops-lab/`
- **FlexVPN Linux lab**: `docker build -t ipsec-lab:local labs/ipsec-basics/`
- **WireGuard lab**: `docker build -t wireguard-lab:local labs/wireguard/`
- **OPNsense labs**: local QEMU/KVM base image — see [OPNsense platform notes](../../platforms/opnsense.md)
- **cEOS labs**: `docker import cEOS-lab-4.35.2F.tar ceos:4.35.2F`

## cEOS Variants

DMVPN was previously maintained on Arista cEOS as well; that variant is **deprecated** and
`labs/dmvpn-ceos/` remains only as a placeholder pointing at the VyOS labs above. DMVPN
practice in this repo is VyOS-only.
