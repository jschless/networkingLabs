# Ticket TR-205 — Core transit adjacency stuck

**Reported by:** Network monitoring  
**Impact:** A redundant routed transit relationship is not reaching its normal
operational state; user traffic is currently using alternate paths.  
**Symptom:** Both transit interfaces are up and peers are visible, but the
relationship repeatedly stalls during database synchronization after
maintenance.

Diagnose, fix, and verify the incident. Submit the state evidence from both
sides, the minimal correction, and restored control-plane and data-plane tests.
