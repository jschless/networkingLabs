# Ticket TR-HA-301 — Protected application reachable outside sign-in

**Reported by:** Security monitoring
**Impact:** The payroll application can be viewed without the normal managed
device sign-in check. The approved employee bookmark still works and its
access checks report healthy.
**Symptom:** A legacy direct bookmark now returns the payroll application page
from the managed workstation. An unmanaged identity is still denied when it
uses the approved bookmark.

Diagnose, contain, fix, and verify the incident. Provide a short write-up
containing request-path evidence, the corrective change, and proof that the
approved experience still works while the legacy direct bookmark is denied.
