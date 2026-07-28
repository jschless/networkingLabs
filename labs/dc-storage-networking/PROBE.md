# Feature Probe Record — `dc-storage-networking`

## Scope and decision

- **Feature and learning objective:** prove two independent iSCSI/TCP sessions to
  one synthetic LIO LUN, Linux device-mapper multipath, deterministic single-path
  failure/recovery, and bounded exact-MTU failure without exposing a host disk.
- **Decision:** **Go with a safety-preserving KVM initiator and the documented
  Linux bridge/`tc` ToR fallback. No rename required.**
- **Reason and fidelity statement:** Ubuntu's kernel iSCSI control path on this
  host cannot create a session from a container network namespace
  (`iscsid: sendmsg: bug? ctrl_fd 4`). The initiator therefore runs in a 768 MiB
  KVM guest with its own kernel and only a disposable OS disk plus the synthetic
  LUN. Real LIO, iSCSI, SCSI, device-mapper, MTU, and failover behavior remains
  live. WP-11 explicitly authorizes Linux bridges when cEOS cannot supply the
  required storage/QoS data plane. The same host/image's WP-09 probe records that
  cEOSLab 4.35.2F has no hardware egress scheduler, so Linux HTB is used and no
  lossless/ASIC claim is retained.
- **Owner and date:** WP-11 / Codex, 2026-07-27.

## Environment

| Item | Exact value |
|---|---|
| Host OS/kernel | Ubuntu 22.04.5 LTS; `5.15.0-181-generic` x86_64 |
| ContainerLab version | `0.74.1` commit `1866b3a2b` |
| Docker version | client/server `29.5.3`; overlay2; cgroup v2 |
| Local tools image | `dc-storage-tools:1.0.0`, image ID `sha256:f9b6d68d09eff2682300db097c20b191ad84464d8fa0c89252401a2ed91755ad`, 1,007,658,040 bytes |
| External bases | Ubuntu `24.04@sha256:4fbb8e6a8395de5a7550b33509421a2bafbc0aab6c06ba2cef9ebffbc7092d90`; Ubuntu Noble cloud image `20260725` SHA-256 `d1940f7d69d343355e183dff1e08a59852d32e7309baa7a4bad8365b11b005ac` |
| Storage stack | targetcli-fb `2.1.53-1ubuntu3`; open-iscsi `2.1.9-3ubuntu5.4`; multipath-tools `0.9.4-5ubuntu8.2`; guest kernel `6.8.0-136-generic` |
| Virtualization/workload | QEMU `8.2.2+ds-0ubuntu1.17`; fio `3.36-1ubuntu0.1` |
| Host before probe | 15 GiB RAM, 13 GiB available; 142 GiB disk available; no running containers |

## Smallest load-bearing test

The disposable two-node topology is under `probe/`. One target exposes a 128 MiB
sparse file over two direct 9000-MTU links. The initiator container bridges those
links into a pinned Ubuntu KVM guest and provides an isolated management link.

```text
$ /usr/bin/time -v labs/dc-storage-networking/probe/probe.sh
Login ... portal: 10.111.10.20,3260] successful.
Login ... portal: 10.111.20.20,3260] successful.
Iface IPaddress: 10.111.10.10 ... SID: 1 ... LOGGED_IN
Iface IPaddress: 10.111.20.10 ... SID: 2 ... LOGGED_IN
36001405... dm-0 LIO-ORG,storage-lun
|- ... sda ... active ready running
`- ... sdb ... active ready running
8980 bytes from 10.111.10.20
... sda ... failed faulty running
... sdb ... active ready running
[MTU 1500] 1 packets transmitted, 0 received, 100% packet loss
[MTU 9000] 8980 bytes from 10.111.10.20
clab-dc-storage-probe-initiator 734.8MiB / 15.37GiB
clab-dc-storage-probe-target 3.559MiB / 15.37GiB
PROBE PASS: two sessions, multipath failover, exact MTU failure/recovery
Elapsed (wall clock): 1:23.02
Maximum resident set size (probe runner): 52784 KiB
```

The probe wrote/read a bounded 8 MiB region through the isolated map and compared
SHA-256 data before and after a path failure. The final lab additionally disables
LIO demo-mode write protection and asserts `wp=rw`.

## Failed boundary probe and honest resolution

The first container-only attempt loaded the host's `iscsi_tcp` module and reached
both portals, but kernel session creation from the container network namespace
failed:

```text
iscsid: connected local port ... to 10.111.10.20:3260
iscsid: sendmsg: bug? ctrl_fd 4
iscsiadm: read error (0/2), daemon died?
```

Using host networking or mounting host block devices would weaken the required
safety boundary, so neither was retained. KVM was already available at `/dev/kvm`
and gives the storage initiator a separate kernel/device namespace without
changing the learning objective.

Ubuntu targetcli also required the exact host `/lib/modules` read-only bind and a
minimal system D-Bus. Both are explicit in the topology; the target scripts name
only the lab IQN, `storage-lun`, and `/var/lib/storage/lun.img`.

## Cleanup and repeatability

- **Destroy/cleanup command:** probe trap logs out only
  `iqn.2026-07.lab.example:dc-storage`, flushes the guest map, deletes only that
  target and `storage-lun`, then runs
  `containerlab destroy --topo probe/topology.clab.yml --cleanup`.
- **Artifacts checked:** `clab-dc-storage-probe-*` containers, the exact configfs
  IQN, fileio object, iSCSI sessions, and device-mapper map.
- **Result:** no probe containers, target, session, map, or backing file remained.
  The final successful run started after the exact same clean checks, so the
  probe is repeatable.

## Unsupported behavior and fallback

The probe does not prove Fibre Channel/FCoE, array controllers, SCSI
reservations/fencing, FIP, PFC/ECN/DCQCN, ASIC queue buffers, or RoCE. Linux HTB
is a real bounded scheduler, not lossless Ethernet. Those exclusions are carried
into the README, validation record, coverage entries, and evidence manifest.
