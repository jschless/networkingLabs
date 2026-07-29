# Ticket TR-DE-301 — Inter-site application lost after maintenance

**Reported by:** Data-center application operations
**Impact:** Users at Site B cannot reach the Site A production application after
the maintenance window. Each site's local production application remains healthy.
**Symptom:** The inter-site session monitor is green, but Site B no longer has a
usable path to either Site A application. Site-local checks remain successful.

Diagnose, fix, and verify the incident. Provide a short write-up containing the
request-path evidence, smallest corrective change, and proof of local and
inter-site recovery without widening the failure domain.
