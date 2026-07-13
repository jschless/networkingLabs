# Proctor rubric — TR-106 (confidential)

**Root cause:** `voice1` is configured to use nonexistent resolver
`10.250.20.254` instead of the range DNS service at `10.250.40.10`.  
**Pass threshold:** 70/100 and `verify.sh` passes. **Time band:** 15 minutes.

| Evidence / decision | Points | Deduction guidance |
|---|---:|---|
| Proves direct IP reachability and isolates the symptom to name resolution | 20 | -10 if the portal is assumed down |
| Inspects the endpoint resolver configuration and compares it with known-good | 30 | -15 for changing network infrastructure first |
| Identifies the incorrect resolver as the root cause | 20 | -10 if only DNS timeout output is cited |
| Corrects only the endpoint resolver setting | 15 | -15 for host-file or static-route workarounds |
| Verifies the returned address and TCP to that resolved address | 15 | -10 if only ping is used |

Red flags: adding `web.range.test` to `/etc/hosts`, changing the DNS server, or
restarting unrelated nodes caps the score at 69. The scenario verifier is
required for a pass.
