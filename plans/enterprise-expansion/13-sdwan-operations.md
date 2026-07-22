# WP-13 — SD-WAN Control and Operations

## Outcome

Build `labs/sdwan-operations/`, a level-4 follow-on to `sdwan-concepts`. The
student should enroll edges through PKI, establish control and data overlays across
two transports, distribute segmented routes/policy from a controller, steer an
application by measured SLA, use local internet breakout selectively, and diagnose
an overlay failure whose underlay remains healthy.

The exact lab name may become `orchestrated-wan-overlay` if the feature probe
cannot support an honest SD-WAN control-plane implementation. Do not retain the
SD-WAN name for another set of manually configured GRE tunnels.

## Platform decision gate

The implementation agent first evaluates locally runnable, license-compatible,
pin-able SD-WAN candidates. The decision record must compare:

- controller/orchestrator/edge availability and licensing;
- unattended bootstrap and certificate enrollment;
- multi-transport overlay and segmentation;
- application/SLA policy and telemetry;
- API/CLI observability and runtime fault injection;
- image size, memory, offline repeatability, and cleanup.

Potential outcomes:

1. **Preferred:** a real open-source or freely lab-licensed controller/edge stack
   meets all mandatory behaviors. Use and name it.
2. **Acceptable:** build a provider-neutral orchestrated overlay using VyOS/Linux
   edges, a real PKI, a real controller API/state store, BGP/route distribution,
   IPsec/WireGuard tunnels, measured probes, and centralized policy. Name it
   `orchestrated-wan-overlay` and map behaviors to SD-WAN products.
3. **Stop:** if neither can provide control/data separation and centralized
   lifecycle honestly, retain `sdwan-concepts` and publish only a product-sandbox
   plan. Do not build a mock dashboard.

## Mandatory live behaviors

- controller/orchestrator identity distinct from forwarding nodes;
- certificate-based edge enrollment and revocation/expiry visibility;
- two underlays per branch, labeled as MPLS/private and internet;
- encrypted overlay and segmented route exchange;
- centralized policy distribution with version/audit state;
- active SLA measurement for loss/latency/jitter and bounded path switching;
- application-aware or at least DSCP/prefix/port-aware path policy;
- selective local internet breakout versus hub security path;
- telemetry showing underlay, overlay, tunnel, route and policy health separately.

## Topology/addressing

```text
                        controller / PKI
                           | control
 branch1 == MPLS == hub/edge == MPLS == branch2
    ||                ||                 ||
 internet ========= internet ========= internet
    |                                    |
 corp/app                              corp/app
                         \-- SaaS test
```

- Branch LANs: `10.113.10.0/24`, `10.113.20.0/24`.
- Hub services: `10.113.30.0/24`.
- Controller management: `10.113.40.0/24`.
- MPLS underlay: sequential `/30`s under `172.20.113.0/24`.
- Internet underlay: sequential `/30`s under `192.0.2.112/28`.
- Overlay/loopbacks: `10.255.113.0/24`.
- Segments: CORP and GUEST, with guest local breakout only.

Prebuild underlay IP connectivity, controller/PKI services, endpoint apps and
traffic profiles. Withhold enrollment, overlays, routing, segmentation, SLA and
breakout policy.

## Student task sequence

1. **Guided plane survey:** prove both underlays while overlay routes/services are
   absent; distinguish management, control, and data traffic.
2. **Hinted bootstrap/enrollment:** issue edge identity, enroll branch/hub nodes,
   verify trust chains and reject an unknown edge.
3. **Hinted overlay/segments:** establish encrypted tunnels/control adjacencies and
   distribute CORP/GUEST routes without cross-segment leaks.
4. **Hinted centralized policy:** publish a versioned topology/routing policy,
   observe edge acknowledgement, and verify rollback to the previous version.
5. **Hinted application SLA:** measure both paths, prefer MPLS for voice/critical app,
   internet for bulk/SaaS, then inject latency/loss and measure switching/hysteresis.
6. **Hinted local breakout:** send guest/SaaS directly to internet while corporate
   private-app traffic uses hub inspection; verify return symmetry and segmentation.
7. **Open brownout case:** tune thresholds/hold-down so real degradation causes
   bounded failover without oscillation from a single transient probe.
8. **Break-It:** one edge certificate expires or is revoked. Both underlays ping and
   existing local LAN works, but control/overlay cannot establish or renew. Diagnose
   trust/time/control status, rotate identity through the intended enrollment path,
   and prove route/policy recovery without disabling certificate validation.

## Make the invisible visible

- Capture enrollment/control and encrypted data-plane flows separately.
- Display controller desired state, edge applied version and acknowledgement.
- Correlate probe time series with path decision and service loss.
- Show per-segment route tables and tunnel identities.
- Compare brownout and hard-down behavior.

## Automated checks

`check.sh` must assert at minimum:

1. Both underlays healthy independently.
2. All edges enrolled with trusted, unexpired identity.
3. Control sessions and overlay tunnels healthy.
4. CORP routes exchange; GUEST remains isolated.
5. Critical app takes preferred path in golden state.
6. Bulk/SaaS policy takes intended path.
7. Injected brownout switches within bound and respects hysteresis.
8. Hard failure uses alternate transport.
9. Guest local breakout cannot reach private services.
10. Controller policy version equals edge applied version.
11. Rollback restores previous policy and service.
12. Expired/revoked certificate Break-It fails control while underlay checks stay green.

## Planned files/docs

- Standard lab files, platform decision/probe record, pinned images, PKI, controller
  bootstrap, traffic profiles, `VALIDATION.md`.
- `docs/tracks/enterprise/sdwan-operations.md` or
  `orchestrated-wan-overlay.md`, placed after `sdwan-concepts`.
- Exact product mapping table and explicit fidelity statement.

## Resource target

- Target ≤ 8 GiB steady, hard ceiling 10 GiB; readiness ≤ 4 minutes.
- If a real controller exceeds this, document an external/sandbox companion instead
  of violating lab-host headroom.

## Definition of done

All master gates apply. The platform naming must match actual fidelity. Validate
enrollment, revocation/rotation, two transports, two segments, policy versioning,
brownout/hysteresis, hard failure, local breakout and clean redeploy.
