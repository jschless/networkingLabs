# WP-07 — Internet Peering and IXP Operations

## Outcome

Build `labs/internet-peering-ixp/`, a practice lab that moves beyond ordinary
eBGP configuration into exchange operations: bilateral and route-server peering,
import/export policy, IRR-derived filters, RPKI validation, maximum-prefix,
communities, graceful maintenance, remote-triggered blackholing, and the contact/
evidence workflow used during a routing incident.

Target coverage: level 4. Existing `bgp-prefix-security`, `bgp-rpki`,
`enterprise-wan-edge`, and advanced-edge tickets are prerequisites.

## Fidelity

Live:

- an IXP peering LAN and two redundant route servers;
- multilateral route-server and bilateral sessions;
- route-server semantics without inserting its AS into the forwarding path;
- explicit import/export filters and approved prefix/ASN inventory;
- IRR-to-prefix-list generation from local deterministic objects;
- RPKI RTR validation using the existing proven pattern;
- standard/large/blackhole communities where supported;
- maximum-prefix and graceful shutdown/maintenance behavior;
- route leak, invalid origin, stale filter, and RTBH data-plane outcomes.

Evidence/design:

- PeeringDB-style records, LOA/authorization, NOC contacts, traffic ratios,
  port/cross-connect ordering, settlement-free policy, and full-table scale.

## Feature-probe gate

1. Probe cEOS for route-server client semantics, `enforce-first-as` behavior,
   large communities, graceful shutdown community handling, and blackhole next hops.
2. Probe FRR 8.4 only for features cEOS lacks; route servers may use FRR if that
   is the smallest exact implementation. Record why this exception is required.
3. Reuse the pinned local RPKI RTR implementation from `bgp-rpki`; prove it can
   carry the planned ROAs and fail closed/open according to explicit policy.
4. Pin and test `bgpq4` or an equivalent local IRR filter generator against a
   checked-in local IRR dataset—never depend on live public IRR during the lab.
5. Measure memory for the selected router mix before adding endpoints.

## Lab type and platform

- Type: practice/capstone.
- `rs1`, `rs2`: cEOS if exact semantics work, otherwise FRR with documented reason.
- `enterprise`: cEOS AS65001.
- `peer-content`: cEOS AS65002.
- `peer-saas`: cEOS or FRR AS65003.
- `transit`: cEOS/FRR AS64500.
- `rpki`, `irr`, `looking-glass`, endpoint services: lightweight Linux.

## Topology/addressing

```text
                    rs1        rs2
                      \        /
 enterprise ----------- IXP LAN -------- peer-content
      |                    |              |
   transit              peer-saas      services
      |
 internet-test       rpki / irr / looking-glass
```

- IXP peering LAN: `198.18.70.0/24`; no participant default route.
- Bilateral links: sequential `/30`s under `192.0.2.0/24`.
- Enterprise prefix: `203.0.113.0/24`.
- Content prefix: `198.51.100.0/24`.
- SaaS prefix: documentation-safe distinct `/24` represented by lab-internal route.
- Management/services: `10.100.70.0/24`.

Prebuild interfaces, loopbacks, prefix ownership records, ROAs, local IRR objects,
looking glass, endpoint services, and management access. Withhold BGP sessions,
policies, community handling, generated filters, and maintenance/RTBH controls.

## Student task sequence

1. **Guided peering review:** validate port/VLAN/IP/ASN/contact/prefix records and
   identify why a session may be technically possible but operationally unauthorized.
2. **Hinted bilateral peering:** establish enterprise↔content with MD5 where the
   platform supports it, explicit import/export, max-prefix, and no transit leak.
3. **Hinted route-server peering:** connect all participants to rs1/rs2; implement
   route-server semantics, next-hop behavior, and redundant policy.
4. **Hinted IRR filters:** generate deterministic prefix/as-path filters from local
   route/route6/aut-num/as-set objects, review the diff, apply them, and verify
   approved advertisements only.
5. **Hinted RPKI:** classify valid/invalid/not-found paths and implement a policy that
   drops invalid while treating not-found according to the documented lab decision.
6. **Hinted communities:** implement no-export, regional/local preference, graceful
   shutdown, and an IXP blackhole community with explicit scope.
7. **Hinted maintenance:** drain one route-server/peer path without dropping all
   reachability; compare administrative drain with hard shutdown.
8. **Open incident coordination:** an unauthorized more-specific appears. Use local
   looking glass, RPKI/IRR state, contact records, route capture, and timestamps to
   identify origin and prepare a concise escalation.
9. **Break-It:** peer-saas legitimately adds a second prefix, but enterprise's
   generated IRR filter is stale. BGP remains Established and other services work.
   Diagnose received-versus-accepted routes, update the authoritative local IRR object,
   regenerate/review/apply policy, and prove no extra prefix was admitted.

## Make the invisible visible

- Compare route-server control path with data-plane next hop.
- Inspect received, accepted, advertised, and best paths separately.
- Show the generated policy diff from IRR source to router filter.
- Correlate ROA with per-path RPKI state.
- Capture graceful drain and blackhole route propagation.

## Automated checks

`check.sh` must assert at minimum:

1. Both route-server sessions per participant are healthy.
2. Bilateral session is healthy.
3. Route server does not become unintended forwarding next hop.
4. Only registered prefixes are accepted from each participant.
5. Enterprise never provides peer-to-peer or peer-to-transit transit.
6. RPKI invalid route is rejected; valid route accepted.
7. Not-found treatment matches documented policy.
8. Maximum-prefix threshold and warning/teardown behavior are asserted safely.
9. Graceful drain shifts traffic before session teardown.
10. RTBH affects only the selected host/prefix and expires/clears cleanly.
11. Looking glass shows the same intended propagation.
12. Stale IRR Break-It fails accepted-prefix assertions even though sessions stay up.

## Evidence pack

Create synthetic PeeringDB/IRR/NOC/LOA/cross-connect records with no real contacts or
IDs. Include an incident timeline and route collector snapshot generated from the lab.
Provide provenance/checksums and separate student/proctor views.

## Planned files/docs

- Standard lab files, local IRR/RPKI data, generator wrapper, looking-glass config,
  `PROBE.md`, and `VALIDATION.md`.
- `docs/tracks/bgp/internet-peering-ixp.md`, registered in BGP, Enterprise, and
  MPLS/SP study paths.
- Enterprise coverage map distinguishes protocol peering from operational peering.

## Resource target

- Prefer 3 cEOS participants + 2 lightweight FRR route servers + Linux services.
- Target ≤ 7 GiB steady, hard ceiling 9 GiB.

## Definition of done

All master gates apply. Verify route-server next-hop semantics, IRR generation from
source data, all RPKI states, no-transit negative paths, drain/RTBH behavior, stale
filter diagnosis, and clean policy restoration after redeploy.
