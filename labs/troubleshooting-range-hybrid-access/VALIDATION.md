# Validation Record — `troubleshooting-range-hybrid-access`

## Decision and frozen contract

**Result:** pass. Topology `1.0.0` was frozen on 2026-07-29 only after clean
deploy, both reference-ticket dry runs, adversarial workaround checks,
idempotent golden reset, scoped destroy/redeploy, repository gates, and final
cleanup passed.

The installed ticket-authoring skill references the missing
`labs/troubleshooting-range/references/range-routing.md`. `DESIGN.md` supplies
the equivalent node/address/path/safe-mutation map for this range.

## Environment

| Item | Exact value |
|---|---|
| Date and owner | 2026-07-29 UTC; Codex |
| Base commit | `155e3c3` (`origin/main` at branch creation) |
| Host | x86_64 Linux `5.15.0-181-generic #191-Ubuntu` |
| ContainerLab | 0.74.1, commit `1866b3a2b`, 2026-03-15 |
| Docker | client/server 29.5.3 |
| Built image | `ops-lab:local`, `sha256:f21d6ee3c25e92a74f0c16206c9e55f6bdbcc1c51d0f817e64c51074a22034f7`, 68,762,000 bytes |
| In-image versions | Alpine 3.20; Python 3.12.13; iptables/ip6tables 1.8.10 (`nf_tables`); dnsmasq 2.90-r3; BIND tools 9.18.49-r0 |
| Build | `docker build -t ops-lab:local images/ops-lab/`; 7.49 s; command max RSS 52,680 KiB; exit 0 |

The earlier load-bearing probe used the pre-rebuild local image ID and Python
3.12.12; its exact result and the curl-to-Python fallback are preserved in
`PROBE.md`. The clean range walk used the rebuilt image above.

## Clean live walk

| Stage | Exact command/result | Time | Command RSS |
|---|---|---:|---:|
| Clean deploy | `./range.sh deploy`; all 9 exec hooks clean; health 23/23 | 13.06 s | 42,200 KiB |
| Status | `./range.sh status`; 9/9 running; health 23/23 | health gate < 3 s | — |
| T1 inject | `./range.sh start t1-workload-policy-port`; symptom proved with routing, DNS, health endpoint, and site B healthy | 2.59 s | 30,180 KiB |
| T1 minimal repair | Deleted only the marked IPv4 and IPv6 TCP/8080 rejects | < 1 s | — |
| T1 verify | `./range.sh verify`; dual-stack app restored, adjacent services healthy, direct protected origin denied, no broad bypass | 0.43 s | 29,836 KiB |
| T1 reset | `./range.sh reset`; clear plus no-container-restart golden restore; health 23/23 | 10.80 s | 30,216 KiB |
| T3 inject | `./range.sh start t3-origin-bypass`; PEP checks stayed healthy while both direct origin paths became reachable | 2.59 s | 30,264 KiB |
| T3 minimal repair | Deleted only the marked IPv4 and IPv6 direct-origin permits | < 1 s | — |
| T3 verify | `./range.sh verify`; managed PEP path healthy, unmanaged identity and both direct origin paths denied | 1.43 s | 30,044 KiB |
| T3 reset | `./range.sh reset`; clear plus no-container-restart golden restore; health 23/23 | 10.98 s | 30,188 KiB |
| First scoped destroy | `./range.sh destroy`; no range container, network, lab directory, SSH include, or named link remained | 1.94 s | 42,224 KiB |
| Repeat deploy | `./range.sh deploy` then `./range.sh status`; health 23/23 | 11.86 s | 42,328 KiB |
| Frozen deploy | `./range.sh deploy` with topology metadata `1.0.0`; health 23/23 | 12.78 s | 42,228 KiB |
| Final cleanup | `./range.sh destroy`; deleted only this range's XDG attempt state; no range resource remains | 1.90 s | 41,608 KiB |

Two consecutive golden resets also passed health 23/23 in 10.02 and 10.01
seconds. Both scenario clear scripts were run twice in a clean state and
remained successful.

Pre-clean shakedown found and corrected two reset issues before the recorded
clean walk: flushing the full IPv6 main table removed link-local routes, and
atomic replacement of Docker's bind-mounted `/etc/hosts` failed. The final
reset preserves kernel routes, cycles only range links, uses `nodad` on fixed
addresses, and rewrites the existing hosts file in place.

