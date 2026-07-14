# Ticket TR-209 — Portal listener stops taking sessions

**Reported by:** Application monitoring
**Impact:** Users on every client network cannot start new portal sessions.
**Symptom:** DNS and ICMP checks pass, and the service host still reports a
listener on TCP/8080, but new TCP connections time out. Restarting client
applications has no effect.

Diagnose, fix, and verify the incident. Submit client and service-side TCP
evidence, the minimal correction, and repeated successful application tests.
