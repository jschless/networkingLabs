# Proctor rubric — TR-305 (confidential)

**Root cause:** The writable `services1` dnsmasq configuration maps
`web.range.test` to `198.18.0.10` instead of the service address
`10.250.40.10`; DNS is responsive and the web process is healthy.  
**Pass threshold:** 70/100 and `verify.sh` passes. **Time band:** 60 minutes.

| Evidence / decision | Points | Deduction guidance |
|---|---:|---|
| Reproduces the name-based failure and confirms general guest routing | 10 | -5 if the report is accepted without a client test |
| Compares the DNS answer with the documented service address | 25 | -10 if only resolver reachability is checked |
| Proves direct TCP/8080 service health at `10.250.40.10` | 15 | -10 for restarting the web process without evidence |
| Locates the incorrect authoritative dnsmasq record as the root cause | 20 | -10 if a client-side workaround is proposed |
| Corrects the DNS data, reloads only dnsmasq, and verifies explicit DNS plus TCP | 30 | -20 for `/etc/hosts` or changing client resolvers |

Red flags: host-file overrides, client resolver changes, or restarting routing
nodes caps the score at 69. The scenario verifier is required for a pass and
queries the range DNS server directly, so a client-only mask cannot pass.