## Positive and negative evidence

The 23 health assertions cover:

- both IPv4 WAN transports and both IPv6 WAN transports;
- IPv4/IPv6 preferred path through WAN A with WAN B installed as standby;
- dual-stack DNS reachability and exact A/AAAA answers;
- site-A IPv4/IPv6 application, site-B application, and health endpoints;
- managed identity success and unmanaged identity denial at the PEP;
- IPv4/IPv6 direct protected-origin denial;
- default-deny cloud forwarding, absence of scenario markers and netem state,
  and ≤5-second host/container clock delta.

Adversarial verifier checks also passed:

- T1 rejected a broad managed-prefix-to-origin allow even though it masked the
  application symptom.
- T3 rejected origin-host-only blocking while the architectural bypass permits
  remained on `cloud-edge`.
- Both verifiers reject host-file workarounds or missing default-deny state.

Sanitized rubric transcripts are in
`validation-artifacts/t1-workload-policy-port.md` and
`validation-artifacts/t3-origin-bypass.md`. They contain no credentials,
tokens, packet payloads, or private addresses outside the documentation ranges.

## Resources and limits

| Measurement | Result |
|---|---:|
| Steady nine-container memory (`docker stats`) | 33.542 MiB total |
| T3 fault-state memory snapshot | 33.606 MiB total |
| Observed reset peak (5 `docker stats` samples) | 39.254 MiB total |
| Host available memory during frozen deployment | 12 GiB; 0 B swap used |
| Host headroom target | Passed by more than 8 GiB |
| Container memory limit | unset (`HostConfig.Memory=0`; host cgroup limit shown) |
| Frozen deployment time | 12.78 s |
| Health/reset target | health < 3 s; reset 10.01–10.98 s; both below target |

Linux 5.15 exposes `memory.current` but not `memory.peak` in these container
cgroups, so peak is the highest sampled aggregate during reset rather than a
kernel lifetime high-water counter. Even that conservative observation is far
below the 8 GiB range target.

## Repository and package gates

| Gate | Result |
|---|---|
| `python3 scripts/validate_ticket.py .../t1-workload-policy-port` | `OK — ticket contract validated` |
| `python3 scripts/validate_ticket.py .../t3-origin-bypass` | `OK — ticket contract validated` |
| `python3 scripts/lint-labs.py` | `OK — 142 labs checked, 52 distinct images, all consistent` |
| `./scripts/check-docs-admonitions.sh` | `OK: no malformed admonitions in docs/` |
| `mkdocs build --strict` | Passed; final documentation build completed in 21.27 s |
| `shellcheck -S warning scripts/*.sh labs/*/check.sh` | Passed |
| Range-local ShellCheck over controller, health, resets, and all scenario scripts | Passed |
| `python3 scripts/validate-enterprise-coverage.py` | `OK — 29 enterprise coverage topic(s) validated` |
| `./scripts/test-enterprise-coverage-validator.sh` | Positive fixture and all five expected-negative fixtures behaved correctly |
| `bash -n` / Python compile / topology YAML parse | Passed; 9 nodes and 9 links |
| `git diff --check` | Passed |

The first strict docs build correctly rejected a relative `DESIGN.md` link
after README inclusion moved its resolution context. The link was made
non-clickable and the recorded strict build passed.

## Limitations, refresh, and cleanup

- This is a live provider-neutral Linux model, not a public cloud control
  plane, RF/WLAN, commercial SD-WAN product, production PKI, or Internet GSLB.
- `ops-lab:local` is an existing repository-local image tag, not a newly
  introduced mutable third-party tag. Its Dockerfile currently follows
  repository convention with `alpine:3.20`; the exact built image ID used for
  this validation is recorded above. No `latest` tag was added.
- The two rubric time bands are provisional. No human blind pilot is claimed,
  and source topics remain level 4 rather than being promoted to level 5.
- Exactly two reference tickets are complete. The remaining ten WP-16 catalog
  scenarios are explicitly planned and not represented as implemented.
- Rollback is scoped: destroy the range and revert this range directory plus
  its docs/validator registrations. The final cleanup removed all range
  containers, the management network, links, generated lab directory, SSH
  include, and `/home/joe/.local/state/troubleshooting-range-hybrid-access`.
  The shared `ops-lab:local` image remains intentionally available for other
  repository labs.
