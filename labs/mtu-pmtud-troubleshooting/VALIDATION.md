# Validation Record — `mtu-pmtud-troubleshooting`

## Status

**Passed — clean target walk, negative fault test, repair, repository gates,
and scoped cleanup completed by the main validator on 2026-07-31.**

The requested `lab-tutor` skill was unavailable. No tutor validation is
claimed; this record is based on the main validator's live walk and review
against `labs/AUTHORING.md`.

## Environment

| Item | Validated value |
|------|-----------------|
| Owner and date | Codex main validator, 2026-07-31 |
| Host | Linux `5.15.0-181-generic`, x86_64 |
| ContainerLab | `0.74.1`, commit `1866b3a2b` |
| Docker | client/server `29.5.3` |
| VyOS image | `vyos:local`, ID `sha256:74835bd5057d274fe0c8761c42e7a30a7a7e06aa8e2ccd050c0da82af3213495` |
| VyOS runtime | `2026.03.15-0031-rolling`; build UUID `d26b303c-df41-45ac-831e-3ebc174a407b`; commit `96ff51d3d2e559` |
| Linux tooling image | `ops-lab:local`, ID `sha256:f21d6ee3c25e92a74f0c16206c9e55f6bdbcc1c51d0f817e64c51074a22034f7` |
| Linux base | Alpine 3.20 at `sha256:d9e853e87e55526f6b2917df91a2115c36dd7c696a35be12163d44e6e2a4b6bc` |
| Repository state | branch `codex/networking-lab-remediation`; validation worktree based on `d8d17d25add4fc7b3bdc4a62f69f13248ca2dc7c` |

## Clean deployment and initial state

Two scoped deployments were used. The first complete learner walk deployed
in 20.97 seconds. After issues found during validation were corrected, a
second cold deployment of the final files completed in 19.46 seconds.

The final cold deployment and an explicit second execution of every Linux
setup script established:

- exactly five nodes and no concurrent lab;
- one provider feedback-drop rule after repeated setup;
- exactly one shared service process on each endpoint after repeated setup;
- both VyOS `tun0` interfaces UP at their default operational MTU 1476 with
  no explicit tunnel-MTU configuration line;
- exact site, transport, and overlay addresses and static routes;
- site and VyOS physical interfaces at MTU 1500 and both provider data
  interfaces at MTU 1400;
- IPv4 forwarding enabled on the provider; and
- the mounted Break-It injector readable by VyOS `admin`.

## Starting symptom and packet boundary

The untouched starting state produced the intended incident:

| Observation | Live result |
|-------------|-------------|
| Small ping A-to-B | 3/3 replies, 0% loss |
| Small ping B-to-A | 3/3 replies, 0% loss |
| UDP/9999 and TCP/8080 listeners | Present on `host-b`; UDP/9999 also present on `host-a` |
| Bounded 262,144-byte HTTP command | Python read timed out and the command exited non-zero |
| A-to-B DF UDP payload 1348 | `ack:1348`, exit 0 |
| A-to-B DF UDP payload 1349 | `TIMEOUT payload=1349 destination=192.168.2.10`, exit 3 |
| `edge-a:eth2` capture for 1349 | Outer IPv4 GRE length 1401, DF set; inner IPv4 length 1377; UDP length 1349 |
| `provider:eth1` capture for 1349 | Same outer/inner packet and flags |
| `host-a:eth1` type 3/code 4 capture | Zero packets during the bounded starting-state capture |
| Provider rule counter | Increased by exactly one for a fresh failing probe |

The simultaneous capture processes were started and reaped by one bounded
host-side orchestration command. Earlier experimental capture launches were
discarded with the first topology and are not used as final cleanup evidence.

## Native repair and PMTUD proof

The learner-visible CLI sequence was executed interactively on both VyOS
edges:

```text
configure
set interfaces tunnel tun0 mtu 1376
commit
save
exit
```

Each edge then had exactly one configured `tun0` MTU line and operational MTU
1376. After flushing host route state, a fresh A-to-B payload 1349 probe
returned:

```text
EMSGSIZE payload=1349 destination=192.168.2.10
```

The simultaneous host capture contained:

```text
192.168.1.1 > 192.168.1.10: ICMP 192.168.2.10 unreachable - need to frag (mtu 1376)
```

Both payload 1348 directions returned `ack:1348`, the bounded HTTP request
returned exactly `262144`, and the provider drop counter stayed unchanged
during the final positive probe set.

## Checker, fault, and repair cycle

| Stage | Result |
|-------|--------|
| Solved-state checker run 1 | 79 passed, 0 failed |
| Solved-state checker run 2 | 79 passed, 0 failed |
| Break-It execution twice | Both runs exited 0; edge-b remained configured and operational at MTU 1300 |
| Direct broken-state A-to-B 1348 | `ack:1348`, exit 0 |
| Direct broken-state B-to-A 1348 | `EMSGSIZE payload=1348 destination=192.168.1.10`, exit 2 |
| Broken-state checker | 75 passed, 4 failed; only edge-b configured MTU, edge-b operational MTU, and the two B-to-A acknowledgement assertions failed |
| Minimal repair | Restored only edge-b `tun0` MTU 1376, committed/saved, then flushed host-b route state |
| Repaired direct B-to-A 1348 | `ack:1348`, exit 0 |
| Repaired checker | 79 passed, 0 failed |

The checker owns its bounded capture as a host-side child, waits/reaps it,
allows the minimal BusyBox `timeout` wrapper settle interval, removes its
temporary file, and finishes with no active capture or probe process on any
Linux node.

## Resource sample

The final solved-state snapshot was:

| Node | Memory |
|------|--------|
| `edge-a` | 258.1 MiB |
| `edge-b` | 258.2 MiB |
| `host-a` | 10.54 MiB |
| `host-b` | 10.48 MiB |
| `provider` | 676 KiB |

The sampled aggregate was approximately 538 MiB, well within the 16 GB host
budget. This is a point-in-time `docker stats --no-stream` sample, not a
long-duration high-water measurement.

## Repository gates

| Command | Result |
|---------|--------|
| Target `bash -n` | Passed |
| Target ShellCheck at warning severity | Passed |
| Python AST syntax for both helpers | Passed |
| Topology YAML parse | Passed |
| `python3 scripts/check-markdown-spacing.py` | Passed |
| `./scripts/check-docs-admonitions.sh` | Passed |
| `python3 scripts/lint-labs.py` | Passed: 143 labs, 52 images |
| `python3 scripts/validate-quizzes.py` | Passed: 44 quiz/key pairs |
| `python3 scripts/test-validate-quizzes.py` | Passed: 7 regression cases |
| `git diff --check` | Passed |
| `mkdocs build --strict` | Passed |
| Repository-wide ShellCheck at error severity | Passed |

An additional repository-wide ShellCheck run at warning severity reported
only existing warnings in unrelated `enterprise-it-101`,
`enterprise-grand-capstone`, and `troubleshooting-range` scripts. It reported
no warning in this target. Those unrelated files were not changed.

## Cleanup and platform boundary

The final topology was destroyed through `./scripts/lab.sh destroy
mtu-pmtud-troubleshooting`. No containers, generated target directory, or
`clab` Docker network remained.

The tested VyOS image reports an unhealthy Docker health state and prints a
boot-configuration warning on entry to configuration mode. Container logs
trace it to the image's missing `/boot/grub/grub.cfg` during a system-option
reset. This existing container-image quirk is documented in
`docs/platforms/vyos.md`; it did not prevent the startup configuration,
native MTU commits/saves, routing, GRE forwarding, or every live assertion
above. Other VyOS builds remain outside this validation boundary.
