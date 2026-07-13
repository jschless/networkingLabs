# Proctor rubric — TR-105 (confidential)

**Root cause:** `corp1` has a permanent ARP entry mapping gateway
`10.250.10.1` to the incorrect MAC address `02:00:00:00:10:fe`.  
**Pass threshold:** 70/100 and `verify.sh` passes. **Time band:** 15 minutes.

| Evidence / decision | Points | Deduction guidance |
|---|---:|---|
| Confirms the failure is limited to `corp1` while link, address, and route are present | 15 | -5 if scope is assumed |
| Tests the local gateway and inspects the neighbor entry before changing it | 30 | -15 for flushing state with no evidence |
| Identifies the permanent incorrect gateway mapping as the root cause | 25 | -10 if only the failed pings are described |
| Removes only the bad neighbor state and allows normal ARP relearning | 15 | -15 for address, VLAN, or routing changes |
| Verifies the learned gateway entry and two remote paths from the client | 15 | -10 if verification is router-only |

Red flags: adding a host route, changing the default gateway, or resetting the
range before capturing the neighbor evidence caps the score at 69. The
scenario verifier is required for a pass.
