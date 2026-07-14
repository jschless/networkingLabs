# Proctor rubric — TR-208 (confidential)

**Root cause:** `corp1` has an incorrectly narrowed ephemeral port range of
`40000-40003`; four established TCP/8080 sessions consume every eligible
source port, so another connect fails locally with `EADDRNOTAVAIL`.
**Pass threshold:** 70/100 and `verify.sh` passes. **Time band:** 35 minutes.

| Evidence / decision | Points | Deduction guidance |
|---|---:|---|
| Reproduces the local connect error and confirms another client succeeds | 15 | -10 if the outage is assumed to be service-wide |
| Shows that no SYN leaves the affected client for the failed attempt | 20 | -10 if only ping is used |
| Correlates the four established source ports with the four-port ephemeral range | 30 | -15 if sessions are killed without checking allocation state |
| Restores the golden ephemeral range without disrupting established sessions | 20 | -20 for restarting the client or service container |
| Opens a new session and confirms the original four remain established | 15 | -10 if existing-session continuity is not checked |

Red flags: restarting a container, changing the server port, or killing all
client sessions as the repair caps the score at 69. The scenario verifier is
required for a pass and requires the golden range plus new and pre-existing
TCP sessions.
