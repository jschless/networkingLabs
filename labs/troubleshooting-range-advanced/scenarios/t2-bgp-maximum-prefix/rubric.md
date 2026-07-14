# Proctor rubric — AR-206 (confidential)

**Root cause:** `edge1` limits ISP1 to one received prefix with `neighbor
192.0.2.1 maximum-prefix 1`. The provider legitimately adds
`203.0.113.0/24` alongside `198.18.10.0/24`; FRR sends a Cease/Maximum Number
of Prefixes notification and leaves the preferred peer Idle.
**Pass threshold:** 70/100 and `verify.sh` passes. **Time band:** 35 minutes.

| Evidence / decision | Points | Deduction guidance |
|---|---:|---|
| Confirms service survives over backup and scopes the resiliency loss | 10 | -5 if a total outage is assumed |
| Captures Idle state, Cease/Maximum Prefix notification, and the configured ceiling | 30 | -20 if the circuit or AS number is changed first |
| Confirms the provider's two approved prefixes rather than treating the new route as a leak | 15 | -10 without received/advertised route evidence |
| Raises the ceiling to a defensible value of at least two and explicitly clears the peer | 25 | -20 for removing maximum-prefix protection entirely |
| Verifies both prefixes accepted, ISP1 preferred, and client service healthy | 20 | -15 if only session state is checked |

Red flags: deleting containment protection, suppressing the approved provider
prefix, or shutting the backup path caps the score at 69. The scenario verifier
is required for a pass and requires a retained ceiling of at least two.
