# WP-03 — Data-Center Interconnect with EVPN

## Outcome

Build `labs/dci-evpn-multisite/`, a two-site practice lab that starts from two
independent healthy EVPN fabrics and makes the student design the inter-site
control/data plane. It must teach when to route between sites, when not to stretch
Layer 2, how tenant routes cross a DCI boundary, and how site-local failures and
MAC mobility appear operationally.

Target coverage: level 4. It complements rather than replaces `vxlan-evpn` and
`evpn-border-ceos`.

## Fidelity and design choice

Preferred implementation: cEOS on all fabric nodes, using standards-based eBGP
EVPN between site border gateways. Do not claim a vendor-specific “EVPN Multi-Site”
feature unless that exact feature and CLI are proven on cEOS 4.35.2F.

The base validated scope is:

- independent Site A and Site B underlays and EVPN control planes;
- a border-gateway role per site;
- inter-site exchange of selected EVPN type-5 prefixes;
- local anycast gateways and tenant VRFs;
- site-aware route targets/policy;
- routed DCI as the default design;
- an explicitly bounded optional L2-stretch exercise only if the probe proves it.

EVPN ESI multihoming is a stretch objective gated by a separate feature probe. MLAG
must not be presented as ESI multihoming.

## Feature-probe gate

Prove with two cEOS VTEPs and two route reflectors/border roles:

1. eBGP EVPN sessions can exchange type-5 routes between independent fabrics.
2. Imported type-5 routes install in the intended VRF and forward end to end.
3. Route-target rewrite/filter policy works as documented.
4. The DCI data path uses the expected VTEP/border next hop; capture it.
5. A border or DCI link failure withdraws routes within a bounded interval and
   does not disturb site-local tenant reachability.
6. If testing L2 stretch, prove type-2/3 propagation, MAC mobility sequence handling,
   duplicate-MAC behavior, and BUM containment. If any is unreliable, exclude the
   live stretch task and retain it as a design comparison.

Do not scaffold six cEOS nodes until the four-node probe fits the host and passes.

## Lab type and platform

- Type: practice/capstone.
- cEOS: `a-spine`, `a-leaf`, `a-bgw`, `b-spine`, `b-leaf`, `b-bgw`.
- Linux endpoints: `a-app`, `a-client`, `b-app`, `b-client`.
- Optional traffic observer: lightweight Linux capture node only if port mirroring
  is reliable; otherwise capture on border interfaces.

Six cEOS nodes are justified by the learning boundary: each site must remain an
independent fabric with a distinct border. Do not add a second leaf per site until
the base lab validates and resource headroom is measured.

## Topology and addressing

```text
 a-app -- a-leaf -- a-spine          b-spine -- b-leaf -- b-app
             \       |                  |       /
              \-- a-bgw ===== DCI ===== b-bgw-/
 a-client ------------------------------------------- b-client
```

- Site A loopbacks: `10.10.0.0/24`; Site B: `10.20.0.0/24`.
- Underlay links: sequential `/30`s under `10.11.0.0/16` and `10.21.0.0/16`.
- DCI: two `/30` links under `10.255.10.0/24` if dual-link ECMP is supported;
  start with one link in the probe.
- Tenant PROD: VLAN 10, L2VNI 10010 per site, L3VNI 50010,
  Site A `172.16.10.0/24`, Site B `172.17.10.0/24`.
- Tenant DEV: VLAN 20, L2VNI 10020, L3VNI 50020, intentionally site-local.
- Shared service: `172.31.10.0/24`, exported only to PROD.

Prebuild and validate both site-local fabrics. Withhold inter-site EVPN sessions,
route-target/policy mapping, DCI VRF forwarding, and any optional stretch state.

## Student task sequence

1. **Guided site validation:** prove each underlay, local EVPN sessions, anycast
   gateway, and site-local tenant isolation before touching DCI.
2. **Hinted border control plane:** establish inter-site eBGP EVPN between `a-bgw`
   and `b-bgw`, with explicit AF activation, extended communities, BFD if proven,
   and inbound/outbound route policy.
3. **Hinted routed PROD exchange:** export and import PROD type-5 routes only.
   Verify Site A and B PROD subnets reach each other while DEV remains local.
4. **Hinted shared services:** export the shared prefix to PROD at both sites and
   prove DEV has neither route nor policy access.
5. **Hinted failure-domain drill:** shut a DCI link/border and distinguish
   site-local EVPN health from inter-site service health. Measure withdrawal and recovery.
6. **Open design comparison:** document and test the consequences of routing at the
   border versus stretching a VLAN. If the optional stretch probe passed, enable one
   migration VLAN, move a workload, and inspect MAC-mobility state; otherwise use
   the checked evidence fixture.
7. **Break-It:** Site B receives the PROD type-5 NLRI but does not install it because
   one import route target is wrong. Local apps and all sessions appear healthy.
   Diagnose NLRI received vs. VRF RIB installation, make the smallest RT repair,
   and prove DEV remained isolated.

## Make the invisible visible

- Display local and inter-site EVPN RIBs separately.
- Trace RD/RT, VNI, and next hop from advertised route to VRF FIB.
- Capture VXLAN/EVPN traffic on the DCI.
- Compare route withdrawal with site-local host reachability during failure.
- For optional mobility, show sequence number and FDB movement, not just ping.

## Automated checks

`check.sh` must assert at minimum:

1. Both site-local underlays are healthy.
2. All site-local EVPN sessions are established.
3. Inter-site border sessions are established.
4. PROD type-5 routes are exchanged and installed.
5. DEV routes do not cross DCI.
6. PROD clients reach the remote PROD app.
7. Both PROD sites reach shared services.
8. DEV cannot reach shared services or remote DEV.
9. No default route or management prefix leaks between sites.
10. Intended border/VTEP next hops are installed.
11. Single DCI-link failure preserves service if the final topology includes two links.
12. Complete border loss removes remote service without breaking local service.
13. Break-It state fails on RT/FIB assertions even if a static route masks ping.

## Planned files and docs

- Standard lab files plus `PROBE.md`, `VALIDATION.md`, and optional mobility fixtures.
- `docs/tracks/data-center/dci-evpn-multisite.md`.
- Data Center, Enterprise, HA, Troubleshooting, and coverage-map registration.
- Add a DCI progression to study paths: `spine-leaf → vxlan-evpn → evpn-border-ceos
  → dci-evpn-multisite`.

## Resource target

- 6 cEOS + 4 Linux.
- Target steady state ≤ 10.5 GiB, leaving ≥ 3 GiB host headroom.
- If steady state exceeds target, reduce endpoints or use one site spine as a
  combined RR; do not collapse away the border/fabric distinction.

## Definition of done

All master gates apply. Validate every positive and negative tenant path, full
border loss, link failure, RT mismatch, clean convergence, and a second clean
deploy. Document whether mobility/ESI is live, evidence-only, or excluded.
