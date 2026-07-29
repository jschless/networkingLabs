# Sanitized live transcript — TR-DE-301

**Date:** 2026-07-29 UTC
**Topology:** `1.0.0` candidate, subsequently frozen unchanged

## Start and decision path

```text
./range.sh start t3-dci-maintenance-policy
Results: 26 passed, 0 failed
Ticket symptom is active: site-local services remain healthy while Site A inter-site production routes are suppressed.
t3_start_elapsed=3.83
```

Observed evidence:

```text
Site B -> Site A PROD: Network unreachable
Site B local application: HTTP body site-b-prod-ok
10.21.0.1 ... Established ... L2VPN EVPN
10.255.10.2 ... Established ... L2VPN EVPN
route-map DCI-PROD deny 5
  match extcommunity DCI-PROD
neighbor 10.255.10.2 route-map DCI-PROD out
```

This separated endpoint state, local EVPN, Site B's missing PROD FIB, the green
inter-site session, and the ordered Site A export policy.

## Minimal repair and verifier

The repair removed only `route-map DCI-PROD deny 5` and performed
`clear bgp * soft out`. Result:

```text
PASS: EVPN-derived inter-site service is restored in both directions, local/shared service remains healthy, and no static-route or L2-stretch workaround exists.
t3_verify_elapsed=0.92
```

An adversarial high-distance static tenant route left apparent service healthy
but was rejected:

```text
EXPECTED_FAIL verifier rejected static tenant route
ERROR: static Site B tenant route masks the EVPN path
```

The static route was removed, verify passed, clear ran twice, and golden reset
returned health 26/26 with all five cEOS restart counts still zero.
