# Proctor rubric — AR-202

**Root cause:** An inbound `BLOCK-IN` route map on edge1 denies `198.18.10.0/24` from ISP1 while leaving the session Established. **Pass threshold:** 70/100 and `verify.sh` passes. **Time band:** 35 minutes.

| Evidence / decision | Points | Deduction guidance |
|---|---:|---|
| Confirms service failover works while the preferred path is absent | 15 | -5 if outage is assumed |
| Shows the peer is Established but contributes no expected prefix | 25 | -10 if only summary state is checked |
| Traces the missing NLRI through inbound policy and prefix-list order | 30 | -15 for changing outbound policy |
| Restores `ISP1-IN` and removes only the unintended inbound policy | 15 | -15 for permitting all routes globally |
| Verifies ISP1 path, local preference 200, and end-to-end service | 15 | -10 if policy state is not rechecked |

Static routes, disabling the alternate provider, or broad permit-all policy caps the score at 69. The verifier is required for a pass.
