# WP-00 Enterprise Coverage Foundation — Probe and Validation Record

**Date:** 2026-07-22
**Decision:** Go — the documentation/YAML validator foundation is reproducible.

## Scope and applicability

This is Phase 0 only: documentation, inventory validation, templates, fixture
rules, and policy. It introduces no NOS, ContainerLab topology, image, or live
lab deployment. The `new-lab` skill's cEOS/SR-Linux/FRR references and the
troubleshooting-range scenario authoring contract are therefore inapplicable to
this work item; no selected NOS or scenario was substituted.

## Smallest load-bearing platform probe

The validator schema and representative repository registrations are the
load-bearing feature for this documentation-only package.

| Item | Exact value |
|---|---|
| Python | 3.10.12 |
| PyYAML | 6.0.3 |
| Git | 2.34.1 |
| Host kernel | 5.15.0-181-generic |
| Docker | 29.5.3, build d1c06ef |
| ContainerLab | 0.74.1 (commit `1866b3a2b`, 2026-03-15) |
| Host memory at probe | 15 GiB total; 11 GiB available; 0 B swap used |
| Host filesystem at probe | 150 GiB available |

Command:

```bash
/usr/bin/time -v python3 scripts/validate-enterprise-coverage.py \
  tests/fixtures/enterprise-coverage/valid.yaml
```

Result: `OK — 2 enterprise coverage topic(s) validated`; elapsed 0.03 seconds,
maximum resident set size 12,352 KiB, exit 0. The same probe rejected the five
negative fixtures: level 6, a missing lab path, an unregistered level-3 topic, a
level-3 lab without `check.sh`, and a level-5 topic without scenario metadata.

**Fallback/rename decision:** no fallback or rename was needed. No image or
hardware claim is made by this package.

## Full validation transcript summary

| Check | Result |
|---|---|
| `python3 scripts/validate-enterprise-coverage.py` | `OK — 29 enterprise coverage topic(s) validated` |
| `scripts/test-enterprise-coverage-validator.sh` | Positive fixture passed; all five negative fixtures failed as required |
| `python3 scripts/lint-labs.py` | `OK — 127 labs checked, 36 distinct images, all consistent` |
| `./scripts/check-docs-admonitions.sh` | `OK: no malformed admonitions in docs/` |
| `mkdocs build --strict` | Passed; documentation built in 14.43 seconds |
| `shellcheck -S warning scripts/*.sh labs/*/check.sh` | Passed with ShellCheck 0.11.0 |
| `git diff --check` | Passed |

ShellCheck was absent from the base host, so the validation environment installed
the user-local `shellcheck-py` 0.11.0.1 package, which provides ShellCheck 0.11.0;
no repository dependency or image was changed.

## Runtime, resources, and cleanup

No ContainerLab topology or Docker container was deployed. Deploy time, peak and
steady runtime memory, Break-It/fix/redeploy behavior, and runtime destruction
are **not applicable**. The documentation validator used 12,352 KiB maximum RSS
in its representative probe. No runtime state, namespaces, containers, images,
captures, or overlays were created; cleanup is complete.

## Limitations and follow-up

- The initial inventory deliberately leaves historical `last_live_validation`
  dates blank rather than inventing evidence. Owners must add a dated clean
  validation when a topic is next live-walked.
- Planned packages remain level 0. This PR does not claim their labs, fixtures,
  image pins, or blind assessment ranges are complete.
- Existing mutable image references are disclosed as legacy technical debt by the
  new policy; this Phase 0 work does not change lab images.
