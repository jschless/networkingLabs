# anycast-dns validation record

Status: **validated by the main agent**

The final modified resolver image built successfully with the exact pinned
packages, and the final topology deployed cleanly from scratch. This live
record was collected on amd64. The checker contains the documented arm64 cEOS
mapping, but no arm64 live-validation claim is made.

## Clean deployment and baseline

- Both cEOS routers reported EOS `4.35.2F-46221466.4352F`, engineering build
  ID `6f39e5bb-e6c7-4637-b931-ecb30d43e034`.
- Each router had exactly one Established core peer and accepted two core
  prefixes; c1 reached c2.
- Each resolver had exactly one dnsmasq, one watchdog, its local identity, and
  the shared VIP. Each installed the exact `172.16.0.0/16` client return route.
- Neither router had a VIP route before the service-host BGP boundary was
  configured.

## Documented solution

- Native cEOS and FRR accepted the documented solution. Each cEOS router had
  exactly two Established peers and each resolver host had exactly one.
- Each host advertised only its unique `/32` and the shared VIP `/32`;
  management and service-transit prefixes were absent.
- Each cEOS BGP RIB held exactly two VIP paths: the local one-AS path was active
  and best, while the remote path contained two AS hops. Each FIB installed
  only its exact local resolver next hop.
- c1 selected dns1 and c2 selected dns2. Both received the shared record, both
  local VIP traces were two hops, and both cross-site unique-address queries
  returned the intended resolver identity.
- The solved checker reported `52 passed, 0 failed`.

## Normal withdrawal and recovery

Stopping dnsmasq caused no BGP peer drops. Failover completed in 2.657 seconds:
r1 retained the one remote VIP path and c1's trace became three hops. Recovery
completed in 0.878 seconds, restoring one daemon, one watchdog, and the local
best path.

## Supported fault and repair

- Running `break.sh` twice succeeded.
- The broken checker reported exactly `47 passed, 5 failed`. The intended
  failures were aggregate dnsmasq uniqueness, watchdog uniqueness, local DNS,
  c1 anycast identity/data, and cross-site unique identity.
- The VIP, BGP sessions, both VIP paths, and local FIB remained green during
  the fault, proving the stale service-to-route coupling blackhole.
- Running `solution.sh` twice succeeded and the final checker returned
  `52 passed, 0 failed`.
- A second clean redeploy after the return-route and checker fixes also reached
  `52 passed, 0 failed` with no runtime workaround.

## Resource and cleanup evidence

| Container | No-stream memory |
|-----------|-----------------:|
| r1 | 1.233 GiB |
| r2 | 1.227 GiB |
| dns1 | 18.09 MiB |
| dns2 | 18.05 MiB |
| c1 | 676 KiB |
| c2 | 672 KiB |

The sampled total was approximately 2.50 GiB. Safe destroy succeeded, leaving
no target containers, Docker network, PID/lock files, or packet-capture
artifacts.

The `lab-tutor` skill was unavailable, so no tutor-validation claim is made.
