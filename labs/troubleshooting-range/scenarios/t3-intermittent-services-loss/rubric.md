# Proctor rubric — TR-307 (confidential)

**Root cause:** `core1 eth5`, the routed services link, has a runtime `netem`
qdisc dropping 35 percent of transmitted packets. Interfaces, OSPF, routing,
DNS, and the web process are configured correctly, so individual retries can
misleadingly succeed.
**Pass threshold:** 70/100 and `verify.sh` passes. **Time band:** 60 minutes.

| Evidence / decision | Points | Deduction guidance |
|---|---:|---|
| Uses a repeated sample to quantify mixed success and loss from affected clients | 20 | -15 for accepting one successful ping as proof of health |
| Proves the service process, addressing, routes, and OSPF remain healthy | 15 | -10 for restarting services before isolating the path |
| Localizes loss to the services-facing path with counters, qdisc, or capture evidence | 30 | -15 if intermittent loss is asserted without hop-specific evidence |
| Removes only the unintended loss policy from the affected interface | 15 | -15 for changing routing costs or moving traffic as a workaround |
| Verifies a zero-loss sample plus repeated DNS and HTTP success from corporate and voice | 20 | -15 if verification is a single retry |

Red flags: adding static routes, shutting redundant links, restarting
containers, or declaring success after one probe caps the score at 69. The
scenario verifier is required for a pass and rejects any remaining `netem`
policy or packet loss in its controlled sample.
