# Ticket AR-204 — Primary internet route missing internally

**Reported by:** Enterprise route assurance  
**Impact:** Internet service remains available over the backup edge, but internal routers no longer learn the service prefix from the primary edge.  
**Symptom:** The primary edge has a valid preferred external route and healthy neighbors. The route disappears only after crossing into the internal routing domain.

Diagnose, fix, and verify the incident. Submit evidence from both routing domains, the minimal boundary correction, and restored primary-path verification.
