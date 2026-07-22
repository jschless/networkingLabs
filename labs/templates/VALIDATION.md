# Validation Record — `<lab-name>`

> Copy this file to `labs/<lab-name>/VALIDATION.md` after a clean live walk. Keep
> commands and dates exact; “not applicable” is valid for a documentation-only
> package, but do not leave a deployed topology behind.

## Environment

| Item | Exact value |
|---|---|
| Date and owner | |
| Host OS/kernel | |
| ContainerLab/Docker versions | |
| Image tags/digests | |
| Repository commit | |

## Clean run

| Stage | Command/result | Time | Memory |
|---|---|---:|---:|
| Deploy | | | |
| Healthy/check | | | |
| Break-It failure | | | |
| Minimal repair/check | | | |
| Destroy/cleanup | | | |
| Redeploy/recheck/destroy | | | |

## Positive and negative evidence

List the service/control/data-path assertions that passed, then the intended
denials or break states that failed. Include relevant output excerpts or links to
safe, versioned evidence; never include secrets or sensitive capture payloads.

## Repository gates

Record the exact result of:

```bash
python3 scripts/lint-labs.py
./scripts/check-docs-admonitions.sh
mkdocs build --strict
shellcheck -S warning scripts/*.sh labs/*/check.sh
```

## Limitations, refresh, and cleanup

- Unsupported or evidence-only behavior:
- Image vulnerability-refresh review/result:
- Residual runtime artifacts checked and cleanup result:
- Follow-ups not represented as complete:
