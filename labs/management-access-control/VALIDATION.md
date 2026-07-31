# Validation Record — `management-access-control`

## Environment

| Item | Exact value |
|---|---|
| Date and owner | 2026-07-31, Codex |
| Host OS/kernel | Linux `5.15.0-181-generic`, x86_64 |
| ContainerLab / Docker | ContainerLab `0.74.1` commit `1866b3a2b`; Docker client/server `29.5.3` |
| cEOS | `ceos:4.35.2F`, ID `sha256:f27a0e7dba17e46a755e41b6914ca5644dc2cd03570252f273b7fc76e8ba73ca`; NOS reports `4.35.2F-46221466.4352F (engineering build)` |
| Linux clients | `ops-lab:local`, ID `sha256:f21d6ee3c25e92a74f0c16206c9e55f6bdbcc1c51d0f817e64c51074a22034f7`, 68,762,000 bytes |
| Linux base | `alpine:3.20` pinned to multi-arch OCI index `sha256:d9e853e87e55526f6b2917df91a2115c36dd7c696a35be12163d44e6e2a4b6bc`; selected amd64 manifest reports Alpine 3.20.10 |
| Repository base | `origin/main` at `d812c39d2448c44a0566f12250b0aff9c299f6a5`; validation working tree based on orchestration commit `c37ddd6657d4` |

The digest-pinned `ops-lab:local` rebuild completed from cache in 0.78
seconds with 52,820 KiB maximum builder-process RSS and reproduced the
recorded image ID.

## Clean run

| Stage | Command/result | Time | Memory |
|---|---|---:|---:|
| Deploy | `./scripts/lab.sh deploy management-access-control`; three nodes started from a clean state | about 24 s | not sampled during startup |
| Baseline | Both ICMP probes and all four source/service TCP probes succeeded before policy | under 3 s | not sampled |
| Hidden solution and healthy check | README cEOS commands accepted; admin TCP/22 and TCP/443 allowed, guest TCP/22 and TCP/443 denied, both pings preserved; final checker 24/24 | about 24 s for the strengthened check | final solved sample: cEOS 1.122 GiB, clients 612 KiB each |
| Break-It failure | `./labs/management-access-control/break.sh`; admin SSH/HTTPS timed out, ICMP succeeded, and sequence 5 counted the denied TCP packets; strengthened checker rejected the state with 7 findings | pass (intended failure) | included in sampled run |
| Minimal repair/check | Removed only sequence 5; all outcomes restored and checker passed 24/24 | pass | included in sampled run |
| Attachment negative test | Added the ACL to Ethernet1; checker rejected the state, including the explicit interface-attachment assertion; removed only that attachment | pass (intended failure) | included in sampled run |
| Destroy/cleanup | `./scripts/lab.sh destroy management-access-control`; all containers, host/SSH entries, and generated directory removed | 3.7 s | no residual containers |
| Redeploy/recheck/destroy | Rebuilt pinned client image, clean redeploy, hidden solution, 24/24 check, both negative checker tests, final 24/24 check, and clean destroy | pass | final repeat sample: cEOS 1.115 GiB, clients 612 KiB each |

The highest sampled value across the platform probe and full lab was 1.19
GiB for cEOS. The highest sampled full-topology aggregate was about 1.162 GiB.
No swap was in use after cleanup.

## Positive and negative evidence

Positive assertions proven live:

- The clean baseline exposed SSH and HTTPS eAPI to both source subnets, while
  both routed interface addresses answered ICMP.
- The learned configuration was accepted by cEOS 4.35.2F and became
  `Configured` and `Active` inbound on the default-VRF control plane.
- The authorized source reached TCP/22 and TCP/443; the guest source timed out
  on both ports; unrelated ICMP remained available from both sources.
- Before/after snapshots proved that fresh traffic incremented the exact five
  intended first-match ACL sequences.
- Operational eAPI output proved HTTPS running on TCP/443 and plaintext HTTP
  shut down on TCP/80.
- The checker required exactly five intended ACL entries and no data-plane ACL
  attachment on Ethernet1 or Ethernet2.

Negative assertions proven live:

- The rule-order fault preserved ICMP but denied authorized SSH and HTTPS
  before the specific permit entries. The checker rejected the extra entry,
  service outcomes, and unchanged intended service counters.
- Attaching the named ACL to Ethernet1 caused the checker to reject the
  otherwise working service state. Removing only that attachment restored a
  24/24 pass.
- The first checker draft incorrectly expected default HTTPS to appear in
  running-config. Live output showed the service operational but the default
  omitted; the final checker uses `show management api http-commands`.
- EOS accepted `clear ip access-lists counters MGMT-PLANE` but took about
  ten seconds and warned about stale hardware counters. The final checker
  therefore uses faster before/after snapshots rather than claiming an
  instantaneous clear.

## Repository gates

| Gate | Final result |
|---|---|
| `python3 scripts/check-markdown-spacing.py` | `OK: Markdown block spacing is valid` |
| `./scripts/check-docs-admonitions.sh` | `OK: no malformed admonitions in docs/` |
| `python3 scripts/lint-labs.py` | `OK — 143 labs checked, 52 distinct images, all consistent` |
| `python3 scripts/validate-quizzes.py` | `OK — 44 quiz/key pairs; totals, catalog metadata, remediation labs, links, and whitespace validated` |
| `shellcheck -S warning scripts/*.sh labs/*/check.sh` | Passed repository-wide |
| `git diff --check` | Passed |
| `mkdocs build --strict` | Passed; only existing informational notices for unnaved pages were emitted |

All gates were rerun after the evidence records and reviewer fixes; the table
records those final results.

## Limitations, refresh, and cleanup

- The requested `lab-tutor` skill was unavailable; no tutor validation is
  claimed. `labs/AUTHORING.md` was used for student-flow review.
- TCP service reachability was tested, not interactive SSH authentication or
  an authenticated eAPI call. That keeps the lab focused on control-plane
  source/service policy.
- cEOS is a licensed imported image. The exact tag, local image ID, and
  reported NOS version are recorded. Docker Scout is not installed, so no
  vulnerability scan result is claimed.
- The shared Linux client image now pins the Alpine 3.20.10 multi-architecture
  index digest. No vulnerability scanner result is claimed; review again by
  2026-08-31 or sooner for an actionable advisory.
- Final destroy removed all three containers, the generated lab directory,
  host entries, and SSH fragment. Matching container and directory checks
  returned absent.
