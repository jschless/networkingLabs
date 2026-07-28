# Validation Record — `network-gitops-change-pipeline`

## Environment

| Item | Exact value |
|---|---|
| Date and owner | 2026-07-28, Codex |
| Host OS/kernel | Linux `5.15.0-181-generic`, x86_64 |
| ContainerLab / Docker | ContainerLab `0.74.1` commit `1866b3a2b`; Docker client/server `29.5.3` |
| cEOS | `ceos:4.35.2F`, ID `sha256:f27a0e7dba17e46a755e41b6914ca5644dc2cd03570252f273b7fc76e8ba73ca`; NOS reports `4.35.2F-46221466.4352F` |
| Tools base | `python:3.12.7-alpine3.20@sha256:5049c050bdc68575a10bcb1885baa0689b6c15152d8a56a7e399fb49f783bf98` |
| Built image | `network-gitops:local`, ID `sha256:819bcfe41fe3af6f26fc4e15e34591c50c798262d712456994a5222eddcbf5fa`, 91,127,571 bytes |
| Direct Python packages | Jinja2 3.1.5, jsonschema 4.23.0, pytest 8.3.4, PyYAML 6.0.2 |
| Main Alpine tools | bash 5.2.26-r0, curl 8.14.1-r2, Git 2.45.4-r0, iproute2 6.9.0-r0, iputils 20240117-r0, jq 1.7.1-r0, tcpdump 4.99.4-r1 |
| Outer repository base | `origin/main` at `7ff9aa0` when the branch was created |

The local image built in 9.29 seconds with 52,732 KiB maximum builder-process
RSS. No Internet access is needed after that one-time build.

## Clean run

| Stage | Command/result | Time | Memory |
|---|---|---:|---:|
| Build | `docker build -t network-gitops:local labs/network-gitops-change-pipeline/`; success | 9.29 s | image 86.9 MiB; builder max RSS 52,732 KiB |
| Deploy | `./scripts/lab.sh deploy network-gitops-change-pipeline`; four independent clean deploys succeeded | 39.19–42.68 s | ContainerLab process max RSS 43,520 KiB or less |
| Baseline readiness | `./scripts/lab.sh check ... --baseline`; 18/18 on clean source | final 65.18 s after deploy returned | bounded 40×2-second route/service retry |
| Student work | README commands created intent/template/tests and the safe workflow policy; `pytest -q` passed 5/5; unsafe route and management fixtures rejected before device access | under 1 s static; API plan bounded | Python pipeline max RSS 29,528 KiB |
| Healthy pipeline | three snapshots, three named session commits, structured and client service checks; success | 3.16 s | sampled full-lab peak 3,676.715 MiB |
| Idempotent rerun | `changed: []`, `applied: []`, `idempotent: true`; success | 3.1 s class | sampled steady 3,647.349 MiB |
| Success check | `./scripts/lab.sh check ... --success`; 22/22 | pass | included student workflow, corp allow, and guest deny |
| Break-It failure | leaf1 committed v3; leaf2 rejected stale `10.999.1.1/30`; edge1 stopped; visible check failed 20 pass / 2 fail | bounded | service remained available; split state retained for diagnosis |
| Minimal repair | snapshot replace on leaf1 only; Git revert of stale inventory/intent commit; clean v2 rerun | pass | `partial_rolled_back` evidence names only leaf1 |
| Full check | drift detect/adopt proposal/revert, three-device forced post-check rollback, evidence and boundary gates | 30/30 | corp 200; guest timeout/deny |
| Repeatability | destroy, clean redeploy, 18/18 blank-baseline check, destroy; repeated after final source edits | pass | no cEOS flash snapshot or internal Git state persisted |

The full active-lab sample was 3,676.715 MiB at peak and 3,647.349 MiB
steady, well below the 7 GiB steady / 9 GiB peak package targets. At the final
measurement the host retained about 9.6 GiB available RAM and used no swap.
The successful pipeline itself was far below the three-minute target; deploy
plus final readiness was about 108 seconds.

## Positive and negative evidence

Positive assertions proven live:

