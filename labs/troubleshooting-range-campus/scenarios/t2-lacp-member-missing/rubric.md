# Proctor rubric — CR-303 (confidential)

**Root cause:** `acc1 Ethernet2` was removed from channel-group 1. The Port-Channel remained up over Ethernet1, which masks the defect from a simple reachability test.
**Pass threshold:** 70/100 and `verify.sh` passes. **Time band:** 35 minutes.

| Evidence / decision | Points | Deduction guidance |
|---|---:|---|
| Uses LACP peer/bundle state on both switches | 30 | -15 for relying on carrier state |
| Confirms service survives on the remaining member | 15 | -10 for declaring no incident because ping works |
| Restores the missing member as LACP active in the intended group | 30 | -20 for converting the bundle to static mode |
| Proves both members are collecting/distributing and traffic still works | 25 | -15 for one-sided verification |

Red flags: shutting the whole Port-Channel, changing trunk VLANs, or restarting containers caps the score at 69. The scenario verifier is required for a pass.
