# Proctor rubric — CR-302 (confidential)

**Root cause:** `acc1` received priority 0, making the access switch root for the RSTP instance instead of `dist1` (priority 4096). User forwarding remains available, so this requires control-plane evidence rather than an outage-only diagnosis.
**Pass threshold:** 70/100 and `verify.sh` passes. **Time band:** 35 minutes.

| Evidence / decision | Points | Deduction guidance |
|---|---:|---|
| Establishes root ID, bridge ID, and root port from both switches | 30 | -15 for relying only on monitoring text |
| Confirms user VLAN traffic remains available while design intent is wrong | 15 | -10 for inventing an outage |
| Restores the approved root priority without changing unrelated VLAN/trunk state | 30 | -20 for solving by disabling STP or the port-channel |
| Verifies intended root and endpoint forwarding after convergence | 25 | -15 for checking one switch only |

Red flags: disabling spanning tree, changing the distribution priority without evidence, or restarting containers caps the score at 69. The scenario verifier is required for a pass.
