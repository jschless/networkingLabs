# Proctor rubric — TR-301 (confidential)

**Root cause:** `core1 eth5`, the services-facing routed link, is
administratively disabled. Its OSPF prefix is withdrawn while the web process
and DNS service remain healthy, so corporate clients cannot reach their
resolver; the L7 symptom is therefore a routing-control-plane fault.  
**Pass threshold:** 70/100 and `verify.sh` passes. **Time band:** 60 minutes.

| Evidence / decision | Points | Deduction guidance |
|---|---:|---|
| Separates name resolution, service reachability, and general client routing | 20 | −10 for treating the report as proof that the web process is down |
| Proves a healthy alternate path (for example corporate → branch) | 10 | −5 if blast radius is never bounded |
| Finds the missing services-prefix route and traces its OSPF origin | 30 | −15 for jumping to a static workaround |
| Restores the OSPF advertisement with the minimal change | 20 | −20 for adding static routes that mask the adjacency/control-plane defect |
| Verifies DNS and TCP service access from corporate client | 20 | −10 if only a router-side command is used |

Red flags: static-route papering over the missing advertisement, restarting the
service without evidence, or broad config replacement before diagnosis caps the
score at 69.
