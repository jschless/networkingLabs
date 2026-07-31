# Security Track

Ten labs covering ACL fundamentals, black-core routing, OPNsense NGFW policy, MACsec encryption, 802.1X NAC, uRPF anti-spoofing, Control Plane Policing, wired dot1x on Arista EOS, zero-trust access, and an integrated advanced-security architecture capstone.

| Lab | Type | Platform | What You Learn |
|-----|------|----------|----------------|
| [acl-basics](acl-basics.md) | Build | cEOS + Linux | Transit extended ACLs, source/protocol/port filtering, placement, counters |
| [macsec-basics](macsec-basics.md) | Practice | VyOS | IEEE 802.1AE MACsec, MKA key agreement, plain-vs-protected Ethernet |
| [black-core-routing](black-core-routing.md) | Capstone | VyOS + Linux | Red/black separation, ciphertext underlay, plaintext overlay, packet-capture proof |
| [opnsense-ngfw-basics](opnsense-ngfw-basics.md) | Capstone | OPNsense | Aliases, NAT, DMZ publishing, state, logs, Suricata IPS |
| [dot1x-nac](dot1x-nac.md) | Practice | Custom | 802.1X port auth, RADIUS, EAP, NAC enforcement |
| [urpf-antispoofing](urpf-antispoofing.md) | Build | VyOS + Linux | Prove strict and loose uRPF with route asymmetry, one-way capture, and live drop counters |
| [copp-basics](copp-basics.md) | Practice | FRR | Control Plane Policing, traffic classification, rate limiting |
| [dot1x-ceos-practice](dot1x-ceos-practice.md) | Practice | cEOS | 802.1X wired NAC on Arista EOS, RADIUS, MAB |
| [zero-trust-secure-access](zero-trust-secure-access.md) | Practice | Keycloak + Linux | OIDC claims, mTLS device signal, resource policy, origin isolation, decision logs |
| [advanced-security-architecture](advanced-security-architecture.md) | Capstone | Linux + Suricata + ModSecurity | VRF/zone policy, state/NAT, IDS/IPS, WAF/PEP, controlled egress, OOB, RTBH, evidence correlation |

## Platform Notes

- **macsec-basics**: `vyos:local` — one-time build from a VyOS ISO, see [VyOS platform notes](../../platforms/vyos.md)
- **black-core-routing**: `vyos:local` (see [VyOS platform notes](../../platforms/vyos.md)) and `docker build -t black-core-tools:local labs/black-core-routing/`
- **OPNsense NGFW**: local QEMU/KVM base image (see [OPNsense platform notes](../../platforms/opnsense.md)) and `docker build -t opnsense-tools:local labs/opnsense-ngfw-basics/`
- **dot1x-nac**: `docker build -t nac-lab:local labs/dot1x-nac/`
- **zero-trust-secure-access**: `docker build -t zt-access-tools:local labs/zero-trust-secure-access/` and `docker build -f labs/zero-trust-secure-access/Dockerfile.keycloak -t zt-keycloak:local labs/zero-trust-secure-access/`
- **advanced-security-architecture**: `docker build -t advanced-security-tools:1.0.0 labs/advanced-security-architecture/` and `docker build -f labs/advanced-security-architecture/Dockerfile.fw -t advanced-security-fw:1.0.0 labs/advanced-security-architecture/`
- **FRR labs**: `docker build -t frr-lab:local images/frr/`
- **cEOS**: `docker import cEOS-lab-4.35.2F.tar ceos:4.35.2F`
