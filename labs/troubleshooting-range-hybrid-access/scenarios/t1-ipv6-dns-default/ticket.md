# Ticket TR-HA-103 — Managed workstation loses IPv6 name and application access

**Reported by:** Campus service-desk analyst
**Impact:** The managed workstation cannot resolve or open the approved cloud
application over IPv6. Coworkers are unaffected, and the same workstation can
still reach the application by its IPv4 address.
**Symptom:** The workstation retains its assigned IPv6 address, but it has no
usable IPv6 default path. Queries using its configured name service time out,
and direct IPv6 application requests fail.

Diagnose, fix, and verify the incident. Provide a short write-up containing the
observed scope, decisive evidence, corrective change, and positive plus
negative end-to-end verification.
