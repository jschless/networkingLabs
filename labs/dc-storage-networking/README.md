# Data-Center Storage Networking — Practice Lab

Build two independent Ethernet/IP storage paths, authenticate an iSCSI initiator,
combine the paths with Linux device-mapper multipath, validate jumbo MTU exactly,
and protect bounded storage I/O during path failure and contention. The live scope
is IP storage at coverage level 4. Fibre Channel, FCoE, DCB/PFC, RoCE, and array
controller behavior remain clearly labeled level-1 evidence.

The initiator runs in a 768 MiB KVM guest inside its ContainerLab node. That extra
boundary is deliberate: the guest sees only its disposable OS disk and the
synthetic iSCSI LUN—never a host disk. The target is a 256 MiB sparse file; no
host block device or loop device is passed to the lab.

## Topology

```text
                         Storage A / background
                    +----------- tor1 -----------+
                    |              |             |
             storagea          target1:a     traffic-gen
                 |                 |
 initiator1(KVM) |                 |  one synthetic LUN
                 |                 |
             storageb          target1:b
                    |              |
                    +----------- tor2 -----------+
                         Storage B

 initiator1.mgmt ---- observer bridge ---- target1.mgmt
                              \----------- target2.mgmt
 target2 is a cold-spare validation endpoint, not a shared-array controller.
```

### Networks

| Network | Prefix | Endpoints | Purpose |
|---|---|---|---|
| Storage A | `10.111.10.0/24` | initiator `.10`, target1 `.20`, target2 `.21` | iSCSI path A |
| Storage B | `10.111.20.0/24` | initiator `.10`, target1 `.20`, target2 `.21` | iSCSI path B |
| Management | `10.111.30.0/24` | initiator `.10`, target1 `.20`, target2 `.21`, observer `.40` | control/observation only |
| Background | `10.111.40.0/24` | traffic-gen `.10`, target1 `.20`, initiator-container `.254` | controlled contention |

### Node reference

| Node | Role | Initial state |
|---|---|---|
| `tor1`, `tor2` | Independent Linux bridge ToRs | ports up; storage bridges withheld |
| `initiator1` | Container hosting an isolated Ubuntu 24.04 KVM initiator | addressing ready; no sessions or multipath policy |
| `target1` | LIO file-backed target with initiator-scoped CHAP ACL | target ready; zero sessions |
| `target2` | Cold-spare path/capacity validation endpoint | no shared LUN claim |
| `observer` | Management-only bridge and capture point | management ready |
| `traffic-gen` | Background load source | addressing ready |

## Fidelity and safety boundary

- Live: LIO iSCSI discovery/login, CHAP, two TCP sessions, SCSI path identity,
  device-mapper multipath, failover/recovery, exact MTU, Linux `tc` scheduling,
  queue counters, bounded I/O, and checksum integrity.
- Emulated: the two ToRs are Linux bridges because cEOSLab has no hardware egress
  scheduler; Linux `tc` is the plan-authorized fallback. This lab does not call
  HTB “lossless Ethernet.”
- Evidence-only: FC login/name server/zoning/VSAN reasoning and reduced
  RoCE/ECN/PFC evidence under
  `labs/fixtures/dc-storage-networking/`.
- Not represented: shared-array controllers, reservations/fencing, FIP, NPV/NPIV,
  IVR, ASIC buffers, DCQCN, pause storms, or production SAN operational tooling.

!!! warning "Linux/amd64 and KVM required"
    The safe initiator boundary requires Linux/amd64 with `/dev/kvm`. Do not
    replace it with host-mode `iscsid`, mount host `/dev`, or pass a host disk.

## How to use this lab

This is a **practice lab**, not a tutorial. Each task gives you an
**objective** and **hints** — your job is to produce the configuration.

- **Predict before you configure.** When a task asks for a prediction,
  commit to an answer before touching the CLI. Being wrong and finding out
  why is the point.
