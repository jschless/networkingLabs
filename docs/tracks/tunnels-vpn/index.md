# Tunnels & VPN Track

Eleven labs covering GRE, IPsec, DMVPN (Phase 1/2/3), FlexVPN, WireGuard, and VRF-Lite across FRR and Arista cEOS platforms.

| Lab | Type | Platform | What You Learn |
|-----|------|----------|----------------|
| [gre-basics](gre-basics.md) | Practice | FRR | GRE tunnel, routing over GRE, recursive routing pitfall |
| [gre-ceos](gre-ceos.md) | Practice | cEOS | GRE on Arista cEOS, EOS tunnel syntax, OSPF over GRE |
| [gre-ipsec](gre-ipsec.md) | Practice | strongSwan | GRE + IPsec transport mode |
| [ipsec-basics](ipsec-basics.md) | Practice | strongSwan | IKEv2 site-to-site IPsec, PSK, tunnel mode |
| [dmvpn-phase1](dmvpn-phase1.md) | Practice | FRR | Hub-and-spoke DMVPN, mGRE, NHRP, OSPF |
| [dmvpn-phase2](dmvpn-phase2.md) | Practice | cEOS | DMVPN Phase 2 — spoke-to-spoke tunnels, NHRP shortcuts |
| [dmvpn-phase3](dmvpn-phase3.md) | Practice | cEOS | DMVPN Phase 3 — NHRP shortcuts with OSPF p2mp |
| [dmvpn-ceos](dmvpn-ceos.md) | Practice | cEOS | DMVPN Phase 1 hub-and-spoke on Arista cEOS |
| [flexvpn-basics](flexvpn-basics.md) | Practice | strongSwan | IKEv2 FlexVPN, Virtual Tunnel Interfaces |
| [wireguard](wireguard.md) | Practice | WireGuard | WireGuard VPN, key pairs, hub-and-spoke topology |
| [vrf-lite](vrf-lite.md) | Practice | cEOS | VRF-Lite, per-VRF routing tables, route leaking |

## Platform Notes

- **FRR labs**: `docker build -t frr-lab:local images/frr/`
- **IPsec/FlexVPN labs**: `docker build -t ipsec-lab:local labs/ipsec-basics/`
- **WireGuard lab**: `docker build -t wireguard-lab:local labs/wireguard/`
- **cEOS labs**: `docker import cEOS-lab-4.35.2F.tar ceos:4.35.2F`
