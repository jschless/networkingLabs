# Validation Record — `orchestrated-wan-overlay`

## Environment

| Item | Exact value |
|---|---|
| Date and owner | 2026-07-23 / WP-13 |
| Host OS/kernel | Linux `5.15.0-181-generic` x86_64 |
| ContainerLab/Docker | `0.74.1` (`1866b3a2b`) / `29.5.3` |
| Image | `orchestrated-wan-tools:1.0.0`, `sha256:f51bddd12349bd7a7f7a3e7611b1fdc7b8492d6f4e88cc9731788cda000ee74c`, 133,481,925 bytes; base `debian:12.12-slim` |
| Repository base commit | `e0b0d7b` |

## Clean run

| Stage | Command/result | Time | Memory |
|---|---|---:|---:|
| Build | `docker build -t orchestrated-wan-tools:1.0.0 labs/orchestrated-wan-overlay` succeeded | 11.15 s first build | 52,520 KB max builder RSS |
| Deploy | `./scripts/lab.sh deploy orchestrated-wan-overlay` succeeded from a cleared runtime | 4.81 s | 41,524 KB deploy-process max RSS |
| Enrollment/readiness | Enrolled hub/branch1/branch2; independent transport pings, certificates, mTLS controller state, WireGuard peers, CORP/GUEST and breakout tests passed | < 15 s | 14 containers; sampled total about 89 MiB |
| Healthy/check | `./scripts/lab.sh check orchestrated-wan-overlay` passed 21 assertions | about 15 s | 12.7 MiB largest edge sample; far below 8 GiB target |
| Brownout/hard-down | `tc netem loss 100%` selected `wg-inet-hub` after four failed samples; after removal it returned to MPLS after the five-good-sample/15-second hold-down. Hard `eth2` down also retained private service through the independent hub return overlay | bounded within 8 s; failback about 20 s | unchanged materially |
| Break-It failure | `pki /revoke.sh branch1`, then `./labs/orchestrated-wan-overlay/check.sh --break-it`, passed 9 assertions: both underlays green, control down, overlays withdrawn | 6 s | unchanged materially |
| Minimal repair/check | `branch1 /enroll.sh`, reconciliation, then normal 21-assertion check passed | < 20 s | unchanged materially |
| Redeploy/recheck/destroy | Scoped destroy, runtime clear, deploy/enroll/recheck repeated; final scoped destroy and resource check performed | 4.81 s deploy | no retained lab containers/networks |

## Positive and negative evidence

- Two independently addressed MPLS/private and internet underlays passed from both branches to hub.
- OpenSSL validated all three enrolled edge certificates; controller desired/applied version and audit state converged through `v2` publish and `v1` rollback.
- WireGuard peer interfaces existed on each enrolled edge; CORP branch-to-hub and branch-to-branch paths passed.
- GUEST-to-private was denied while GUEST-to-SaaS local breakout succeeded.
- Critical route table `100` used MPLS in golden state. The hard-down case moved branch1 critical forwarding to the internet tunnel and retained private-app reachability.
- Revocation specifically produced controller `control: down` plus withdrawn branch1 overlay interfaces while both underlay pings remained green. A new certificate restored the normal checker.

## Repository gates

The following commands were run after the final source review:

```text
python3 scripts/lint-labs.py
./scripts/check-docs-admonitions.sh
mkdocs build --strict
shellcheck -S warning scripts/*.sh labs/*/check.sh
```

All completed successfully; exact output is recorded in the final PR validation summary.

## Limitations, refresh, and cleanup

- **Unsupported or evidence-only behavior:** No vendor controller UI/API, OMP/TLOC/BFD protocol, carrier MPLS, DPI, commercial licensing, or external SaaS availability is claimed.
- **Image vulnerability-refresh review:** Debian base is pinned to `12.12-slim`; refresh it and re-run the full lifecycle when Debian publishes a security update. No unpinned `latest` image is used.
- **Residual runtime artifacts:** `./scripts/lab.sh destroy orchestrated-wan-overlay`, `docker ps`, `docker network ls`, and the ignored lab runtime directory were scoped-checked. No `clab-orchestrated-wan-overlay-*` containers or lab-named networks remain after final cleanup.
- **Follow-up:** Hub return traffic is intentionally kept on the independent internet overlay so a branch MPLS hard-down has a live reverse path; it is a demonstrable lab policy, not an ECMP or production return-path design.
