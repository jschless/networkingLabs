# Proctor rubric — CR-301 (confidential)

**Root cause:** A configuration BPDU was received on `acc1 Ethernet5`, a PortFast/BPDU-Guard-protected meeting-room edge. EOS placed the port in errdisabled state. Recovery requires clearing the operational state only after the temporary switch is removed.
**Pass threshold:** 70/100 and `verify.sh` passes. **Time band:** 15 minutes.

| Evidence / decision | Points | Deduction guidance |
|---|---:|---|
| Identifies the affected port and errdisabled state | 25 | -15 for diagnosing from link LEDs alone |
| Uses STP/event evidence to distinguish BPDU protection from a physical fault | 25 | -15 for treating errdisable as an ordinary shutdown |
| Recovers the port only after containing the unexpected bridge source | 25 | -20 for permanently disabling BPDU protection |
| Proves the port is forwarding and guard policy remains in place | 25 | -15 for no post-recovery proof |

Red flags: disabling BPDU Guard globally, changing the campus root, or restarting containers caps the score at 69. The scenario verifier is required for a pass.
