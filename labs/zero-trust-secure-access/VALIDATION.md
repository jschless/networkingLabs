# Validation Record — `zero-trust-secure-access`

## Environment

| Item | Exact value |
|---|---|
| Date and owner | 2026-07-23, Codex |
| Host OS/kernel | Ubuntu Linux `5.15.0-181-generic`, x86_64 |
| ContainerLab/Docker versions | ContainerLab `0.74.1` (commit `1866b3a2b`); Docker Client/Server `29.5.3` |
| Image tags/digests | `zt-access-tools:local` from `python:3.12.7-alpine3.20@sha256:5049c050bdc68575a10bcb1885baa0689b6c15152d8a56a7e399fb49f783bf98`; `zt-keycloak:local` from `quay.io/keycloak/keycloak:26.0.7@sha256:4388e2379b7e870a447adbe7b80bd61f5fbf04e925832b19669fda4957f05a81` and `busybox:1.36.1-musl@sha256:3c6ae8008e2c2eedd141725c30b20d9c36b026eb796688f88205845ef17aa213` |
| Repository base | `5d1d5a752bb38bad45cb43d68e343b994354e357` (`origin/main`) |

## Clean run

| Stage | Command/result | Time | Memory |
|---|---|---:|---:|
| Build/deploy | `docker build -t zt-access-tools:local .`, `docker build -f Dockerfile.keycloak -t zt-keycloak:local .`, `containerlab deploy -t topology.clab.yml --reconfigure`; 15 containers running | 5 s deploy; Keycloak discovery ready after 8 s | 697 MiB steady total |
| Healthy/check | issued `managed-client` certificate, installed student policy and gateway rules, then `./check.sh` | 10.6 s | 26/26 assertions passed |
| Break-It failure | `./check.sh --break-it` inserted remote-to-origin TCP/8080 accept | 10.6 s | 25 pass, 1 expected failure; PEP permit still succeeded while direct origin returned 200 |
| Minimal repair/check | deleted only the inserted nftables handle, then `./check.sh` | 10.6 s | 26/26 assertions passed |
| Redeploy/recheck/destroy | empty `runtime/`, redeploy; repeat the policy/cert setup and check; destroy as recorded below | repeatable | no residual lab containers or generated runtime files |

Observed steady `docker stats --no-stream` use: Keycloak 605.4 MiB; PEP 15.15 MiB; each app/log/PKI 13.9–14.0 MiB; all bridge, gateway, and client helpers below 1.3 MiB. Total is about 697 MiB, below the 5 GiB steady/7 GiB peak target.

## Positive and negative evidence

- Keycloak discovery served issuer `http://10.90.30.10:8080/realms/ztna`; CLI password grant issued audience `pep` tokens with group claims.
- The final automated matrix passed: managed finance + mTLS permit; unmanaged finance device denial; operations permit/finance denial; partner-route-only permit; anonymous public permit; wrong issuer/audience rejection; each direct origin IP denial; origin-initiated remote/identity denial; required PEP-origin firewall rule; permit and deny decision logs.
- Disabling `finuser` through Keycloak `kcadm.sh` caused an existing token to receive HTTP 401 on the next PEP request. The check reenables the user after the assertion.
- The independent Break-It test intentionally returns non-zero with `Break-It independent origin path assertion` after adding one broad `eth1` to `eth4` TCP/8080 rule. Deleting that handle restores the 26/26 pass.

## Repository gates

```text
python3 scripts/lint-labs.py                         OK — 132 labs checked, 42 distinct images, all consistent
./scripts/check-docs-admonitions.sh                  OK: no malformed admonitions in docs/
mkdocs build --strict                                Documentation built successfully (existing unnavved troubleshooting-page notices only)
shellcheck -S warning scripts/*.sh labs/*/check.sh enterprise-it-101/eit.sh   exit 0
```

`python3 scripts/validate-enterprise-coverage.py` and its fixture wrapper were also run. They currently fail on a pre-existing unrelated inventory entry, `labs/fixtures/wireless-core-operations`, which does not exist; this lab's own registration is valid under `lint-labs.py`.

## Limitations, refresh, and cleanup

- **Unsupported/evidence-only behavior:** static mTLS certificates are not posture or EDR; password grant is a deterministic CLI helper rather than browser automation; SSE/SASE PoP, CASB, SWG, DLP, continuous-risk scoring, and global availability are conceptual only.
- **Session semantics:** PEP calls Keycloak introspection per protected request. Disabling a user was rejected on the next request in the live run; access tokens have a 20-second lifespan. No claim is made about distributed cache delay.
- **Image review:** exact tags/digests recorded above; 2026-07-23 pull/build review found no mutable tag in this lab. Dependency vulnerability triage remains the monthly maintainer responsibility in the image policy.
- **Cleanup:** `containerlab destroy -t topology.clab.yml --cleanup`; `docker ps --format '{{.Names}}' | rg '^clab-zero-trust-secure-access-'` returned no rows; generated `runtime/` was cleared with a disposable Alpine container and is gitignored.
- **Follow-up:** correct the unrelated enterprise-coverage fixture path before treating its repository-wide validator gate as green.
