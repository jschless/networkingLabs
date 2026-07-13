# Proctor rubric — AR-301

**Root cause:** edge1's POSTROUTING MASQUERADE rule for `10.251.0.0/16` on `eth3` is missing, so RFC1918 client sources have no return route while edge-originated traffic works. **Pass threshold:** 70/100 and `verify.sh` passes. **Time band:** 60 minutes.

| Evidence / decision | Points | Deduction guidance |
|---|---:|---|
| Separates working edge-originated traffic from failing client traffic | 15 | -10 if the external service is blamed |
| Proves the forward route and primary next hop are healthy | 15 | -10 for changing BGP/OSPF first |
| Captures untranslated client source or missing NAT policy/counters | 30 | -15 if translation is assumed |
| Restores the exact scoped egress MASQUERADE rule | 20 | -20 for broad address/routing changes |
| Verifies NAT policy and TCP from corporate and branch clients | 20 | -10 if only ping is used |

Changing client addresses, adding internet routes to private space, or failing over around the bad primary policy caps the score at 69. The verifier is required for a pass.
