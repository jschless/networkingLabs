# Ticket AR-206 — Preferred provider resets after route expansion

**Reported by:** Edge routing monitoring
**Impact:** The preferred provider session resets when the provider announces
its newly approved second prefix. Internet service continues over the backup
path at reduced resiliency.
**Symptom:** The physical circuit is up and peer parameters have not changed.
The provider confirms that its expected announcement set grew from one prefix
to two during the maintenance window.

Diagnose, fix, and verify the incident without disabling route-containment
protection. Submit peer-reset evidence, the minimal correction, both accepted
provider routes, restored preferred-path evidence, and an end-to-end test.
