# anycast-dns pre-remediation probe

This file preserves evidence gathered by the main agent against the previous
FRR-only implementation. It is not final validation of the remediated cEOS
lab.

## Observed workflow

- A clean six-node deployment completed successfully with FRR routers, FRR
  resolver hosts, and two incidental clients.
- The baseline had healthy local VIP/DNS behavior and no BGP configuration.
- Applying the previous documented solution produced `17 passed, 0 failed`.
- Each router retained two VIP paths, selected its one-AS local host path, and
  sent the local client through a two-hop path to its local resolver.
- A visible dnsmasq stop caused remote selection after 3.950 seconds; recovery
  to the local instance was observed after 2.007 seconds.
- Killing the route-health coupling before the service preserved every BGP
  session and both VIP paths while creating a site-local blackhole.
- The previous host configuration accepted only two routes at the router but
  actually advertised **seven** routes outbound. Adding a host outbound policy
  reduced the sender-side advertisement to the exact intended two `/32`s.
- The old six-container deployment sampled approximately 80 MiB total memory.

## Limitation

This evidence proves the routing-on-host behavior and the old FRR data path
only. At probe time, the final cEOS 4.35.2F configuration, native RIB/FIB JSON,
exact checker counts, idempotent fault/repair, resource use, and cleanup were
deferred. That later evidence is recorded separately in `VALIDATION.md`.
