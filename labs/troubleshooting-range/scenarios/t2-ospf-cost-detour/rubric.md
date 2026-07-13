# Proctor rubric — TR-207 (confidential)

**Root cause:** `acc1 Ethernet1` has an explicit OSPF cost of 100, making the
services prefix prefer `Ethernet2` through `core2` at metric 30 instead of the
golden primary path through `core1` at metric 20.  
**Pass threshold:** 70/100 and `verify.sh` passes. **Time band:** 35 minutes.

| Evidence / decision | Points | Deduction guidance |
|---|---:|---|
| Confirms service reachability and captures the unexpected next hop/metric | 20 | -10 if the working service causes the alert to be dismissed |
| Compares candidate OSPF paths and interface costs | 30 | -15 for changing unrelated adjacencies |
| Identifies the explicit access-uplink cost as the selection cause | 20 | -10 if only the chosen route is described |
| Removes the unintended override without hard-coding a route | 15 | -15 for a static route or changing the redundant link |
| Verifies metric 20 through the primary next hop and end-to-end service | 15 | -10 if only ping or only RIB state is checked |

Red flags: adding a static route, inflating costs elsewhere, or disabling the
redundant path caps the score at 69. The scenario verifier is required for a
pass.
