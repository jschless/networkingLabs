# Validation Record — `dc-storage-networking`

## Environment

| Item | Exact value |
|---|---|
| Date and owner | 2026-07-27, WP-11 / Codex |
| Host OS/kernel | Ubuntu 22.04.5 LTS, `5.15.0-181-generic` x86_64, `/dev/kvm` available |
| ContainerLab/Docker versions | ContainerLab `0.74.1` (`1866b3a2b`); Docker `29.5.3` |
| Local image | `dc-storage-tools:1.0.0`; `sha256:f9b6d68d09eff2682300db097c20b191ad84464d8fa0c89252401a2ed91755ad`; 1,007,658,040 bytes |
| Pinned bases | Ubuntu `24.04@sha256:4fbb8e6a8395de5a7550b33509421a2bafbc0aab6c06ba2cef9ebffbc7092d90`; Noble cloud image `20260725`, SHA-256 `d1940f7d69d343355e183dff1e08a59852d32e7309baa7a4bad8365b11b005ac` |
| Storage versions | targetcli-fb `2.1.53-1ubuntu3`; guest kernel `6.8.0-136-generic`; open-iscsi `2.1.9-3ubuntu5.4`; multipath-tools `0.9.4-5ubuntu8.2` |
| Repository base | `dfee8b3ed63b0a14cc2fa81ca853468feade410a` (`origin/main`) |

## Clean live walk

The walk started with no `clab-dc-storage-networking-*` containers, lab network,
configfs target, guest session/map, backing file, or generated lab directory.

| Stage | Command/result | Wall time | Runtime memory |
|---|---|---:|---:|
| Build/probe | `probe/probe.sh`: two sessions, one two-path map, path failure/recovery, exact 8972-byte MTU failure/recovery; cleanup passed | 1:23.02 | initiator 734.8 MiB; target 3.559 MiB |
| First deploy/readiness | `./scripts/lab.sh deploy dc-storage-networking`: seven nodes ready; initial state had zero sessions/maps and a zero-block sparse LUN | 0:51.94 | approximately 735 MiB total |
| Student path | Ran Tasks 2–6 in order without reading solution source; two SHA-256 values matched | 0:07.97 | no material increase |
| Healthy check | `./labs/dc-storage-networking/check.sh`: `32 passed, 0 failed` | 0:58.76 | checker maximum RSS 29,960 KiB |
| Break-It failure | `break-it.sh` set only `tor1:eth2` to MTU 1500; `check.sh --break-it`: small ping and both sessions remained healthy, exact 8972-byte payload failed, a direct 8 MiB read remained blocked for five seconds, mismatch identified; the checker aborted only its disposable read by recycling path A and left the fault present; `5 passed, 0 failed` | 0:11.39 | checker maximum RSS 29,944 KiB |
| Minimal repair/check | `repair-break-it.sh` restored only `tor1:eth2` to MTU 9000; full check: `32 passed, 0 failed` | 0:58.05 | checker maximum RSS 30,012 KiB |
| First destroy | `destroy.sh`: scoped target/session/map/container cleanup passed | 0:03.32 | no lab processes |
| Redeploy | Clean redeploy started with guest MTU 1500, no sessions/map, policy isolation present, and zero allocated LUN blocks | 0:51.85 | approximately 748 MiB total |
| Repeat solution/check | `solution.sh` produced matching SHA-256 values; full check: `32 passed, 0 failed` | 0:08.43 + 0:57.92 | peak observed 737.7 MiB initiator; other six containers total 9.9 MiB |
| Final bounded-fault rerun | Clean deployment suppressed the lab-only CHAP value from deploy output; MTU configuration drained/reconnected one path at a time so TCP MSS reflected 9000; Break-It `5/0`, one-interface repair, full check `32/0` | check 1:04.83 | checker maximum RSS 30,076 KiB |
| Final destroy | `destroy.sh`: scoped cleanup passed; the prior timed cleanup was 0:03.17 | under 4 s | zero lab runtime resources |

The 256 MiB LUN remained sparse: before login it had zero allocated blocks; after
two live walks it used 16,384 × 512-byte blocks (8 MiB physical). The KVM
initiator had a fixed 768 MiB guest RAM allocation. All test reads/writes were
bounded to an 8 MiB region on `/dev/mapper/<lab-map>`.

## Positive and negative evidence

- Two CHAP-authenticated portals produced two iSCSI sessions, exactly two SCSI
  paths with one serial, and one writable `LIO-ORG,storage-lun` multipath map.
- Raw 8 MiB write/read SHA-256 integrity passed. Either ToR initiator link could
  be failed and restored while bounded I/O remained intact; recovery left two
  ready paths and no duplicate SCSI device.
- Exact DF payload `8972` passed on Storage A and B. During Break-It, ordinary
  ping and session state still passed while the exact jumbo probe failed and a
  direct 8 MiB path-A read stalled; the only mismatch was `tor1:eth2` at MTU
  1500. The checker bounded and aborted its own read by recycling only path A,
  then left the MTU fault in place for diagnosis.
- The background endpoint and source-bound storage address could not enter the
  management segment. The observer could reach the cold-spare management
  endpoint.
- Linux HTB kept the bounded read under the declared 10-second threshold while
  its storage class counter increased. This is scheduler evidence, not a
  lossless-Ethernet claim.
- LIO exposed only `/var/lib/storage/lun.img`, used the named initiator ACL, and
  showed no loop, host disk, NVMe, or device-backed LUN.
- Reduced synthetic FC and RoCE evidence is checksummed in
  `labs/fixtures/dc-storage-networking/MANIFEST.md`; it is coverage level 1, not
  emulation evidence.

## Repository gates

Run from the repository root after the live walk:

```text
python3 scripts/lint-labs.py
  OK: 139 labs checked, 49 local images referenced

./scripts/check-docs-admonitions.sh
  OK

mkdocs build --strict
  PASS

shellcheck -S warning scripts/*.sh labs/*/check.sh
  PASS

./scripts/test-enterprise-coverage-validator.sh
  PASS: valid fixture and repository accepted; every negative fixture rejected
```

## Limitations, refresh, and cleanup

- The lab does not emulate FC/FCoE, array controllers, SCSI fencing/reservations,
  FIP, PFC, ECN/DCQCN, RoCE, ASIC queues, or shared-controller failover.
  `target2` is a cold-spare endpoint, not a second controller for the same LUN.
- The Linux bridge/HTB fallback and KVM initiator decision are recorded in
  `PROBE.md`. The container-only kernel-iSCSI boundary failed honestly; host
  networking and host disk mounts were not used.
- The image was rebuilt on 2026-07-27 from a digest-pinned Ubuntu base using the
  dated, checksummed 2026-07-25 Noble cloud image and then exercised live. No
  Trivy or Docker Scout scanner was installed, so this is a freshness review,
  not a vulnerability-scan claim.
- Both cleanup walks removed the exact IQN, multipath/session state, backing file,
  seven containers, network attachment, and generated runtime directory.
  Final inspection found no `clab-dc-storage-networking-*` container, lab
  network, configfs target, or generated directory. The reusable
  `dc-storage-tools:1.0.0` image remains by design.
- No unsupported behavior is represented as complete. Hardware FC/RoCE practice
  remains an external-platform follow-up.
