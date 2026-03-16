# Security Track

Six labs covering ACL fundamentals, MACsec encryption, 802.1X NAC, uRPF anti-spoofing, Control Plane Policing, and wired dot1x on Arista EOS.

| Lab | Type | Platform | What You Learn |
|-----|------|----------|----------------|
| [acl-basics](acl-basics.md) | Practice | FRR | Interface ACLs, default deny, source/protocol/port filtering, counters |
| [macsec-basics](macsec-basics.md) | Practice | VyOS | IEEE 802.1AE MACsec, MKA key agreement, plain-vs-protected Ethernet |
| [dot1x-nac](dot1x-nac.md) | Practice | Custom | 802.1X port auth, RADIUS, EAP, NAC enforcement |
| [urpf-antispoofing](urpf-antispoofing.md) | Practice | FRR | Unicast RPF, source IP anti-spoofing, strict vs loose mode |
| [copp-basics](copp-basics.md) | Practice | FRR | Control Plane Policing, traffic classification, rate limiting |
| [dot1x-ceos-practice](dot1x-ceos-practice.md) | Practice | cEOS | 802.1X wired NAC on Arista EOS, RADIUS, MAB |

## Platform Notes

- **macsec-basics**: `docker build -t vyos:local -f Dockerfile.vyos .`
- **dot1x-nac**: `docker build -t nac-lab:local labs/dot1x-nac/`
- **FRR labs**: `docker build -t frr-lab:local images/frr/`
- **cEOS**: `docker import cEOS-lab-4.35.2F.tar ceos:4.35.2F`
