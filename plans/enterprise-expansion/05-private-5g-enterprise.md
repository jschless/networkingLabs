# WP-05 — Private 5G and Mobile Transport

## Outcome

Deliver a two-lab Mobile Infrastructure track:

1. `labs/private-5g-enterprise/` — attach simulated UEs through a real open-source
   5G core and gNB simulator, establish PDU sessions, route user traffic through a
   UPF into enterprise applications, apply subscriber/DNN policy, and troubleshoot
   “registered but no data” failures.
2. `labs/mobile-transport-timing/` — teach the IP transport seam: VRFs, QoS,
   redundant backhaul, software-timestamp PTP behavior, and timing evidence, while
   explicitly excluding RF and hardware SyncE claims.

Targets: level 4 for core/user-plane integration and level 3 for transport/timing.

## Fidelity

`private-5g-enterprise` uses pinned Open5GS and UERANSIM-compatible images. It
should expose real NAS/NGAP/PFCP/GTP-U behavior within the simulator limits.

Live:

- subscriber/SUPI and lab-safe key provisioning;
- gNB connection to AMF over N2 and UPF data over N3;
- registration, authentication, PDU session, UE address allocation;
- AMF/SMF/UPF separation and logs;
- DNN selection, policy, route/NAT or routed enterprise integration;
- GTP-U capture and mapping outer tunnel to inner UE flow;
- multiple subscribers or DNNs with different access policy.

Not claimed:

- real NR RF/PHY, spectrum, antenna, handover measurements, SIM hardware, lawful
  intercept, carrier billing, production roaming, or radio planning.

`mobile-transport-timing` may use `linuxptp` software timestamping only. Hardware
timestamp accuracy, boundary/transparent clock silicon, SyncE, and GNSS remain
evidence/design topics.

## Load-bearing probes

### Core probe

1. Pin a mutually compatible Open5GS/UERANSIM release set.
2. Run the core, one gNB, and one UE under ContainerLab/Docker network namespaces.
3. Prove registration, PDU session, TUN creation, UE address, and enterprise-app ping.
4. Capture decodable NGAP, PFCP, and GTP-U on known interfaces.
5. Prove destroy removes TUN devices, routes, processes, Mongo state, and namespaces.
6. Measure clean readiness and avoid fragile fixed sleeps.

If SCTP, TUN, or required capabilities cannot work safely on the host, stop and
document the blocker; do not replace the core with HTTP mocks.

### Timing probe

1. Prove `ptp4l`/`phc2sys` software-timestamp mode between namespaces.
2. Determine which metrics are meaningful without PHC hardware.
3. Test BMCA/grandmaster change and clock-offset injection safely.
4. Capture PTP messages and confirm cleanup.

## Lab A topology — `private-5g-enterprise`

```text
 ue-corp )) ueransim-gnb --N2--> open5gs-core
 ue-guest ))       |       --N3--> upf -- enterprise-edge -- corp-app
                  logs                         \-- internet-test
```

Prefer separate logical containers for `core-cp` and `upf`; the control-plane
container may run AMF/SMF/UDM/AUSF/NRF/PCF plus Mongo for resource economy. Use a
separate `subscriber-admin` only if provisioning cannot be made safely through a
documented CLI/API.

| Network | Prefix | Purpose |
|---|---|---|
| N2/N3 access | `10.80.10.0/24` | gNB to core/UPF |
| Core services | `10.80.20.0/24` | SBI/PFCP/Mongo |
| Corp UE pool | `10.81.0.0/16` | `corp` DNN |
| Guest UE pool | `10.82.0.0/16` | `guest` DNN |
| Enterprise app | `10.83.10.0/24` | Private application |
| Internet test | `198.18.80.0/24` | External reachability |

Prebuild core services, lab certificates/keys, addresses, applications, and base
routing. Withhold subscriber records, gNB/AMF peer parameters, DNN policy, and
enterprise route/policy integration.

