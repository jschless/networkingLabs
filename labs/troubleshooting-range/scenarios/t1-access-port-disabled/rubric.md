# Proctor rubric — TR-101 (confidential)

**Root cause:** `acc1 Ethernet3`, the corporate workstation access port, is
administratively disabled.  
**Pass threshold:** 70/100 and `verify.sh` passes. **Time band:** 15 minutes.

| Evidence / decision | Points | Deduction guidance |
|---|---:|---|
| Establishes scope from `corp1` and compares a known-good path | 15 | −5 if scope is assumed without a test |
| Checks the access-switch port state before changing it | 30 | −15 for a change with no state evidence |
| Identifies the administrative port state as the root cause | 25 | −10 if only symptoms are described |
| Restores the port with the minimal change | 15 | −15 for unrelated/shotgun configuration |
| Verifies from the client and switch, then writes up result | 15 | −10 if verification is omitted |

Red flags: configuring static host routes, modifying unrelated VLANs or routing,
or using a broad reset before documenting evidence caps the score at 69.
