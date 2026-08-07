# Validation Record — `wireguard`

## Environment

| Item | Exact value |
|---|---|
| Date and owner | 2026-08-06; Codex implementation and main live validation |
| Host OS/kernel | Ubuntu 22.04; Linux 5.15.0-181-generic x86_64 |
| Architecture | amd64 |
| ContainerLab/Docker versions | ContainerLab 0.74.1 (`1866b3a2b`); Docker Engine 29.5.3 |
| WireGuard image | `wireguard-lab:local`; ID `sha256:70c809c97e5ec153d351e17ccb11b6572abbe4cb69e532d4079a0474c24854c8`; 90,858,330 bytes; base `debian@sha256:7b140f374b289a7c2befc338f42ebe6441b7ea838a042bbd5acbfca6ec875818` |
| Incidental WAN image | `ops-lab:local`; ID `sha256:f21d6ee3c25e92a74f0c16206c9e55f6bdbcc1c51d0f817e64c51074a22034f7`; 68,762,000 bytes |
| Repository state | Pre-commit validation of the working tree based on `8bacda3` |

The built image reported the exact intended package set: bash
`5.2.15-2+b13`, iproute2 `6.1.0-3`, iputils-ping
`3:20221126-1+deb12u1`, tcpdump `4.99.3-1`, and wireguard-tools
`1.0.20210914-1+b1`.

## Clean run

| Stage | Command/result | Time | Memory |
|---|---|---:|---:|
| Image build | `docker build -t wireguard-lab:local labs/wireguard/` — exit 0; exact package query matched all five pins. A main cached rebuild also passed. | 5.93 s for the recorded worker build; cached rebuild not separately measured | command max RSS 53,220 KiB for the recorded worker build |
| First deploy | `./scripts/lab.sh deploy wireguard` — exit 0; exact four-container inventory, internal three-port bridge, exact WAN addresses and transport pings; overlay initially absent | Not separately measured | Not measured during deploy |
| Learner build/check | Generated three fresh, distinct key pairs; key and configuration files were mode `600`; applied all three README configurations with `wg-quick`; `./scripts/lab.sh check wireguard` reported 29 passed, 0 failed | Not separately measured | Point sample below |
| Encrypted capture | Bounded `tcpdump` on hub `eth1` during `gw-a` to `gw-b` traffic captured 8 of 8 requested outer UDP packets | Bounded by `timeout 12` | Included in point sample |
| Break-It failure | Ran `./labs/wireguard/break.sh` twice; both executions passed their postconditions; checker reported the exact intended 25 passed, 4 failed state | Not separately measured | Included in point sample |
| Minimal repair/check | Ran `./labs/wireguard/solution.sh` twice; both executions passed and the checker returned to 29 passed, 0 failed | Not separately measured | Included in point sample |
| First destroy/cleanup | `./scripts/lab.sh destroy wireguard`; no lab containers, Docker network, or generated `clab-wireguard` directory remained | Not separately measured | Not applicable |
| Redeploy/recheck/destroy | Clean second deploy, new keys and configurations, 29 passed and 0 failed, followed by a second clean destroy; no containers, network, or generated directory remained | Not separately measured | Not separately measured |

The point-in-time container memory sample was 1.098 MiB for `hub`, 800 KiB
for `gw-a`, 736 KiB for `gw-b`, and 1.293 MiB for `wan`, approximately
3.927 MiB total. This is a point sample, not peak or steady-state profiling.

### Final reviewer-fix revalidation

On 2026-08-06, a fresh clean deployment generated new keys and executed the
revised collapsed README solution commands exactly. Every private-key,
public-key, and `wg0.conf` file was mode `600`, including the new derived,
stored, and live identity-continuity assertions; the checker passed 29 of 29.
Two consecutive `break.sh` executions produced the exact 25 passed, 4 failed
contract. Two consecutive `solution.sh` executions each restored a 29 of 29
check. The final destroy left no `clab-wireguard-*` containers, `clab` Docker
network, or generated lab directory.

## Positive and negative evidence

Positive evidence from both clean builds included:

- exactly four running containers with the intended three
  `wireguard-lab:local` critical nodes and one `ops-lab:local` incidental WAN;
- `br-wan` containing all three data ports, exact `10.0.0.1/24`,
  `10.0.0.10/24`, and `10.0.0.20/24` transport addresses, and all required WAN
  pings;
- an empty overlay baseline before learner work, followed by three fresh and
  distinct public-key identities and protected mode-`600` key/configuration
  files; each private key derived the stored public key, which also matched the
  live interface identity;
- exact `wg0` addresses and up state, two enrolled spoke identities on the
  hub, one hub identity on each spoke, hub UDP/51820, spoke endpoint
  `10.0.0.1:51820`, 25-second lab keepalives, and exact hub `/32` versus spoke
  `/24` prefix ownership;
- expected `wg0` routes, hub IPv4 forwarding, recent authenticated handshakes,
  and nonzero bidirectional transfer counters for every peer;
- all hub-to-spoke, spoke-to-hub, and bidirectional hub-forwarded
  spoke-to-spoke ICMP paths; and
- 29 passed, 0 failed from the stable end-state checker.

The per-node continuity assertion is non-secret and configuration-complete: it
requires a nonempty `wg0.conf`, pipes `wg-quick strip wg0` directly into
`wg setconf` on a uniquely named temporary WireGuard interface, and compares
only that interface's public key with the separately derived, stored, and live
identities. An EXIT trap deletes the temporary interface on every path; neither
the private key nor stripped configuration is printed.

