# WP-12 — Network GitOps and Safe Change Pipeline

## Outcome

Build `labs/network-gitops-change-pipeline/`, a practice lab that turns declared
intent into reviewed configuration, performs pre-change validation, applies a
bounded multi-device change, runs post-change and service-path tests, detects a
partial push/drift condition, and rolls back safely with evidence.

Target coverage: level 4. This extends `automation-fundamentals`,
`network-automation-netbox`, `suzieq-network-observability`, and ZTP rather than
repeating their introductory material.

## Fidelity and tooling decision

The pipeline must be entirely local and deterministic. It may use:

- YAML inventory/intent and Jinja templates;
- Git inside the automation container;
- Python with Nornir/Scrapli/NAPALM/eAPI, chosen after image probe;
- pytest-based semantic and service-path tests;
- Batfish only if a pinned image fits resource/time budgets and materially improves
  pre-change reachability validation; otherwise implement explicit route/policy tests;
- local secret files or environment injection with obvious lab-only credentials.

Do not market “ran Ansible once” as GitOps. The learning mechanism is versioned
intent → reviewed diff → validation → controlled deploy → independent verification
→ rollback/audit.

## Feature-probe gate

1. Prove cEOS eAPI transactional/config-session or replace/rollback behavior on
   4.35.2F and record exact limitations.
2. Prove the selected Python driver retrieves structured running state and applies
   candidate changes idempotently.
3. Prove a two-device change can intentionally fail on device 2 while preserving
   enough evidence to detect and roll back device 1.
4. Prove config snapshots/rollback survive only as intended across lab sessions.
5. Benchmark optional Batfish; exclude it if it pushes readiness/resource beyond
   package targets.

## Lab type and platform

- Type: practice/capstone.
- `leaf1`, `leaf2`, `edge1`: cEOS.
- `client`, `app`, `observer`: Linux.
- `automation`: pinned `network-gitops:local` with Git, Python tooling, pytest,
  Jinja, JSON/YAML, and selected network driver.
- Optional local webhook/CI runner only if it remains inspectable; a shell/Python
  pipeline is preferable to hiding workflow inside a heavyweight product.

## Topology/addressing

```text
 client -- leaf1 ==== leaf2 -- edge1 -- app
               \       /
                observer

 automation -- management plane to all devices
```

Use sequential `/30` routed links, loopbacks `10.0.12.N/32`, client
`10.112.10.0/24`, app `10.112.20.0/24`, and a management network. Golden state
includes redundant routing and a policy denying guest-to-app while allowing corp.

Prebuild addressing, management/API access, Git repository skeleton, baseline
intent, test endpoints and one signed/identified initial commit. Withhold templates,
rendering, tests, deployment transaction, rollback and drift reconciliation.

## Student task sequence

1. **Guided source-of-truth survey:** compare intent, rendered candidate, running
   structured state and real service paths. Identify which is authoritative for
   design versus current truth.
2. **Hinted rendering:** write/complete a deterministic template and schema checks;
   render configs in stable order and reject invalid/unknown intent.
3. **Hinted pre-change validation:** test syntax/semantics, neighbor expectations,
   prefix/policy invariants, management reachability and blast radius. Fail on an
   intentionally bad route leak before device access.
4. **Hinted review artifact:** generate a normalized semantic diff and change plan
   showing devices, order, expected transient state, verification and rollback trigger.
5. **Hinted controlled deploy:** take snapshots, use config sessions/candidate replace
   where available, apply in safe order, and stop on first unexpected result.
6. **Hinted independent verification:** query structured device state and test actual
   client/app positive and negative paths—not merely compare running config to candidate.
7. **Hinted rollback:** trigger a failed post-check, restore snapshots, verify service,
   and retain audit evidence.
8. **Open drift case:** an emergency manual change is present. Decide adopt-versus-
   revert, update intent or device safely, and prove idempotent reconciliation.
9. **Break-It:** device 1 accepts a change, device 2 rejects it due to a capability/
   stale-inventory mismatch. The pipeline process exits, but the network is in a
   split state. Detect partial application, prevent further stages, roll back device 1,
   fix authoritative inventory/capability data, and rerun from a clean commit.

## Make the invisible visible

- Show normalized structured state instead of scraping display text where possible.
- Preserve rendered candidate, diff, pre/post test results, device transaction IDs,
  timestamps and rollback output per attempt.
- Compare config equivalence with service/policy correctness.
- Show idempotent second run with zero changes.

## Automated checks

`check.sh` must assert at minimum:

1. Intent schema and referential integrity pass.
2. Rendering is deterministic and secret-safe.
3. Pre-check rejects unauthorized prefix/default/policy changes.
4. Management reachability is protected from candidate changes.
5. Successful pipeline produces expected device state on all nodes.
6. Corp service path works and guest deny remains enforced.
7. Second run is idempotent.
8. Manual drift is detected with a semantic diff.
9. Partial push is detected before success is reported.
10. Rollback restores both device state and service invariants.
11. Failed attempt preserves evidence but no secret values.
12. Clean redeploy produces the baseline Git/device state.

## Repository/branch teaching boundary

The lab uses an internal disposable Git repository; it must never commit or mutate
the outer `/home/joe/containerlab` repository during student exercises. Scripts must
validate their working directory and refuse to operate outside the automation
container's lab repo.

## Planned files/docs

- Standard lab files plus intent/schema/templates, pipeline modules, tests, fixtures,
  `PROBE.md`, `VALIDATION.md`, and sample attempt evidence.
- `docs/tracks/operations/network-gitops-change-pipeline.md`.
- Operations study path places this after automation, NetBox and observability labs.

## Resource target

- 3 cEOS + 4 Linux; target ≤ 7 GiB steady and ≤ 9 GiB peak.
- Pipeline completion target ≤ 3 minutes without optional Batfish, ≤ 6 minutes with it.

## Definition of done

All master gates apply. Validate success, idempotent rerun, rejected pre-check,
post-check rollback, partial push, drift adopt/revert, evidence redaction, and outer
repository protection. A failed pipeline must never leave the lab claiming success.