## Lab A tasks

1. **Guided architecture survey:** identify which interfaces carry SBI, N2, N3,
   PFCP, GTP-U, and plain enterprise IP. Follow one registration attempt across logs.
2. **Hinted subscriber provisioning:** create corp and guest subscribers from supplied
   lab identities/keys, with distinct DNN and session policy.
3. **Hinted gNB and UE attachment:** configure PLMN/TAC/AMF values, establish NGAP,
   register UEs, and prove authentication without exposing real-world secrets.
4. **Hinted PDU session:** configure corp/guest DNNs, address pools, UPF routing, and
   enterprise return paths. Prove inner UE IP and outer GTP-U mapping by capture.
5. **Hinted segmentation:** corp UE reaches private app; guest reaches internet-test
   only; neither reaches core management/SBI.
6. **Open policy case:** add a contractor subscriber with a restricted DNN/prefix and
   justify whether enforcement belongs in PCF/UPF, enterprise firewall, or both.
7. **Break-It:** corp UE registers and receives an IP, but the private app is unreachable
   because SMF selects a DNN whose UPF route/enterprise return prefix is wrong. Diagnose
   registration vs. PDU vs. GTP-U vs. enterprise return path; fix the intended route/policy.

## Lab B topology/tasks — `mobile-transport-timing`

```text
 gnb-site -- agg1 ==== agg2 -- mobile-core
               \==== backup /
                  ptp-gm
```

- cEOS for aggregation if QoS/PTP control support probes successfully; otherwise
  cEOS for routing/QoS and Linux for PTP endpoints.
- Student builds separate management/control/user VRFs, DSCP classification and
  measured congestion policy, BFD-protected redundant routing, and software PTP.
- Invisible mechanism: packet captures correlate PTP, GTP/control markings, queues,
  and failover.
- Break-It: wrong QoS trust on one ingress causes control/timing packets to share a
  congested best-effort queue; reachability remains green while offset/jitter and
  session stability degrade.

## Automated checks

Lab A `check.sh` must assert at minimum:

1. AMF/SMF/UPF services are ready.
2. gNB NGAP association is healthy.
3. Both UEs register.
4. Both receive addresses from correct DNN pools.
5. PFCP session and GTP-U tunnel exist per UE.
6. Corp reaches private app and internet-test as designed.
7. Guest reaches internet-test but not private app/core management.
8. Enterprise has exact return routes, not a blanket route masking policy.
9. Captured inner/outer addresses match session state.
10. Break-It fails on route/policy assertions despite UE registration.

Lab B `check.sh` must assert at minimum:

1. Three VRFs remain isolated.
2. Both routed backhaul paths are healthy; preferred path is deterministic.
3. BFD/failure convergence stays within the measured bound.
4. QoS classification counters match offered traffic.
5. Congestion preserves the defined control/user thresholds.
6. PTP software session and offset stay within a declared lab-only bound.
7. Timing failover occurs and is captured.

## Planned files/docs

- Two standard lab directories, pinned Dockerfiles/images, `PROBE.md` and
  `VALIDATION.md` per lab.
- New `docs/tracks/mobile/index.md` plus wrapper pages and mkdocs nav.
- Image-build table updates and a prominent host capability/SCTP/TUN warning.
- Fixture pack for hardware PTP/SyncE/RF/handover evidence, provenance-controlled.

## Resource target

- Core lab: ≤ 5 GiB steady, ≤ 7 GiB peak, readiness ≤ 180 seconds.
- Transport lab: ≤ 6 GiB steady.
- Never deploy both concurrently in documented workflow.

## Definition of done

Three clean core deploy/destroy cycles; no stale TUN/SCTP/Mongo state; captures decode
as claimed; two-DNN positive/negative policy works; Break-It distinguishes registration
from user-plane/return-path failure; timing documentation labels software timestamps
and never reports them as hardware-grade synchronization.
