# Ticket AR-302 — Large downloads stall while small requests work

**Reported by:** Corporate application support  
**Impact:** Users can connect to the internet test service and retrieve its small page, but larger downloads time out.  
**Symptom:** DNS is not involved, routing and TCP setup succeed, and ordinary ping works. The failure depends on response size and began after ICMP policy hardening.

Diagnose, fix, and verify the incident. Submit exact-size testing, path-MTU and policy evidence, the minimal repair, and successful small and large transfers.
