# Proctor rubric — TR-209 (confidential)

**Root cause:** A stalled replacement process on `services1` owns
`10.250.40.10:8080` with a listen backlog of one but never calls `accept()`.
Two queued connections fill the accept queue, so a listener exists while all
new TCP handshakes time out.
**Pass threshold:** 70/100 and `verify.sh` passes. **Time band:** 35 minutes.

| Evidence / decision | Points | Deduction guidance |
|---|---:|---|
| Reproduces the timeout and proves DNS, ICMP, and routing remain healthy | 15 | -10 if the symptom is treated as total reachability loss |
| Distinguishes a listening socket from an application accepting work | 20 | -10 if listener presence is accepted as service health |
| Shows `Recv-Q` exceeding the configured backlog and identifies the stalled owner | 30 | -15 without queue/process evidence |
| Stops only the stalled process/queued test sessions and restores the approved web process | 20 | -20 for restarting the container or changing the application port |
| Verifies an empty healthy accept queue and repeated HTTP success from two client networks | 15 | -10 for a single local socket test |

Red flags: changing routes, flushing firewall policy, adding a proxy, or
restarting the container caps the score at 69. The scenario verifier is
required for a pass and rejects the stalled process and filled queue.
