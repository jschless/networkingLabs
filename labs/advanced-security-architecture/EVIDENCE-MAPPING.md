# Advanced Security Architecture — Fidelity and Product Mapping

## Live in this lab

| Capability | Live mechanism | Evidence |
|---|---|---|
| Zone and VRF separation | Linux VRFs, 802.1Q transit separation, explicit nftables conduits | `ip route show vrf ...`, policy counters, positive/negative paths |
| Stateful firewall and NAT | nftables connection tracking, exact DNAT, source NAT, ordered counters | `nft -a list ruleset`, `conntrack -L` |
| IDS/IPS | Suricata NFQUEUE with one safe alert and one safe scoped drop signature | `fast.log`, EVE JSON, HTTP result |
| WAF | nginx + ModSecurity with a deterministic benign marker rule | HTTP 403, audit rule ID `1141001`, normal HTTP 200 |
| DNS and web egress control | dnsmasq source/query logging and Squid destination allowlist | central DNS log, Squid access log, bypass denials |
| Identity/resource policy | signed lab assertion consumed by a resource PEP; one partner route | PEP permit/deny logs and direct-origin denial |
| DDoS/route response seam | nftables public rate limit and token/prefix/TTL-scoped RTBH API | excess-drop counter, selected-prefix outage, timed recovery |
| Incident evidence | UTC collector, shared event IDs, WAF/PEP/origin/RTBH logs | `evidence.sh EVENT_ID` |

The resource PEP consumes a pre-issued lab assertion so this capstone reuses the
identity concepts from `zero-trust-secure-access`; it does not repeat realm,
client, group, or device-certificate lessons.

## Evidence/product mapping only

These are architecture review topics, not emulated product claims:

| Product capability | What to map during design review | Why it is not claimed live |
|---|---|---|
| TLS decryption | lawful purpose, data minimization, bypass categories, certificate lifecycle, privileged access, retention, and change approval | The lab sends synthetic HTTP only; it never intercepts private traffic. |
| Malware sandboxing | file detonation boundary, verdict latency, privacy, evasion limits, and release path | No untrusted file or malware execution is included. |
| CASB/DLP | sanctioned-service inventory, data classifiers, false-positive handling, and exception ownership | Squid destination policy is not CASB, content inspection, or DLP. |
| Cloud-delivered SSE | identity/device context, PoP selection, fail-open/closed posture, service dependencies, and logging custody | No commercial SSE/SASE control plane or global PoP is present. |
| Vendor application databases | signature provenance, update cadence, ambiguity, encrypted-traffic limits, and override governance | Port/path policy is never called application identification. |
| Production threat feeds | licensing, confidence, expiry, poisoning resistance, rollback, and offline behavior | Only two repository-owned safe signatures are loaded. |

## Licensed and optional components

OPNsense is a valid open-source platform but its repository workflow depends on a
locally installed QEMU disk plus root-created tap devices. The probe could not
run that lifecycle noninteractively. An imported FortiOS image was also present,
but no plan-owned reproducible license/activation workflow was available. Neither
platform is required by this lab, and neither is represented by the Linux
fallback. See `PROBE.md` for the exact decision.