- **Open the hints before the solution.** The solution toggle is the answer
  key — use it to check your work or when genuinely stuck, not as step one.
- **Verify like an operator.** After each task, prove the state is what you
  think it is with state and data-path commands before moving on.

## Deploy

The one-time build downloads a dated Ubuntu Noble cloud image, verifies its
SHA-256 in the Dockerfile, and produces `dc-storage-tools:1.0.0`. No internet is
needed after the image exists.

```bash
docker build -t dc-storage-tools:1.0.0 labs/dc-storage-networking/
./scripts/lab.sh deploy dc-storage-networking
```

The KVM guest normally becomes ready in 45–75 seconds. Access the container shell
and then the guest:

```bash
./scripts/lab.sh bash dc-storage-networking initiator1
vm-exec hostname
vm-exec ip -br address
```

Always use the scoped cleanup at the end:

```bash
./labs/dc-storage-networking/destroy.sh
```

## Task 1 — Survey the blank storage flow (guided)

**Objective:** Identify management, discovery/session, and data paths; prove the
initiator has no session and that the target backing object is a lab sparse file.

**Predict first:** Does an addressable target mean a storage session already exists?

```bash
./scripts/lab.sh cmd dc-storage-networking initiator1 \
  "vm-exec sudo iscsiadm -m session"
./scripts/lab.sh cmd dc-storage-networking initiator1 \
  "vm-exec sudo multipath -ll"
./scripts/lab.sh cmd dc-storage-networking target1 \
  "targetcli /backstores/fileio ls"
./scripts/lab.sh cmd dc-storage-networking target1 \
  "du -h /var/lib/storage/lun.img; stat -c %s /var/lib/storage/lun.img"
./scripts/lab.sh cmd dc-storage-networking observer \
  "ping -c2 10.111.30.20"
```

<details markdown="1">
<summary>Check your work</summary>

`iscsiadm` reports no active sessions and `multipath -ll` is empty. The target
shows `/var/lib/storage/lun.img`, with a logical size of 268435456 bytes and near
zero physical allocation before I/O. Management ping works even though the
storage ToR bridges do not yet exist. Addressing and a target are prerequisites,
not proof of a session.

</details>

## Task 2 — Segment the two storage fabrics (hinted)

**Objective:** Build one bridge on each ToR so Storage A and B are independent,
while management remains on the observer bridge.

**Predict first:** Can a broadcast on Storage A appear on Storage B after the
correct configuration?

<details markdown="1">
<summary>Hints</summary>

- Use one Linux bridge per ToR and enslave only that ToR's data ports.
- `ip link add ... type bridge`, `ip link set ... master ...`, and `bridge link`
  expose the mechanism.
- Do not attach any `eth3` management link to a storage bridge.

</details>

<details markdown="1">
<summary>Solution</summary>

```bash
./labs/dc-storage-networking/configure-fabric.sh
```

Equivalent bridge membership is `tor1` `eth1`–`eth4` in `br-storage-a`, and
`tor2` `eth1`–`eth3` in `br-storage-b`. Management stays on
`observer:br-mgmt`.

</details>

<details markdown="1">
<summary>Check your work</summary>

```bash
./scripts/lab.sh cmd dc-storage-networking tor1 "bridge link"
./scripts/lab.sh cmd dc-storage-networking tor2 "bridge link"
./scripts/lab.sh cmd dc-storage-networking observer "bridge link"
./scripts/lab.sh cmd dc-storage-networking initiator1 \
  "vm-exec ping -c2 10.111.10.20; vm-exec ping -c2 10.111.20.20"
```

Both storage pings pass, but the bridge tables have no shared interface. That
proves separate L2 failure domains rather than two IPs on one bridge.

</details>

## Task 3 — Discover and authenticate two iSCSI sessions (hinted)

**Objective:** Discover the same target over both portals, configure CHAP, and
log in twice with the fixed initiator IQN.

