# Proctor rubric — AR-201

**Root cause:** `edge2` expects remote AS 64599 for peer `192.0.2.3`; ISP2 actually uses AS 64502. **Pass threshold:** 70/100 and `verify.sh` passes. **Time band:** 35 minutes.

| Evidence / decision | Points | Deduction guidance |
|---|---:|---|
| Confirms primary service remains healthy and scopes the backup alert | 15 | -5 if user impact is assumed |
| Proves link/IP reachability while the BGP session is not Established | 20 | -10 for cycling the interface |
| Compares configured local/remote AS values on both peers | 30 | -15 if authentication or ACLs are changed without evidence |
| Corrects only the erroneous peer AS | 20 | -20 for replacing the full routing configuration |
| Verifies Established state and receipt of the internet prefix | 15 | -10 if only ping is used |

Restarting a router, changing provider AS 64502, or disabling the peer caps the score at 69. The scenario verifier is required for a pass.
