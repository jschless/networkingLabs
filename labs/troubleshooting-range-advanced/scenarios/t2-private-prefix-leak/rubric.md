# Proctor rubric — AR-205 (confidential)

**Root cause:** `edge1` has an unintended BGP `network 10.251.10.0/24`
statement. Because the corporate route exists in its RIB, edge1 originates the
private prefix to ISP1; it then propagates across both provider paths.
**Pass threshold:** 70/100 and `verify.sh` passes. **Time band:** 35 minutes.

| Evidence / decision | Points | Deduction guidance |
|---|---:|---|
| Confirms internal service is healthy and scopes the event as exposure rather than outage | 10 | -5 if user impact is invented |
| Traces the private prefix from internet-core/ISP views back to the enterprise origin AS | 25 | -15 without external route evidence |
| Compares edge1 advertised routes and BGP origination configuration | 25 | -15 for applying an inbound filter at the wrong boundary |
| Removes only the unintended origination and refreshes outbound advertisements | 20 | -20 for shutting the BGP peer or filtering the whole corporate AS |
| Proves withdrawal at ISP1 and internet-core while internal and internet service remain healthy | 20 | -15 if verification stops at the edge configuration |

Red flags: shutting provider sessions, removing the internal corporate route,
or applying a broad deny that also removes the approved service prefix caps the
score at 69. The scenario verifier is required for a pass and checks external
withdrawal plus normal client service.