A final focused clean deployment exercised this strengthened assertion. The
checker passed 29 of 29 and left no `wgck*` temporary interface on `hub`,
`gw-a`, or `gw-b`. With the hub's `wg0.conf` emptied while its live interface
state remained intact, the checker returned exactly 28 passed and 1 failed:
only `hub protected key/config continuity`. Restoring the container-local
backup returned the checker to 29 of 29, again with no temporary interface
left on any node.

The validated visibility point is the hub's outer `eth1` interface. During a
fresh `gw-a` to `gw-b` overlay probe, the bounded capture recorded 8 of 8
WireGuard datagrams among outer addresses `10.0.0.10`, `10.0.0.20`, and hub
`10.0.0.1:51820`, including the hub replies. The capture exposed no inner
`192.168.100.x` address or ICMP field. Capturing on the internal WAN container's
bridge or member ports recorded no packets on this host, so the README does not
claim that visibility point.

The negative test remained bounded after two fault injections:

- WAN addresses and reachability, keys, interfaces, routes, recent handshakes,
  and transfer counters remained green;
- `ip route get 192.168.100.10` on the hub still selected `wg0`, demonstrating
  that the connected interface route survives independently of peer ownership;
- only the live hub ownership for `gw-a` changed to
  `192.168.100.99/32`, and the dependent overlay data paths failed; and
- the checker reported exactly 25 passed and these four expected failures:
  `hub exact spoke prefix ownership`, `hub-to-spoke overlay paths`,
  `spoke-to-hub overlay paths`, and `forwarded spoke-to-spoke overlay paths`.

Two executions of the bounded repair restored `gw-a` ownership to
`192.168.100.10/32` and returned the checker to 29 passed, 0 failed.

## Repository gates

All final implementation gates passed after the live-discovered capture and
forwarding-check corrections:

```text
bash/sh syntax checks for labs/wireguard scripts                 PASS
shellcheck -S warning for labs/wireguard scripts                 PASS
python3 scripts/check-markdown-spacing.py                        PASS
./scripts/check-docs-admonitions.sh                              PASS
python3 scripts/lint-labs.py                                     PASS (143 labs, 52 images)
python3 scripts/validate-quizzes.py                              PASS (44 quiz/key pairs)
git diff --check                                                 PASS
mkdocs build --strict                                            PASS
```

`lab-tutor` was unavailable in this environment. The README was built against
the `labs/AUTHORING.md` fallback contract. The read-only AUTHORING fallback
review completed after two fix/follow-up rounds with no actionable findings
remaining; no tutor-validation claim is made.

## Limitations, refresh, and cleanup

- The Linux critical-role exception is intentional and intrinsic to the native
  kernel WireGuard plus `wg`/`wg-quick` learning objective. This lab makes no
  VyOS, router-NOS control-plane, or FRR fidelity claim.
- Live validation covered amd64 only. arm64, physical hardware, IPv6, NAT,
  scale, roaming, and long-duration rekey behavior were not exercised. The
  keepalive setting was validated as lab state, not as a live NAT traversal
  test.
- **Image advisory review, 2026-08-06:** The exact validated
  `wireguard-lab:local` image
  (`sha256:70c809c97e5ec153d351e17ccb11b6572abbe4cb69e532d4079a0474c24854c8`)
  was reviewed without changing the package inventory under test. In a
  transient container, `/var/lib/dpkg/status` was saved before installing
  `debsecan`; the scan then used `debsecan --suite bookworm --status
  /tmp/original.status`. It reported 104 affected package/CVE records,
  representing 48 unique CVEs across 33 installed binary packages.
  Repeating the query with `--only-fixed` returned 0 records: the configured
  Bookworm suite offered no fixed package versions for those reported items.
  This means rebuilding from current Bookworm would not remove them; it does
  **not** mean the image has zero risk.
- The authoritative Debian Security Tracker source-package review found one
  open Debian-unimportant TEMP issue for
  [bash](https://security-tracker.debian.org/tracker/source-package/bash), no
  open-issue section for
  [iproute2](https://security-tracker.debian.org/tracker/source-package/iproute2),
  open Debian-unimportant CVE-2025-47268 for
  [iputils](https://security-tracker.debian.org/tracker/source-package/iputils),
  and open Debian-unimportant CVE-2023-1801, CVE-2019-1010220, and
  CVE-2018-19519 for
  [tcpdump](https://security-tracker.debian.org/tracker/source-package/tcpdump).
  The [wireguard source-package
  page](https://security-tracker.debian.org/tracker/source-package/wireguard)
  had no open-issue section.
- **Advisory disposition:** Accept the pinned image for this isolated,
  disposable, root-only IPv4 lab. Its bounded `tcpdump` is restricted to
  UDP/51820 on controlled synthetic transport; the workflow provides no SMB or
  deep attacker-controlled capture, untrusted local users, or arbitrary ping
  targets. The next routine image review remains 2026-09-06.
- Deployment, workflow, break/repair, and cleanup times were not measured
  separately. The reported container memory is a point sample rather than a
  peak.
- Both destroys removed the disposable key material along with the containers.
  Residual checks found no lab containers, Docker network, or generated
  `clab-wireguard` directory after either run.
- The read-only AUTHORING fallback review is complete after two fix/follow-up
  rounds, with no actionable findings remaining.
