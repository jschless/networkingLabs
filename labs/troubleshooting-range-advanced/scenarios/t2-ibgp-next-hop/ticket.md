# Ticket AR-203 — Backup edge cannot use the preferred route

**Reported by:** Edge path monitoring  
**Impact:** Both provider relationships are up, but the backup enterprise edge cannot install the organization-preferred path learned internally.  
**Symptom:** The preferred route is present in control-plane output, yet its external next hop is not reachable from the receiving edge, so that device selects its local provider instead.

Diagnose, fix, and verify the incident. Submit route-validity and next-hop evidence, the minimal correction, and expected best-path proof.
