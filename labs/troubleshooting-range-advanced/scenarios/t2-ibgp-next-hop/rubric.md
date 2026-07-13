# Proctor rubric — AR-203

**Root cause:** edge1 no longer applies `next-hop-self` toward iBGP peer edge2, exposing ISP1 next hop `192.0.2.1`, which edge2 cannot resolve. **Pass threshold:** 70/100 and `verify.sh` passes. **Time band:** 35 minutes.

| Evidence / decision | Points | Deduction guidance |
|---|---:|---|
| Confirms all sessions are up and service remains available | 15 | -5 if adjacency failure is assumed |
| Compares the received iBGP route, selected path, and next-hop resolution | 30 | -15 if only local preference is checked |
| Identifies missing next-hop rewriting at the advertising edge | 25 | -10 if an IGP route to provider transit is proposed |
| Restores next-hop-self on the correct peer | 15 | -15 for leaking provider transit into OSPF |
| Verifies edge2 selects edge1 at local preference 200 | 15 | -10 if only session state is verified |

Advertising ISP transit internally, static next-hop routes, or changing local preference caps the score at 69. The verifier is required for a pass.
