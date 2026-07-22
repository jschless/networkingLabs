# WP-11 — Data-Center Storage Networking

## Outcome

Deliver:

1. `labs/dc-storage-networking/` — a live practice lab for redundant Ethernet/IP
   storage paths using iSCSI and/or NVMe/TCP, multipath, jumbo MTU, segmentation,
   failure recovery, queue/congestion observation, and the “ping works, I/O stalls” case.
2. `labs/fixtures/dc-storage-networking/` — evidence-analysis material for Fibre
   Channel/FCoE, zoning, NPV/NPIV, VSANs, DCB/PFC/ECN/RoCE and SAN operations not
   faithfully provided by the current images.

Target: level 4 for IP storage and level 1 for FC/FCoE/RoCE hardware behavior.

## Fidelity

Live:

- isolated storage VLANs/VRFs and management separation;
- two initiator-to-target paths through independent ToR paths;
- iSCSI or NVMe/TCP discovery/session, multipath and failover;
- exact MTU validation and large-I/O behavior;
- throughput/latency/queue impact under controlled contention;
- path-health versus application/I/O health;
- CHAP or appropriate lab authentication and least-privilege management.

Evidence-only:

- Fibre Channel fabric login/name server, FLOGI/PLOGI, zoning, VSAN/IVR;
- FCoE FIP, lossless Ethernet, PFC pause storms;
- RoCEv2 ECN/PFC/DCQCN and ASIC buffer telemetry;
- real array/controller behavior and SCSI reservation/fencing.

## Feature-probe gate

1. Pin a target/initiator stack (`targetcli`/LIO or NVMe target) supported by the host.
2. Prove two independent sessions and Linux device-mapper multipath inside privileged
   but safely scoped containers.
3. Prove deterministic path failure and recovery without wedging host storage.
4. Prove exact MTU mismatch produces a bounded, observable lab symptom and reset.
5. Prove controlled I/O workload uses only ephemeral files/loop devices inside the
   lab and cannot touch host block devices.
6. Probe cEOS MTU/QoS data-plane behavior; use Linux bridges/routers if cEOS does
   not forward/storage-test as required.

Never pass host block devices into this lab. Use sparse files and loop devices
created inside the container/runtime and deleted on teardown.

## Lab type and platform

- Type: practice.
- `tor1`, `tor2`: cEOS if exact L2/L3/MTU behavior passes; otherwise Linux/OVS.
- `initiator1`, `target1`, `target2`, `observer`, `traffic-gen`: pinned Linux storage image.
- Optional `fabric-rtr`: cEOS/FRR only if a routed-storage variant is part of the
  validated scope.

## Topology/addressing

```text
                 tor1 -------- target1
 initiator1 ===== ||              ||
                 tor2 -------- target2
                   \-- observer / background load
```

| Network | Prefix | Purpose |
|---|---|---|
| Storage A | `10.111.10.0/24` | Path A |
| Storage B | `10.111.20.0/24` | Path B |
| Management | `10.111.30.0/24` | Control/monitoring |
| Background | `10.111.40.0/24` | Congestion generation |

Prebuild addressing, target backing files, service daemons, discovery records and
safe workload scripts. Withhold storage VLAN/VRF policy, initiator login, multipath
policy, MTU, QoS and monitoring.

## Student task sequence

1. **Guided storage-flow survey:** identify discovery, session, data and management
   paths; inspect empty sessions and validate that no host storage is exposed.
2. **Hinted fabric segmentation:** build independent storage A/B paths and management
   isolation; prove no accidental bridging or routed cross-talk.
3. **Hinted storage session:** discover/login to the target, authenticate, map the
   ephemeral device and run a bounded read/write integrity test.
4. **Hinted multipath:** establish two paths, configure selection/failure policy,
   verify path identities, and fail one path during I/O without corruption.
5. **Hinted MTU:** configure a consistent jumbo MTU, prove exact payload/frame limits
   hop by hop, and compare small ping with large I/O.
6. **Hinted contention:** generate background load, observe latency/queue behavior,
   and apply the validated scheduling policy without claiming lossless Ethernet.
7. **Open maintenance case:** remove one path/target for maintenance, drain safely,
   verify redundancy/capacity, restore it, and document rollback triggers.
8. **Break-It:** one intermediate interface reverts to 1500 while endpoint sessions
   remain established and small probes work. Large reads hang/retry. Diagnose MTU/
   counters/capture, repair the mismatched hop, and verify data integrity—not just ping.
9. **FC/RoCE evidence case:** trace supplied FC login/zoning evidence and a RoCE
   congestion/PFC case; identify likely fault domain and next safe validation step.

## Make the invisible visible

- Display session and multipath state tied to network interfaces.
- Capture discovery/login and storage data headers where safe.
- Correlate interface MTU/counters with I/O size and retries.
- Graph bounded I/O latency during path failure/contention.
- In evidence mode, trace WWPN→VSAN→zone→target and queue/PFC/ECN state.

## Automated checks

`check.sh` must assert at minimum:

1. Storage A/B and management isolation.
2. Two sessions/paths established with expected identities.
3. Multipath device uses only lab backing files.
4. Read/write checksum integrity passes.
5. Either path can fail independently while bounded I/O continues.
6. Both paths restore cleanly without duplicate/stale device state.
7. Jumbo MTU passes on every hop and exact large payload succeeds.
8. Management is inaccessible from storage data sources where intended.
9. Congestion policy keeps measured storage latency under declared lab threshold.
10. MTU Break-It fails large I/O while session/small-probe assertions expose the trap.
11. Destroy removes loop devices, mappings, mounts and sparse backing files.

## Planned files/docs

- Standard lab files, pinned storage image, safe workload/integrity scripts,
  `PROBE.md`, `VALIDATION.md`, teardown assertions, and fixture manifest.
- `docs/tracks/data-center/dc-storage-networking.md`.
- Data Center progression and coverage entries explicitly split IP-storage live
  from FC/FCoE/RoCE evidence-only.

## Resource target

- 2 cEOS/OVS + 5 Linux; ≤ 5 GiB steady.
- Disk: bounded sparse files totaling ≤ 2 GiB logical and a documented much smaller
  physical allocation; cleanup is mandatory.

## Definition of done

All master gates apply. A safety review must prove no host block device is reachable.
Run path failures during I/O, checksum validation, MTU Break-It, contention comparison,
and clean teardown. Fixture claims require storage-domain review before merge.
