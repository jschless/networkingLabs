# Validation Record — `ot-zone-conduit`

## Environment

| Item | Exact value |
|---|---|
| Date and owner | 2026-07-27, Codex |
| Host OS/kernel | Linux `5.15.0-181-generic`, x86_64 |
| ContainerLab/Docker | ContainerLab `0.74.1` (`1866b3a2b`); Docker client/server `29.5.3` |
| Base image | `ubuntu:24.04@sha256:4fbb8e6a8395de5a7550b33509421a2bafbc0aab6c06ba2cef9ebffbc7092d90` |
| Built image | `ot-zone-tools:1.0.0`, `sha256:3e99b1d097f1f51c38096146165c270866330548d82307ed80f22a274c96afdc`, 196,971,812 bytes |
| Components | PyModbus `3.11.3`; Suricata `7.0.3`; nftables `1.0.9`; ulogd `2.0.8`; OpenSSH `9.6p1`; sshpass `1.09`; tcpdump `4.99.4` |
| Base repository commit | `5740518e31e36c573d71af5b34a1ad637378f735` (`origin/main`) |

## Clean run

| Stage | Command/result | Time | Memory |
|---|---|---:|---:|
| No-cache image build | `docker build --no-cache -t ot-zone-tools:1.0.0 labs/ot-zone-conduit/`; passed | 28.89 s | build runner max RSS 53,420 KiB |
| Clean deploy/readiness | `containerlab deploy -t labs/ot-zone-conduit/topology.clab.yml`; 13 lightweight nodes; both PLC listeners and HMI read ready | 3.54 s | deploy runner max RSS 42,712 KiB |
| Student path/check | Applied the documented inventory, conduit, operations, maintenance, monitoring, and open sensor-gateway path; rolled back the open change; `check.sh` | 38 passed, 0 failed | steady sample 107.48 MiB; 0 B swap |
| Peak sample | Polled every 250 ms across all current-lab cgroups while `check.sh` exercised SSH, maintenance, Modbus, IDS, and negative paths | n/a | 131.48 MiB aggregate sampled peak |
| Break-It negative | `break-it.sh`; ordinary `check.sh` returned 1 with only historian cadence failing (37 passed, 1 failed) | bounded by checks | HMI remained current |
| Break-It evidence | `check.sh --break-it` | 3 passed, 0 failed | return-drop counter > 0 |
| Minimal repair/check | `repair-break-it.sh`; removed only `OT-BREAK-900`; `check.sh` | 38 passed, 0 failed | no policy broadening |
| First destroy | `containerlab destroy ... --cleanup`; no lab containers or lab directory | 3.34 s | runner max RSS 41,880 KiB |
| Redeploy/reset | clean deploy; PLC1 `[420,73]`, PLC2 `[315,61]`; withheld nftables policy empty; solution and `check.sh` repeated | 3.98 s deploy; 38 passed | runner max RSS 41,916 KiB |
| Final destroy | scoped destroy and orphan checks | 3.25 s | runner max RSS 42,308 KiB |

The maintenance check proved both explicit disable and automatic five-second
expiry. It also proved the window remained source-scoped: `eng-ws` succeeded
while `attacker-test` remained denied.

## Positive and negative evidence

Positive:

- HMI and historian decoded the two declared register pairs at the two-second
  cadence; clean redeploy restored both initial pairs.
- The enterprise→jump and jump→engineering OpenSSH hops used different
  synthetic credentials and produced separate accepted-authentication logs.
- Engineering writes failed outside maintenance, succeeded only during the
  bounded window, restored the prior value, and failed after automatic expiry.
- Named nftables counters and NFLOG records exposed `OT-RULE-110`, `210`, `310`,
  `410`, `420`, and default-deny IDs.
- Suricata identified `app_proto:"modbus"` and matched function 6 from the
  unauthorized test source. Pausing the IDS left the HMI path healthy.
- The temporary `10.110.40.150` sensor-gateway change read PLC1 only after its
  exact rule was added; removing the rule and address completed rollback.
- Sampled clock spread across firewall, historian, site router, HMI, PLC, and IDS
  stayed within two seconds.

Negative:

- Direct enterprise-to-PLC TCP/502, jump-to-PLC TCP/502, PLC-initiated
  enterprise traffic, out-of-window writes, and unauthorized maintenance writes
  failed.
- The planned return-path Break-It made only historian delivery stale. The
  ordinary healthy check failed, HMI stayed current, and the injected rule's
  counter incremented.
- Route and `/etc/hosts` assertions plus named counter checks prevent a static
  route or host-file workaround from satisfying the end-state gate.

## Repository gates

| Gate | Result |
|---|---|
| `python3 scripts/lint-labs.py` | Passed: `OK — 138 labs checked, 48 distinct images, all consistent` |
| `./scripts/check-docs-admonitions.sh` | Passed: no malformed admonitions |
| `mkdocs build --strict` | Passed; final build completed in 16.56 seconds |
| `shellcheck -S warning scripts/*.sh labs/*/check.sh` | Passed |
| `git diff --check` | Passed |
| `python3 scripts/validate-enterprise-coverage.py` | Inherited failure only: existing topic #14 registers nested `labs/fixtures/wireless-core-operations`, while the validator permits exactly `labs/<name>`; the new two-component `labs/ot-zone-conduit` entry and its `check.sh` satisfy the schema |
| `scripts/test-enterprise-coverage-validator.sh` | Stops at the same inherited full-inventory failure before its fixture cases |

`origin/main` already contains both the nested WP-02 fixture registration and the
two-component-only validator. This PR does not rewrite unrelated wireless
coverage or validator policy; the accepted master Gate E commands above are all
green.

## Limitations, refresh, and cleanup

- **Unsupported/evidence-only:** real PLC programming, safety-instrumented
  systems, deterministic fieldbuses, TSN/hardware timing, vendor engineering
  stations, physical process hazards, fail-safe performance, and plant approval
  remain outside the live claim.
- **Enforcement seam:** the simulator's maintenance interlock is application
  logic and the nftables guard is source/port policy. The lab does not claim an
  L3 firewall can authorize a Modbus function by user identity. Passive Suricata
  observes but does not enforce.
- **Node-count note:** retaining every named role in the work-package topology
  uses 13 lightweight Linux nodes, two more than the plan's shorthand
  “2 cEOS + 9 Linux” envelope. This avoids collapsing the enterprise user or
  passive cell switch into a firewall. At 0.105 GiB steady and 0.128 GiB sampled
  peak, it remains far below the 6 GiB memory target.
- **Image refresh:** the external Ubuntu base is digest pinned and PyModbus is
  version pinned. Ubuntu package versions above were recorded from the built
  image; refresh requires the same probe and clean lifecycle.
- **Cleanup:** no `clab-ot-zone-conduit-*` or probe container, lab directory,
  current-lab network, maintenance process, capture, namespace, or runtime log
  remained after final scoped destruction.
- **Follow-up:** an OT/security reviewer should review terminology and safety
  framing before merge. No human plant pilot or hardware validation is
  represented as complete.
