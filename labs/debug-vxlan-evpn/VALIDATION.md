# Validation Record — `debug-vxlan-evpn`

Status: **validated by the main agent on amd64**

## Environment

| Item | Exact value |
|---|---|
| Date and owner | 2026-08-06, main Codex agent |
| Host OS/kernel | Ubuntu 22.04, `5.15.0-181-generic`, x86_64 |
| ContainerLab/Docker versions | ContainerLab `0.74.1` (`1866b3a2b`); Docker client/server `29.5.3` |
| Network image | Licensed local `ceos:4.35.2F`, image ID `sha256:f27a0e7dba17e46a755e41b6914ca5644dc2cd03570252f273b7fc76e8ba73ca`, amd64 |
| Incidental host image | `ops-lab:local`, image ID `sha256:f21d6ee3c25e92a74f0c16206c9e55f6bdbcc1c51d0f817e64c51074a22034f7`, amd64 |
| Repository base | `c95e61d1ea799940d9d3c719401548a11525a720` before the uncommitted lab implementation |

## Clean run

| Stage | Command/result | Time | Memory |
|---|---|---:|---:|
| Deploy | `./scripts/lab.sh deploy debug-vxlan-evpn`: exactly three cEOS network nodes and two Linux hosts started cleanly | OSPF and EVPN converged in approximately 45 s | See snapshot below |
| Incident evidence | OSPF, Lo0 reachability, and all three EVPN peerings remained healthy; the intended endpoint traffic failed | Not separately captured | No second snapshot |
| Minimal repair/check | `solution.sh`; solved checker returned `44 passed, 0 failed` | Not separately captured | No second snapshot |
| Repeat fault | `break.sh` succeeded twice; each broken check returned exactly `37 passed, 7 failed` | Not separately captured | No second snapshot |
| Repeat repair/check | `solution.sh` succeeded twice; final checker returned `44 passed, 0 failed` | Not separately captured | No second snapshot |
| Destroy/cleanup | Lab destroy succeeded; no matching container, network, or generated lab artifact remained | Not separately captured | Zero lab runtime resources |

No unmeasured stage duration is represented as exact. The point-in-time
no-stream memory snapshot was:

| Container | Memory |
|---|---:|
| spine | 1.209 GiB |
| vtep1 | 1.255 GiB |
| vtep2 | 1.269 GiB |
| host1 | 636 KiB |
| host2 | 632 KiB |

The sampled total was approximately 3.73 GiB.

## Positive and negative evidence

Positive solved-state evidence:

- `spine`, `vtep1`, and `vtep2` ran the exact `ceos:4.35.2F` tag; only
  `host1` and `host2` used the incidental `ops-lab:local` image.
- The spine had exactly two Full OSPF adjacencies; each VTEP had exactly one.
  The documented VTEP Loopback0 addresses were mutually reachable.
- The spine had exactly two Established EVPN peers; each VTEP had exactly one
  Established peer to the spine.
- In solved state, native Vxlan1 used Loopback0, VLAN 100 mapped to VNI 100,
  remote IMET and Type-2 evidence installed against `10.0.0.2`, and endpoint
  ping succeeded in both directions.
- The solved checker reported `44 passed, 0 failed` before and after the
  repeatable fault/repair lifecycle.

Negative incident evidence:

- Running `break.sh` twice returned success both times. The broken checker
  consistently reported `37 passed, 7 failed`.
- The exact affected assertions were: `vtep2` VXLAN source was not Loopback0;
  `vtep1` had no remote VTEP `10.0.0.2`, remote IMET next hop `10.0.0.2`,
  host2 Type-2 route, or host2 MAC-to-VTEP binding; and both endpoint pings
  failed.
- Every inventory, image, host address/MAC/link, access VLAN, OSPF adjacency,
  Lo0 reachability, and EVPN peer assertion remained green while broken.
- The spine received the `vtep2` EVPN route with forwarding identity
  `10.0.0.22`. `vtep1` had no underlay route to `10.0.0.22`, so it rejected
  that remote EVPN state.
- A bounded underlay capture recorded exactly three one-way packets from
  `10.0.0.22` to `10.0.0.1`, UDP destination port 4789, VNI 100, during a
  failed three-packet endpoint ping. No reverse VXLAN packet was observed.
- Running `solution.sh` twice returned success both times and restored the
  final `44/44` checker result.

## Repository gates

The following gates were run after the live walk and documentation-link fix:

```text
bash -n labs/debug-vxlan-evpn/{check,break,solution}.sh
sh -n labs/debug-vxlan-evpn/configs/host{1,2}/setup.sh
shellcheck -x labs/debug-vxlan-evpn/{check,break,solution}.sh \
  labs/debug-vxlan-evpn/configs/host{1,2}/setup.sh
  PASS

python3 scripts/check-markdown-spacing.py
  PASS

./scripts/check-docs-admonitions.sh
  PASS

python3 scripts/lint-labs.py
  PASS: 143 labs

python3 scripts/validate-quizzes.py
  PASS: 44 quiz/key pairs

git diff --check
  PASS

mkdocs build --strict
  PASS after correcting the paired build-lab link to its published wrapper
```

## Limitations, refresh, and cleanup

- The local amd64 cEOS image and exact canonical tag were exercised live.
  The arm64 mapping was not live-tested, so no arm64 validation claim is made.
- cEOS is a licensed local prerequisite. The image identity and version are
  recorded, but no vulnerability scanner or advisory-refresh claim is made.
- The `lab-tutor` skill was unavailable, so no tutor-validation claim is made.
- The memory figures are one no-stream sample, not capacity guidance.
- The lab does not validate physical ASIC forwarding, hardware counters,
  production scale, IPv6 VXLAN, EVPN multihoming, or failure convergence.
- Final cleanup found no `clab-debug-vxlan-evpn-*` container, lab Docker
  network, or generated lab directory. The reusable local images remain by
  design.
