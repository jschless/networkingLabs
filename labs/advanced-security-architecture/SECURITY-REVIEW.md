# Security Claim Review — `advanced-security-architecture`

## Author audit

| Claim | Live evidence | Boundary checked |
|---|---|---|
| Inter-zone flows cannot bypass the gateway | USER/SERVER VRFs use distinct tagged transits; public/partner bypass probes fail | no direct core route leak |
| Public origin is WAF-only | exact DNAT + `ct status dnat`, WAF-source-only origin rule, internet origin/private-WAF denials | NAT is not described as policy |
| Partner is resource-scoped | signed assertion, one-resource PEP policy, direct-origin denial | not called full posture, IdP, VPN, or SSE |
| IDS/IPS is inline | two-direction NFQUEUE, alert and scoped `[Drop]`, normal 200 | safe local rules only; no production-feed claim |
| WAF action is deterministic | benign literal marker, rule ID 1141001, audit 403, normal 200 | no exploit payload or full CRS-coverage claim |
| Egress is controlled | DNS/proxy positive and negative paths, bypass denials, source/destination logs | destination policy is not CASB/DLP/application ID |
| RTBH is bounded | wrong-token denial, one allowlisted `/32`, 2–10 second TTL, unaffected sibling, expiry | not a production BGP community controller |
| Evidence is correlated | shared event IDs across WAF/origin/PEP and timed IDS/RTBH records | firewall denial uses an independent path probe, not a fabricated application log |

The author found no secret, private key, customer data, exploit payload,
production prefix, mutable image tag, or appliance/license claim in the
package. Lab-only bearer strings are explicitly scoped and the topology has no
host-published service port.

## Independent reviewer sign-off

Required by WP-14 before merge.

- Reviewer:
- Date:
- Commit reviewed:
- Result / findings:
