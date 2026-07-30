# Ticket TR-HA-104 — Secondary application site removed from service results

**Reported by:** Global applications on-call
**Impact:** New requests for the shared multi-site application are directed
only to the primary site, so the service has lost site redundancy.
**Symptom:** `global.hybrid.test` returns only the primary site's IPv4 and IPv6
addresses. The secondary site's regional name and application health check
remain usable from the managed workstation.

Diagnose, fix, and verify the incident. Provide a short write-up containing the
observed scope, decisive evidence, corrective change, and positive plus
negative end-to-end verification.
