# Proctor rubric — TR-107 (confidential)

**Root cause:** The web process on `services1` listens on
`127.0.0.1:8080` instead of `10.250.40.10:8080`, so local access works but the
kernel refuses remote TCP connections.
**Pass threshold:** 70/100 and `verify.sh` passes. **Time band:** 15 minutes.

| Evidence / decision | Points | Deduction guidance |
|---|---:|---|
| Reproduces an immediate remote refusal and confirms DNS/IP reachability | 15 | -10 if the symptom is described only as "down" |
| Distinguishes a refusal from a timeout using client TCP evidence | 20 | -10 if routing is changed without loss evidence |
| Shows the running process is bound only to loopback | 30 | -15 if process existence alone is treated as listener health |
| Restarts only the web process on the service address | 20 | -20 for restarting the container or changing client addressing |
| Verifies the listener and remote TCP access from corporate and voice clients | 15 | -10 if only a local service test is used |

Red flags: adding a local proxy, changing the advertised service address, or
restarting the container caps the score at 69. The scenario verifier is
required for a pass and rejects a loopback-only listener.