- cEOS eAPI returned structured version, interface, route, OSPF-neighbor, and
  configuration-session state.
- Schema/referential checks, deterministic rendering, semantic review artifact,
  repository commit identity, and the withheld student-owned safe workflow
  policy passed.
- Each changed device received a unique named configuration session and explicit
  flash snapshot before commit.
- Successful state was `gitops-v2` plus the approved
  `203.0.113.12/32` discard canary on leaf1, leaf2, and edge1.
- The real corp source `10.112.10.10` received HTTP 200 from the app while the
  guest source `10.112.10.20` remained denied.
- A second run changed zero devices.
- Manual drift was exposed semantically; adopt created an uncommitted review
  artifact without touching the device, and revert restored intent.
- The forced post-check candidate changed all three devices, then restored
  edge1, leaf2, and leaf1 in reverse order. Device and service checks passed
  afterward.

Negative assertions proven live:

- The route-leak and management-plane fixtures exited at pre-check with
  `device_access_count: 0`.
- The planned Break-It produced exactly:

  ```text
  applied=["leaf1"]
  failed_device="leaf2"
  stopped_before=["edge1"]
  error="ip address 10.999.1.1/30 ... invalid command"
  ```

- `check.sh --success` failed in that split state and refused another deploy.
- Repair rolled back only leaf1, reverted the stale authoritative Git commit,
  and returned the full check to pass.
- Running the pipeline from `/tmp` with its module on `PYTHONPATH` was refused.
- Evidence scans found no `admin`, password, authorization header, or encoded
  Basic token.

Sanitized representative output is versioned under
`artifacts/sample-attempt/`; complete attempts remain disposable inside the
automation container and are removed at destroy.

## Repository gates

| Gate | Final result |
|---|---|
| `python3 scripts/lint-labs.py` | `OK — 141 labs checked, 52 distinct images, all consistent` |
| `./scripts/check-docs-admonitions.sh` | `OK: no malformed admonitions in docs/` |
| `python3 scripts/validate-enterprise-coverage.py` | `OK — 29 enterprise coverage topic(s) validated` |
| `scripts/test-enterprise-coverage-validator.sh` | Positive fixture passed; all five negative fixtures failed as required |
| `mkdocs build --strict` | Passed with MkDocs 1.6.1 / Material 9.7.5 in 22.23 s, max RSS 85,348 KiB |
| `shellcheck -S warning scripts/*.sh labs/*/check.sh` | Passed with ShellCheck 0.11.0 |
| `git diff --check` | Passed |

The first strict docs build correctly failed because the new wrapper used one
too many `../` path segments. The include was corrected to the repository's
current wrapper convention, and the recorded final strict build passed. The two
pre-existing unnaved troubleshooting wrapper notices remain warnings, not new
errors.

## Limitations, refresh, and cleanup

- cEOS configuration sessions isolate and commit candidates, but 4.35.2F keeps
  one completed session, does not autosave on commit, and did not provide a
  direct committed-session rollback in the probe. Explicit snapshots plus
  `configure replace` are the documented transaction boundary.
- Flash snapshots and the internal Git repository are intentionally container
  local. They do not survive scoped destroy; a real pipeline needs durable,
  access-controlled off-device evidence and backups.
- eAPI is lab-only HTTP with `admin/admin`. Production TLS, AAA, external secret
  management, approvals, signed commits, and hosted CI are not claimed.
- Batfish is excluded because no repository-pinned image was available and the
  explicit route, prefix, policy, management, structured-state, and real
  service-path tests satisfy this package. No model-wide reachability claim is
  made.
- The Python base is digest-pinned and direct Python dependencies are
  version-pinned. Alpine packages were recorded exactly from the 3.20 build.
  No vulnerability scanner result is claimed; the next monthly image review is
  due by 2026-08-28 or sooner for an actionable advisory.
- Final `./scripts/lab.sh destroy network-gitops-change-pipeline` removed all
  seven containers, the `network-gitops-mgmt` network, host entries, SSH
  fragment, generated lab directory, flash snapshots, and internal evidence.
  Probe resources were also absent. Matching container/network/directory checks
  all returned zero/absent.
