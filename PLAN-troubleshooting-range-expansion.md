# Troubleshooting Range Expansion Plan

> **Status: ACTIVE — Wave B initial campus range completed 2026-07-14.** This plan turns the
> troubleshooting coverage audit into deployable, proctored tickets that follow
> `labs/troubleshooting-range/scenarios/AUTHORING.md`.

## Goals and constraints

- Prefer observable enterprise failure modes over additional variations of a
  static route or administratively disabled interface.
- Keep the existing ranges fast and persistent. Add no containers in Wave A.
- Keep steady-state use below 8 GiB per deployed range and at least 5 GiB host
  memory available. Larger ranges are separately deployable, not simultaneous.
- Every scenario is symptom-only for the engineer, runtime-only in its
  injector, idempotent in its clear path, and protected by a golden-state
  health assertion.
- Every completed ticket must pass the structural validator and a live
  `status -> start -> diagnose -> repair -> verify -> reset` dry run.
- Use real protocol or kernel behavior where ContainerLab can reproduce it.
  Do not pretend that a synthetic counter is an optical, ASIC, or RF failure.

## Priority model

1. **Breadth:** close a domain with little or no current incident coverage.
2. **Diagnostic transfer:** reward evidence that applies across vendors.
3. **Emulation fidelity:** use a real Linux/network protocol mechanism with a
   deterministic symptom and repair.
4. **Resource cost:** reuse a running topology before adding nodes or images.
5. **Reset safety:** prefer state the generic no-restart reset can prove clean.

## Wave A — existing topologies, no node growth

This is the active implementation wave. It adds failure mechanics that the
current enterprise and advanced-edge ranges can model faithfully.

### Enterprise range

- [x] **T1 duplicate gateway address** — an endpoint claims its default
      gateway's IPv4 address; distinguish local addressing conflict from VLAN,
      routing, or upstream failure.
- [x] **T2 web accept-queue exhaustion** — the service still listens and the
      network is healthy, but the application is no longer accepting queued
      TCP sessions.
- [x] **T3 intermittent services-link loss** — controlled `tc netem` loss makes
      DNS/web intermittently fail while interfaces and OSPF remain healthy.

### Advanced edge range

- [x] **T2 BGP maximum-prefix containment** — a legitimate second provider
      prefix exceeds a stale one-prefix ceiling and resets the preferred peer.
- [x] **T2 private-prefix route leak** — the enterprise accidentally advertises
      an internal prefix to its provider while internal service remains healthy.

Shared work:

- [x] Extend reset and health gates for qdisc, duplicate-address, service
      process, maximum-prefix, and leaked-prefix state.
- [x] Update catalogs, ticket totals, known-good references, and the routing
      authoring reference.

## Wave B — separately deployed campus incident range

Build `labs/troubleshooting-range-campus/` from the proven `stp-operations`,
`lacp-etherchannel`, and `campus-l2-hardening` behaviors. Target two cEOS
switches plus lightweight Linux endpoints; do not run it concurrently with
both existing ranges during assessment.

- [x] BPDU Guard or port-security errdisable, with cause-specific recovery.
- [x] STP root drift.
- [ ] Excessive topology-change churn.
- [x] LACP mode/member inconsistency with a logical bundle that is degraded or
      selectively blackholes flows.
- [x] Allowed/native VLAN mismatch with one-VLAN-only impact.
- [ ] MAC flapping and broadcast-storm localization.
- [ ] First-hop redundancy split brain, failed tracking, and stale-neighbor
      behavior after failover (deferred: this cEOS image has no usable VRRP/HSRP
      interface mode; implement with a capable image or a keepalived range).
- [ ] DHCP snooping/DAI trust error and rogue DHCP containment (deferred: the
      current cEOS image does not expose operational per-interface trust).

## Wave C — services, identity, and dual-stack range

Build a lightweight service range around one access switch, redundant DHCP/DNS
services, NTP, RADIUS/TACACS+, a web/TLS endpoint, and dual-stack clients.

- [ ] DHCP pool exhaustion, wrong relay `giaddr`/scope, and Option 82 policy.
- [ ] DNS forwarder, split-horizon, stale negative-cache, and TCP/53 failures.
- [ ] NTP skew presenting as Kerberos, certificate, and log-correlation failure.
- [ ] RADIUS timeout vs reject, EAP certificate chain/expiry, CoA, and dynamic
      VLAN authorization.
- [ ] TACACS authorization/accounting failure and unsafe local fallback.
- [ ] Rogue/conflicting IPv6 Router Advertisement, RDNSS/DHCPv6 disagreement,
      and Neighbor Discovery/DAD faults.
- [ ] IPv4-good/IPv6-bad dual-stack application behavior.
- [ ] TLS SNI, hostname, trust-chain, and mTLS client-certificate incidents.

## Wave D — advanced edge and hybrid operations

Extend the advanced range or add a separate all-Linux hybrid range when the
healthy-state gate for each technology is explicit.

- [ ] IPsec/IKE proposal, selector, NAT-T, rekey, and tunnel-MTU incidents.
- [ ] Stateful-firewall asymmetry, rule shadowing, NAT port exhaustion, and
      hairpin NAT.
- [ ] Cloud-like route-table plus stateful/stateless policy interactions,
      overlapping prefixes, and private DNS.
- [ ] SD-WAN control/certificate/TLOC/BFD/overlay-policy incidents using a real
      available image; otherwise leave them documented rather than simulated.
- [ ] QoS trust/classification/policer failures under measured congestion.
- [ ] Multicast RPF, IGMP querier/snooping, RP mapping, and TTL failures.
- [ ] Load-balancer health-check, persistence, and anycast-unhealthy-advertiser
      incidents.
- [ ] Platform CPU/memory/route-scale and control-plane policing symptoms.
- [ ] Telemetry-pipeline blindness, clock skew, stale inventory, and misleading
      alert thresholds.
- [ ] Automation partial push, configuration drift, non-idempotence, and
      rollback/running-vs-startup mismatch.

## Fidelity boundary

The following topics need hardware, RF tooling, or explicit simulation labels:

- Optical receive power, FEC, transceiver EEPROM, PoE budgets, line-card and
  environmental alarms.
- Real 802.11 RF interference, roaming, airtime contention, and client-driver
  interoperability.
- ASIC-only microbursts, TCAM partitioning, and hardware forwarding defects.

ContainerLab can still teach the evidence workflow by replaying captures or
fixtures, but those exercises must be labeled as evidence analysis rather than
live fault emulation.

## Completion record

| Date | Wave | Result |
|---|---|---|
| 2026-07-13 | Plan | Capacity checked with both ranges running: 9.6 GiB available; Wave A selected because it requires no additional nodes. |
| 2026-07-13 | Wave A | Added five tickets with no node growth; all passed structural validation and live repair/verify/reset dry runs. |
| 2026-07-14 | Wave B | Built a separate two-cEOS campus range and live-proved BPDU Guard errdisable, STP root drift, LACP member loss, and a one-VLAN trunk mismatch. |
