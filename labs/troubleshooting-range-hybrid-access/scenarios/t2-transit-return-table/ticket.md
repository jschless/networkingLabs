# Ticket TR-HA-201 — Hybrid services time out despite active routes

**Reported by:** Enterprise network operations
**Impact:** The managed campus workstation cannot use approved hybrid
applications or name services over IPv4 or IPv6. Hosted-side health checks
remain green.
**Symptom:** The affected destination prefixes remain installed and selected
through the preferred hybrid connection. Request packets reach the hosted
side, but the workstation receives no replies and its sessions time out.

Diagnose, fix, and verify the incident. Provide a short write-up containing the
observed scope, decisive evidence, corrective change, and positive plus
negative end-to-end verification.
