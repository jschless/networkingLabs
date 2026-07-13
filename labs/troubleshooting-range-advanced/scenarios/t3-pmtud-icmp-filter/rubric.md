# Proctor rubric — AR-302

**Root cause:** edge1 OUTPUT policy drops ICMP fragmentation-needed messages generated for the 1400-byte core link, preventing the remote server from reducing packet size. **Pass threshold:** 70/100 and `verify.sh` passes. **Time band:** 60 minutes.

| Evidence / decision | Points | Deduction guidance |
|---|---:|---|
| Reproduces successful small and failed 64 KiB HTTP transfers | 20 | -10 without size-controlled evidence |
| Confirms routing, NAT, TCP setup, and the 1400-byte bottleneck | 20 | -10 for treating this as generic packet loss |
| Uses DF/MTU or policy counters to identify blocked fragmentation-needed ICMP | 30 | -15 for guessing MSS issues |
| Removes only the ICMP drop rule | 15 | -15 for lowering endpoint MTUs or MSS clamping |
| Verifies exact small and large transfers through the original path | 15 | -10 if only ping is used |

Lowering client/server MTU, disabling DF, or changing the primary path caps the score at 69. The verifier is required for a pass.