**Predict first:** Will discovery prove access when the target ACL requires CHAP?

<details markdown="1">
<summary>Hints</summary>

- Work inside the guest with `vm-exec sudo iscsiadm`.
- Use SendTargets discovery against `.10.20` and `.20.20`.
- For each node record, update `authmethod`, `username`, and `password` before
  `--login`. The lab-only values are `labinitiator` / `LAB-Storage-26!`.

</details>

<details markdown="1">
<summary>Solution</summary>

```bash
./labs/dc-storage-networking/login-storage.sh
```

The helper performs the two discoveries, applies CHAP to each exact portal
record, and logs in. It never logs into an unscoped target.

</details>

<details markdown="1">
<summary>Check your work</summary>

```bash
./scripts/lab.sh cmd dc-storage-networking initiator1 \
  "vm-exec sudo iscsiadm -m session -P 1"
./scripts/lab.sh cmd dc-storage-networking target1 \
  "targetcli /iscsi/iqn.2026-07.lab.example:dc-storage/tpg1/acls ls"
```

Two `LOGGED_IN` sessions point to distinct portal/source pairs. The ACL names only
`iqn.2026-07.lab.example:initiator1`; discovery alone was not authorization.

</details>

## Task 4 — Combine paths and prove write integrity (hinted)

**Objective:** Apply a multipath policy using a TUR checker and round-robin path
selection, then write and read back a bounded payload through the map.

**Predict first:** How many SCSI disks and how many multipath maps should one LUN
produce?

<details markdown="1">
<summary>Hints</summary>

- Match `LIO-ORG` / `storage-lun`.
- Use `path_grouping_policy multibus`, `path_checker tur`, and
  `path_selector "round-robin 0"`.
- Restart `multipathd`, run `multipath -r`, and inspect `multipath -ll`.

</details>

<details markdown="1">
<summary>Solution</summary>

```bash
./labs/dc-storage-networking/configure-multipath.sh
./labs/dc-storage-networking/integrity.sh
```

</details>

<details markdown="1">
<summary>Check your work</summary>

```bash
./labs/dc-storage-networking/observe.sh
```

The guest shows two `LIO-ORG storage-lun` iSCSI disks with the same serial, one
`dm-*` map, `wp=rw`, and two `active ready running` paths. The two SHA-256 lines
from `integrity.sh` match because data was written through the map and read back,
not merely read from a prefilled file.

</details>

## Task 5 — Validate jumbo MTU hop by hop (hinted)

**Objective:** Raise every Storage A/B hop to MTU 9000 and prove the exact largest
IPv4 ICMP payload (`8972` bytes) on both paths.

**Predict first:** Why is ordinary ping insufficient evidence for jumbo storage?

<details markdown="1">
<summary>Hints</summary>

- Inspect endpoint, tap, bridge, and ToR member MTUs with `ip -d link`.
- Change the guest's `storagea`/`storageb`, its container taps/bridges, both ToRs,
  and target storage interfaces.
- An established TCP session keeps its negotiated MSS. Drain and reconnect one
  iSCSI path at a time after the MTU change so large I/O actually exercises it.
- Use `ping -M do -s 8972`; `9000 - 20 - 8 = 8972`.

</details>

<details markdown="1">
<summary>Solution</summary>

```bash
./labs/dc-storage-networking/configure-mtu.sh
```

</details>

<details markdown="1">
<summary>Check your work</summary>

```bash
./scripts/lab.sh cmd dc-storage-networking initiator1 \
  "vm-exec ping -I storagea -M do -s 8972 -c2 10.111.10.20"
./scripts/lab.sh cmd dc-storage-networking initiator1 \
  "vm-exec ping -I storageb -M do -s 8972 -c2 10.111.20.20"
```

Both exact payloads pass with DF semantics. A default 56-byte ping would prove
reachability while saying nothing about the frame size used by large I/O. The
solution also reconnects each session independently so its TCP MSS reflects the
new endpoint MTU without dropping both paths together.

