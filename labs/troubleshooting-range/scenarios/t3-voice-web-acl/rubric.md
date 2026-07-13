# Proctor rubric — TR-306 (confidential)

**Root cause:** `services1` has a first-match INPUT rule dropping TCP/8080 from
source `10.250.20.0/24`; DNS, ICMP, routing, the web listener, and corporate
TCP access remain healthy.  
**Pass threshold:** 70/100 and `verify.sh` passes. **Time band:** 60 minutes.

| Evidence / decision | Points | Deduction guidance |
|---|---:|---|
| Reproduces voice TCP failure and proves corporate TCP success | 15 | -10 if source-specific scope is missed |
| Separates DNS, ICMP, route, and listener health from TCP policy | 20 | -10 for restarting the service first |
| Inspects ordered service-host policy and uses the matching rule/counter as evidence | 25 | -15 for changing routers without policy evidence |
| Removes only the source-specific drop rule | 20 | -20 for flushing all policy or changing the client source |
| Verifies DNS and TCP from voice plus unaffected corporate TCP | 20 | -10 if only the affected client is tested |

Red flags: flushing the entire ruleset, adding NAT/static routes, or changing
the application port caps the score at 69. The scenario verifier is required
for a pass and rejects the injected rule if it remains present.
