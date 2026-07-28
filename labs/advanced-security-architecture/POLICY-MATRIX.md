# Advanced Security Architecture — Policy Matrix

This matrix is the business intent used by the lab checks. `Via` is part of the
policy: a successful packet on a different path is a failure, not an equivalent
permit.

| Source | Destination | Service | Decision | Required path / evidence |
|---|---|---|---|---|
| internet test | public application | TCP/80 on `198.51.100.80` | permit | exact DNAT → WAF → origin; firewall, WAF, and origin evidence |
| internet test | private WAF `10.114.30.10` | TCP/8080 | deny | no publication translation |
| internet test | protected origin | TCP/8080 | deny | independent origin-bypass test |
| user | protected internal application | TCP/8080 | permit | USER VRF → stateful gateway → SERVER VRF |
| user | public application (hairpin) | TCP/80 on `198.51.100.80` | permit | intentional DNAT → WAF → origin |
| user | controlled resolver | UDP/TCP 53 | permit | source and query in DNS log |
| user | controlled egress proxy | TCP/3128 | permit | proxy decides destination policy |
| user | public resolver or direct web | UDP/TCP 53, TCP/8080 | deny | direct-bypass probe fails |
| partner | resource PEP | TCP/8443, `/partner-app` | permit | valid signed assertion → resource policy → WAF → origin |
| partner | resource PEP | `/internal-app` | deny | PEP decision log |
| partner | protected origin | TCP/8080 | deny | independent PEP/WAF-bypass test |
| WAF/PEP | protected origin | TCP/8080 | permit | one source, one origin, one service |
| admin | gateway management | TCP/8443 | permit | OOB `MGMT` VRF only |
| break-glass | gateway management | TCP/8443 | permit | dedicated OOB source only |
| any data-plane zone | gateway management | TCP/8443 | deny | no route leak into `MGMT` VRF |
| security services | documentation services | TCP/8080 | permit | egress NAT and scoped route |
| security services | edge RTBH API | TCP/9000 | permit | allowlisted prefix, token, and 2–10 second TTL |
| application/control nodes | central collector | UDP/514 | permit | UTC timestamp and shared event ID where applicable |

The topology is intentionally IPv4-only. IPv6 enforcement is covered by the
`enterprise-dual-stack-capstone`; this lab does not turn an untested IPv6 path
into a security claim.