</details>

## Task 6 — Protect storage during contention (hinted)

**Objective:** Create a bounded 20 Mb/s egress scheduler on the Storage A
initiator-facing port, give traffic to `10.111.10.10` a 15 Mb/s minimum, and keep
the default background class at 5 Mb/s.

**Predict first:** Does this configuration make the Ethernet fabric lossless?

<details markdown="1">
<summary>Hints</summary>

- Use HTB classes on `tor1:eth1`; classify by the storage destination address.
- Observe `tc -s class`, not just the configuration.
- This is priority/minimum-bandwidth scheduling, not PFC, ECN, or DCB.

</details>

<details markdown="1">
<summary>Solution</summary>

```bash
./labs/dc-storage-networking/configure-qos.sh
./labs/dc-storage-networking/contention.sh
```

</details>

<details markdown="1">
<summary>Check your work</summary>

`contention.sh` offers 40 Mb/s of background traffic and prints
`storage_ms=... threshold_ms=10000`. The storage read stays below the declared
10-second lab threshold and class `1:10` counters increase. This proves the Linux
scheduler policy used here; it does not prove lossless Ethernet or ASIC behavior.

</details>

## Task 7 — Drain a path for maintenance (open)

**Objective:** Remove either Storage A or B from service, prove bounded I/O and
remaining redundancy/capacity before maintenance, restore the path, and document
your rollback triggers. Do not inspect the solution scripts.

**Predict first:** Which state—TCP session, SCSI path, or application checksum—
should authorize the maintenance window?

<details markdown="1">
<summary>Hints</summary>

- Start with `observe.sh`, fail only one ToR initiator-facing port, and keep a
  bounded integrity read/write running.
- Restore the link and wait for two `active ready running` paths.
- Treat `target2` only as a cold-spare reachability/capacity endpoint; it is not a
  second controller for the same LUN.

</details>

<details markdown="1">
<summary>Solution</summary>

```bash
./scripts/lab.sh cmd dc-storage-networking tor1 "ip link set eth1 down"
timeout 25 ./labs/dc-storage-networking/integrity.sh
./scripts/lab.sh cmd dc-storage-networking tor1 "ip link set eth1 up"
./labs/dc-storage-networking/observe.sh
```

Repeat with `tor2:eth1`. Roll back if the surviving path is not `ready`, the
bounded integrity check fails, or the second path does not restore without a
duplicate SCSI device.

</details>

<details markdown="1">
<summary>Check your work</summary>

The integrity hash remains equal during either single-path outage. After restore,
there are exactly two iSCSI disks, one multipath map, and two ready paths. Session
state alone is insufficient: an established TCP session can coexist with failed
large I/O.

</details>

## Task 8 — Break-It: ping works, direct I/O stalls

**Objective:** Diagnose a case where Storage A sessions and small ping remain
healthy, but jumbo probes and direct large I/O fail. Repair only the mismatched
hop and prove data integrity.

**Predict first:** Which observation will distinguish MTU from CHAP, discovery,
and target-LUN faults?

```bash
./labs/dc-storage-networking/break-it.sh
```

Begin from symptoms:

```bash
./labs/dc-storage-networking/check.sh --break-it
./scripts/lab.sh cmd dc-storage-networking initiator1 \
  "vm-exec sudo iscsiadm -m session -P 1"
./scripts/lab.sh cmd dc-storage-networking tor1 "ip -d link show eth2"
./scripts/lab.sh cmd dc-storage-networking tor1 \
  "timeout 8 tcpdump -ni eth1 -c1 'icmp and greater 1500'"
```

<details markdown="1">
<summary>Hints</summary>

- Compare small ping with `ping -M do -s 8972`.
- Compare MTU on both ToR member ports and both endpoints.
- A healthy Storage B path does not make an MTU black hole on path A acceptable.
  Separate session, path, and application health, and keep recovery-time
  objectives in mind.

