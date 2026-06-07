# Tunnels & VPN Track

Ten labs covering GRE, IPsec, DMVPN (Phase 1/2/3 plus a certificate-IPsec capstone), FlexVPN, WireGuard, and VRF-Lite across Arista cEOS, VyOS, Linux/strongSwan, and WireGuard platforms.

| Lab | Type | Platform | What You Learn |
|-----|------|----------|----------------|
| [gre-basics](gre-basics.md) | Practice | cEOS | GRE on Arista cEOS, EOS tunnel syntax, OSPF over GRE |
| [gre-ipsec](gre-ipsec.md) | Practice | VyOS | GRE + IPsec transport mode |
| [ipsec-basics](ipsec-basics.md) | Practice | VyOS | IKEv2 site-to-site IPsec, PSK, tunnel mode |
| [dmvpn-phase1](dmvpn-phase1.md) | Practice | VyOS | Hub-and-spoke DMVPN, mGRE, NHRP, OSPF |
| [dmvpn-phase2](dmvpn-phase2.md) | Practice | VyOS | DMVPN Phase 2 — spoke-to-spoke tunnels, NHRP shortcuts |
| [dmvpn-phase3](dmvpn-phase3.md) | Practice | VyOS | DMVPN Phase 3 — NHRP shortcuts with OSPF p2mp |
| [dmvpn-phase3-ipsec-capstone](dmvpn-phase3-ipsec-capstone.md) | Capstone | VyOS | DMVPN Phase 3 with in-lab PKI and certificate-based IPsec |
| [flexvpn-basics](flexvpn-basics.md) | Practice | strongSwan | IKEv2 FlexVPN, Virtual Tunnel Interfaces |
| [wireguard](wireguard.md) | Practice | WireGuard | WireGuard VPN, key pairs, hub-and-spoke topology |
| [vrf-lite](vrf-lite.md) | Practice | cEOS | VRF-Lite, per-VRF routing tables, route leaking |

## Platform Notes

- **VyOS labs**: `docker build -t vyos:local -f Dockerfile.vyos .`
- **FlexVPN Linux lab**: `docker build -t ipsec-lab:local labs/ipsec-basics/`
- **WireGuard lab**: `docker build -t wireguard-lab:local labs/wireguard/`
- **cEOS labs**: `docker import cEOS-lab-4.35.2F.tar ceos:4.35.2F`

## cEOS Variants

Arista cEOS reimplementations of two labs above are available in the repo but not yet
documented here:
[`labs/gre-ceos/`](https://github.com/jschless/networkingLabs/tree/main/labs/gre-ceos) and
[`labs/dmvpn-ceos/`](https://github.com/jschless/networkingLabs/tree/main/labs/dmvpn-ceos).
Each has its own README.
