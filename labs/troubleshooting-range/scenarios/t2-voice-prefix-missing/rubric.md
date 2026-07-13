# Proctor rubric — TR-206 (confidential)

**Root cause:** `acc1` no longer includes `10.250.20.0/24` in its OSPF network
statements, so the connected voice SVI remains locally healthy but the prefix
is absent from remote OSPF RIBs and the LSDB.  
**Pass threshold:** 70/100 and `verify.sh` passes. **Time band:** 35 minutes.

| Evidence / decision | Points | Deduction guidance |
|---|---:|---|
| Bounds the failure to remote-to-voice traffic and proves local gateway health | 15 | -5 if the endpoint is assumed down |
| Confirms adjacencies are Full but the voice route/LSA is absent remotely | 30 | -15 for cycling neighbors without evidence |
| Traces the missing prefix to route origination on the access router | 25 | -10 if only a static workaround is proposed |
| Restores the exact voice network advertisement | 15 | -15 for redistribution or static-route workarounds |
| Verifies the remote route, remote endpoint reachability, and healthy peers | 15 | -10 if only local ping is used |

Red flags: adding remote static routes, restarting OSPF, or changing the voice
endpoint address caps the score at 69. The scenario verifier is required for a
pass.
