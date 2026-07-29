# Feature Probe Record — `network-gitops-change-pipeline`

## Scope and decision

- **Feature and learning objective:** prove structured cEOS state retrieval,
  idempotent eAPI change, a bounded config-session commit, deterministic
  partial-push detection, and snapshot-based rollback before building the
  three-device change pipeline.
- **Decision:** go; no fallback or rename.
- **Reason and fidelity statement:** cEOS 4.35.2F accepts named configuration
  sessions through eAPI and returns structured interface/route/session JSON.
  A committed session is not itself a rollback point on this image, so the
  documented pipeline design takes an explicit running-config snapshot and uses
  `configure replace` for rollback. That is real cEOS replace behavior, not a
  mocked transaction.
- **Owner and date:** Codex, 2026-07-28.

## Environment

| Item | Exact value |
|---|---|
| Host OS/kernel | Linux `5.15.0-181-generic`, x86_64 |
| ContainerLab | `0.74.1`, commit `1866b3a2b` |
| Docker | client/server `29.5.3` |
| Git / Python | Git `2.34.1`; Python `3.10.12` |
| cEOS | `ceos:4.35.2F`, image ID `sha256:f27a0e7dba17e46a755e41b6914ca5644dc2cd03570252f273b7fc76e8ba73ca`, 2,562,840,665 bytes |
| Reported NOS | cEOSLab `4.35.2F-46221466.4352F (engineering build)` |
| Planned tools base | `python:3.12.7-alpine3.20@sha256:5049c050bdc68575a10bcb1885baa0689b6c15152d8a56a7e399fb49f783bf98` |
| Host before probe | 15 GiB RAM, 13 GiB available, 0 B swap used; 139 GiB disk available |

No unrelated container or `clab-*` network was active before the probe.

## Smallest load-bearing test

The disposable topology in `probe/` uses two cEOS nodes and one `/30`. Both
nodes enable lab-only HTTP eAPI on an isolated `172.31.212.0/24` management
network. The exact run was:

```bash
/usr/bin/time -v containerlab deploy \
  -t labs/network-gitops-change-pipeline/probe/topology.clab.yml
python3 labs/network-gitops-change-pipeline/probe/probe.py
docker stats --no-stream \
  clab-network-gitops-probe-probe1 clab-network-gitops-probe-probe2
containerlab destroy \
  -t labs/network-gitops-change-pipeline/probe/topology.clab.yml --cleanup
```

ContainerLab deployed in 28.11 seconds with 42,800 KiB maximum host-process
RSS. eAPI became ready on the fourth bounded attempt. Relevant output:

```text
probe1: version=4.35.2F-46221466.4352F (engineering build); structured_state=connected
probe2: version=4.35.2F-46221466.4352F (engineering build); structured_state=connected
probe1 apply: one semantic change
probe2 rejected: CLI command 4 of 5 'ip address 10.999.1.1/30' failed: invalid command
partial_push_detected=true
rollback_description=''
idempotency first: one semantic change
idempotency second: zero changes
probe_result=PASS
```

The Python eAPI driver completed in 3.13 seconds with 18,396 KiB maximum RSS.
Steady container memory immediately afterward was 1.175 GiB for `probe1` and
1.155 GiB for `probe2` (2.330 GiB total). Structured `show interfaces
Ethernet1` returned `forwardingModel`, line/interface state, primary address,
MTU, counters, and rates without display-text scraping.

Named-session behavior was also inspected directly:

```text
Maximum number of completed sessions: 1
Maximum number of pending sessions: 5
Merge on commit is disabled
Autosave to startup-config on commit is disabled
```

`copy running-config flash:probe-baseline.cfg` returned `Copy completed
successfully.` After a committed change,
`configure replace flash:probe-baseline.cfg` restored the empty interface
description. A second idempotent apply issued zero configuration commands.

## Optional Batfish decision

`docker image inspect batfish/allinone` returned `No such image:
batfish/allinone:latest`. No repository-pinned Batfish image or existing package
contract is available. Pulling a floating optional image would violate the image
policy, while explicit schema, prefix/policy, management-plane, structured-route,
and real service-path tests cover this package's pre-change objective. Batfish is
therefore excluded; the lab makes no Batfish or model-wide reachability claim.

## Cleanup and repeatability

The first scoped destroy removed both probe containers, its management network,
host entries, SSH fragment, and lab directory. A clean redeploy reported an empty
Ethernet1 description and:

```text
snapshot_after_redeploy=absent
```

This proves flash snapshots survive only inside the current disposable cEOS
container and are intentionally lost at scoped destroy. The final
`containerlab destroy ... --cleanup` left zero matching containers, networks,
or generated lab directories.

## Unsupported behavior and limitations

- EOS config sessions supply candidate isolation and an auditable commit record,
  but this image retains only one completed session and does not expose a direct
  rollback command for an already committed session. The lab uses explicit
  pre-change snapshots plus `configure replace`.
- Committed sessions do not autosave startup-config. The lab intentionally keeps
  changes session-scoped and disposable; persistence across lab destroys is not
  claimed.
- An unknown interface can be accepted with a warning for future hardware.
  Therefore the partial-push fixture uses stale capability data that produces an
  invalid address command, which cEOS rejects before commit.
- eAPI uses obvious lab-only `admin/admin` over isolated HTTP. No production
  transport-security or secret-management claim is made.