</details>

<details markdown="1">
<summary>Solution</summary>

```bash
./labs/dc-storage-networking/repair-break-it.sh
./labs/dc-storage-networking/integrity.sh
./labs/dc-storage-networking/check.sh
```

</details>

<details markdown="1">
<summary>Check your work</summary>

The injected difference is only `tor1:eth2` at MTU 1500. After it returns to 9000,
the 8972-byte probe passes, both direct paths are ready, the map has no stale or
duplicate device, and write/read hashes match. Repairing CHAP or relogging sessions
would not correct an intermediate MTU.

</details>

## Task 9 — Trace FC and RoCE evidence (open)

**Objective:** Use the synthetic, reduced fixtures to identify the FC zoning fault
domain and the RoCE congestion fault domain, then name the next safe read-only
validation step without claiming hardware was emulated.

```bash
less labs/fixtures/dc-storage-networking/fc-login-zoning.txt
less labs/fixtures/dc-storage-networking/roce-congestion.txt
```

<details markdown="1">
<summary>Hints</summary>

- FC: follow WWPN → FCID → VSAN → zone → active zone set.
- RoCE: compare queue depth, ECN marks, pause time, CNPs, and p99 latency by
  interval. Correlation does not prove ASIC causality.

</details>

<details markdown="1">
<summary>Solution</summary>

The expected deductions and alternative explanations are recorded in the fixture
`MANIFEST.md`. Review it only after writing your own incident note.

</details>

<details markdown="1">
<summary>Check your work</summary>

Your note must keep these mechanisms at evidence level 1, identify at least one
alternative explanation, and recommend a read-only validation before any zoning
or PFC change. A synthetic counter sequence is not live fabric telemetry.

</details>

## Verification

From the completed healthy state:

```bash
./labs/dc-storage-networking/check.sh
```

It asserts segmentation, CHAP ACL scope, two sessions, one two-path map, writable
lab-only backing, checksum integrity, either-path failure/recovery, exact MTU,
management denial, bounded scheduler latency, and no duplicate SCSI state.

## Challenge questions

1. If both paths share one upstream power domain, which result in this lab would
   overstate production redundancy?
2. Rank session state, path-checker state, latency, and application checksum as
   maintenance gates, and justify the ordering.
3. How would asymmetric MTU affect writes differently from reads when TCP offload
   and application I/O sizes vary?
4. Which production evidence would you require before enabling PFC for RoCE, and
   what pause-storm rollback trigger would you define?
5. When should a cold-spare target become a shared-controller design, and which
   reservation/fencing tests become mandatory?

## Troubleshooting

| Symptom | Likely cause | Safe fix |
|---|---|---|
| KVM guest never becomes ready | `/dev/kvm` absent or non-amd64 host | Use the stated Linux/amd64 KVM prerequisite; do not fall back to host `iscsid` |
| Discovery works but login fails | CHAP node record or initiator IQN mismatch | Compare the exact ACL/IQN and update the portal-specific node auth |
| Two disks, no multipath map | policy not installed or `multipathd` not restarted | Apply the LIO device stanza, restart, and rescan |
| `wp=ro` | target demo-mode write protection remains enabled | Verify `demo_mode_write_protect=0` before writing |
| Small ping works, jumbo fails | one hop still MTU 1500 | inspect every endpoint/tap/bridge/member; repair only the mismatch |
| Session is logged in but direct I/O stalls | path transport/MTU failure hidden by TCP state | inspect `multipath -ll`, exact jumbo probes, and bounded direct-path I/O |
| Destroy reports a residual target | scoped cleanup was interrupted | rerun `destroy.sh`; never use broad Docker or configfs cleanup |

## Cleanup

```bash
./labs/dc-storage-networking/destroy.sh
```

The wrapper logs out the exact IQN, flushes the guest map, removes only the
`storage-lun` LIO object and sparse file, destroys only this topology, and fails
if its containers or target remain.
