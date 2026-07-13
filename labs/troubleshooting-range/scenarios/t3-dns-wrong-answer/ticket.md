# Ticket TR-305 — Guest portal resolves incorrectly

**Reported by:** Service desk  
**Impact:** Guest users cannot open `web.range.test`; the application health
check by address remains green.  
**Symptom:** Name lookups complete without timing out, but clients are directed
to an address where the portal is not listening. Direct access to the approved
service address succeeds from the same client network.

Diagnose, fix, and verify the incident. Submit evidence separating client
routing, resolver reachability, DNS data, and application state, plus the
minimal correction and end-to-end verification.
